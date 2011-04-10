from django.conf.urls.defaults import *
from project.xmpp import xmpp_handler

# Uncomment the next two lines to enable the admin:
#from django.contrib import admin
#admin.autodiscover()

urlpatterns = patterns('',
    # Example:
    # (r'^chat/', include('project.chat.urls')),
    # (r'^random/', include('project.random.urls')),
    (r'^office/', include('project.office.urls')),
    (r'^experts/', include('project.experts.urls')),
    # (r'^talk2me/', include('project.talk2me.urls')),
    
    ('^_ah/xmpp/message/chat/', 'project.xmpp.xmpp_handler'),
    
    # Uncomment the admin/doc line below and add 'django.contrib.admindocs' 
    # to INSTALLED_APPS to enable admin documentation:
    # (r'^admin/doc/', include('django.contrib.admindocs.urls')),

    # Uncomment the next line to enable the admin:
    #(r'^admin/', include(admin.site.urls)),
)
