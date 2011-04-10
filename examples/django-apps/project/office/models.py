from google.appengine.ext import db

class Owner(db.Model):
    email = db.StringProperty(required=True)
    gtalk = db.BooleanProperty(default=True)
    
    def __repr__(self):
        return '<Owner email=%r gtalk=%r />'%(self.email, self.gtalk)

class Visitor(db.Model):
    clientId = db.StringProperty(required=True)
    email = db.StringProperty()
    name = db.StringProperty(default='Anonymous')
    purpose = db.StringProperty()
    
    publish = db.StringProperty()
    play = db.StringProperty()
    
    is_owner = db.BooleanProperty(default=False)
    owner = db.StringProperty(required=True)
    
    modified_on = db.DateTimeProperty(auto_now=True)

    def __repr__(self):
        return '<Visitor clientId=%r email=%r name=%r is_owner=%r owner=%r />'%(self.clientId, self.email, self.name, self.is_owner, self.owner)
    
    def get_object(self, full=True):
        if full:
            return {'clientId': self.clientId, 'name': self.name, 'url': self.publish, 'purpose': self.purpose}
        else:
            return {'clientId': self.clientId}
        
class Message(db.Model):
    sender = db.StringProperty()
    senderName = db.StringProperty()
    receiver = db.StringProperty()
    text = db.StringProperty(multiline=True)
    created_on = db.DateTimeProperty(auto_now_add=True)
    
    def __repr__(self):
        return '<Message sender=%r senderName=%r receiver=%r text=%r />'%(self.sender, self.senderName, self.receiver, self.text)
    
    def get_object(self):
        return {'senderName': self.senderName, 'text': self.text}
     
    
    
    