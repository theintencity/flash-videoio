// This is re-used from http://code.google.com/p/webtalk-project with modifications

var webtalk = {
		
//whether this active or not?
active: true,

// The base URL on which this HTML is loaded without terminating /.
// All web service paths are constructed relative to this.
service: location.href.substring(0,location.href.lastIndexOf('/')),

// The client identifier of this client is randomly generated on load.
clientId: null,

// The display name of this user using this client. 
myname: null,

// Extra information that is published in the user list
extra: null,

// the current chat room location. '' means no location or chat room.
location: '',

// Periodic interval in milliseconds to refresh and update
interval: 6000,

//timer that periodically fetches chathistory and userlist
timer: null,

//last timestamp when refresh was done
lastRefresh: 0,

//versions of userlist and chathistory of last fetch.
userlistVersion: 0,
chathistoryVersion: 0,

//the actual displayed userlist and chathistory as array of objects.
//userlist is indexed by clientId. chathistory is just an array.
userlist: {},
chathistory: [],

// When the page is loaded, create the random clientId, and start the 
// periodic refresh timer
load: function() {
	webtalk.clientId = Math.floor(Math.random()*10000000000).toString();
},

// When the page is unloaded, clear the periodic timer, and logout.
unload: function() {
	webtalk.setLocation(null);
},

// Get the AJAX object for making HTTP requests.
// @return the request object.
getRequest: function() {
	var ajaxRequest;  // The variable that makes Ajax possible!
	try{ // Opera 8.0+, Firefox, Safari
		ajaxRequest = new XMLHttpRequest();
	} catch (e) { // Internet Explorer Browsers
		try{
			ajaxRequest = new ActiveXObject("Msxml2.XMLHTTP");
		} catch (e) {
			try {
				ajaxRequest = new ActiveXObject("Microsoft.XMLHTTP");
			} catch (e) {
				return false; // Something went wrong
			}
		}
	}
	return ajaxRequest;
},

// Get the status text from AJAX request object. This is
// useful because sometimes the request.status or request.statusText
// give exception.
// @param request the AJAX request object returned by getRequest()
// @return status string, e.g., "200 OK".
getStatus: function(request) {
	var status = "N/A";
	var statusText = "N/A";
	try { status = request.status; } catch (e) {}
	try { statusText = request.statusText; } catch (e) {}
	return status + " " + statusText;
},

// Set the location value. If the location is reset to null, it exist any
// chat room. For a valid location change, it joins that new chat room.
// @param value the string such as "public" for public chat room, or null to exit any.
// @param forceJoin force the join whether location changed or not. Value must be not null.
setLocation: function(value, forceJoin) {
	if (!webtalk.active)
		return;
	
	if (value) {
		// The built-in escape function does not change the "/" character, but this 
		// interferes with parameter identification of service, 
		// hence I explicitly escape "/" character.
		var escapedValue = escape(value).replace(/\//g, '%2f');
		
		// join the new chat room if location changed
		if (escapedValue != webtalk.location || forceJoin) {
			webtalk.location = escapedValue;
			webtalk.joinRoom();
		}
	} else {
		// exit the existing room if location is reset.
		webtalk.onChatHistory([]);
		webtalk.onUserList([]);
		webtalk.leaveRoom();
		webtalk.location = '';
	}
},

// Join the chat room for the location. It is invoked only if a location change
// demands a new chat room. 
// It resets the versions because we are in a new chat room. It then does
// 1. post my user data to chat room user list
// 2. get the chat room user list
// 3. get the chat room chat history
// 4. start the timer to periodically refresh user list and chat history
joinRoom: function() {
	webtalk.userlistVersion = 0;
	webtalk.chathistoryVersion = 0;
	webtalk.postUserList();
	setTimeout(function() { webtalk.loadUserList(); }, 200);
	webtalk.loadChatHistory();

	if (webtalk.timer == null) {
		webtalk.timer = setInterval(webtalk.timerHandler, webtalk.interval);
	}
	webtalk.lastRefresh = (new Date()).getTime();
},

// Leave any existing chat room. First clear any refresh timer. Then reset any
// versions. Finally remove my user data from the chat room user list.
leaveRoom: function() {
	if (webtalk.timer != null) {
		clearInterval(webtalk.timer);
		webtalk.timer = null;
	}
	webtalk.chathistoryVersion = 0;
	webtalk.userlistVersion = 0;
	if (webtalk.location) {
		webtalk.deleteUserList();
	}
},

// The periodic refresh timer does
// 1. post my user data to chat room user list (to refresh)
// 2. get chat room user list
// 3. get chat room chat history.
// It skips the steps if it is invoked too soon. It also correctly handles
// 304 not modified response in steps 2 and 3.
timerHandler: function() {
	var now = (new Date()).getTime();
	if ((now - webtalk.lastRefresh) > (webtalk.interval-1000)) {
		if (webtalk.location) {
			webtalk.lastRefresh = now;
			webtalk.postUserList();
			setTimeout(function() { webtalk.loadUserList(); }, 200);
			webtalk.loadChatHistory();
		}
	}
},

// Post a new chat message to the chat room's chat history. It also handles any
// special commands such as
// @user 2:private message targetted to user with name "user 2".
// The method ensures that my name is set, otherwise it skips the posting of chat
// messages.
postChatHistory: function(text) {
	if (!webtalk.location)
		return;

	if (!webtalk.myname) {
		alert("Cannot send message without setting your screen name");
		return;
	}

	timestamp = (new Date()).getTime();
	var request = webtalk.getRequest();
	request.onreadystatechange = function() {
		if (request.readyState == 4) {
			if (request.status == 200) {
				// nothing
			} else {
				webtalk.onError("POST /chathistory failed (" + webtalk.getStatus(request) + ")");
			}
		}
	}

	var url = webtalk.service + "/chathistory?location=" + webtalk.location;
	var target = text.match(/^@([^:]+):/)
	if (target) {
		var found = null;
		for (var s in webtalk.userlist) {
			if (webtalk.userlist[s].name == target[1].toString()) {
				found = webtalk.userlist[s];
			}
		}
		if (!found) {
			webtalk.onError("User with name " + target[1].toString() + " not in this chat room");
			return;
		}
		
		url += "&targetId=" + escape(webtalk.clientId);
		text = text.substr(target[1].length+2);
	}
	request.open("POST", url, true);
	request.setRequestHeader("Content-Type", "application/json");
	request.send('{"sender":"' + webtalk.myname + '","senderId":"' + webtalk.clientId + '","timestamp":' + timestamp + ',"text":"' + text + '"}');
},

// Get the chat room chat history. The supplied callback function is invoked
// on success with an array of chat messages. In case of 304 response, it doesn't
// invoke the callback. For any other failure it displays the error message.
getChatHistory: function(callback) {
	var request = webtalk.getRequest();
	request.onreadystatechange = function() {
		if (request.readyState == 4) {
			if (request.status == 200) {
				obj = eval("(" + request.responseText + ")");
				webtalk.chathistoryVersion = obj.version;
				callback(obj.chathistory);
			} else if (request.status == 304) {
				// chat history is not modified
			} else {
				webtalk.chathistoryVersion = 0;
				webtalk.onError("GET /chathistory failed (" + webtalk.getStatus(request) + ")");
			}
		}
	}

	var url = webtalk.service + "/chathistory?location=" + webtalk.location + "&since=" + webtalk.chathistoryVersion;
	if (webtalk.myname)
		url += "&targetId=" + escape(webtalk.clientId);
	request.open("GET", url, true);
	request.send(null);
},

// Load the chat room's chat history using getChatHistory and set the result to
// the user interface using onChatHistory methods. It formats the response
// so that the chat history is displayed with correct order: if same user sent
// multiple messages, they are ordered chronologically for that user, and
// each user messages are ordered in reverse chronological by user name. This makes
// the most recent comment first, but still allows readability for multiple messages
// from the same user.
loadChatHistory: function() {
	if (!webtalk.location)
		return;

	webtalk.getChatHistory(function(data) {
		var msgs = [];
		var str = "";
		for (var s in data) {
			var obj = data[s];
			var obj_date = (new Date(obj.timestamp*1000)).toLocaleDateString();
			var msg;
			if (msgs.length > 0 && msgs[0].senderId == obj.senderId && 
					msgs[0].sender == obj.sender && msgs[0].date == obj_date) {
				msg = msgs[0];
			} else {
				msg = {"sender": obj.sender, "senderId": obj.senderId, "date": obj_date, 
					   "text": obj.sender + " [" + obj_date + "]:\n"};
				msgs.unshift(msg);
			}
			msg.text += "\t" + obj.text + "\n";
		}
		webtalk.chathistory = msgs;
		webtalk.onChatHistory(msgs);
	});
},

// Post my user data to the chat room's user list using POST userlist
// web service. The web service implicitly removes my user data from my previous
// chat room's user list.
postUserList: function() {
	if (!webtalk.location)
		return;

	var request = webtalk.getRequest();
	request.onreadystatechange = function() {
		if (request.readyState == 4) {
			if (request.status == 200) {
				// nothing
			} else {
				webtalk.onError("POST /userlist failed (" + webtalk.getStatus(request) + ")");
			}
		}
	}

	var url = webtalk.service + "/userlist?location=" + webtalk.location;
	request.open("POST", url, true);
	request.setRequestHeader("Content-Type", "application/json");
	request.send('{"name":"' + webtalk.myname + '","clientId":"' + webtalk.clientId + '","extra":"' + webtalk.extra + '"}');
},

// Delete my user data from chat room's user list using POST userlist/delete
// web service.
deleteUserList: function() {
	if (!webtalk.location)
		return;

	var request = webtalk.getRequest();
	var url = webtalk.service + "/userlist/delete?location=" + webtalk.location;

	request.open("POST", url, true);
	request.setRequestHeader("Content-Type", "application/json");
	request.send('{"name":"' + webtalk.myname + '","clientId":"' + webtalk.clientId + '"}');
},

// Get the chat room's user list and invoke the supplied callback function on
// success with the list of user data. It doesn't call the callback if 304 is
// received. It indicates the error message for any other error response.
getUserList: function(callback) {
	var request = webtalk.getRequest();
	request.onreadystatechange = function() {
		if (request.readyState == 4) {
			if (request.status == 200) {
				obj = eval("(" + request.responseText + ")");
				webtalk.userlistVersion = obj.version;
				callback(obj.userlist);
			} else if (request.status == 304) {
				// user list is not modified.
			} else {
				webtalk.userlistVersion = 0;
				webtalk.onError("GET /userlist failed (" + webtalk.getStatus(request) + ")");
			}
		}
	}

	var url = webtalk.service + "/userlist?location=" + webtalk.location + "&since=" + webtalk.userlistVersion;
	request.open("GET", url, true);
	request.send(null);
},

// Load the chat room's user list by getUserList to get the data and then onUserList
// to set the user interface with the data.
loadUserList: function() {
	if (!webtalk.location)
		return;

	webtalk.getUserList(function(data) {
		var userlist = {};
		var users = [];
		for (var s in data) {
			users.push(data[s]);
			userlist[data[s].clientId] = data[s];
		}
		webtalk.userlist = userlist;
		webtalk.onUserList(users);
	});
},

//Application will override this method to update the display as needed.
onChatHistory: function(msgs) {
	//	var chathistory = document.getElementById("chathistory");
	//	var text = msgs ? msgs.map(function(obj) { return obj.text; }).join("") : "";
	//	chathistory.value = text || "<empty>";
},

// Callback invoked when the userlist changes. This is overridden by the application
// to update the user list display. Application can also sort the user list by name.
onUserList: function(users) {
	//	var userlist = document.getElementById("userlist");
	//	var text = users ? users.map(function(obj) { return obj.name; }).sort().join("\n") : "";
	//	userlist.value = text || "<empty>";
},

// Display an error message in the input box.
onError: function(msg, level) {
	// if (!level) level = "error";
	//	var input = document.getElementById("input");
	//	setTimeout(function() { input.value = "ERROR: " + msg; input.setSelectionRange(0, input.value.length); }, 100);
},

mustBeLast: function() { }

};
