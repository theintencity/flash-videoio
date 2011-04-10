import datetime, calendar

from google.appengine.api import users
from google.appengine.ext import db
from google.appengine.ext.db import djangoforms

from django.shortcuts import render_to_response

from project.experts.models import Event
from project.experts.views.common import get_login_user
from django.http import HttpResponse, HttpResponseRedirect

def index(request, account):
    user = get_login_user(request)
    now = datetime.datetime.now()
    return render_to_response('experts/calendar.html', 
            {'user': user, 'account': account, 'today': now.strftime('%Y-%m-%d')})
        
def get_frame_url(account, tzoffset, dt):
    return '/experts/%s/calendar/%s/%s'%(account, tzoffset, dt.strftime('%Y-%m-%d') if isinstance(dt, datetime.datetime) else dt)

class MyCalendar(calendar.HTMLCalendar):
    def __init__(self, now, firstdayweek=6):
        calendar.HTMLCalendar.__init__(self, firstdayweek)
        self.now = now
        
    def formatday(self, day, weekday):
        if day == 0:
            return '<td class="noday">&nbsp;</td>' # day outside month
        else:
            body = '<div style="width: 100%%; height: 100%%;" onclick="window.location=\'../%d-%d-%d\'">%d</div>'%(self.now.year, self.now.month, day, day)
            return '<td class="%s">%s</td>' % (self.cssclasses[weekday] if day != self.now.day else 'today', body)

    def formatweek(self, theweek):
        s = ''.join(self.formatday(d, wd) for (d, wd) in theweek)
        return '<tr>%s</tr>' % s

    def formatweekday(self, day):
        return '<th class="%s">%s</th>' % (self.cssclasses[day], calendar.day_abbr[day])

    def formatweekheader(self):
        s = ''.join(self.formatweekday(i) for i in self.iterweekdays())
        return '<tr>%s</tr>' % s

    def formatmonthname(self, theyear, themonth, withyear=True):
        s = str(calendar.month_name[themonth])
        if withyear:
            prev = '../%d-%d-1'%(theyear if themonth > 1 else theyear - 1, themonth - 1 if themonth > 1 else 12)
            next = '../%d-%d-1'%(theyear if themonth < 12 else theyear + 1, themonth + 1 if themonth < 12 else 1)
            s = '%s %s<div style="float:left;"><a href="%s">&lt;&lt;prev</a></div><div style="float:right;"><a href="%s">next&gt;&gt;</a></div>'%(s, theyear, prev, next)
        return '<tr><th colspan="7" class="month">%s</th></tr>' % s

class EventForm(djangoforms.ModelForm):
    class Meta:
        model = Event
        exclude = ('owner', 'visitor', 'created_on')
    
def edit(request, account, tzoffset, date, key):
    user = get_login_user(request)
    tzdelta = datetime.timedelta(minutes=int(tzoffset))
    if account == user.email():
        target = user
    else:
        target = users.User(email=account)
        target = db.GqlQuery('SELECT * FROM User WHERE account = :1', target).get()
            
    event = db.get(key)
    if not event:
        return HttpResponse('Calendar event does not exist for key "%s"'%(key,))
    
    start_time, end_time = event.start_time - tzdelta, event.end_time - tzdelta
    event.start_time, event.end_time = start_time, end_time
    
    if request.method == 'POST':
        form = EventForm(request.POST, instance=event)
        if form.is_valid():
            event1 = form.save(commit=False)
            if user.email() == account:
                event.start_time = event1.start_time + tzdelta
                event.end_time = event1.end_time + tzdelta
            event.subject, event.description = event1.subject, event1.description
            event.put()
            return HttpResponseRedirect(get_frame_url(account, tzoffset, date))
    else:
        form = EventForm(instance=event)
        
    return render_to_response('experts/calendaredit.html', 
            {'user': user, 'account': account, 'date': event.start_time.strftime('%A, %d %b'),
            'form': form, 'is_my_calendar': bool(user.email() == account),
            'person': target.name if user.email() == account else user.name,
            'start_time': start_time.strftime('%A, %d %b %I:%M %p '),
            'end_time': end_time.strftime('%A, %d %b %I:%M %p ') })
    
def frame(request, account, tzoffset, date):
    user = get_login_user(request)
    error_message = status = ''
    tzdelta = datetime.timedelta(minutes=int(tzoffset))
    now = datetime.datetime.now() - tzdelta
    if date != 'now':
        yy, mm, dd = map(int, date.split('-', 2))
        now = datetime.datetime(year=yy, month=mm, day=dd, hour=now.hour, minute=now.minute, second=now.second)
        
    c = MyCalendar(now)
    text = c.formatmonth(now.year, now.month)
    
    if account:
        if account == user.email():
            target = user
        else:
            target = users.User(email=account)
            target = db.GqlQuery('SELECT * FROM User WHERE account = :1', target).get()
        
    if request.method == 'POST' and 'add_event' in request.POST:
        subject0, time0, duration0, desc0 = [request.POST.get(x) for x in ('subject', 'time', 'duration', 'description')]
        start_time = now.replace(hour=int(time0.split(':')[0])+(12 if time0.endswith('pm') else 0),
                                 minute=int(time0.split(' ')[0].split(':')[1]),
                                 second=0, microsecond=0) + tzdelta
        end_time = start_time + datetime.timedelta(hours=1)
#        return HttpResponse('start_time=' + str(start_time) + ' end_time=' + str(end_time) 
#                            + ' provider=' + account.email() + ' user=' + user.email() + " subject=" + subject0) 
        event = Event(subject=subject0, owner=account, visitor=user.email(), start_time=start_time, end_time=end_time, description=desc0)
        event.put()
        status = 'Added "%s" at %s'%(event.subject, event.start_time.strftime('%I:%M %p'))
    
    if request.method == 'GET' and 'delete' in request.GET:
        key = request.GET.get('delete')
        event = db.get(key)
        if event and (event.owner == user.email() or event.visitor == user.email()):
            status = 'Deleted "%s" at %s'%(event.subject, (event.start_time - tzdelta).strftime('%I:%M %p'))
            event.delete()
        else:
            error_message = 'Cannot delete event with key "%s"'%(key,)
            
    start_time = now.replace(hour=0, minute=0, second=1, microsecond=0) + tzdelta
    end_time = now.replace(hour=23, minute=59, second=59, microsecond=0) + tzdelta
    
    events = db.GqlQuery('SELECT * FROM Event WHERE owner = :1 AND start_time >= :2 AND start_time < :3 ORDER BY start_time', account, start_time, end_time).fetch(100)
    
    appointments = []
    for event in events:
        is_my_event = bool(event.owner == user.email() or event.visitor == user.email())
        description = '%s<br/>%s'%(event.subject or '', event.description or '') if is_my_event else 'Busy'
        start_time, end_time = (event.start_time - tzdelta).strftime('%I:%M %p'), (event.end_time - tzdelta).strftime('%I:%M %p') 
        appointments.append({'key': event.key(), 
            'time': '%s-%s'%(start_time[:-3] if start_time[-3:] == end_time[-3:] else start_time, end_time), 
            'description': description, 'is_my_event': is_my_event, 
            'person': event.visitor if event.owner == user.email() else event.owner
        })    
    
    prev = now.replace(day=1, month=now.month-1 if now.month > 1 else 12, year=now.year if now.month > 1 else now.year - 1)
    next = now.replace(day=1, month=now.month+1 if now.month < 12 else 1, year=now.year if now.month < 12 else now.year + 1)
    
    start_time = now.replace(day=1, hour=0, minute=0, second=1, microsecond=0) + tzdelta
    end_time = start_time.replace(day=1, month=now.month+1 if now.month < 12 else 1, year=now.year if now.month < 12 else now.year + 1) + tzdelta
    events = db.GqlQuery('SELECT * FROM Event WHERE owner = :1 AND start_time >= :2 AND start_time < :3 ORDER BY start_time', account, start_time, end_time).fetch(1000)
    by_day = {}
    for event in events:
        start_time = event.start_time - tzdelta
        if start_time.day not in by_day:
            by_day[start_time.day] = []
        by_day[start_time.day].append(event)
        
    for day, event_list in by_day.iteritems():
        pattern = '>%d</div>'%(day,)
        text = text.replace(pattern, '>%d<br/>%s</div>'%(day, ', '.join([(event.start_time - tzdelta).strftime('%H:%M') for event in event_list])))

    return render_to_response('experts/calendarframe.html', 
            {'user': user, 'account': account, 'status': status, 'error_message': error_message,
            'calendar': text, 'appointments': appointments, 'date': now.strftime('%A, %d %b, %I:%M %p'),
            'availability': target.availability, 'is_my_calendar': bool(user.email() == account),
            'prev': get_frame_url(account, tzoffset, prev),
            'next': get_frame_url(account, tzoffset, next)
            })
        
