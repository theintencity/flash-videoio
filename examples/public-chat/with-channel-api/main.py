# Copyright (c) 2010, Kundan Singh, all rights reserved.
#
# This is a public-chat application built using the Flash VideoIO component on Adobe 
# Stratus service and Google App Engine. This site is just a demonstration of how such 
# services can be built using the generic Flash-VideoIO component.
#
# This version of the project uses the Channel API available in Google App Engine for 
# asynchronous notifications of user list and chat history.
#
# Visit http://code.google.com/p/flash-videoio for more.

import os, datetime, time, logging

from google.appengine.ext import webapp
from google.appengine.ext.webapp.util import run_wsgi_app
from google.appengine.ext import db 
from google.appengine.ext.webapp import template
from google.appengine.api import channel

from django.utils import simplejson as json
    
# The main page at / just returns index.html.
class MainPage(webapp.RequestHandler):
    def get(self):
        path = os.path.join(os.path.dirname(__file__), 'index.html')
        self.response.out.write(template.render(path, {}))

# POST /create/
# Request: {"senderId": "client-id-of-sender"}
# Response: {"token", "new-channel-token-for-clientId-as-stream"}
class Create(webapp.RequestHandler):
    def post(self):
        data = json.loads(self.request.body)
        data = {'token': channel.create_channel(data['senderId'])}
        self.response.out.write(json.dumps(data))
   
# Data model to store connected clients and their locations.
class User(db.Model):
    location = db.StringProperty()
    name = db.StringProperty()
    clientId = db.StringProperty()
    extra = db.BlobProperty()
    lastmodified = db.DateTimeProperty(auto_now=True)
    def get_object(self):
        return {'name': self.name, 'clientId': self.clientId, 'extra': self.extra}
    def __repr__(self):
        return '<User location=%r clientId=%r name=%r lastmodified=%r len(extra)=%d />'%(self.location, self.clientId, self.name, self.lastmodified, len(self.extra) if self.extra else 0)

# Data model to store chat message in a location.
class Chat(db.Model):
    location = db.StringProperty()
    senderId = db.StringProperty()
    sender = db.StringProperty()
    targetId = db.StringProperty()
    timestamp = db.DateTimeProperty(auto_now_add=True)
    text = db.TextProperty()
    extra = db.BlobProperty()
    def get_object(self):
        return {'senderId': self.senderId, 'sender': self.sender, 'targetId': self.targetId, 
                'timestamp': time.mktime(self.timestamp.timetuple()), 
                'text': self.text, 'extra': self.extra}
    def __repr__(self):
        return '<Chat location=%r sender=%r targetId=%r timestamp=%r len(text)=%d len(extra)=%d />'%(self.location, self.sender, self.targetId, self.timestamp, len(self.text), len(self.extra) if self.extra else 0)

# GET /userlist/?location={location}
# Response: {"userlist": [... list of {"name":..., "clientId":..., "extra":...}]
# POST /userlist/?location={location}
# Request: {"clientId":..., "name":..., "extra":...} 
class UserList(webapp.RequestHandler):
    def get(self):
        location = self.request.get('location')
        userlist = [u.get_object() for u in db.GqlQuery('SELECT * FROM User WHERE location = :1', location)]
        # logging.debug("userlist returns: " + json.dumps({'userlist': userlist}))
        self.response.out.write(json.dumps({'userlist': userlist}))
        
    def post(self):
        expired_users = [u for u in db.GqlQuery('SELECT * FROM User WHERE lastmodified < :1', datetime.datetime.fromtimestamp(time.time()-90))]
        added_users, removed_users = [], [u.get_object() for u in expired_users]
        [u.delete() for u in expired_users]
        
        location, body = self.request.get('location'), json.loads(self.request.body)
        clientId, name, extra = body['clientId'], body['name'], body.get('extra', None)
        if extra == 'null': extra = None
        if name == 'null': name = None
        if extra and isinstance(extra, unicode):
            extra = extra.encode('utf-8')

        user = db.GqlQuery('SELECT * FROM User WHERE clientId = :1', clientId).get()
        if self.request.path.endswith('/delete/'):
            if user:
                removed_users.append(user.get_object())
                user.delete()
        else:
            if not user:
                user = User(location=location, name=name, clientId=clientId, extra=extra)
                added_users.append(user.get_object())
            else:
                changed = (user.location != location or user.name != name or user.extra != extra)
                if changed:
                    user.location, user.name, user.extra = location, name, extra
                    added_users.append(user.get_object())
            user.put()
            
        if added_users or removed_users:
            data = json.dumps({'method': 'userlist', 'added': added_users, 'removed': removed_users})
            for u in db.GqlQuery('SELECT * FROM User WHERE location = :1', location):
                try:
                    channel.send_message(u.clientId, data)
                except channel.InvalidChannelClientIdError:
                    pass # ignore the exception
                    
# GET /chathistory/?location={location}&target={targetId}
# Response: {"chathistory": [... list of {"senderId":...,"sender":...,"targetId":...,"timestamp":...,"text":...,"extra":...}]
# POST /chathistory?location={location}[&target={targetId}]
# Request: {"senderId":..., "sender":..., "text":..., "extra":...}          
class ChatHistory(webapp.RequestHandler):
    def get(self):
        location, targetId = self.request.get('location'), self.request.get('targetId')
        chats = [u for u in db.GqlQuery('SELECT * FROM Chat WHERE location = :1 ORDER BY timestamp DESC LIMIT 30', location)]
        # logging.debug('result=' + str(chats))
        chathistory = [u.get_object() for u in chats if not u.targetId or u.targetId == targetId]
        result = json.dumps({'chathistory': [r for r in reversed(chathistory)]})
        self.response.out.write(result)
            
    def post(self):
        location, targetId, body = self.request.get('location'), self.request.get('targetId'), json.loads(self.request.body)
        senderId, sender, text, extra = body['senderId'], body['sender'], body['text'], body['extra'] if 'extra' in body else None
        if sender == "null": sender = "User " + str(senderId)
        if text == "null": text = None
        if extra == "null": extra = None
        if targetId == "null" or targetId == "": targetId = None
        if extra and isinstance(extra, unicode):
            extra = extra.encode('utf-8')

        if text:
            chat = Chat(location=location, senderId=senderId, sender=sender, targetId=targetId, text=text, extra=extra)
            chat.put()
            
            data = json.dumps({'method': 'chathistory', 'added': [chat.get_object()]})
            if not targetId:
                for u in db.GqlQuery('SELECT * FROM User WHERE location = :1', location):
                    try:
                        channel.send_message(u.clientId, data)
                    except channel.InvalidChannelClientIdError:
                        pass # ignore the error
            else:
                target = db.GqlQuery('SELECT * FROM User WHERE clientId = :1', targetId).get()
                if target:
                    try:
                        channel.send_message(target.clientId, data)
                    except channel.InvalidChannelClientIdError:
                        pass # ignore the error
                else:
                    self.response.set_status(404)
        

def main():
    logging.getLogger().setLevel(logging.DEBUG)
    application = webapp.WSGIApplication([
        ('/', MainPage), ('/create/', Create),
        ('/userlist/delete/', UserList), ('/userlist/', UserList), 
        ('/chathistory/', ChatHistory),
    ], debug=True)
    run_wsgi_app(application)

if __name__ == "__main__":
    main()
