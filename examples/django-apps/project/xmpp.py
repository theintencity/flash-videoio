import logging, sys

from google.appengine.api import xmpp

from project.experts.views.talk import xmpp_handler as handler1 
from project.office.views import xmpp_handler as handler2
from django.http import HttpResponse, HttpResponseServerError, HttpResponseNotAllowed

def xmpp_handler(request):
    try:
        # logging.info('received xmpp_request %r'%(request,))
        if request.method == 'POST':
            message = xmpp.Message(request.POST)
            receiver, ignore, body = message.body.partition(' ')
            # logging.info(' receiver=%r body=%r'%(receiver, body))
            if '@' not in receiver:
                message.reply('Please start your message with email address of the receiver.')
            else:
                sender = message.sender.partition('/')[0]
                sent_count = 0
                for handler in [handler1, handler2]:
                    sent_count += handler(sender, receiver, body)
                if not sent_count:
                    message.reply('Could not send message to ' + receiver)
                elif sent_count == 1:
                    message.reply('Sent your message')
                else:
                    message.reply('Sent your message to %d session(s)'%(sent_count,))
            return HttpResponse()
        else:
            return HttpResponseNotAllowed()

    except:
        logging.info('xmpp_handler exception %r'%(sys.exc_info(),))
        return HttpResponseServerError()


