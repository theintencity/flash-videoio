import os, random, datetime, time

from google.appengine.api import users
from google.appengine.ext import webapp
from google.appengine.ext.webapp.util import run_wsgi_app
from google.appengine.ext import db 
from google.appengine.ext.webapp import template

class Stream(db.Model):
    publish = db.StringProperty()
    play = db.StringProperty()
    lastmodified = db.DateTimeProperty(auto_now=True)

class Message(db.Model):
    receiver = db.StringProperty()
    content = db.StringProperty(multiline=True)
     
class Call(db.Model):
    first = db.Key()
    second = db.Key()

class MainPage(webapp.RequestHandler):
    def get(self):
        template_values = {}
        path = os.path.join(os.path.dirname(__file__), 'index.html')
        self.response.out.write(template.render(path, template_values))
        
class Logout(webapp.RequestHandler):
    def post(self):
        publish = self.request.body
        streams = db.GqlQuery("SELECT * FROM Stream WHERE publish = :1", publish)
        if streams:
            for stream in streams:
                if stream.play:
                    other = db.GqlQuery("SELECT * FROM Stream WHERE publish = :1", stream.play).get()
                    if other:
                        other.play = None
                        other.put()
                stream.delete()

class Publish(webapp.RequestHandler):
    def post(self):
        # first delete any expired datetime
        streams = db.GqlQuery("SELECT * FROM Stream WHERE lastmodified < :1", datetime.datetime.fromtimestamp(time.time()-60))
        if streams:
            for stream in streams:
                if stream.play:
                    other = db.GqlQuery("SELECT * FROM Stream WHERE publish = :1", stream.play).get()
                    if other:
                        other.play = None
                        other.put()
                stream.delete()
        
        stream = db.GqlQuery("SELECT * FROM Stream WHERE publish = :1", self.request.body).get()
        if not stream:
            stream = Stream()
            stream.publish = self.request.body
            stream.put()
        if self.request.get("change"):
            if stream.play:
                other = db.GqlQuery("SELECT * FROM Stream WHERE publish = :1", stream.play).get()
                if other:
                    other.play = None
                    other.put()
                stream.play = None
                stream.put()
        if not stream.play:
            count = db.GqlQuery("SELECT * FROM Stream WHERE publish != :1 AND play = :2", stream.publish, None).count()
            if count > 0:
                r = random.randint(0, count-1)
                other = db.GqlQuery("SELECT * FROM Stream WHERE publish != :1 AND play = :2", stream.publish, None).fetch(1, r)
                if other:
                    other[0].play, stream.play = stream.publish, other[0].publish
                    other[0].put()
                    stream.put()
            
        if stream.play:
            self.response.headers['Content-Type'] = 'text/plain'
            self.response.out.write(stream.play)
            
            msgs = db.GqlQuery("SELECT * FROM Message WHERE receiver = :1", stream.publish)
            if msgs:
                for msg in msgs:
                    self.response.out.write("\n" + msg.content)
                db.delete(msgs)

class Send(webapp.RequestHandler):
    def post(self):
        body = self.request.body
        receiver, ignore, content = body.partition("\n")
        msg = Message()
        msg.receiver = receiver
        msg.content = content
        msg.put()

application = webapp.WSGIApplication([
    ('/', MainPage), ('/logout', Logout), 
    ('/publish', Publish), ('/send', Send),
    ], debug=True)


def main():
    run_wsgi_app(application)


if __name__ == "__main__":
    main()
