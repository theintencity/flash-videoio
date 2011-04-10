from django.conf.urls.defaults import *

# Uncomment the next two lines to enable the admin:
#from django.contrib import admin
#admin.autodiscover()

urlpatterns = patterns('project.experts.views',
    (r'^$', 'main.index'),
    (r'^search/', 'search.index'),
    (r'^(?P<account>[^\/]+)/profile/', 'profile.index'),
    (r'^(?P<account>[^\/]+)/calendar/(?P<tzoffset>[^\/]+)/(?P<date>[^\/]+)/edit/(?P<key>[^\/]+)/', 'cal.edit'),
    (r'^(?P<account>[^\/]+)/calendar/(?P<tzoffset>[^\/]+)/(?P<date>[^\/]+)/', 'cal.frame'),
    (r'^(?P<account>[^\/]+)/calendar/', 'cal.index'),
    (r'^(?P<account>[^\/]+)/talk/(?P<command>[^\/]+)/', 'talk.command'),
    (r'^(?P<account>[^\/]+)/talk/', 'talk.index'),
    (r'^initialize/', 'tests.create'),
)
