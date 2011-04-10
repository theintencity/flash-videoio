from google.appengine.api import users
from google.appengine.ext import db

from django.http import HttpResponse

from project.experts.models import User
    

def create(request):
    experts = '''
Kundan Singh
kundan10@gmail.com
+1-917-621-6392
http://www.google.com
San Francisco, CA, USA
An independent consultant in VoIP/SIP, Python, programming.
sip, voip, python, programming
Available on weekdays during work hours.

Bill Gates
bill@microsoft.com
+1-111-111-1111
http://microsoft.com
Redmond, WA, USA
Founder of Microsoft Inc.
Windows, software, programming
Not available.
'''
    response = []
    
    for para in experts.strip().split('\n\n'):
        if not para: continue
        name, email, phone, website, address, description, tags, availability = map(str.strip, para.strip().split('\n'))
        account = users.User(email=email)
        user = db.GqlQuery('SELECT * FROM User WHERE account = :1', account).get()
        if user:
            response.append('User ' + email + ' exists')
        else:
            user = User(name=name, account=account, phone=phone, website=website, address=address, description=description, 
                        tags=[x.strip() for x in tags.split(',') if x.strip()], availability=availability)
            user.put()
            response.append('Created User ' + email)
    
    return HttpResponse('<br/>'.join(response))
