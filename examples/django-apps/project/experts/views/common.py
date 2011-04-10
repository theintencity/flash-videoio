from google.appengine.api import users
from project.experts.models import get_current_user

def get_url(request):
    return 'http://' + request.META['HTTP_HOST'] + request.META['PATH_INFO'] + request.META['SCRIPT_NAME'] + ('?' + request.META['QUERY_STRING'] if request.META['QUERY_STRING'] else '')

def get_login_user(request):
    user = get_current_user()
    user.login_url = users.create_login_url(get_url(request))
    user.logout_url = users.create_logout_url(get_url(request))
    return user
    
def clean_html(string):
    return string and string.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;') or string
    
