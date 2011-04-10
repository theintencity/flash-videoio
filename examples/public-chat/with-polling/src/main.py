import os, datetime, time, logging

from google.appengine.api import users
from google.appengine.ext import webapp
from google.appengine.ext.webapp.util import run_wsgi_app
from google.appengine.ext import db 
from google.appengine.ext.webapp import template
from google.appengine.api import xmpp

from django.utils import simplejson as json
    
class MainPage(webapp.RequestHandler):
    def get(self):
#        user = users.get_current_user()
#        if not user:
#            self.redirect(users.create_login_url(self.request.uri))
#            return
        
        template_values = {}
        path = os.path.join(os.path.dirname(__file__), 'index.html')
        self.response.out.write(template.render(path, template_values))
        

    def post(self):
        msg = self.request.get("input")
        status_code = xmpp.send_message("internetvideocity@appspot.com/bot", msg)
        self.response.out.write("status=" + str(status_code) + \
                " presence=" + str(xmpp.get_presence("internetvideocity@appspot.com")))

class XMPPHandler(webapp.RequestHandler):
    def post(self):
        message = xmpp.Message(self.request.POST)
        logging.info(message.body)
        #if message.body[0:5].lower() == 'hello':
        #    message.reply("Greetings!")

class User(db.Model):
    location = db.StringProperty()
    name = db.StringProperty()
    clientId = db.StringProperty()
    extra = db.BlobProperty()
    lastmodified = db.DateTimeProperty(auto_now=True)
    def __repr__(self):
        return '<User location=%r clientId=%r name=%r lastmodified=%r len(extra)=%d />'%(self.location, self.clientId, self.name, self.lastmodified, len(self.extra) if self.extra else 0)

class Chat(db.Model):
    location = db.StringProperty()
    senderId = db.StringProperty()
    sender = db.StringProperty()
    targetId = db.StringProperty()
    timestamp = db.DateTimeProperty(auto_now_add=True)
    text = db.TextProperty()
    extra = db.BlobProperty()
    def __repr__(self):
        return '<Chat location=%r sender=%r target=%r timestamp=%r len(text)=%d len(extra)=%d />'%(self.location, self.sender, self.target, self.timestamp, len(self.text), len(self.extra) if self.extra else 0)

class Version(db.Model):
    location = db.StringProperty()
    chathistory = db.IntegerProperty()
    userlist = db.IntegerProperty()
    def __repr__(self):
        return '<Version location=%r chathistory=%r userlist=%r />'%(self.location, self.chathistory, self.userlist)
    
class UserList(webapp.RequestHandler):
    def get(self):
        location, since = self.request.get('location'), self.request.get('since')
        changeVersion = False
        for u in db.GqlQuery("SELECT * FROM User WHERE lastmodified < :1", datetime.datetime.fromtimestamp(time.time()-60)):
            logging.info('deleting expired %r'%(u,))
            changeVersion = True
            u.delete()
        if changeVersion:
            ver = db.GqlQuery("SELECT * FROM Version WHERE location = :1", location).get()
            if not ver:
                ver = Version(location=location, chathistory=0, userlist=0)
            ver.userlist = ver.userlist + 1
            logging.info('change to %r'%(ver,))
            ver.put()
        else:
            ver = db.GqlQuery("SELECT * FROM Version WHERE location = :1", location).get()
        logging.info('found %r'%(ver,))
        if not ver:
            found, ver = 0, Version(location=location, chathistory=0, userlist=0)
            ver.put()
        else:
            found = ver.userlist
        if found != 0 and str(found) == since:
            self.response.set_status(304)
        else:
            users = db.GqlQuery("SELECT * FROM User WHERE location = :1 ORDER BY lastmodified DESC", location)
            userlist = [{"clientId": u.clientId, 
                         "name": u.name, 
                         "extra": u.extra} for u in users]
            userlist = sorted(userlist, key=lambda u: str(u['name']).lower())
            result = json.dumps({"version": found, "userlist": userlist})
            logging.info('response ' + result)
            self.response.out.write(result)
        
    def post(self):
        location = self.request.get('location')
        changeVersion = False
        for u in db.GqlQuery("SELECT * FROM User WHERE lastmodified < :1", datetime.datetime.fromtimestamp(time.time()-60)):
            logging.info('deleting expired %r'%(u,))
            changeVersion = True
            u.delete()
        
        body = json.loads(self.request.body)
        clientId, name, extra = body['clientId'], body['name'], body['extra'] if 'extra' in body else None
        if extra == "null": extra = None
        if name == "null": name = None
        if extra and isinstance(extra, unicode):
            extra = extra.encode('utf-8')
        logging.info('body clientId='+ str(clientId) + ' name=' + str(name) + ' extra=' + str(extra))
        user = db.GqlQuery("SELECT * FROM User WHERE clientId = :1", clientId).get()
        if self.request.path.endswith('/delete'):
            logging.info('deleting %r'%(user,))
            if user:
                changeVersion = True
                user.delete()
        else:
            logging.info('found %r'%(user,))
            if not user:
                changeVersion = True
                user = User(location=location, name=name, clientId=clientId, extra=extra)
            else:
                if not changeVersion:
                    changeVersion = (user.location != location or user.name != name or user.extra != extra)
                user.location, user.name, user.extra = location, name, extra
            user.put()
        if changeVersion:
            ver = db.GqlQuery("SELECT * FROM Version WHERE location = :1", location).get()
            if not ver:
                ver = Version(location=location, chathistory=0, userlist=0)
            ver.userlist = ver.userlist + 1
            logging.info('change to %r'%(ver,))
            ver.put()
            
class ChatHistory(webapp.RequestHandler):
    def get(self):
        location, targetId, since = self.request.get('location'), self.request.get('targetId'), self.request.get('since')
        ver = db.GqlQuery("SELECT * FROM Version WHERE location = :1", location).get()
        logging.info('found %r'%(ver,))
        if not ver:
            found, ver = 0, Version(location=location, chathistory=0, userlist=0)
            ver.put()
        else:
            found = ver.chathistory
        if found != 0 and str(found) == since:
            self.response.set_status(304)
        else:
            chats = db.GqlQuery("SELECT * FROM Chat WHERE location = :1 ORDER BY timestamp DESC LIMIT 30", location)
            #for u in chats:
            #    logging.info("chat item " + u.senderId + " " + u.targetId + " " + u.text)
            chathistory = [{"senderId": u.senderId, 
                            "sender": u.sender, 
                            "targetId": u.targetId, 
                            "timestamp": time.mktime(u.timestamp.timetuple()), 
                            "text": u.text, 
                            "extra": u.extra} for u in chats]
            result = json.dumps({"version": found, "chathistory": [r for r in reversed(chathistory)]})
            logging.info('response ' + result)
            self.response.out.write(result)
            
    def post(self):
        location, targetId = self.request.get('location'), self.request.get('targetId')
        body = json.loads(self.request.body)
        senderId, sender, text, extra = body['senderId'], body['sender'], body['text'], body['extra'] if 'extra' in body else None
        if sender == "null": sender = "User " + str(senderId)
        if text == "null": text = None
        if extra == "null": extra = None
        if extra and isinstance(extra, unicode):
            extra = extra.encode('utf-8')
        logging.info('body senderId='+ str(senderId) + ' sender=' + str(sender) + ' text=' + str(text) + ' extra=' + str(extra))
        if text:
            chat = Chat(location=location, senderId=senderId, sender=sender, targetId=targetId, text=text, extra=extra)
            chat.put()
            
            ver = db.GqlQuery("SELECT * FROM Version WHERE location = :1", location).get()
            if not ver:
                ver = Version(location=location, chathistory=0, userlist=0)
            ver.chathistory = ver.chathistory + 1
            logging.info('change to %r'%(ver,))
            ver.put()
        
application = webapp.WSGIApplication([
    ('/_ah/xmpp/message/chat/', XMPPHandler), ('/', MainPage), 
    ('/userlist', UserList), ('/userlist/delete', UserList),
    ('/chathistory', ChatHistory),
    ], debug=True)


def main():
    run_wsgi_app(application)

if __name__ == "__main__":
    main()
