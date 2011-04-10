import datetime, time, random, logging, sys, traceback

from google.appengine.api import users, channel, xmpp
from google.appengine.ext import db

from django.http import HttpResponse, HttpResponseServerError, HttpResponseForbidden
from django.shortcuts import render_to_response
from django.utils import simplejson as json

from project.experts.models import ClientStream, OfflineMessage
from project.experts.views.common import get_login_user

def index(request, account):
    user = get_login_user(request)
    stream = str(random.randint(100000000, 999999999))
    token = channel.create_channel(stream)
    
    is_my_office = bool(user.email() == account)
    if is_my_office:
        profile = user
    else:
        target = users.User(email=account)
        profile = db.GqlQuery('SELECT * FROM User WHERE account = :1', target).get()
    return render_to_response('experts/talk.html',
            {'user': user, 'profile': profile, 'account': account, 
             'stream': stream, 'token': token, 'is_my_office': is_my_office})

# All GQL queries are done in separate methods.

def get_stream(clientId):
    return db.GqlQuery('SELECT * FROM ClientStream WHERE clientId = :1', clientId).get()

def get_stream_by_publish(url):
    return db.GqlQuery('SELECT * FROM ClientStream WHERE publish = :1', url).get()

def get_streams_of_owner(owner):
    return db.GqlQuery('SELECT * FROM ClientStream WHERE owner = :1 AND is_owner = :2', owner, True)

def get_streams_of_visitors(owner):
    return db.GqlQuery('SELECT * FROM ClientStream WHERE owner = :1 AND is_owner = :2', owner, False)

def get_streams_of_owner_by_visitor(owner, visitor):
    return db.GqlQuery('SELECT * FROM ClientStream WHERE owner = :1 AND visitor = :2 AND is_owner = :3', owner, visitor, False)
    
def get_streams_expired():
    return db.GqlQuery('SELECT * FROM ClientStream WHERE modified_on < :1', datetime.datetime.fromtimestamp(time.time()-90))

def get_messages_of_owner(owner):
    return db.GqlQuery('SELECT * FROM OfflineMessage WHERE receiver = :1 ORDER BY created_on', owner)
        

# All channel messages are created in separate methods.

def get_disconnect_message():
    return json.dumps({'method': 'connect', 'clientId': None, 'url': None})

def get_connect_message(stream):
    return json.dumps({'method': 'connect', 'clientId': stream.clientId, 'name': stream.name, 'url': stream.publish})

def get_userlist_message(added=None, removed=None):
    added, removed = added or [], removed or []
    return json.dumps({'method': 'userlist', 'added': [x.get_object() for x in added], 'removed': [x.get_object(full=False) for x in removed]})

def get_send_message(senderId, senderName, text):
    return json.dumps({'method':'send', 'senderId': senderId, 'senderName': senderName, 'text': text })

def get_send_error_message(error):
    return json.dumps({'method':'send', 'senderId': None, 'senderName': 'System', 'text': error})

def send_message(stream, data):
    try:
        # logging.info('send_message %r %r'%(stream.clientId, data))
        channel.send_message(stream.clientId, data)
    except channel.InvalidChannelClientIdError:
        pass

# Send a message using xmpp to the google chat user.
def send_message_to_google_chat(email, msg):
    if email.endswith('@gmail.com'):
        target = users.User(email=email)
        target = db.GqlQuery('SELECT * FROM User WHERE account = :1', target).get()
        if target and target.has_chat:
            xmpp.send_message(email, msg)

def xmpp_handler(sender, receiver, body):
    data = get_send_message('0', sender + ' (via Google chat)', body)
    count = 0
    if receiver[0] == '@':
        stream = get_stream(receiver[1:])
        if stream:
            send_message(stream, data)
            count = 1
    elif '@' in receiver:
        for stream in get_streams_of_owner_by_visitor(sender, receiver):
            send_message(stream, data)
            count += 1
    return count


# Clean up the given stream by disconnecting it's other participant,
# and if delete is set, also delete this stream.
def cleanup_stream(stream, delete=True):
    if stream.play:
        other = get_stream_by_publish(stream.play)
        if other:
            if other.play:
                send_message(other, get_disconnect_message())
            other.play = None
            other.put()
    if delete:
        # logging.info('cleanup_stream deleting %r'%(stream.clientId,))
        stream.delete()
    else:
        stream.play = None
        stream.put()
        send_message(stream, get_disconnect_message())

# update the visitors list by sending userlist message to the owner
def update_visitors(owner, added=None, removed=None):
    data = get_userlist_message(added, removed)
    for stream in get_streams_of_owner(owner):
        send_message(stream, data)
    
def command(request, account, command):
    try:
        return command_safe(request, account, command)
    except:
        type, value, tb = sys.exc_info()
        printable = '\n'.join(traceback.format_exception(type, value, tb))
        logging.info('exception in %s: %s'%(command, printable))
        return HttpResponseServerError('Exception: ' + printable)
    
def command_safe(request, account, command):
    user = get_login_user(request)
    is_my_office = bool(user.email() == account)
    if request.method == 'POST':
#        for stream in db.GqlQuery('SELECT * FROM ClientStream'):
#            logging.info('  stream: ' + str(stream))
        input = json.loads(request.raw_post_data)
        
        if command == 'end':
            stream = get_stream(input['clientId'])
            if stream:
                if stream.visitor and stream.visitor != user.email():
                    return HttpResponseForbidden() # do not allow removal by others
                cleanup_stream(stream)
                if not is_my_office:
                    update_visitors(account, removed=[stream])
                
        elif command == 'accept' or command == 'reject':
            if not is_my_office:
                # logging.info('found accept/reject without is_my_office')
                return HttpResponseForbidden()
            
            mine = get_stream(input['clientId'])
            yours = get_stream(input['targetId'])
            # logging.info('command=%r\n mine=%r\n yours=%r\n input=%r'%(command, mine, yours, input))
            
            # disconnect previous participant when accepting a new one
            if mine and command == 'accept' and mine.play and (not yours or mine.play != yours.publish):
                # logging.info('deleting previous partner %r'%(mine.play,))
                previous = get_stream_by_publish(mine.play)
                if previous:
                    previous.play = None
                    previous.put()
                    send_message(previous, get_disconnect_message())
                mine.play = None
                
            # now connect mine and yours streams
            if mine and yours:
                if command == 'accept' and not mine.play and not yours.play:
                    # logging.info('connecting %r and %r'%(mine.clientId, yours.clientId))
                    mine.play, yours.play = yours.publish, mine.publish
                elif command == 'reject' and (mine.play == yours.publish or yours.play == mine.publish):
                    # logging.info('disconnecting %r and %r'%(mine.clientId, yours.clientId))
                    mine.play = yours.play = None
                mine.put()
                yours.put()
                if command == 'accept':
                    send_message(mine, get_connect_message(yours))
                    send_message(yours, get_connect_message(mine))
                elif command == 'reject':
                    send_message(mine, get_disconnect_message())
                    send_message(yours, get_disconnect_message())
            else:
                return HttpResponseServerError('Some data on the server is not valid')
                    
        elif command == 'send':
            # logging.info(' send input = %r'%(input,))
            sender, senderName, text = get_stream(input['senderId']), input['senderName'], input['text']
            if sender and sender.visitor and sender.visitor != user.email():
                # logging.info('sender is invalid %r, user=%r'%(sender, user.email()))
                return HttpResponseForbidden() # do not allow by others
            if 'receiver' in input:
                # send an inline message to the stream, and on error send back error message
                receiver = get_stream_by_publish(input['receiver'])
                if receiver:
                    # logging.info(' sending message to receiver %r'%(receiver,))
                    send_message(receiver, get_send_message(sender.clientId, senderName, text))
                else:
                    # logging.info(' did not find receiver')
                    send_message(sender, get_send_error_message('Did not send message because you are not connected'))
            if 'owner' in input and input['owner'] == account:
                # put a message to all streams of this user
                receivers = get_streams_of_owner(input['owner'])
                sent_count = 0
                for receiver in receivers:
                    input['senderName'] += ' (not connected)'
                    send_message(receiver, get_send_message(sender.clientId, senderName + ' (not connected)', text))
                    sent_count += 1
                    
                # put offline message if it could not be sent to existing streams
                if sent_count == 0:
                    msg = OfflineMessage(sender=user.email(), senderName=senderName + ' (offline message)', receiver=input['owner'], text=text)
                    msg.put()
                
                    # also send message to google chat if possible
                    if not is_my_office:
                        send_message_to_google_chat(account, senderName + ' says ' + text)
        
        elif command == 'publish':
            # first delete any expired stream
            for stream in get_streams_expired():
                cleanup_stream(stream)
                if not stream.is_owner:
                    data = get_userlist_message(removed=[stream])
                    for owner in get_streams_of_owner(stream.owner):
                        send_message(owner, data)
            
            stream = get_stream(input['clientId'])
            if not stream:
                # create new Stream object
                stream = ClientStream(clientId=input['clientId'], visitor=user.email(), name=input['name'], publish=input['url'], owner=account, is_owner=is_my_office)
                stream.put()
                
                # first update user list of owner
                if not is_my_office:
                    data = get_userlist_message(added=[stream])
                    found = False
                    for owner in get_streams_of_owner(account):
                        send_message(owner, data)
                        found = True
                            
                    # then send to google chat if account user is not online here
                    if not found:
                        contact = user.email() if user.email() else '@' + stream.clientId
                        msg = '%s visited your video office on %s GMT. Send your reply starting with %s to this person.'%(user.name, datetime.datetime.now(), contact)
                        send_message_to_google_chat(account, msg)
            else:
                stream.publish, stream.name = input['url'], input['name']
                stream.modified_on = datetime.datetime.now()
                stream.put() # so that last modified is updated
            
            # logging.info('sending userlist and chathistory in response %r %r %r'%(is_my_office, user.email(), account))
            if is_my_office: # return user list also
                visitors = get_streams_of_visitors(account)
                messages = get_messages_of_owner(account)
                
                response = {'userlist': [x.get_object() for x in visitors], 'chathistory': [x.get_object() for x in messages]}
                if response['chathistory']:
                    db.delete([x for x in messages])
                
                return HttpResponse(json.dumps(response))

    return HttpResponse('')

