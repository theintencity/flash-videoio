import random

from google.appengine.ext import db

from django.http import HttpResponseRedirect
from django.shortcuts import render_to_response

from project.experts.views.common import get_login_user, get_url
    
def _get_popular_topics(max_count=10):
    tags = db.GqlQuery('SELECT * FROM Tag ORDER BY count DESC').fetch(max_count)
    return [x.name for x in tags]

def _get_featured_experts(max_count=4, tags_count=2):
    experts = db.GqlQuery('SELECT * FROM User ORDER BY rating DESC').fetch(max_count * 4)
    experts = random.sample(experts, min(max_count, len(experts)))
    return [{'email': u.email(), 
             'name': u.name, 
             'tags': ', '.join(random.sample(u.tags, min(tags_count, len(u.tags))))} for u in experts]

def index(request):
    user = get_login_user(request)
    if not user.is_active or user.name:
        popular_topics = _get_popular_topics()
        featured_experts = _get_featured_experts()
        return render_to_response('experts/index.html', 
                {'user': user, 'popular_topics': popular_topics, 'featured_experts': featured_experts})
    else:
        return HttpResponseRedirect('/experts/%s/profile?continue=%s'%(user.email(), get_url(request)))
    
