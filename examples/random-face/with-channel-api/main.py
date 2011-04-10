# Copyright (c) 2010, Kundan Singh, all rights reserved.
#
# This is a chatroulette-type application built using the Flash VideoIO component on Adobe 
# Stratus service and Google App Engine. This site is just a demonstration of how such 
# services can be built using the generic Flash-VideoIO component, and not meant for 
# production use.
#
# When you land on this page, it prompts you for some nickname, and starts publishing your 
# audio and video stream, after you approve the device access. It tries to connect you with 
# another person who is also on the page publishing his or her video. The status of the 
# connection is displayed in the chat history area. You can also type a message to send 
# to the person you are talking with.
#
# It uses Google App Engine for all session initiation and discovery of other users, and 
# Adobe Stratus to do media negotiation for peer-to-peer media streams. The project contains 
# one HTML file with some javascript and one Python file, with about 400 lines total. There 
# is no authentication, but is easy to add using Google App Engine. You can right-click on 
# this page to view the HTML and javascript source code which contributes to all front-end 
# interactions and shows how to use Flash-VideoIO for chatroulette type applications.
#
# This version of the project uses the Channel API available in Google App Engine for 
# asynchronous notifications of connections, disconnections and chat messages.
#
# Visit http://code.google.com/p/flash-videoio for more.

import os, random, datetime, time, logging

from google.appengine.ext import webapp
from google.appengine.ext.webapp.util import run_wsgi_app
from google.appengine.ext import db 
from google.appengine.ext.webapp import template
from google.appengine.api import channel

from django.utils import simplejson as json

# The individual user. This is created on /login/ and destroyed on /logout/ or
# when expired -- not refreshed for 90 seconds.
#   stream -- the user's stream (unique/random) used as clientId
#   publish -- VideoIO URL to play this user's stream.
#   play -- VideoIO URL that user is connected to.
#   lastmodified -- when was this user login refreshed.
class User(db.Model):
    stream = db.StringProperty()
    publish = db.StringProperty()
    play = db.StringProperty()
    lastmodified = db.DateTimeProperty(auto_now=True)
    
# The main page just return index.html.
class MainPage(webapp.RequestHandler):
    def get(self):
        path = os.path.join(os.path.dirname(__file__), 'index.html')
        self.response.out.write(template.render(path, {}))
        
# Clean up the given user by removing the connection he has and sending the
# updated connect message to his previous connection. If delete is set then
# it also deletes the user.
def cleanup_user(user, delete=True):
    #logging.debug('clean_user ' + user.stream)
    if user.play:
        other = db.GqlQuery('SELECT * FROM User WHERE publish = :1', user.play).get()
        if other: 
            other.play = None
            other.put()
            data = {'method': 'connect', 'play': None}
            try:
                channel.send_message(other.stream, json.dumps(data))
            except channel.InvalidChannelClientIdError:
                logging.warn('InvalidChannelClientIdError: ' + other.stream + ' ' + other.stream)
                other.delete()
        user.play = None
        
    if delete:
        user.delete()

# POST /logout/?stream={stream} 
class Logout(webapp.RequestHandler):
    def post(self):
        user = db.GqlQuery('SELECT * FROM User WHERE stream = :1', self.request.get('stream')).get()
        if not user:
            self.response.set_status(404, 'Stream Not Found')
        else:
            cleanup_user(user)

# POST /create/?stream={stream}
# Response: {"token", "new-channel-token-for-clientId-as-stream"}
class Create(webapp.RequestHandler):
    def post(self):
        stream = self.request.get('stream')
        data = {'token': channel.create_channel(stream)}
        self.response.out.write(json.dumps(data))
   
# POST /login/?stream={stream}[&change=true]
# Request: {"publish": "VideoIO-url-that-can-be-used-to-play-user's-local-video"}
# Response: {"play": "VideoIO-url-that-this-user-should-play"}
# If change is set, then it disconnects previous connection and attempts a new
# connection, to random person. It also cleans up expired User objects before handling.     
class Login(webapp.RequestHandler):
    def post(self):
        users = db.GqlQuery('SELECT * FROM User WHERE lastmodified < :1', datetime.datetime.fromtimestamp(time.time()-90))
        if users:
            for user in users:
                cleanup_user(user)
                    
        
        change = bool(self.request.get('change') == 'true')
        data = json.loads(self.request.body)
        user = db.GqlQuery('SELECT * FROM User WHERE stream = :1', self.request.get('stream')).get()
        if not user:
            user = User()
            user.stream = self.request.get('stream')
            user.publish = data['publish'] 
            user.put()
        
        to_send = False
        if change:
            cleanup_user(user, delete=False)
            to_send = True
        if not user.play:
            count = db.GqlQuery('SELECT * FROM User WHERE publish != :1 AND play = :2', user.publish, None).count()
            if count > 0:
                r = random.randint(0, count-1)
                others = db.GqlQuery('SELECT * FROM User WHERE publish != :1 AND play = :2', user.publish, None).fetch(1, r)
                if others:
                    other = others[0]
                    other.play, user.play = user.publish, other.publish
                    #logging.debug('connecting ' + user.stream + ' ' + other.stream)
                    data = {'method': 'connect', 'play': user.play}
                    try:
                        channel.send_message(user.stream, json.dumps(data))
                    except channel.InvalidChannelClientIdError:
                        logging.warn('InvalidChannelClientIdError: ' + user.stream + ' ' + user.stream)
                        user.play = other.play = None
                    data = {'method': 'connect', 'play': other.play}
                    try:
                        channel.send_message(other.stream, json.dumps(data))
                    except channel.InvalidChannelClientIdError:
                        logging.warn('InvalidChannelClientIdError: ' + other.stream + ' ' + other.stream)
                        user.play = other.play = None
                        other.delete() 
                    other.put()
                    user.put()
                    to_send = False
            #else:
                #logging.debug('no other stream found')
        if to_send:
            user.put()
            data = {'method': 'connect', 'play': user.play}
            try:
                channel.send_message(user.stream, json.dumps(data))
            except channel.InvalidChannelClientIdError:
                logging.warn('InvalidChannelClientIdError: ' + user.stream + ' ' + user.stream)
                cleanup_user(user)
                
        data = {'play': user.play}
        self.response.out.write(json.dumps(data))

# POST /send/?stream={stream}
# Request: {"dest": "VideoIO-url-that-this-user-is-connected-to", "body": "text-message"}
# Send the text message to the target user identified by his VideoIO URL.
class Send(webapp.RequestHandler):
    def post(self):
        data = json.loads(self.request.body)
        user = db.GqlQuery('SELECT * FROM User WHERE stream = :1', self.request.get('stream')).get()
        if not user:
            self.response.set_status(404, 'Stream Not Found')
        elif not user.play:
            self.response.set_status(404, 'Stream Not Connected')
        elif user.play != data['dest']:
            self.response.set_status(404, 'Destination Not Found')
        else:
            other = db.GqlQuery('SELECT * FROM User WHERE publish = :1', user.play).get()
            if not other:
                self.response.set_status(404, 'Other Person Left')
            else:
                data = {'method': 'send', 'body': data['body']}
                try:
                    channel.send_message(other.stream, json.dumps(data))
                except channel.InvalidChannelClientIdError:
                    logging.warn('InvalidChannelClientIdError: ' + other.stream + ' ' + other.stream)
                    cleanup_user(other)


def main():
    logging.getLogger().setLevel(logging.DEBUG)
    application = webapp.WSGIApplication([
        ('/', MainPage), ('/login/', Login), ('/logout/', Logout), 
        ('/create/', Create), ('/send/', Send), 
    ], debug=True)
    run_wsgi_app(application)


if __name__ == "__main__":
    main()
