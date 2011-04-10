import datetime
from google.appengine.api import users
from google.appengine.ext import db

class User(db.Model):
    name = db.StringProperty('Full Name')
    account = db.UserProperty()
    phone_number = db.PhoneNumberProperty('Phone Number')
    address = db.PostalAddressProperty('Postal Address')
    website = db.StringProperty('Homepage URL')
    description = db.TextProperty('Brief Biography')
    rating = db.FloatProperty(default=0.0)
    rating_count = db.IntegerProperty(default=0)
    tags = db.StringListProperty('Expertise, one per line', default=None)
    availability = db.TextProperty('Availability', default='Available by appointment on weekdays in PST timezone')
    has_chat = db.BooleanProperty('Use Google Chat', default=False)
    
    def email(self):
        result = self.account.nickname() if self.account else ''
        return (result + '@gmail.com') if result and '@' not in result else result

def get_current_user():
    account = users.get_current_user()
    if account:
        user = db.GqlQuery('SELECT * FROM User WHERE account = :1', account).get()
        if not user:
            user = User(name='', account=account)
            user.put()
        user.is_active = True
        user.is_staff = users.is_current_user_admin()
    else:
        user = User()
        user.is_active = False
    return user

class Tag(db.Model):
    name = db.StringProperty(required=True)
    count = db.IntegerProperty(default=1)
    
class Event(db.Model):
    subject = db.StringProperty()
    description = db.TextProperty()
    owner = db.StringProperty()
    visitor = db.StringProperty()
    start_time = db.DateTimeProperty()
    end_time = db.DateTimeProperty()
    created_on = db.DateTimeProperty(auto_now_add=True)

class Review(db.Model):
    event = db.ReferenceProperty(Event, collection_name='event_set') # TODO make required=True
    for_user = db.ReferenceProperty(User, required=True, collection_name='for_user_set')
    by_user = db.ReferenceProperty(User, required=True, collection_name='by_user_set')
    rating = db.IntegerProperty(default=3)
    description = db.TextProperty()
    modified_on = db.DateTimeProperty(auto_now=True)

class ClientStream(db.Model):
    clientId = db.StringProperty(required=True)
    visitor = db.StringProperty()
    name = db.StringProperty(default='Anonymous')
    
    publish = db.StringProperty(required=True)
    play = db.StringProperty()

    is_owner = db.BooleanProperty(default=False)
    owner = db.StringProperty(required=True)
    
    modified_on = db.DateTimeProperty(auto_now=True)
    created_on = db.DateTimeProperty(auto_now_add=True)
    
    def __repr__(self):
        return '<ClientStream clientId=%r visitor=%r name=%r is_owner=%r owner=%r />'%(self.clientId, self.visitor, self.name, self.is_owner, self.owner)
    
    def get_object(self, full=True):
        if full:
            return {'clientId': self.clientId, 'name': self.name, 'url': self.publish}
        else:
            return {'clientId': self.clientId}

class OfflineMessage(db.Model):
    sender = db.StringProperty()
    senderName = db.StringProperty()
    receiver = db.StringProperty()
    text = db.StringProperty(multiline=True)
    created_on = db.DateTimeProperty(auto_now_add=True)
    
    def __repr__(self):
        return '<OfflineMessage sender=%r senderName=%r receiver=%r text=%r />'%(self.sender, self.senderName, self.receiver, self.text)
    def get_object(self):
        return {'senderName': self.senderName, 'text': self.text}
     
    
    
    