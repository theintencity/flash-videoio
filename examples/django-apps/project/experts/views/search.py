from google.appengine.api import users
from google.appengine.ext import db

from django.shortcuts import render_to_response

from project.experts.views.common import get_login_user, clean_html

def search_result(user): # what to display in search result
    return u'''
    <li>
        <a href="/experts/%s/calendar" title="View calendar"><img src="/static/media/img/admin/icon_calendar.gif"></img></a>
        <b><a href="/experts/%s/profile" title="View profile">%s</a></b>: %s
        <div class="rating_bar" style="float: right;" title="%.1f stars of %d reviews">
          <div style="width:%d%%"></div>
        </div>
        <blockquote>%s%s</blockquote>
    </li>
    '''%(user.email(), user.email(), user.name, (', '.join(user.tags))[:100], 
         user.rating or 0.0, user.rating_count, int((user.rating or 0.0) * 20),
         ('%s %s %s<br/>'%(clean_html(user.phone_number) or '', 
                           user.website and '<a href="' + clean_html(user.website) + '">' + clean_html(user.website) + '</a>' or '', 
                           clean_html(user.address) or '')) if user.phone_number or user.address or user.website else '',
         clean_html(user.description) or 'No description')
    
def index(request):
    user = get_login_user(request)
    error_message = status = ''
    q = request.GET.get('q', '')
    limit = int(request.GET.get('limit', '10'))
    offset = int(request.GET.get('offset', '0'))
    if ':' not in q:
        tags = [x for x in q.split(' ') if x]
        if tags:
            query = 'SELECT * FROM User WHERE ' + ' AND '.join(['tags = :%d'%(i+1,) for i, x in enumerate(tags)]) + ' ORDER BY rating DESC'
            result = db.GqlQuery(query, *tags).fetch(limit, offset)
            result = [search_result(u) for u in result]
        else:
            result = []
    else:
        attr, value = [x.strip() for x in q.split(':', 1)]
        if attr not in ('name', 'email', 'phone'):
            error_message = 'Invalid attribute "%s", must be one of name, email or phone.'%(attr,)
        else:
            if attr == 'name':
                query, arg = 'SELECT * FROM User WHERE name = :1', value
            elif attr == 'email':
                query, arg = 'SELECT * FROM User WHERE account = :1', users.User(email=value)
            elif attr == 'phone':
                query, arg = 'SELECT * FROM User WHERE phone_number = :1', value
                
            result = db.GqlQuery(query, arg).fetch(limit, offset)
            result = [search_result(u) for u in result]
            if not result:
                error_message = 'No match found. Please enter case sensitive exact value instead of "%s"'%(value,)
                
    return render_to_response('experts/search.html', 
            {'user': user, 'status': status, 'error_message': error_message, 
             'query': q, 'result': result})
    
