from google.appengine.api import users, xmpp
from google.appengine.ext import db
from google.appengine.ext.db import djangoforms

from django.http import HttpResponseRedirect
from django.shortcuts import render_to_response

from project import xmpp
from project.experts.models import User, Tag, Review
from project.experts.views.common import get_login_user

class ProfileForm(djangoforms.ModelForm):
    class Meta:
        model = User
        exclude = ('account', 'rating', 'rating_count')
    
def _update_tags_counts(old_tags, new_tags):
    old_tags = set(old_tags)
    new_tags = set(new_tags)
    for word in old_tags:
        if word not in new_tags:
            tag = db.GqlQuery('SELECT * FROM Tag WHERE name = :1', word).get()
            if tag:
                tag.count -= 1
                if tag.count > 0:
                    tag.put()
                else:
                    tag.delete()
    for word in new_tags:
        if word not in old_tags:
            tag = db.GqlQuery('SELECT * FROM Tag WHERE name = :1', word).get()
            if tag:
                tag.count += 1
            else:
                tag = Tag(name=word, count=1)
            tag.put()
                        
def index(request, account):
    user = get_login_user(request)
    if user.email() == account:
        status = ''
        if request.method == 'POST':
            old_tags = user.tags if user and user.tags else []
            form = ProfileForm(request.POST, instance=user)
            if form.is_valid():
                old_has_chat = user.has_chat
                user = form.save(commit=False)
                if user.tags:
                    user.tags = [x.lower() for x in user.tags if x]
                user.put()
                _update_tags_counts(old_tags, user.tags)
                
                status = 'Successfully saved the user profile'
                
                if not old_has_chat and user.has_chat:
                    if account.endswith('@gmail.com'):
                        xmpp.send_invite(account)
                        status = 'Successfully saved the user profile. Please accept chat invitation from flash-videoio@appspot.com'
                        
                if 'continue' in request.GET:
                    return HttpResponseRedirect(request.GET.get('continue'))
        else:
            if not user.name and user.account:
                user.name = user.account.nickname()
            form = ProfileForm(instance=user)
        return render_to_response('experts/myprofile.html', {'user': user, 'account': account, 
                'status': status, 'form': form, 'website': user.website})
    else:
        status = error_message = ''
        target = users.User(email=account)
        profile = db.GqlQuery('SELECT * FROM User WHERE account = :1', target).get()
        if profile and user.account and request.method == 'POST' and 'rating' in request.POST:
            rating, description = int(request.POST.get('rating')), request.POST.get('review')
            if description == 'Write review here!':
                description = ''
            review = db.GqlQuery('SELECT * FROM Review WHERE for_user = :1 AND by_user = :2', profile, user).get()
            if review:
                old_rating = review.rating
                review.rating = rating
                review.description = description
                if old_rating != rating:
                    if profile.rating_count == 0:
                        profile.rating_count = 1
                    profile.rating = (profile.rating*profile.rating_count - old_rating + rating)/profile.rating_count
            else:
                review = Review(for_user=profile, by_user=user, rating=rating, description=description)
                profile.rating = (profile.rating*profile.rating_count + rating)/(profile.rating_count + 1)
                profile.rating_count += 1
            review.put()
            profile.put()
            
        if profile:
            rating, rating_percent = '%.1f'%(profile.rating or 0.0,), int((profile.rating or 0.0)*20)
            reviews = db.GqlQuery('SELECT * FROM Review WHERE for_user = :1', profile).fetch(100)
            for review in reviews:
                review.rating_percent = int(review.rating * 20)
            allow_review = bool(user.account)
        else:
            rating, rating_percent, reviews, allow_review = 0, 0, [], False
        return render_to_response('experts/profile.html', {'user': user, 'account': account, 'profile': profile, 'status': status, 'error_message': error_message,
                    'reviews': reviews, 'rating': rating, 'rating_percent': rating_percent, 'allow_review': allow_review})
