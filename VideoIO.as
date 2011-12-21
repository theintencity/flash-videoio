/*  Copyright (c) 2010-2011, Kundan Singh. See website for LICENSING.*/
/*  Copyright (c) 2010-2011, VoIP Researcher.*/
package {
	import flash.display.DisplayObject;
	import flash.display.LoaderInfo;
	import flash.events.Event;
	import flash.events.DataEvent;
	import flash.external.ExternalInterface;
	import flash.net.LocalConnection;
	import flash.system.Security;
	
	import mx.core.Application;
	import mx.events.DynamicEvent;
	import mx.events.FlexEvent;
	import mx.events.PropertyChangeEvent;
	import mx.events.VideoEvent;
	import mx.utils.ObjectUtil;
	
	public class VideoIO extends Application {
		private var component:Class = VideoIOInternal;
		
		private var obj:Object = null;
		
		// facebook specific ones
		private var fbConnection1:LocalConnection;
		private var fbConnectionName1:String;
		private var fbConnection2:LocalConnection;
		private var fbConnectionName2:String;
		
		// enable notification or not?
		private var isChild:Boolean = false;
		
		private static const BASE_URL:String = "http://myprojectguide.org/p/face-talk";

		public function VideoIO() {
			this.layout = "absolute";
			this.setStyle("backgroundAlpha", 0);
			this.setStyle("borderStyle", "none");
			this.setStyle("borderThickness", 0);
			this.setStyle("borderVisible", false);
			addEventListener("addedToStage", creationCompleteHandler);
		}

			
		private function creationCompleteHandler(event:Event):void
		{
			obj = new component();
			obj.percentWidth = obj.percentHeight = 100;
			
			if (CONFIG::sdk4) {
				isChild = (mx.core.FlexGlobals.topLevelApplication != this);
			}
			else {
				isChild = (Application.application != this);
			}
			trace("isChild=" + isChild);
			
			if (!isChild) {
				fbInitialize(null);

				// minimum dimension to popup SecurityPanel
				//TODO: does not work on Chrome with Flash Player 10.3
				//obj.minWidth = 215;
				//obj.minHeight = 138;
			}
			
			try {
				obj.addEventListener(FlexEvent.CREATION_COMPLETE, componentCompleteHandler, false, 0, true);
				obj.addEventListener(PropertyChangeEvent.PROPERTY_CHANGE, propertyChangeHandler, false, 0, true);
				obj.addEventListener("callback", callbackHandler, false, 0, true);
				obj.addEventListener("postingNotify", postingNotifyHandler, false, 0, true);
				obj.addEventListener("showingSettings", showingSettingsHandler, false, 0, true);
				obj.addEventListener("hidingSettings", showingSettingsHandler, false, 0, true);
				obj.addEventListener("receiveData", receiveDataHandler, false, 0, true);
				
				if (ExternalInterface.available) {
					if (!isChild) {
						ExternalInterface.addCallback("setProperty", setProperty);
						ExternalInterface.addCallback("getProperty", getProperty);
						ExternalInterface.addCallback("callProperty", callProperty);
					}
				} 
				else {
					trace("ExternalInterface is not available");
				}
			} catch (e:SecurityError) {
				trace("security exception: " + e.message); 
			}
			
			if (!isChild) {
				for (var name:String in parameters) {
					var value:String = parameters[name];
					if (value == "true" || value == "false")
						setProperty(name,  (value == "true"));  // boolean
					else
						setProperty(name, value);               // string
				}
			}
			
			// add the object as child of main application
			addChild(DisplayObject(obj));
		}
		
		public function setProperty(name:String, value:Object):void
		{
			if (obj.hasOwnProperty(name)) {
				trace("setProperty(" + name + "," + (name != "snapshot" ? value : "hidden") + ")");
				obj[name] = (value != '' ? value : null);
			}
			else {
				trace("setProperty(name=" + name + ") ignored");
			}
		}
		
		public function getProperty(name:String):Object
		{
			var result:Object = obj.hasOwnProperty(name) ? obj[name] : null;
			trace("getProperty(" + name + ")=>" + (name != "snapshot" ? result : "hidden"));
			return result;
		}
		
		public function callProperty(name:String, ...args):void
		{
			try {
				trace("callProperty(" + name + ",...)");
				var func:Function = obj[name] as Function;
				func.apply(obj, args);
			} catch (e:Error) {
				trace("callProperty(" + name + ",...) exception\n" + e.getStackTrace());
			}
		}
		
		private function componentCompleteHandler(event:Event):void
		{
			try {
				if (isChild) {
					dispatchEvent2(new Event("onCreationComplete"));
				}
				else if (ExternalInterface.available && ExternalInterface.objectID != null) {
					var param:Object = {objectID: ExternalInterface.objectID};
					trace("invoking JavaScript onCreationComplete objectID=" + ExternalInterface.objectID);
					if (fbConnectionName1 == null)
						ExternalInterface.call("onCreationComplete", param);
					else
						fbConnection1.send(fbConnectionName1, "callFBJS", "onCreationComplete", [param]); 
				}
			} catch (e:Error) {
				trace(e.getStackTrace());
			}
		}
		
		private function propertyChangeHandler(event:PropertyChangeEvent):void
		{
			try {
				var type:String = typeof(obj[event.property]);
				if (type == "string" || type == "boolean" || type == "number") {
					if (isChild) {
						var ev:DynamicEvent = new DynamicEvent("onPropertyChange");
						ev.property = event.property;
						ev.oldValue = event.oldValue;
						ev.newValue = event.newValue;
						dispatchEvent2(ev);
					}
					else if (ExternalInterface.available && ExternalInterface.objectID != null) {
						var param:Object = {
								objectID: ExternalInterface.objectID, 
								property: event.property, 
								oldValue: event.oldValue, 
								newValue: event.newValue
							};
							
						trace("invoking JavaScript onPropertyChange objectID=" + ExternalInterface.objectID
							+ " property=" + event.property
							+ " oldValue=" + event.oldValue
							+ " newValue=" + event.newValue);
						if (fbConnectionName1 == null)
							ExternalInterface.call("onPropertyChange", param);
						else
							fbConnection1.send(fbConnectionName1, "callFBJS", "onPropertyChange", [param]);
					}
				}
			} catch (e:Error) {
				trace(e.getStackTrace());
			}
		}
		
		private function callbackHandler(event:DynamicEvent):void
		{
			try {
				if (isChild) {
					var ev:DynamicEvent = new DynamicEvent("onCallback");
					ev.method = event.method;
					ev.args = event.args;
					dispatchEvent2(ev);
				}
				else if (ExternalInterface.available && ExternalInterface.objectID != null) {
					var param:Object = {
							objectID: ExternalInterface.objectID,
							method: event.method,
							args: event.args
						};
						
						trace("invoking JavaScript onCallback objectID=" + ExternalInterface.objectID
							+ " method=" + event.method
							+ " args=" + event.args);
					if (fbConnectionName1 == null)
						ExternalInterface.call("onCallback", param);
					else
						fbConnection1.send(fbConnectionName1, "callFBJS", "onCallback", [param]);
				}
			} catch (e:Error) {
				trace(e.getStackTrace());
			}
		}
		
		private function postingNotifyHandler(event:DynamicEvent):void
		{
			try {
				if (isChild) {
					var ev:DynamicEvent = new DynamicEvent("onPostingNotify");
					ev.user = event.user;
					ev.text = event.text;
					dispatchEvent2(ev);
				}
				else if (ExternalInterface.available && ExternalInterface.objectID != null) {
					var param:Object = {
							objectID: ExternalInterface.objectID,
							user: event.user,
							text: event.text
						};
						
						trace("invoking JavaScript onPostingNotify objectID=" + ExternalInterface.objectID
							+ " user=" + event.user
							+ " text=" + event.text);
					if (fbConnectionName1 == null)
						ExternalInterface.call("onPostingNotify", param);
					else
						fbConnection1.send(fbConnectionName1, "callFBJS", "onPostingNotify", [param]);
				}
			} catch (e:Error) {
				trace(e.getStackTrace());
			}
		}
		
		private function receiveDataHandler(event:DataEvent):void
		{
			try {
				if (isChild) {
					var ev:DynamicEvent = new DynamicEvent("onReceiveData");
					ev.data = event.data;
					dispatchEvent2(ev);
				}
				else if (ExternalInterface.available && ExternalInterface.objectID != null) {
					var param:Object = {
							objectID: ExternalInterface.objectID,
							data: event.data
						};
						
						trace("invoking JavaScript onReceiveData objectID=" + ExternalInterface.objectID
							+ " data=" + event.data);
					if (fbConnectionName1 == null)
						ExternalInterface.call("onReceiveData", param);
					else
						fbConnection1.send(fbConnectionName1, "callFBJS", "onReceiveData", [param]);
				}
			} catch (e:Error) {
				trace(e.getStackTrace());
			}
		}
		
		private function showingSettingsHandler(event:Event):void
		{
			try {
				if (isChild) {
					var ev:DynamicEvent = new DynamicEvent("onShowingSettings");
					ev.showing = (event.type != "hidingSettings");
					dispatchEvent2(ev);
				}
				else if (ExternalInterface.available && ExternalInterface.objectID != null) {
					var param:Object = {
							objectID: ExternalInterface.objectID,
							showing: (event.type != "hidingSettings")
						};
						
						trace("invoking JavaScript onShowingSettings objectID=" + ExternalInterface.objectID
							+ " showing=" + (event.type != "hidingSettings"));
					if (fbConnectionName1 == null)
						ExternalInterface.call("onShowingSettings", param);
					else
						fbConnection1.send(fbConnectionName1, "callFBJS", "onShowingSettings", [param]);
				}
			} catch (e:Error) {
				trace(e.getStackTrace());
			}
		}
		
		private function fbInitialize(event:Event):void
		{
			try {
				if (('fb_local_connection' in LoaderInfo(this.root.loaderInfo).parameters)
				|| ('fb_fbjs_connection' in LoaderInfo(this.root.loaderInfo).parameters)) {
					Security.loadPolicyFile(BASE_URL + "/crossdomain.xml");
					Security.allowDomain("apps.facebook.com");
					Security.allowDomain("*.facebook.com");
				}
			}
			catch (e:Error) {
				trace("Error in Facebook security domain");
			}
			
			try {
				if ('fb_local_connection' in LoaderInfo(this.root.loaderInfo).parameters) {
					fbConnection1 = new LocalConnection();
					fbConnectionName1 = LoaderInfo(this.root.loaderInfo).parameters.fb_local_connection;
					trace("Facebook local connection " + fbConnectionName1);
				}
			}
			catch (e:Error) {
				trace("Error in Facebook local connection");
				trace(e.getStackTrace());
			}

			try {
				if ('fb_fbjs_connection' in LoaderInfo(this.root.loaderInfo).parameters) {
					fbConnection2 = new LocalConnection();
					fbConnectionName2 = LoaderInfo(this.root.loaderInfo).parameters.fb_fbjs_connection; 
					
					fbConnection2.allowDomain("*");
					fbConnection2.client = {
						"setProperty": function(name:String, value:Object):void {
							this.setProperty(name, value);
						},
						"getProperty": function(name:String):Object {
							return this.getProperty(name);
						}
					};
					fbConnection2.connect(fbConnectionName2);
					trace("Facebook JS connection " + fbConnectionName2);
				}
			}
			catch (e:Error) {
				trace("Error in Facebook JS connection");
				trace(e.getStackTrace());
			}
		}	
		
		private function dispatchEvent2(event:Event):void
		{
			//trace("dispatchEvent type=" + event.type);
			dispatchEvent(event);
			if (this.systemManager != null && this.systemManager.loaderInfo != null 
			&& this.systemManager.loaderInfo.sharedEvents != null) 
				this.systemManager.loaderInfo.sharedEvents.dispatchEvent(event);
		}
	}
}

import flash.display.BitmapData;
import flash.display.Bitmap;
import flash.display.DisplayObject;
import flash.display.Stage;
import flash.display.StageDisplayState;
import flash.events.AsyncErrorEvent;
import flash.events.ContextMenuEvent;
import flash.events.DataEvent;
import flash.events.ErrorEvent;
import flash.events.FocusEvent;
import flash.events.FullScreenEvent;
import flash.events.IOErrorEvent;
import flash.events.NetStatusEvent;
import flash.events.MouseEvent;
import flash.events.ProgressEvent;
import flash.events.SecurityErrorEvent;
import flash.events.StatusEvent;
import flash.events.TimerEvent;
import flash.geom.Matrix;
import flash.media.Camera;
import flash.media.Microphone;
import flash.media.SoundMixer;
import flash.media.SoundTransform;
import flash.media.Video;
import flash.net.NetConnection;
import flash.net.NetStream;
import flash.net.ObjectEncoding;
import flash.net.URLRequest;
import flash.net.navigateToURL;
import flash.system.Capabilities;
import flash.system.Security;
import flash.system.SecurityPanel;
import flash.ui.ContextMenu;
import flash.ui.ContextMenuItem;
import flash.utils.Timer;
import flash.utils.ByteArray;

import mx.binding.utils.BindingUtils;
import mx.containers.Canvas;
import mx.controls.Alert;
import mx.controls.Image;
import mx.controls.VideoDisplay;
import mx.core.Application;
import mx.core.UIComponent;
import mx.events.FlexEvent;
import mx.events.MetadataEvent;
import mx.events.PropertyChangeEvent;
import mx.events.PropertyChangeEventKind;
import mx.events.ResizeEvent;
import mx.events.VideoEvent;
import mx.events.DynamicEvent;
import mx.graphics.codec.JPEGEncoder;
import mx.utils.Base64Encoder;
import mx.utils.Base64Decoder;

import mx.controls.Button;

// Following are dynamically used based on Flash Player version	
//	import flash.net.GroupSpecifier;
//	import flash.net.NetGroup;

/**
 * Dispatched when the camera active state changes.
 */
[Event(name="cameraChange", type="flash.events.Event")]

/**
 * Dispatched when the microphone active state changes.
 */
[Event(name="micChange", type="flash.events.Event")]

/**
 * Dispatched when "privacyEvent" is set to true and Flash Player is about to
 * show the security settings dialog box. This is also dispatched when "showSettings"
 * method is called to explicitly show the settings dialog box.
 */
[Event(name="showingSettings", type="flash.events.Event")]

/**
 * Dispatched when "privacyEvent" is set to true and Flash Player earlier showed
 * the security settings dialog box either implicitly or explicitly on "showSettings",
 * then now the application received the focusIn event to indicate that the
 * security dialog box is no longer active.
 */
[Event(name="hidingSettings", type="flash.events.Event")]

/**
 * Dispatched when the server calls a method. The method and args properties are useful.
 */
[Event(name="callback", type="mx.events.DynamicEvent")]

/**
 * Dispatched when the NetGroup.Posting.Notify is received. The user and text properties are useful.
 */
[Event(name="postingNotify", type="mx.events.DynamicEvent")]

/**
 * Dispatched when the sendData is received on a stream. This is done when the remote side
 * called sendData method to send some data. The data property contains the received data.
 */
[Event(name="receiveData", type="flash.events.DataEvent")]

/**
 * The VideoIO class handles various audio/video recording and playback modes.
 */	
class VideoIOInternal extends Canvas
{
	// the product page URL
	private static const COMPONENT_URL:String = "http://code.google.com/p/flash-videoio";
	
	// the version string
	private static const COMPONENT_VERSION:String = "Powered by Flash-VideoIO " + CONFIG::version;
	
	private var _src:String;
	
	private var _url:String;
	private var _scheme:String;
	private var _args:Array;
	private var _play:String;
	private var _publish:String;
	private var _record:Boolean;
	private var _live:Boolean;
	private var _mirrored:Boolean = true;
	private var _farID:String;
	private var _nearID:String;
	
	// other flags for the video
	private var _poster:String;
	private var _autoplay:Boolean = true;
	private var _loop:Boolean = false;
	private var _controls:UIComponent;
	private var _preload:Boolean = false;
	private var _detectActivity:Boolean = true;
	
	// internal objects and flags
	private var nc:NetConnection;
	private var _local:NetStream;
	private var _remote:NetStream;
	private var _dispatchDisconnect:Boolean = false;
	
	private var _playing:Boolean = false;
	private var _recording:Boolean = false;
	private var _bidirection:Boolean = false;
	private var _camera:Boolean = false;
	private var _microphone:Boolean = false;
	private var _display:Boolean = true;
	private var _deviceAllowed:Boolean = false;
	private var _privacyEvent:Boolean = false;
	
	private var _gain:Number = 0.5;
	private var _level:Number = 0;
	private var _rate:int = 16;
	private var _codec:String = "Speex";
	private var _encodeQuality:int = 6;
	private var _framesPerPacket:int = 1;
	private var _silenceLevel:int = 0;
	private var _echoSuppression:Boolean = true;
	private var _echoCancel:Boolean = true;
	 
	private var _sound:Boolean = true;
	private var _volume:Number = 0.5;
	
	private var _cameraObject:Camera = null;
	private var _microphoneObject:Microphone = null;
	private var _micLevelTimer:Timer;
	private var _smoothing:Boolean = true;
	
	private var _cameraWidth:int = 320;
	private var _cameraHeight:int = 240;
	private var _cameraFPS:int = 12;
	private var _cameraBandwidth:int = 0;
	private var _cameraQuality:int = 0;
	private var _keyFrameInterval:int = 15;
	private var _cameraLoopback:Boolean = false;
	
	private var _videoCodec:String = "Sorenson";
	
	private var _video:Video;
	private var _videoDisplay:VideoDisplay;
	private var _currentTimer:Timer;
	private var _currentTime:Number;
	private var _duration:Number;
	private var _bytesLoaded:Number;
	private var _bytesTotal:Number;
	private var _videoWidth:Number;
	private var _videoHeight:Number;
	private var _currentFPS:Number;
	private var _zoom:String = "in";
	private var _playerState:String;
	
	private var _bandwidth:Number = 0;
	private var _quality:Number = 0.0;
	private var _bufferTime:Number = -1.0;
	private var _bufferTimeMax:Number = -1.0;
	
	private var _image:Image;
	private var _posterBackgroundAlpha:Number;
	
	private var _fullscreen:Boolean = false;
	private var _enableFullscreen:Boolean = true;
	
	private var _lastSendTime:Number=0;
	private var publishWidth:Number;
	private var publishHeight:Number;
		
//	private var _sip:String = "idle";
	
	// group communication
	private var _group:String;
	private var _groupspec:Object;
	private var _netGroup:Object;
// Since NetGroup and GroupSpecifier should be available for earlier Flash Player version
//	private var _groupspec:GroupSpecifier;
//	private var _netGroup:NetGroup;

	private var _snapshot:String;
	
	private var settingsTimer:Timer;
	private var stageChildren:int = 0;
	
	private var _proxyType:String = "none";
	private var _objectEncoding:uint = ObjectEncoding.DEFAULT;
	
	//--------------------------------------
	// CONSTRUCTOR
	//--------------------------------------
	
	public function VideoIOInternal()
	{
		super();
		
		trace("Created " + VideoIOInternal.COMPONENT_VERSION);
		
		horizontalScrollPolicy = verticalScrollPolicy = "off";
		setStyle("backgroundAlpha", 1.0);
		setStyle("borderStyle", "solid");
		setStyle("borderThickness", 0);
		
		addEventListener("cameraChange", cameraChangeHandler);
		addEventListener("micChange", micChangeHandler);
		
		addEventListener(Event.ADDED_TO_STAGE, addHandler);
		addEventListener(Event.REMOVED_FROM_STAGE, removeHandler);
		
		installContextMenu();
	}
	
	//--------------------------------------
	// GETTERS/SETTERS
	//--------------------------------------
	
	public const __doc__src:String = 
	'The "src" read-write string property represents the source URL of the component that controls ' + 
	'the publish, playback or live mode. For example\n' + 
	' rtmp://localhost/call/123?publish=live -- connect and publish local stream\n' + 
	' rtmp://localhost/call/123?play=live&arg=mypass -- play remote stream with auth\n' + 
	' http://server/path/file1.flv -- play the web downloaded video file\n' + 
	' rtmp://server/path/file1     -- play the streamed video file\n' + 
	' ?live=true  -- just display local video\n' + 
	' rtmp://localhost/record?publish=file1&record=true -- record to file1.flv\n' + 
	'For local demo you can use these URLs\n' + 
	' rtmp://localhost/call/123?publish=live   -- sender stream of call\n' + 
	' rtmp://localhost/call/123?play=live      -- receiver stream of call\n' + 
	' rtmp://localhost/call/123?publish=test2&record=true  -- record test2.flv\n' + 
	' http://localhost:8080/123/test2.flv      -- play test2.flv\n' + 
	' rtmp://localhost/call/123?play=test2\n';
	
	[Bindable('propertyChange')]
	/**
	 * The src property controls the connect URL and publish, play or live mode.
	 */
	public function get src():String
	{
		return _src;
	}
	public function set src(value:String):void
	{
		var oldValue:String = _src;
		_src = value;
		
		if (oldValue != value) {
			
			var result:Object = { url:null, scheme:null, args:[], farID:null,
								  publish:null, play:null, record:false, live:false, name:null};
			var params:String = '';
			
			if (value != null) {
				var index:int = value.indexOf(':');
				result.scheme = (index >= 0 ? value.substr(0, index).toLowerCase() : null);
				if (result.scheme == 'http' || result.scheme == 'https') {
					result.url = value;
				}
				else {
					index = value.indexOf('?');
					params = (index >= 0 ? value.substr(index+1) : '');
					result.url = (index >= 0 ? value.substr(0, index) : value);
				}
			}
			
			for each (var part:String in params.split('&')) {
				index = part.indexOf('=');
				var name:String = (index >= 0 ? part.substr(0, index) : part);
				var val:String = (index >= 0 ? part.substr(index+1) : null);
				if (name == "publish" || name == "play" || name =="farID" || name == "group")
					result[name] = val;
				else if (name == "live" || name == "record" || name == "bidirection")
					result[name] = (val != "false");
				else if (name == "arg")
					result.args.push(val);
			}
	
			// initialize all read-only propeties
			setProperty("args", result.args);
			setProperty("scheme", result.scheme);
			setProperty("farID", result.farID);
			setProperty("group", result.group);
			setProperty("bytesLoaded", new Number(0));
			setProperty("bytesTotal", new Number(0));
			setProperty("videoWidth", NaN);
			setProperty("videoHeight", NaN);
			setProperty("currentFPS", NaN);
			setProperty("playerState", null);
			if ('bidirection' in result)
				setProperty("bidirection", result.bidirection);
				
			this.level = 0;
			
			this.record = result.record;
			this.url = result.url;
			
			if (result.publish || result.play) {
				if (this.bidirection) {
					this.publish = result.publish;
					this.play = result.play;
				}
				else if (result.publish) {
					this.play = null;
					this.publish = result.publish;
				}
				else if (result.play) {
					this.publish = null;
					this.live = false;
					this.play = result.play;
				}
			}
			else {
				this.publish = null;
				this.play = null;
				this.live = result.live;
			}
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "src", oldValue, value));
		}
	}
	
	public const __doc__poster:String = 
	'The "poster" read-write string property represents the initial image to display before video ' + 
	'is started to publish or play. This should be an http URL. Example\n' + 
	' http://kundansingh.com/images/face.jpg\n';
	
	[Bindable('propertyChange')]
	/**
	 * The poster (or initial image) to display before video is started or 
	 * connected.
	 */
	public function get poster():String
	{
		return _poster;
	}
	public function set poster(value:String):void
	{
		var oldValue:String = _poster;
		_poster = value;
		if (oldValue != value) {
			if (oldValue != null)
				detachPoster();
			if (value != null)
				attachPoster();
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "poster", oldValue, value));
		}
	}
	
	public const __doc__posterBackgroundAlpha:String =
	'The "posterBackgroundAlpha" read-write number property represents the background alpha ' + 
	'of the poster image. If the value is 0 or NaN the background is not displayed. Otherwise ' + 
	'the same poster images is faded using the value alpha, streched and displayed as background\n';
	
	[Bindable('propertyChange')]
	/**
	 * The posterBackgroundAlpha is greater than 0 indicates that a background is displayed
	 * as a faded poster using this alpha.
	 */
	public function get posterBackgroundAlpha():Number
	{
		return _posterBackgroundAlpha;
	}
	public function set posterBackgroundAlpha(value:Number):void
	{
		var oldValue:Number = _posterBackgroundAlpha;
		_posterBackgroundAlpha = value;
		if (oldValue != value) {
			if (!isNaN(oldValue))
				detachPosterBackground();
			if (!isNaN(value))
				attachPosterBackground();
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "posterBackgroundAlpha", oldValue, value));
		}
	}
	
	public const __doc__preload:String =
	'The "preload" read-write boolean property controls whether the video should be pre-loaded ' + 
	'before it is played.\n';
	
	[Bindable('propertyChange')]
	/**
	 * The preload property controls whether the video should be pre-loaded before
	 * the user starts play.
	 */
	public function get preload():Boolean
	{
		return _preload;
	}
	public function set preload(value:Boolean):void
	{
		var oldValue:Boolean = _preload;
		_preload = value;
		if (oldValue != value) {
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "src", oldValue, value));
		}
	}
	
	public const __doc__autoplay:String =
	'The "autoplay" read-write boolean property controls whether the video should be played ' + 
	'automatically when the "src" property is assigned and video is loaded, or should it wait ' + 
	'for explicit play command using the "playing" property. The default is true indicating ' + 
	'automatic play when ready.\n';
	
	[Bindable('propertyChange')]
	/**
	 * The autoplay property controls whether the video should be played automatically
	 * when started.
	 */
	public function get autoplay():Boolean
	{
		return _autoplay;
	}
	public function set autoplay(value:Boolean):void
	{
		var oldValue:Boolean = _autoplay;
		_autoplay = value;
		if (oldValue != value) {
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "autoplay", oldValue, value));
		}
	}
	
	public const __doc__loop:String =
	'The "loop" read-write boolean property controls whether the video should loop to begining ' + 
	'when it reaches the end.\n';
	 
	[Bindable('propertyChange')]
	/**
	 * The loop property controls whether the video should be looped after completed.
	 */
	public function get loop():Boolean
	{
		return _loop;
	}
	public function set loop(value:Boolean):void
	{
		var oldValue:Boolean = _loop;
		_loop = value;
		if (oldValue != value) {
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "loop", oldValue, value));
		}
	}
	
	public const __doc__controls:String = 
	'The "controls" read-write boolean property controls whether the video control panel should ' + 
	'be displayed or not. Default is false. The current implementation displays a video control ' + 
	'panel at the bottom of the user interface view. The control panel automatically hides if ' + 
	'there is no mouse activity for some time, and the mouse is not over the control panel. If ' + 
	'the mouse is rolled over the control panel, the view remains visible. Later, if the user moves ' + 
	'the mouse anywhere on the video view, the control panel re-appears if it was hidden before. ' + 
	'By the default, the control panel displays various control buttons based on the current state. ' + 
	'For example, if the "play" property is set, then the play/pause, speaker and volume ' + 
	'controls are displayed, whereas if the "publish" property is set, then the record/stop, ' + 
	'camera, microphone and gain controls are displayed.\n';
	 
	[Bindable('propertyChange')]
	/**
	 * The controls property controls whether the video should display user controls or not.
	 */
	public function get controls():Boolean
	{
		return (_controls != null);
	}
	public function set controls(value:Boolean):void
	{
		var oldValue:Boolean = (_controls != null);
		if (value && _controls == null) {
			_controls = new VideoControl();
			this.addChild(_controls);
		}
		else if (!value && _controls != null) {
			this.removeChild(_controls);
			_controls = null;
		}
		if (oldValue != value) {
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "controls", oldValue, value));
		}
	}
	
	public const __doc__detectActivity:String = 
	'The "detectActivity" read-write boolean property controls whether the mouse activity is ' + 
	'detected, e.g., to automatically hide the control bar. Default is "true".\n';
	 
	[Bindable('propertyChange')]
	/**
	 * The detectActivity property controls whether the mouse activity is detected or not?
	 */
	public function get detectActivity():Boolean
	{
		return _detectActivity;
	}
	public function set detectActivity(value:Boolean):void
	{
		var oldValue:Boolean = _detectActivity;
		_detectActivity = value;
		if (oldValue != value) {
			if (_controls != null && (_controls is VideoControl)) {
				if (value)
					VideoControl(_controls).startHideTimer();
				else
					VideoControl(_controls).stopHideTimer();
			}
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "detectActivity", oldValue, value));
		}
	}
	
	public const __doc__args:String = 
	'The "args" read-only array of values represents the connection arguments captured from ' + 
	'the "src" URL\'s "arg" parameters. For example if "src" is set to ' + 
	'"rtmp://server/record?publish=live&arg=myuser&arg=mypass" then the "args" property will ' + 
	'be ["myuser","mypass"].\n';
	
	/**
	 * The read-only args property defines the connect() arguments if any.
	 * This is set using zero of more arg params in the "src" URL.
	 */
	public function get args():Array
	{
		return _args;
	}
	
	public const __doc__scheme:String =
	'The "scheme" read-only string property indicates the scheme of the "src" URL. ' + 
	'It is set automatically when the "src" property is set.\n';
	
	/**
	 * The read-only URL scheme property of the URL.
	 * This is set using the scheme of the "src" URL.
	 */
	public function get scheme():String
	{
		return _scheme;
	}
	
	public const __doc__farID:String =
	'The "farID" read-write string property indicates the farID parameter of the "src" ' + 
	'URL. It is set automatically when the "src" property is set. This property is ' + 
	'used to create NetStream object in scheme of "rtmfp" to establish direct connection ' + 
	'to the given farID peer. For example, if "src" is set to ' + 
	'"rtmfp://stratus.adobe.com/some-developer-key?play=live1&farID=some-far-id" then ' + 
	'"some-far-id" is assumed to be the ID of the remote side who is publishing the stream ' + 
	'named "live1".\n';
	
	/**
	 * The read-write farID property of the URL to play.
	 * This is set using farID param in the "src" URL.
	 */
	public function get farID():String
	{
		return _farID;
	}
	public function set farID(val:String):void
	{
		_farID = val;
	}
	
	public const __doc__nearID:String =
	'The "nearID" read-only string property indicates the nearID property of the established ' + 
	'NetConnection when the "rtmfp" scheme is used to establish direct connection. ' + 
	'It is available only after the connection to the server is established using the ' + 
	'"src" URL of the form "rtmfp://stratus.adobe.com/some-developer-key...". The application ' + 
	'should capture the "nearID" and give it to the remote side who wants to play the ' + 
	'stream published by this side, so that the remote side can use this property as its ' + 
	'"farID" property to play the stream.\n';
	
	/**
	 * The read-only nearID property of the URL after publish.
	 * This is available after connection is complete using an rtmfp URL.
	 */
	public function get nearID():String
	{
		return _nearID;
	}
	
	public const __doc__url:String =
	'The "url" read-write string property refers to the url part of the "src" property. ' + 
	'The url part excludes any parameters if the URL scheme is "rtmp" or "rtmfp" but includes ' + 
	'those if the scheme is "http" or "https". Although "url" property is read-write, ' + 
	'the application should not directly write this property. Instead the application writes ' + 
	'the "src" property, which implicitly sets the "url" property. Setting the "url" property ' + 
	'connects, disconnects or reconnects to the services in case of "rtmp" or "rtmfp" URLs, ' + 
	'and starts "load" or "unload" in case of "http" or "https" URLs.\n';
	
	[Bindable('propertyChange')]
	/**
	 * The url property controls the connection. 
	 * This can also be set using the "src" property.
	 */
	public function get url():String
	{
		return _url;
	}
	public function set url(value:String):void
	{
		var oldValue:String = _url;
		_url = value;
		
		if (oldValue != value) {
			setProperty("nearID", null); // nearID will be set on success
			
			var index:int = (value != null ? value.indexOf(':') : -1);
			_scheme = (index >= 0 ? value.substr(0, index).toLowerCase() : null);
			
			if (oldValue != null) {
				if (oldValue.substr(0, 4) == "http")
					unload(true);
				else 
					disconnect();
			}
			if (value != null) {
				if (value.substr(0, 4) == "http")
					load();
				else
					connect();
			}
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "url", oldValue, value));
		}
	}
	
	public const __doc__isDownload:String =
	'The "isDownload read-only boolean property indicates whether the "src" will cause ' + 
	'progressive download of media or not? It is true for "http" and "https" URLs, and ' + 
	'false for other URLs such as "rtmp" and "rtmfp".\n'
	
	public function get isDownload():Boolean
	{
		return _scheme == 'http' || _scheme == 'https';			
	}
	
	public const __doc__play:String =
	'The "play" read-write string property refers to the play stream name for streaming ' + 
	'"src" value, such as "rtmp" or "rtmfp" URLs. Although this is a read-write property ' + 
	'the application should use the "play" parameter of the "src" property to set this. ' + 
	'For example, if the "src" is set to "rtmp://server/path?play=live1" then the ' + 
	'"play" property is automatically set to "live1". Setting this property resets the ' + 
	'"publish" and "live" properties and creates the NetStream for the given play stream ' + 
	'name. Resetting this property to null resets the "playing" property and stops the' + 
	'previous play stream if any.\n';
	
	[Bindable('propertyChange')]
	/**
	 * The stream-name for playback.
	 */
	public function get play():String
	{
		return _play;
	}
	public function set play(value:String):void
	{
		var oldValue:String = _play;
		_play = value;
		
		if (oldValue != value) {
			if (oldValue != null && (url == null || url.substr(0, 4) != "http"))
				playing = false;
			if (value != null) {
				if (!bidirection) {
					if (publish != null)
						publish = null;
					if (live)
						live = false;
				}
				
				if (display)
					attachVideo();
				if (autoplay)
					createStream();
			}
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "play", oldValue, value));
		}
	}
	
	public const __doc__publish:String =
	'The "publish" read-write string property refers to the publish stream name for streaming ' + 
	'"src" value, such as "rtmp" or "rtmfp" URLs. Although this is a read-write property ' + 
	'the application should use the "publish" parameter of the "src" property to set this. ' + 
	'For example, if the "src" is set to "rtmp://server/path?publish=live1" then the ' + 
	'"publish" property is automatically set to "live1". Setting this property resets the ' + 
	'"play" and sets the "live" properties, enables "camera" and "microphone" properties ' + 
	'and creates the given publish stream name. Resetting this property to null resets the ' + 
	'"recording", "live", "camera" and "microphone" properties and destroys the previous ' + 
	'publish stream if any.\n';
	
	[Bindable('propertyChange')]
	/**
	 * The stream-name for publish.
	 */
	public function get publish():String
	{
		return _publish;
	}
	public function set publish(value:String):void
	{
		var oldValue:String = _publish;
		_publish = value;
		
		if (oldValue != value) {
			if (oldValue != null) {
				recording = false;
				if (live)
					live = false;
				camera = microphone = false;
			}
			if (value != null) {
				if (!bidirection) {
					if (play != null)
						play = null;
				}
				if (!live)
					live = true;
				camera = microphone = true;
				if (display)
					attachVideo();
				if (autoplay)
					createStream();
			}
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "publish", oldValue, value));
		}
	}
	
	public const __doc__record:String =
	'The "record" read-write boolean property refers to whether the publish stream is also ' + 
	'recorded on the server, and is derived from the "record" parameter of the "src" property. ' + 
	'For example if the "src" is set to "rtmp://server/path?publish=test1&record=true" ' + 
	'then the "record" property is set to true. Although this is a read-write property ' + 
	'the application should use the "record" parameter of the "src" property to set this.\n';
	
	[Bindable('propertyChange')]
	/**
	 * The record property along with publish allows recording of video to server.
	 */
	public function get record():Boolean
	{
		return _record;
	}
	public function set record(value:Boolean):void
	{
		var oldValue:Boolean = _record;
		_record = value;
		if (oldValue != value) {
			if (recording) { // reset recording stream
				destroyStream();
				createStream();
			}
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "record", oldValue, value));
		}
	}
	
	public const __doc__live:String =
	'The "live" read-write boolean property refers to whether the current display mode is live ' + 
	'camera view or not. This is implicitly set when "publish" property is set. This can be ' + 
	'explicitly set by the "live" parameter in the "src" property. For example, when the ' + 
	'"src" property is set to "?live=true" then "live" property is set to true. This property ' + 
	'controls the "camera" property, but not the reverse. This property when set also attaches ' + 
	'the camera to the local video display.\n';
	
	[Bindable('propertyChange')]
	/**
	 * Whether local video is displayed as preview.
	 */
	public function get live():Boolean
	{
		return _live;
	}
	public function set live(value:Boolean):void
	{
		var oldValue:Boolean = _live;
		_live = value;
		if (oldValue != value) {
			camera = value;
			if (value && display)
				attachVideo();
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "live", oldValue, value));
		}
	}
	
	public const __doc__mirrored:String =
	'The "mirrored" read-write boolean property controls whether the local video view is mirrored ' + 
	'either for live or when publish is set. This property does not effect the remote view when ' + 
	'play is set. Default is "true".\n';
	
	[Bindable('propertyChange')]
	/**
	 * Whether local video is mirrored or not?
	 */
	public function get mirrored():Boolean
	{
		return _mirrored;
	}
	public function set mirrored(value:Boolean):void
	{
		var oldValue:Boolean = _mirrored;
		_mirrored = value;
		if (oldValue != value) {
			resizeVideoHandler(null);
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "mirrored", oldValue, value));
		}
	}
	
	public const __doc__bidirection:String =
	'The "bidirection" read-write boolean property controls whether to support both play and publish ' + 
	'streams at the same time or not. Default is false. Setting this to true will allow you to set both ' + 
	'"play" and "publish" properties for bi-directional stream. The stream which is set later ' + 
	'is used to attach to the video display. This is useful for SIP call using the SIP-RTMP gateway ' + 
	'which requires both "publish=local" and "play=remote".\n';
			
	[Bindable('propertyChange')]
	/**
	 * Whether the streams are created for both directions is possible.
	 */
	public function get bidirection():Boolean
	{
		return _bidirection;
	}
	public function set bidirection(value:Boolean):void
	{
		var oldValue:Boolean = _bidirection;
		_bidirection = value;
		if (oldValue != value) {
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "bidirection", oldValue, value));
		}
	}
	
	public const __doc__playing:String =
	'The "playing" read-write boolean property refers to the play or pause state of the stream. ' + 
	'If "isDownload" is true, i.e., the "src" is a "http" or "https" URL, then the "playing" ' + 
	'property calls the play() or pause() method of the VideoDisplay object. Otherwise, ' + 
	'it creates or destroys the NetStream for playing. This property is implicitly set when ' + 
	'"autoplay" is set and the "src" property is set to indicate a play mode. This property ' + 
	'is also attached to the state of play/pause button in the control panel if visible.\n';
			
	[Bindable('propertyChange')]
	/**
	 * Whether the video is playing or not (if play is valid).
	 */
	public function get playing():Boolean
	{
		return _playing;
	}
	public function set playing(value:Boolean):void
	{
		var oldValue:Boolean = _playing;
		_playing = value;
		
		trace("playing " + oldValue + "=>" + value);
		if (oldValue != value) {
			if (value) 
				detachPoster();
				
			if (isDownload) {
				if (oldValue)
					_videoDisplay.pause();
				if (value)
					_videoDisplay.play();
			}
			else {
				if (oldValue)
					destroyStream();
				if (value)
					createStream();
			}
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "playing", oldValue, value));
		}
	}
	
	public const __doc__recording:String =
	'The "recording" read-write boolean property refers to the publish or stop state of the ' + 
	'stream. This is useful only for a publish stream of "rtmp" or "rtmfp" URL. The property ' + 
	'creates or destroys the NetStream for publish. This is implicitly set when "src" points to ' + 
	'a publish stream, e.g., "rtmp://server/path?publish=live1, and the stream is created. ' + 
	'This property is also attached to the state of the record/stop button in the control ' + 
	'panel if visible.\n';
	
	[Bindable('propertyChange')]
	/**
	 * Whether the camera/microphone is capturing or not (if publish or live is valid).
	 */
	public function get recording():Boolean
	{
		return _recording;
	}
	public function set recording(value:Boolean):void
	{
		var oldValue:Boolean = _recording;
		_recording = value;
		
		if (oldValue != value) {
			if (oldValue)
				destroyStream();
			if (value)
				createStream();
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "recording", oldValue, value));
		}
	}
	
	public const __doc__camera:String =
	'The "camera" read-write boolean property refers to whether the camera is on and ' + 
	'capturing video or not. This is implicitly set when "live" or "publish" property is ' + 
	'set. This can be explicitly set to control the camera on/off. This property is also ' + 
	'attached to the camera on/off icon on the control panel if visible. On Mac OS, when ' + 
	'set, it tries to use the "USB Video Class Video" camera, whereas on other platforms it' + 
	'tries to use the default camera. When the camera is set or reset or when the ' + 
	'cameraObject is changed a "cameraChange" event is dispatched.\n';
	
	[Bindable('propertyChange')]
	/**
	 * Whether camera is active or not?
	 */
	public function get camera():Boolean
	{
		return _camera;
	}
	public function set camera(value:Boolean):void
	{
		var oldValue:Boolean = _camera;
		if (value != oldValue) {
			if (!value) {
				_camera = value;
				if (_cameraObject != null) {
					_cameraObject = null;
					dispatchEvent(new Event("cameraChange"));
				}
			}
			else {
				if (_cameraObject == null) {
					var index1:int = Camera.names.indexOf("USB Video Class Video");
					var index2:int = Camera.names.indexOf("Built-in iSight");
					if (index1 >= 0 && Capabilities.os.indexOf("Mac") >= 0) 
						_cameraObject = Camera.getCamera(index1.toString());
					else if (index2 >= 0 && Capabilities.os.indexOf("Mac") >= 0) 
						_cameraObject = Camera.getCamera(index2.toString());
					else
						_cameraObject = Camera.getCamera();
					if (_cameraObject != null) {
						_cameraObject.setLoopback(_cameraLoopback);
						_cameraObject.setMode(_cameraWidth, _cameraHeight, _cameraFPS);
						_cameraObject.setQuality(_cameraBandwidth, _cameraQuality);
						dispatchEvent(new Event("cameraChange"));
					}
				}
				if (_cameraObject != null) {
					if (_cameraObject.muted) {
						setProperty("deviceAllowed", false);
						showSettings();
						_cameraObject.addEventListener(StatusEvent.STATUS, cameraStatusHandler, false, 0, true);
					}
					else {
						setProperty("deviceAllowed", true);
						_camera = value;
					}
				}
			}
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "camera", oldValue, value));
		}
	}
	
	public const __doc__microphone:String =
	'The "microphone" read-write boolean property refers to whether the microphone is on and ' + 
	'capturing audio or not. This is implicitly set when "publish" property is ' + 
	'set. This can be explicitly set to control the microphone on/off. This property is also ' + 
	'attached to the microphone on/off icon on the control panel if visible. ' + 
	'When the microphone is set or reset or when the ' + 
	'microphoneObject is changed a "microphoneChange" event is dispatched.\n';
	
	[Bindable('propertyChange')]
	/**
	 * Whether microphone is active or not?
	 */
	public function get microphone():Boolean
	{
		return _microphone;
	}
	public function set microphone(value:Boolean):void
	{
		var oldValue:Boolean = _microphone;
		if (value != oldValue) {
			if (!value) {
				stopMicLevelTimer();
				_microphone = value;
				if (_microphoneObject != null) {
					_microphoneObject = null;
					if (CONFIG::sdk4) { 
						// use getMicrophone to remove the enhance microphone which takes unnecessary CPU 
						if (Microphone['getEnhancedMicrophone'] != undefined) {
							var mic:Microphone = Microphone.getMicrophone(-1);
						}
					}
					dispatchEvent(new Event("micChange"));
				}
			}
			else {
				if (_microphoneObject == null) {
					if (CONFIG::sdk4) {
						if(Microphone['getEnhancedMicrophone'] == undefined) {
							_microphoneObject = Microphone.getMicrophone(-1);
						}
						else {
							if (!this.echoCancel) {
								trace('enhanced mic available but not used');
								_microphoneObject = Microphone.getMicrophone(-1);
							}
							else {
								trace('enhanced mic available and used');
								_microphoneObject = Microphone['getEnhancedMicrophone'](-1);
								var options:Object = new flash.media.MicrophoneEnhancedOptions();
								options.mode = flash.media.MicrophoneEnhancedMode.FULL_DUPLEX;
								options.autoGain = false;
								options.echoPath = 128;
								options.nonLinearProcessing = true;
								_microphoneObject['enhancedOptions'] = options;
							}
						} 
					} 
					else {
						_microphoneObject = Microphone.getMicrophone(-1);
					}
					if (_microphoneObject != null) {
						_microphoneObject.codec = codec;
						_microphoneObject.rate = rate;
						_microphoneObject.encodeQuality = encodeQuality;
						_microphoneObject.framesPerPacket = framesPerPacket;
						_microphoneObject.setSilenceLevel(silenceLevel);
						_microphoneObject.setUseEchoSuppression(echoSuppression);
						gain = _microphoneObject.gain / 100;
						dispatchEvent(new Event("micChange"));
					}
				}
				if (_microphoneObject != null) {
					if (_microphoneObject.muted) {
						setProperty("deviceAllowed", false);
						showSettings();
						_microphoneObject.addEventListener(StatusEvent.STATUS, micStatusHandler, false, 0, true);
					}
					else {
						setProperty("deviceAllowed", true);
						_microphone = value;
						startMicLevelTimer();
					}
				}
			}
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "microphone", oldValue, value));
		}
	}
	
	public const __doc__cameraObject:String =
	'The "cameraObject" read-only property refers to the currently selected Camera object, ' + 
	'or null if none is selected or in use.\n';
	 
	/**
	 * The camera object.
	 */
	public function get cameraObject():Camera
	{
		return _cameraObject;
	}
	
	public const __doc__microphoneObject:String =
	'The "microphoneObject" read-only property refers to the currently selected Microphone object, ' + 
	'or null if none is selected or in use.\n';
	 
	/**
	 * The microphone object.
	 */
	public function get microphoneObject():Microphone
	{
		return _microphoneObject;
	}
	
	public const __doc__privacyEvent:String =
	'The "privacyEvent" read-write boolean property controls whether an event callback is ' + 
	'invoked when the Flash Player demands privacy settings display or not? It also allows ' + 
	'using the deviceAllowed property to know if the user has changed his device access ' + 
	'permissions. Default is "false".\n';
	
	[Bindable('propertyChange')]
	/**
	 * Whether to dispatch event callback when Flash Player settings is shown?
	 */
	public function get privacyEvent():Boolean
	{
		return _privacyEvent;
	}
	public function set privacyEvent(value:Boolean):void
	{
		var oldValue:Boolean = _privacyEvent;
		_privacyEvent = value;
		if (oldValue != value) {
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "privacyEvent", oldValue, value));
		}
	}
	
	public const __doc__deviceAllowed:String =
	'The "deviceAllowed" read-only boolean property indicates whether the microphone and/or ' + 
	'camera device is allowed (or denied) by the end user in the Flash Player security' + 
	'settings. To get the correct values for this property, you must set the "privacyEvent" ' + 
	'property to "true". The value is not valid until a device access is needed.\n';
	
	/**
	 * Whether access to camera and microphone is allowed?
	 */
	public function get deviceAllowed():Boolean
	{
		var mic:Microphone = Microphone.getMicrophone();
		var cam:Camera = Camera.getCamera();
		return (mic && !mic.muted || cam && !cam.muted);
	}
	
	public const __doc__display:String =
	'The "display" read-write boolean property refers to whether the video display is enabled ' + 
	'or not. Default is "true". This property applies to both publish and play mode. ' + 
	'If you do not want to display the video, e.g., for audio-only user interface or ' + 
	'for second publish stream, you can set this to "false".\n';
	
	[Bindable('propertyChange')]
	/**
	 * Whether display is enabled or not?
	 */
	public function get display():Boolean
	{
		return _display;
	}
	public function set display(value:Boolean):void
	{
		var oldValue:Boolean = _display;
		if (value != oldValue) {
			_display = value;
			
			if (!value) {
				if (video != null) {
					detachVideo();
				}
			}
			else {
				if (video == null) {
					if (play != null || publish != null || live) {
						attachVideo();
					}
				}
			}
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "display", oldValue, value));
		}
	}
	
	public const __doc__videoDisplay:String =
	'The "videoDisplay" read-only property refers to the currently displayed VideoDisplay ' + 
	'object when "isDownload" is true, or none if there is no VideoDisplay. Either the ' + 
	'VideoDisplay or Video object is available when a video is displaying.\n';
	 
	/**
	 * The video display object.
	 */
	public function get videoDisplay():VideoDisplay
	{
		return _videoDisplay;
	}
	
	public const __doc__video:String =
	'The "video" read-only property refers to the currently displayed Video ' + 
	'object when "live" or "playing" is true, or none if there is no Video. Either the ' + 
	'VideoDisplay or Video object is available when a video is displaying.\n';
	 
	/**
	 * The video object.
	 */
	public function get video():Video
	{
		return _video;
	}
	
	public const __doc__videoWidth:String =
	'The "videoWidth" read-only number property refers to the width in pixels of the active ' + 
	'video display if any, or NaN if none. This is the original unscaled width.\n';
	 
	/**
	 * The width of video display.
	 */
	public function get videoWidth():Number
	{
		return _videoWidth;
	}
	
	public const __doc__videoHeight:String =
	'The "videoHeight" read-only number property refers to the height in pixels of the active ' + 
	'video display if any, or NaN if none. This is the original unscaled height.\n';
	 
	/**
	 * The height of video display.
	 */
	public function get videoHeight():Number
	{
		return _videoHeight;
	}
	
	public const __doc__zoom:String =
	'The "zoom" read-write string property controls the zoom mode when the video aspect ratio is ' +
	'different than the display aspect ratio. The video aspect ratio is set by the capture device such as Camera, ' +
	'sent by the publishing stream to the playing stream or present in the video file itself. The display ' +
	'aspect ratio is determined by the dimension of the VideoIO.swf object and is based on the ' +
	'dimensions specified in embedding object/embed tags in HTML, SWFLoader component in parent SWF or ' +
	'monitor size in full screen mode. When this property is set to null, there is no zoom adjustiment made ' +
	'and the displayed video may be distorted, e.g., if 320x240 video is displayed in 1280x720 it will ' +
	'appear to be horizontally stretched. When this property is set to "in", the video is zoomed in without ' +
	'distortion so as to fill the full display size, e.g., if 320x240 video is displayed in 1280x720 it will ' +
	'zoom in central 320x180 of the video and fill the full display area. When this property is set to "out", ' +
	'the video is zoomed out without distortion so as to show the full video, e.g., is 320x240 video is displayed ' +
	'in 1280x720 it will expand full 320x240 to central 960x720 region on the display area, but leave blank spaces ' +
	'on left and right side of the video. Default is "in" which is well suited for video conferencing. If you have ' +
	'sub-titles or log to be displayed on top or bottom, use null or "out" to display the full video because "in" ' +
	'can hide parts of the video on the sides.\n';
	
	[Bindable('propertyChange')]
	/**
	 * The zoom mode when aspect ratio of video is different than the display aspect ratio?
	 */
	public function get zoom():String
	{
		return _zoom;
	}
	public function set zoom(value:String):void
	{
		var oldValue:String = _zoom;
		if (value != oldValue) {
			_zoom = value;
			resizeVideoHandler(null);
			sendVideoSize();
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "zoom", oldValue, value));
		}
	}
	
	public const __doc__currentFPS:String =
	'The "currentFPS" read-only number property refers to the current frames per second of video ' + 
	'display in live streaming mode. If unavailable, this is NaN.\n';
	 
	/**
	 * The current FPS of playing stream.
	 */
	public function get currentFPS():Number
	{
		return _currentFPS;
	}
	
	public const __doc__bandwidth:String =
	'The "bandwidth" read-only number property indicates the stream bandwidth in bytes per second for live ' + 
	'play or publish mode. It is calculated using the currentBytesPerSecond property of the NetStream ' + 
	'object. This property gives the rough idea of the bandwidth utilization. It does not depend on ' + 
	'playbackBackBytesPerSecond of NetStream. If unavailable, this field is NaN.\n';
	
	/**
	 * The bandwidth property the live NetStream.
	 */
	public function get bandwidth():Number
	{
		return _bandwidth;
	}
	
	public const __doc__gain:String =
	'The "gain" read-write number property refers to the microphone gain, and is between ' + 
	'0 and 1. When set, it is scaled to 0-100 and applied to the gain property of the ' + 
	'"microphoneObject".\n';
	
	[Bindable('propertyChange')]
	/**
	 * The microphone volume is a number between 0.0 and 1.0. When set, it updates the microphone
	 * gain.
	 */
	public function get gain():Number
	{
		return _gain;
	}
	public function set gain(value:Number):void
	{
		var oldValue:Number = _gain;
		_gain = value;
		if (_microphoneObject != null)
			_microphoneObject.gain = value * 100;
		if (oldValue != value) {
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "gain", oldValue, value));
		}
	}
	
	public const __doc__level:String =
	'The "level" read-only number property refers to the microphone level, and is between ' + 
	'0 and 1. It is not valid only when "microphone" is true, indicating that the ' + 
	'microphone is actively capturing the audio.\n';
	
	[Bindable('propertyChange')]
	/**
	 * The microphone level is the current activity level of the microphone.
	 */
	public function get level():Number
	{
		return _level;
	}
	public function set level(value:Number):void
	{
		var oldValue:Number = _level;
		_level = value;
		if (oldValue != value) {
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "level", oldValue, value));
		}
	}
	
	public const __doc__rate:String =
	'The "rate" read-write number property refers to the microphone sampling rate, and is ' + 
	'8 or 16. This is useful only when "codec" is "Speex" for the "microphoneObject". Default' + 
	'is 16. It represents the sampling rate of the codec in kHz. ' + 
	'It is not recommended to change this value unless you really need to use ' + 
	'a different sampling rate, e.g., for interoperating with telephony network you may need ' + 
	'8 kHz sampling.\n';
	
	[Bindable('propertyChange')]
	/**
	 * The sampling rate property of the microphone.
	 */
	public function get rate():Number
	{
		return _rate;
	}
	public function set rate(value:Number):void
	{
		var oldValue:Number = _rate;
		_rate = value;
		if (_microphoneObject != null)
			_microphoneObject.rate = value;
		if (oldValue != value) {
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "rate", oldValue, value));
		}
	}
	
	public const __doc__codec:String =
	'The "codec" read-write string property refers to the microphone codec, and is ' + 
	'"Speex" or "NellyMoser". In Flash Player 11+, "PCMU" and "PCMA" are also supported. ' +
	'Default is "Speex".\n';
	
	[Bindable('propertyChange')]
	/**
	 * The codec property of the microphone.
	 */
	public function get codec():String
	{
		return _codec;
	}
	public function set codec(value:String):void
	{
		var oldValue:String = _codec;
		_codec = value;
		if (_microphoneObject != null)
			_microphoneObject.codec = value;
		if (oldValue != value) {
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "codec", oldValue, value));
		}
	}
	
	public const __doc__encodeQuality:String =
	'The "encodeQuality" read-write number property refers to the microphone encodeQuality, and is ' + 
	'a number between 0 and 10, with 10 indicating highest quality. This is useful only when ' + 
	'"codec" is "Speex" and controls the bandwidth of the captured audio stream. ' + 
	'Default is 6.\n';
	
	[Bindable('propertyChange')]
	/**
	 * The encodeQuality property of the microphone.
	 */
	public function get encodeQuality():Number
	{
		return _encodeQuality;
	}
	public function set encodeQuality(value:Number):void
	{
		var oldValue:Number = _encodeQuality;
		_encodeQuality = value;
		if (_microphoneObject != null)
			_microphoneObject.encodeQuality = value;
		if (oldValue != value) {
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "encodeQuality", oldValue, value));
		}
	}
	
	public const __doc__framesPerPacket:String =
	'The "framesPerPacket" read-write number property refers to the microphone framesPerPacket, ' + 
	'and is typically a small number like 1 or 2. Default is 1. It is not recommended to change ' + 
	'this value. Some versions of Flash Player are known to work well when "framesPerPacket" is ' + 
	'1 if the "codec" is "Speex".\n';
	
	[Bindable('propertyChange')]
	/**
	 * The framesPerPacket property of the microphone.
	 */
	public function get framesPerPacket():Number
	{
		return _framesPerPacket;
	}
	public function set framesPerPacket(value:Number):void
	{
		var oldValue:Number = _framesPerPacket;
		_framesPerPacket = value;
		if (_microphoneObject != null)
			_microphoneObject.framesPerPacket = value;
		if (oldValue != value) {
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "framesPerPacket", oldValue, value));
		}
	}
	
	public const __doc__silenceLevel:String =
	'The "silenceLevel" read-write number property refers to the microphone silenece level, and is between ' + 
	'0 and 100. When set to 0, it disables silence suppression, and when set to 100, it disables any audio.' + 
	'Default is 0. Recommended value is 2.\n';
	
	[Bindable('propertyChange')]
	/**
	 * The silenceLevel is between 0 and 100 for silence suppression: 0 means disable silence suppression,
	 * and 100 means suppress all audio. Recommended value is 2 for video conference and 0 for video message
	 * recording.
	 */
	public function get silenceLevel():Number
	{
		return _silenceLevel;
	}
	public function set silenceLevel(value:Number):void
	{
		var oldValue:Number = _silenceLevel;
		_silenceLevel = value;
		if (_microphoneObject != null)
			_microphoneObject.setSilenceLevel(value);
		if (oldValue != value) {
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "silenceLevel", oldValue, value));
		}
	}
	
	public const __doc__echoSuppression:String =
	'The "echoSuppression" read-write boolean property controls whether echo suppression is enabled in ' + 
	'Flash Player or not. Default is true.\n';
	
	[Bindable('propertyChange')]
	/**
	 * Controls the Microphone's setUseEchoSuppression().
	 */
	public function get echoSuppression():Boolean
	{
		return _echoSuppression;
	}
	public function set echoSuppression(value:Boolean):void
	{
		var oldValue:Boolean = _echoSuppression;
		_echoSuppression = value;
		if (_microphoneObject != null)
			_microphoneObject.setUseEchoSuppression(value);
		if (oldValue != value) {
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "echoSuppression", oldValue, value));
		}
	}
	
	public const __doc__echoCancel:Object =
	'The "echoCancel" read-write Object property controls the echo cancellation mode when used with Flash Player 10.3 or ' +
	'later. For earlier versions, it does not have any effect. If true it uses getEnhancedMicrophone with the default echo ' +
	'cancellation options, and if false it uses the getMicrophone without echo cancellation options. Changing the property ' +
	'does not have any effect after "microphone" is set to true, which happens implicitly in publish mode. Default is true.\n';
	
	[Bindable('propertyChange')]
	/**
	 * Controls the Microphone's echo cancellation mode.
	 */
	public function get echoCancel():Boolean
	{
		return _echoCancel;
	}
	public function set echoCancel(value:Boolean):void
	{
		var oldValue:Boolean = _echoCancel;
		_echoCancel = value;
		if (oldValue != value) {
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "echoCancel", oldValue, value));
		}
	}
	
	public const __doc__sound:String =
	'The "sound" read-write boolean property refers to whether the play sound is on or off. ' + 
	'Default is true. This property is also attached to the speaker on/off icon on the ' + 
	'control panel if visible. This controls the global sound volume of the application.\n';
	
	[Bindable('propertyChange')]
	/**
	 * Whether the speaker is active or not (muted)?
	 */
	public function get sound():Boolean
	{
		return _sound;
	}
	public function set sound(value:Boolean):void
	{
		var oldValue:Boolean = _sound;
		_sound = value;
		updateMixer();
		if (oldValue != value) {
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "sound", oldValue, value));
		}
	}
	
	public const __doc__volume:String =
	'The "volume" read-write number property refers to play sound volume between 0 and 1 ' + 
	'with 1 indicating full volume. Default is 0.5. ' + 
	'This property is also attached to the speaker volume slider on the ' + 
	'control panel if visible. This controls the global sound volume of the application.\n';
	
	[Bindable('propertyChange')]
	/**
	 * The speaker volume property controls the volume level of the global SoundMixer.
	 */
	public function get volume():Number
	{
		return _volume;
	}
	public function set volume(value:Number):void
	{
		var oldValue:Number = _volume;
		_volume = value;
		updateMixer();
		if (oldValue != value) {
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "volume", oldValue, value));
		}
	}
	
	public const __doc__smoothing:String =
	'The "smoothing" read-write boolean property refers to whether smoothing is applied to ' + 
	'the "video" display or not. Default is true. Since smoothing algorithm take CPU cycles, ' + 
	'applications may want to reset this property to reduce CPU utilization during playback.\n';
	
	[Bindable('propertyChange')]
	/**
	 * The smoothing property controls the smoothing of various Video objects in the application.
	 */
	public function get smoothing():Boolean
	{
		return _smoothing;
	}
	public function set smoothing(value:Boolean):void
	{
		var oldValue:Boolean = _smoothing;
		_smoothing = value;
		if (video != null)
			video.smoothing = value;
		if (oldValue != value) {
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "smoothing", oldValue, value));
		}
	}
	
	//public const __doc__cameraAspectRatio:String =
	//'The "cameraAspectRatio" read-write number property controls to the camera capture aspect ratio. ' + 
	//'Default is 4/3 which is 1.333333... For using non-standard aspect ratio such as HD, first set "cameraAspectRatio" ' + 
	//'and then set either "cameraWidth" or "cameraHeight". When using non-default aspect ratio, it is the ' +
	//'application\'s responsibility to set "cameraAspectRatio" of both publish and play side to be the same. ' +
	//'The play side also needs the correct value for correct display even though the value is not applied to a camera. ' +
	//' When this property is changed, the "cameraWidth" or "cameraHeight" are not automatically adjusted ' +
	//'immediately, but it waits until either "cameraWidth" or "cameraHeight" is set, and then both the properties ' +
	//'are adjusted. You can also set this property to a string, e.g., "4:3" or "16:9" but reading it will always ' +
	//'return the number representation.\n';
	//
	//[Bindable('propertyChange')]
	///**
	// * The camera aspect ratio.
	// */
	//public function get cameraAspectRatio():Object
	//{
	//	return _cameraAspectRatio;
	//}
	//public function set cameraAspectRatio(value:Object):void
	//{
	//	var oldValue:Number = _cameraAspectRatio as Number;
	//	if (value is Number) {
	//		_cameraAspectRatio = value as Number;
	//	}
	//	else if (value is String) {
	//		try {
	//			var parts:Array = value.split(":");
	//			_cameraAspectRatio = parseInt(parts[0])/parseInt(parts[1]);
	//		} catch (e:Error) {
	//			trace("error parsing the cameraAspectRatio " + value);
	//		}
	//	}
	//	if (oldValue != _cameraAspectRatio) {
	//		dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "cameraAspectRatio", oldValue, _cameraAspectRatio));
	//	}
	//}
	
	public const __doc__cameraDimension:String =
	'The "cameraDimension" read-write string property controls to the camera capture dimension. ' + 
	'Default is "320x240". This property should be used instead of "cameraWidth" or "cameraHeight" ' +
	'and is required when setting to a non-standard aspect ratio such as HD camera capture. ' +
	'When this property is changed, the "cameraWidth" and "cameraHeight" are also changed as needed. ' +
	'When the display size is not 320x240, it periodically transmits the publish dimension to the player ' +
	'using NetStream\'s setVideoSize function, which in turn is used by the play side to adjust the ' +
	'aspect ratio of the display.\n';
	
	[Bindable('propertyChange')]
	/**
	 * The camera capture dimension.
	 */
	public function get cameraDimension():String
	{
		return "" + _cameraWidth + "x" + _cameraHeight;
	}
	public function set cameraDimension(value:String):void
	{
		var oldWidth:Number = _cameraWidth;
		var oldHeight:Number = _cameraHeight;
		var oldDimension:String = "" + _cameraWidth + "x" + _cameraHeight;
		if (oldDimension != value) {
			try {
				var parts:Array = value.split("x");
				var width:Number = parseInt(parts[0]);
				var height:Number = parseInt(parts[1]);
				// after both width and height are parsed.
				_cameraWidth = width;
				_cameraHeight = height;
				trace("changed from " + oldWidth + "x" + oldHeight + " to " + _cameraWidth + "x" + _cameraHeight);
			} catch (e:Error) {
				trace("error parsing the cameraDimension " + value);
				return;
			}
			setCameraMode();
			resizeVideoHandler(null);
			if (oldWidth != _cameraWidth)
				dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "cameraWidth", oldWidth, _cameraWidth));
			if (oldHeight != _cameraHeight)
				dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "cameraHeight", oldHeight, _cameraHeight));
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "cameraDimension", oldDimension, value));
		}
	}
	
	public const __doc__cameraWidth:String =
	'The "cameraWidth" (deprecated) read-write number property refers to the camera capture width in pixels. ' + 
	'Default is 320. Higher values give better quality picture but consume higher bandwidth. The ' + 
	'application may want to increase the resolution of capture for higher quality recording. ' + 
	'When setting "cameraWidth" it also changes "cameraHeight" and "cameraDimension" to keep the ' +
	'aspect ratio of 4:3. To change the aspect ratio you must set "cameraDimension" instead of ' +
	'"cameraWidth" or "cameraHeight".\n';
	
	[Deprecated]
	[Bindable('propertyChange')]
	/**
	 * The camera capture width.
	 */
	public function get cameraWidth():Number
	{
		return _cameraWidth;
	}
	public function set cameraWidth(value:Number):void
	{
		var oldWidth:Number = _cameraWidth;
		var oldDimension:String = "" + _cameraWidth + "x" + _cameraHeight;
		_cameraWidth = value;
		if (oldWidth != value) {
			var oldHeight:Number = _cameraHeight;
			_cameraHeight = Math.round(value*(3/4));
			var dimension:String = "" + _cameraWidth + "x" + _cameraHeight;
			setCameraMode();
			resizeVideoHandler(null);
			if (oldWidth != _cameraWidth)
				dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "cameraWidth", oldWidth, _cameraWidth));
			if (oldHeight != _cameraHeight)
				dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "cameraHeight", oldHeight, _cameraHeight));
			if (oldDimension != dimension)
				dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "cameraDimension", oldDimension, dimension));
		}
	}
	
	public const __doc__cameraHeight:String =
	'The "cameraHeight" (deprecated) read-write number property refers to the camera capture height in pixels. ' + 
	'Default is 240. Higher values give better quality picture but consume higher bandwidth. The ' + 
	'application may want to increase the resolution of capture for higher quality recording. ' + 
	'When setting "cameraHeight" it also changes "cameraWidth" and "cameraDimension" to keep the ' +
	'aspect ratio of 4:3. To change the aspect ratio you must set "cameraDimension" instead of ' +
	'"cameraWidth" or "cameraHeight".\n';
	
	[Deprecated]
	[Bindable('propertyChange')]
	/**
	 * The camera capture height.
	 */
	public function get cameraHeight():Number
	{
		return _cameraHeight;
	}
	public function set cameraHeight(value:Number):void
	{
		var oldHeight:Number = _cameraHeight;
		var oldDimension:String = "" + _cameraWidth + "x" + _cameraHeight;
		_cameraHeight = value;
		if (oldHeight != value) {
			var oldWidth:Number = _cameraWidth;
			_cameraWidth = Math.round(value*(4/3));
			var dimension:String = "" + _cameraWidth + "x" + _cameraHeight;
			setCameraMode();
			resizeVideoHandler(null);
			if (oldWidth != _cameraWidth)
				dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "cameraWidth", oldWidth, _cameraWidth));
			if (oldHeight != _cameraHeight)
				dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "cameraHeight", oldHeight, _cameraHeight));
			if (oldDimension != dimension)
				dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "cameraDimension", oldDimension, dimension));
		}
	}
	
	public const __doc__cameraFPS:String =
	'The "cameraFPS" read-write number property refers to the camera frames per second. ' + 
	'Default is 12. Higher values give better quality picture but consume higher bandwidth. The ' + 
	'application may want to increase the frames per second for higher quality recording.\n';
	
	[Bindable('propertyChange')]
	/**
	 * The fps (frames-per-second) property of the camera.
	 */
	public function get cameraFPS():Number
	{
		return _cameraFPS;
	}
	public function set cameraFPS(value:Number):void
	{
		var oldValue:Number = _cameraFPS;
		_cameraFPS = value;
		if (oldValue != value) {
			setCameraMode();
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "cameraFPS", oldValue, value));
		}
	}
	
	public const __doc__cameraBandwidth:String =
	'The "cameraBandwidth" read-write number property controls the maximum bandwidth in ' + 
	'bytes per second of the camera. A value of 0 means the camera can use as much ' + 
	'bandwidth as needed to maintain the desired "quality". Ideally only "cameraBandwidth" or ' + 
	'"cameraQuality" but not both should be set. Default is 0.\n';
	
	[Bindable('propertyChange')]
	/**
	 * The bandwidth property of the camera.
	 */
	public function get cameraBandwidth():Number
	{
		return _cameraBandwidth;
	}
	public function set cameraBandwidth(value:Number):void
	{
		var oldValue:Number = _cameraBandwidth;
		_cameraBandwidth = value;
		if (_cameraObject != null)
			_cameraObject.setQuality(_cameraBandwidth, _cameraQuality);
		if (CONFIG::player11) {
			if (_local != null && _local.videoStreamSettings != null) {
				_local.videoStreamSettings.setQuality(_cameraBandwidth, _cameraQuality);
			}
		}
		if (oldValue != value) {
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "cameraBandwidth", oldValue, value));
		}
	}
	
	public const __doc__cameraQuality:String =
	'The "cameraQuality" read-write number property controls the desired frame quality ' + 
	'of the camera and is between 0 and 100. A value of 0 means the quality can vary as needed ' + 
	'to avoid exceeding the available "bandwidth". A value of 1 means lowest quality with ' + 
	'maximum compressions and 100 means highest quality without compression. ' + 
	'Ideally only "cameraBandwidth" or "cameraQuality" but not both should be set. ' + 
	'Default is 0.\n';
	
	[Bindable('propertyChange')]
	/**
	 * The quality property of the camera.
	 */
	public function get cameraQuality():Number
	{
		return _cameraQuality;
	}
	public function set cameraQuality(value:Number):void
	{
		var oldValue:Number = _cameraQuality;
		_cameraQuality = value;
		if (_cameraObject != null)
			_cameraObject.setQuality(_cameraBandwidth, _cameraQuality);
		if (CONFIG::player11) {
			if (_local != null && _local.videoStreamSettings != null) {
				_local.videoStreamSettings.setQuality(_cameraBandwidth, _cameraQuality);
			}
		}
		if (oldValue != value) {
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "cameraQuality", oldValue, value));
		}
	}
	
	public const __doc__keyFrameInterval:String =
	'The "keyFrameInterval" read-write number property controls the desired key frame interval ' + 
	'of the camera. Default value is 15, which means every 15th frame is a key frame. ' + 
	'Allowed values are 1 to 28.\n';
	
	[Bindable('propertyChange')]
	/**
	 * The keyFrameInterval property of the camera.
	 */
	public function get keyFrameInterval():Number
	{
		return _keyFrameInterval;
	}
	public function set keyFrameInterval(value:Number):void
	{
		var oldValue:Number = _keyFrameInterval;
		_keyFrameInterval = value;
		if (_cameraObject != null)
			_cameraObject.setKeyFrameInterval(_keyFrameInterval);
		if (CONFIG::player11) {
			if (_local != null && _local.videoStreamSettings != null) {
				_local.videoStreamSettings.setKeyFrameInterval(_keyFrameInterval);
			}
		}
		if (oldValue != value) {
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "keyFrameInterval", oldValue, value));
		}
	}
	
	public const __doc__cameraLoopback:String =
	'The "cameraLoopback" read-write number property controls whether a local view of what the ' + 
	'camera is capturing is compressed and decompressed (true), as it would be for live ' + 
	'transmission, or whether the local view is uncompressed (false). The default value is false.\n';
	
	[Bindable('propertyChange')]
	/**
	 * The loopback property of the camera.
	 */
	public function get cameraLoopback():Boolean
	{
		return _cameraLoopback;
	}
	public function set cameraLoopback(value:Boolean):void
	{
		var oldValue:Boolean = _cameraLoopback;
		_cameraLoopback = value;
		if (_cameraObject != null)
			_cameraObject.setLoopback(value);
		if (oldValue != value) {
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "cameraLoopback", oldValue, value));
		}
	}
	
	public const __doc__videoCodec:String =
	'The "videoCodec" read-write string property refers to the publishing NetStream video codec, and is ' + 
	'"Sorenson" or "H264Avc". This property is only available when using Flash Player 11+, otherwise setting ' +
	'this property is ignored. Additionally for H264Avc, profile and level are supplied, e.g., "H264Avc/baseline/2". ' +
	'Default is "Sorenson".\n';
	
	[Bindable('propertyChange')]
	/**
	 * The video codec property of the publish stream.
	 */
	public function get videoCodec():String
	{
		return _videoCodec;
	}
	public function set videoCodec(value:String):void
	{
		if (CONFIG::player11) {
			var oldValue:String = _videoCodec;
			_videoCodec = value;
			if (_local != null) {
				_local.videoStreamSettings = createVideoStreamSettings();
			}
			if (oldValue != value) {
				dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "videoCodec", oldValue, value));
			}
		}
		else {
			trace("ignoring videoCodec property in this version of Flash Player");
		}
	}
	
	CONFIG::player11
	private function createVideoStreamSettings():flash.media.VideoStreamSettings {
		var s:flash.media.VideoStreamSettings;
		if (_videoCodec.substr(0, 7) == "H264Avc") {
			var parts:Array = _videoCodec.split("/");
			var profile:String = parts.length >= 2 ? parts[1] : flash.media.H264Profile.BASELINE;
			var level:String = parts.length >= 3 ? parts[2] : flash.media.H264Level.LEVEL_2;
			s = new flash.media.H264VideoStreamSettings();
			flash.media.H264VideoStreamSettings(s).setProfileLevel(profile, level);
			trace("using H264Avc/" + profile + "/" + level);
		} else if (_videoCodec == "Sorenson") {
			s = new flash.media.VideoStreamSettings();
		} else {
			trace("ignoring invalid videoCodec property: " + _videoCodec + ". using Sorenson");
			s = new flash.media.VideoStreamSettings();
		}
		// copy Camera settings to VideoStreamSettings.
		s.setKeyFrameInterval(_keyFrameInterval);
		s.setMode(_cameraWidth, _cameraHeight, _cameraFPS);
		s.setQuality(_cameraBandwidth, _cameraQuality);
		return s;
	}
	
	public const __doc__currentTime:String =
	'The "currentTime" read-write number property refers to the current play head position, ' + 
	'in seconds, since the video started to play or record. For playback of live stream, the ' + 
	'playhead position may start from some positive value if the player joins the stream after ' + 
	'some time. If the current time is not known, the value is NaN. This property is also ' + 
	'attached to the numeric display (as formatted duration in hh:mm:ss) or current position ' + 
	'in the playhead bar on the control panel, if available.\n';
	
	[Bindable('propertyChange')]
	/**
	 * The current time in play mode.
	 */
	public function get currentTime():Number
	{
		return _currentTime;
	}
	public function set currentTime(value:Number):void
	{
		var oldValue:Number = _currentTime;
		_currentTime = value;
		if (oldValue != value) {
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "currentTime", oldValue, value));
		}
	}
	
	/**
	 * Use setCurrentTime instead of setting currentTime directly when seeking to a new
	 * position. The currentTime is automatically updated based on the playheadTime of
	 * videoDisplay or time of playing NetStream.
	 */
	public function setCurrentTime(value:Number):void
	{
		this.currentTime = value;
		if (videoDisplay != null)
			videoDisplay.playheadTime = value;
		if (play != null && _remote != null)
			_remote.seek(value);
	}
	
	public const __doc__duration:String =
	'The "duration" read-write number property refers to the total length of the media, ' + 
	'in seconds. For live or recorded streams, this value is unavailable or NaN. For real-time ' + 
	'playback of the stream or downloaded video file, this value may not be available, unless ' + 
	'set by metadata or has finished playback once. This property is also attached to the ' + 
	'length of the playhead bar on the control panel, if available.\n';
	
	[Bindable('propertyChange')]
	/**
	 * The duration in play mode.
	 */
	public function get duration():Number
	{
		return _duration;
	}
	public function set duration(value:Number):void
	{
		var oldValue:Number = _duration;
		_duration = value;
		if (oldValue != value) {
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "duration", oldValue, value));
		}
	}

	public const __doc__bytesLoaded:String =
	'The "bytesLoaded" read-only number property indicates the number of bytes of data that ' + 
	'has been loaded so far in the system. If unavailable, this is NaN.\n';
	
	/**
	 * The total bytes loaded so far in play mode.
	 */
	public function get bytesLoaded():Number
	{
		return _bytesLoaded;
	}

	public const __doc__bytesTotal:String =
	'The "bytesTotal" read-only number property indicates the total size of the file being ' + 
	'loaded in the system. If unavailable, such as for live streams, this is NaN.\n';
	
	/**
	 * The total bytes of media file in play mode.
	 */
	public function get bytesTotal():Number
	{
		return _bytesTotal;
	}

	public const __doc__playerState:String =
	'The "playerState" read-only string property indicates the player state when playing an "http" or "https" ' +
	'URL. For other play or publish modes, the value is null. ' +
	'Please see the "VideoDisplay.state" property in Flex documentation for details.\n';
	
	/**
	 * Player's state (VideoDisplay)
	 */
	public function get playerState():String
	{
		return _playerState;
	}

	public const __doc__quality:String =
	'The "quality" read-only number property indicates the quality of the play stream as ' + 
	'number between 0 (very low) and 1 (very high). The quality is calculated based on ' + 
	'some combination of other metrics such as number of packet losses and delay of ' + 
	'the stream. This property is also attached to the quality bars displayed in the ' + 
	'control panel in stream play mode displaying 4 bars indicating quality values in ' + 
	'range of (0, 0.25], (0.25, 0.5], (0.5, 0.75], (0.75, 1.0]), respectively.\n';
	
	[Bindable('propertyChange')]
	/**
	 * The quality of stream in play mode.
	 */
	public function get quality():Number
	{
		return _quality;
	}
	public function set quality(value:Number):void
	{
		var oldValue:Number = _quality;
		_quality = value;
		if (oldValue != value) {
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "quality", oldValue, value));
		}
	}

	public const __doc__bufferTime:String =
	'The "bufferTime" read-write number property controls the playing stream bufferTime in seconds. ' +
	'Default is negative (-1.0) which indicates do not set. If you are experiencing choppiness, ' +
	'set it to a higher value.\n';
	
	[Bindable('propertyChange')]
	/**
	 * The bufferTime of stream in play mode.
	 */
	public function get bufferTime():Number
	{
		return _bufferTime;
	}
	public function set bufferTime(value:Number):void
	{
		var oldValue:Number = _bufferTime;
		_bufferTime = value;
		if (value != oldValue) {
			if (_remote != null) {
				_remote.bufferTime = value >= 0 ? value : 0;
			}
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "bufferTime", oldValue, value));
		}
	}
				
	public const __doc__bufferTimeMax:String =
	'The "bufferTimeMax" read-write number property controls the playing stream bufferTimeMax in seconds. ' +
	'Default is negative (-1.0) which indicates do not set. This property puts an upper limit on bufferTime.\n';
	
	[Bindable('propertyChange')]
	/**
	 * The bufferTimeMax of stream in play mode.
	 */
	public function get bufferTimeMax():Number
	{
		return _bufferTimeMax;
	}
	public function set bufferTimeMax(value:Number):void
	{
		var oldValue:Number = _bufferTimeMax;
		_bufferTimeMax = value;
		if (value != oldValue) {
			if (_remote != null && _remote.hasOwnProperty("bufferTimeMax")) {
				_remote["bufferTimeMax"] = value >= 0 ? value : 0;
			}
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "bufferTimeMax", oldValue, value));
		}
	}
				
	public const __doc__fullscreen:String =
	'The "fullscreen" read-only property controls the full screen mode of the application.' + 
	'Due to restriction in Flash Player, this property can only be set in response to ' + 
	'a mouse click or button press within Flash Player, hence setting this property by ' + 
	'the external application has no effect. This property is also attached to the fullscreen ' + 
	'button state in control panel, and the clicking the button triggers or comes out of ' + 
	'full screen mode.\n';
	
	[Bindable('propertyChange')]
	/**
	 * Whether the current mode is full screen or not?
	 */
	public function get fullscreen():Boolean
	{
		return _fullscreen;
	}
	public function set fullscreen(value:Boolean):void
	{
		var oldValue:Boolean = _fullscreen;
		_fullscreen = value;
		if (oldValue != value) {
			try {
				stage.displayState = value ? StageDisplayState.FULL_SCREEN: StageDisplayState.NORMAL;
			} catch (e:SecurityError) {
				_fullscreen = oldValue;
			}
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "fullScreen", oldValue, value));
		}
	}

	public const __doc__enableFullscreen:String =
	'The "enableFullscreen" read-write property controls whether full screen mode is enabled ' + 
	'or not. Default is true. If the full screen mode is disabled, then the user interface ' + 
	'elements needed to do full screen are hidden. Resetting this property to false is ' + 
	'useful when you know that full screen is not available, e.g., in Facebook FBML application.\n';
	
	[Bindable('propertyChange')]
	/**
	 * Whether the full screen button is enabled or not?
	 */
	public function get enableFullscreen():Boolean
	{
		return _enableFullscreen;
	}
	public function set enableFullscreen(value:Boolean):void
	{
		var oldValue:Boolean = _enableFullscreen;
		_enableFullscreen = value;
		if (oldValue != value) {
			if (value) {
				var fullscreen:ContextMenuItem = new ContextMenuItem("Toggle full-screen");
				menu.customItems.push(fullscreen);
				fullscreen.addEventListener(ContextMenuEvent.MENU_ITEM_SELECT, fullScreenMenuHandler);
			}
			else {
				var menu:ContextMenu;
				if (CONFIG::sdk4) {
					menu = mx.core.FlexGlobals.topLevelApplication.contextMenu;
				}
				else {
					menu = Application.application.contextMenu;
				}
				var found:Boolean = false;
				for (var i:int=0; i<menu.customItems.length; ++i) {
					if (menu.customItems[i].caption == "Toggle full-screen") {
						menu.customItems.splice(i, 1);
						break;
					}
				}
				
			}
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "enableFullscreen", oldValue, value));
		}
	}
	
//		public const __doc__sip:String =
//		'The "sip" read-write property controls and indicates the SIP call state as follows:\n' + 
//		' Setting to "invite:sip:user@domain" will initiate a SIP call to the target destination.\n' +
//		' Value of "inviting:sip:user@domain" indicates that outgoing call invitation is in progress.\n' + 
//		' Setting to "idle" will terminate any active or pending call.\n' + 
//		' Value of "invited:sip:user@domain" indicates that the target user is inviting you.\n' + 
//		' Setting to "active" in "inviting" state will accept an incoming call.\n' +
//		' Setting to "idle:reason" in "inviting" state will reject an incoming call with supplied reason.\n' + 
//		'This property assumes that "src" property was already set correctly to connect to a "siprtmp"\n' + 
//		'gateway and to register using additional arguments such as local SIP URI, auth name and password.\n' +
//		'When you are in a SIP call, the "play" and "publish" property are automatically set to "local" and "remote" ' +
//		'as required by the "siprtmp" software, and previously set values of "play" and "publish" properties are ' +
//		'ignored.\n';
//		
//		[Bindable('propertyChange')]
//		/**
//		 * The SIP call state property.
//		 */
//		public function get sip():String
//		{
//			return _sip;
//		}
//		public function set sip(value:String):void
//		{
//			_sip = value;
//		}
	
	public const __doc__group:String =
	'The "group" read-write string property refers to the group name for application ' + 
	'level multicast in both publish and play mode. Although this is a read-write property ' + 
	'the application should use the "group" parameter of the "src" property to set this. ' + 
	'For example, if the "src" is set to "rtmp://server/path?group=my/group1&publish=live1" ' + 
	'then the "group" property is automatically set to "my/group1". This "group" property ' + 
	'must be set before publish or play, so that it takes effect before publishing or playing.\n';
	
	[Bindable('propertyChange')]
	/**
	 * The group-name for publish or play.
	 */
	public function get group():String
	{
		return _group;
	}
	public function set group(value:String):void
	{
		var oldValue:String = _group;
		_group = value;
		// TODO: cannot be set in active call.
		if (oldValue != value) {
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "group", oldValue, value));
		}
	}
	
	public const __doc__snapshot:String = 
	'The "snapshot" read-write string property represents a one-time snapshot of the video stream. ' + 
	'It represents the base64 encoded JPEG image data. The application can get the snapshot and ' + 
	'publish it to the backend. The application can set the snapshot to display the image.\n';
	
	[Bindable('propertyChange')]
	/**
	 * The snapshot property to represent instantaneous base64 of JPEG image data.
	 */
	public function get snapshot():String
	{
		return _snapshot;
	}
	public function set snapshot(value:String):void
	{
		var oldValue:String = _snapshot;
		_snapshot = value;
		if (oldValue != value) {
			if (oldValue != null) 
				detachPoster();
			if (value != null)
				attachPoster();
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "snapshot", oldValue, value));
		}
	}
	
	public const __doc__objectEncoding:String = 
	'The "objectEncoding" read-write number property represents the NetConnection objectEncoding and defaults to 3. ' +
	'Possible values are 3 and 0 for AMF3 and AMF0 respectively. ' +
	'This property must be set before url or src is set so that the value is applied before invoking the connect method on ' +
	'NetConnection. Setting it after the connection is initiated has no effect on the current connection.\n';
	
	[Bindable('propertyChange')]
	/**
	 * The objectEncoding of the NetConnection.
	 */
	public function get objectEncoding():Number
	{
		return _objectEncoding;
	}
	public function set objectEncoding(value:Number):void
	{
		var oldValue:Number = _objectEncoding;
		_objectEncoding = value;
		if (oldValue != value) {
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "objectEncoding", oldValue, value));
		}
	}
	
	public const __doc__proxyType:String = 
	'The "proxyType" read-write string property determines which fallback methods are tried if an initial connection attempt ' +
	'fails. Possible values are "none", "best", "HTTP", and "CONNECT", and default is "none". The value of "best" ' +
	'is particularly useful when using "rtmps" with native SSL instead of HTTPS tunneling. '
	'This property must be set before url or src is set so that the value is applied before invoking the connect method on ' +
	'NetConnection. Setting it after the connection is initiated has no effect on the current connection.\n';
	
	[Bindable('propertyChange')]
	/**
	 * The proxyType of the NetConnection.
	 */
	public function get proxyType():String
	{
		return _proxyType;
	}
	public function set proxyType(value:String):void
	{
		var oldValue:String = _proxyType;
		_proxyType = value;
		if (oldValue != value) {
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "proxyType", oldValue, value));
		}
	}
	
	//--------------------------------------
	// PUBLIC METHODS
	//--------------------------------------
	
	public const __doc__call:String =
	'The "call" method can be used to call some method on the server using the connected ' +
	'NetConnection object. It invokes the call method on the NetConnection object. ' +
	'In the reverse direction, the callback event is posted with method and args when ' +
	'the server calls a method on the client using the NetConnection object. The callback ' + 
	'event eventually invokes the onCallback Javascript function. ' + 
	'The call() method and callback event are useful for interacting with intelligent ' + 
	'server such as SIP-RTMP gateway (siprtmp) to perform PC-to-phone or phone-to-PC calls.\n' +
	'For example, if you are running the gateway on localhost, then ' + 
	'to register as "sip:kundan@localhost" with authname "kundan", password "mypass", ' + 
	'display-name "Kundan Singh", rate "narrowband", you can use the following "src" property.\n' + 
	' rtmp://localhost/sip/kundan@localhost?arg=kundan&arg=kundan&arg=Kundan Singh&arg=narrowband\n';
	
	/**
	 * Method to call something on the server using the connected NetConnection object's call() method.
	 */
	public function call(methodName:String, ...args):void
	{
		if (nc != null && nc.connected) {
			var func:Function = nc.call;
			args.splice(0, 0, methodName, null);
			func.apply(nc, args);
		}
		else {
			throw new Error("not connected to server");
		}
	}
	
	public const __doc__post:String =
	'The "post" method can be used to send some message to the net group associated with the ' +
	'application level multicast group. It invokes the post method on the NetGroup object. ' +
	'In the reverse direction, the postingNotify event is posted with user and text when ' +
	'an incoming message is received on the NetGroup object. The postingNotify ' + 
	'event eventually invokes the onPostingEvent Javascript function. ' + 
	'The post() method and postingNotify event are useful for implementing multicast group ' + 
	'communication, e.g., multiparty text chat. Note that for the "post" method to work, ' + 
	'you must set the "group" property to join a net group.\n';
	
	/**
	 * Method to post something to the net group.
	 */
	public function post(user:String, text:String):void
	{
		if (nc != null && nc.connected && _netGroup != null) {
			var message:Object = new Object();
			message.sender = _netGroup.convertPeerIDToGroupAddress(nc.nearID);
			message.user = user;
			message.text = text;
			_netGroup.post(message);
		}
		else {
			throw new Error("not connected to net group");
		}
	}
	
	public const __doc__sendData:String =
	'The "sendData" method can be used to send some text in a publishing stream to all the other subscribed ' +
	'playing streams. This is particularly useful for P2P RTMFP mode using Stratus service where you cannot use ' +
	'the call() method and implement a server side feature, but you need an end-to-end text/data transfer mechanism.' +
	'Unlike the post() method that works in a group, the sendData() method is useful for client-server and ' +
	'peer-to-peer streams. The other end receives a onReceiveData(data) callback method invoked when it receives ' +
	'the sendData command in the stream. For a one-to-many stream, the publishers calls sendData and all the ' +
	'players receive onReceiveData callback. You can call sendData only if VideoIO is publishing, and will get ' +
	'onReceiveData only if VideoIO is playing. It is up to the application to define the meaning of the text data ' +
	'send and received via this method.\n';
	
	/**
	 * Method to sendData in a publish stream which is received by all play streams.
	 */
	public function sendData(data:String):void
	{
		if (_local != null) {
			trace("sending sendData(" + data + ")");
			_local.send("sendData", data);
		}
		else {
			trace("sendData() ignored with no publish stream");
		}
	}
	
	public const __doc__showSettings:String =
	'The "showSettings" method shows the Flash Player security settings. The application ' + 
	'may detect on launch that "deviceAllowed" is false, and invoke this prompt to get ' + 
	'device permissions. If "privacyEvent" is true then "hidingSettings" is dispatched when ' +
	'this application receives focus again.\n';
	
	/**
	 * Method to show Flash Player security settings.
	 */
	public function showSettings():void
	{
		if (privacyEvent) {
			dispatchEvent(new Event("showingSettings"));
			
			if (CONFIG::sdk4) {
				var stage:Stage = mx.core.FlexGlobals.topLevelApplication.stage;
			}
			else {
				var stage:Stage = Application.application.stage;
			}
			if (settingsTimer == null) {
				stageChildren = stage.numChildren;
				settingsTimer = new Timer(100, 0);
				settingsTimer.addEventListener(TimerEvent.TIMER, settingsTimerHandler, false, 0, true);
				settingsTimer.start();
			}
		}
		Security.showSettings(SecurityPanel.PRIVACY);
	}
	
	//--------------------------------------
	// PRIVATE METHODS
	//--------------------------------------
	
	// Private setter to dispatch propertyChange event.
	private function setProperty(property:String, value:Object):void
	{
		var oldValue:Object = this["_" + property];
		this["_" + property] = value;
		if (value != oldValue) {
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, property, oldValue, value));
		}
	}
	
	// set the camera's setMode and if player11 then video stream's setMode as well.
	private function setCameraMode():void
	{
		if (_cameraObject != null)
			_cameraObject.setMode(_cameraWidth, _cameraHeight, _cameraFPS);
		if (CONFIG::player11) {
			if (_local != null && _local.videoStreamSettings != null) {
				_local.videoStreamSettings.setMode(_cameraWidth, _cameraHeight, _cameraFPS);
			}
		}
	}
	
	// when settings timer fires, check if the stage.numChildren is same as before
	// showSettings, and if yes, that means the security panel is closed.
	// In that case dispatch the hidingSettings event.
	private function settingsTimerHandler(event:TimerEvent):void
	{
		if (CONFIG::sdk4) {
			var stage:Stage = mx.core.FlexGlobals.topLevelApplication.stage;
		}
		else {
			var stage:Stage = Application.application.stage;
		}
		if (settingsTimer != null && (stage.numChildren == stageChildren)) {
			settingsTimer.removeEventListener(TimerEvent.TIMER, settingsTimerHandler);
			settingsTimer.stop();
			settingsTimer = null;
			if (privacyEvent) {
				dispatchEvent(new Event("hidingSettings"));
			}
		}
	}
	
	// update the global soundmixer based on the current speaker volume.
	private function updateMixer():void
	{
		var transform:SoundTransform = new SoundTransform();
		transform.volume = (_sound ? _volume : 0);
		SoundMixer.soundTransform = transform;
	}
	
	private function cameraStatusHandler(event:StatusEvent):void
	{
		var oldValue:Boolean = _camera;
		if (event.code != null && event.code.toLowerCase().indexOf("unmuted") >= 0) {
			setProperty("deviceAllowed", true);
			_camera = true;
		}
		else {
			setProperty("deviceAllowed", false);
			_camera = false;
		}
		if (oldValue != _camera) {
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "camera", oldValue, _camera));
		}
	}
	
	private function micStatusHandler(event:StatusEvent):void
	{
		var oldValue:Boolean = _microphone;
		if (event.code != null && event.code.toLowerCase().indexOf("unmuted") >= 0) {
			setProperty("deviceAllowed", true);
			startMicLevelTimer();
			_microphone = true;
		}
		else {
			setProperty("deviceAllowed", false);
			stopMicLevelTimer();
			_microphone = false;
		}
		if (oldValue != _microphone) {
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "microphone", oldValue, _microphone));
		}
	}
	
	private function startMicLevelTimer():void
	{
		if (_micLevelTimer == null) {
			_micLevelTimer = new Timer(100, 0);
			_micLevelTimer.addEventListener(TimerEvent.TIMER, micLevelTimerHandler, false, 0, true);
			_micLevelTimer.start();
		}
	}
	
	private function stopMicLevelTimer():void
	{
		if (_micLevelTimer != null) {
			_micLevelTimer.stop();
			_micLevelTimer = null;
		}
	}
	
	private function micLevelTimerHandler(event:TimerEvent):void
	{
		level = new Number((_microphoneObject != null && !_microphoneObject.muted && _microphoneObject.activityLevel >= 0) ? _microphoneObject.activityLevel / 100 : 0);
	}
	
	private function connect():void
	{
		if (nc == null && url != '') {
			nc = new NetConnection();
			nc.proxyType = proxyType;
			nc.objectEncoding = objectEncoding;

			// The CallProxy approach now works.
			nc.client = new CallProxy(this);

			nc.addEventListener(NetStatusEvent.NET_STATUS, netStatusHandler, false, 0, true);
			nc.addEventListener(IOErrorEvent.IO_ERROR, errorHandler, false, 0, true);
			nc.addEventListener(SecurityErrorEvent.SECURITY_ERROR, errorHandler, false, 0, true);
			nc.addEventListener(AsyncErrorEvent.ASYNC_ERROR, errorHandler, false, 0, true);
			
			var func:Function = nc.connect;
			var args:Array = [url];
			for each (var arg:Object in this.args) 
				args.push(arg);
				
			_dispatchDisconnect = true;
			trace('connect() ' + args);
			func.apply(nc, args);
		}
	}

	private function called(method:String, ...args):void 
	{
		var event:DynamicEvent = new DynamicEvent("callback");
		event.method = method;
		event.args = args;
		trace("CallProxy dispatchEvent type=callback method=" + method);
		dispatchEvent(event);
	}
	
	private function called2(method:String, args:Array):void 
	{
		var event:DynamicEvent = new DynamicEvent("callback");
		event.method = method;
		event.args = args;
		trace("CallProxy dispatchEvent type=callback method=" + method);
		dispatchEvent(event);
	}
	
	private function disconnect():void
	{
		if (nc != null) {
			trace("disconnect()");
			_dispatchDisconnect = false;
			nc.close();
			nc.removeEventListener(NetStatusEvent.NET_STATUS, netStatusHandler);
			nc.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, errorHandler);
			nc.removeEventListener(AsyncErrorEvent.ASYNC_ERROR, errorHandler);
			nc.removeEventListener(IOErrorEvent.IO_ERROR, errorHandler);
			nc.client = {};
			nc = null;
			destroyStream();
		}
		detachVideo();
	}
	
	private function netStatusHandler(event:NetStatusEvent):void 
	{
		trace('netStatusHandler() ' + event.type + ' ' + event.info.code);
		
		switch (event.info.code) {
		case 'NetConnection.Connect.Success':
			setProperty("nearID", nc.nearID);
			if (CONFIG::sdk4) {
				if (group != null) 
					createGroup();
				else if (autoplay && (publish != null || play != null))
					createStream();
			} 
			else {
				if (autoplay && (publish != null || play != null))
					createStream();
			}
			break;
		case 'NetConnection.Connect.Failed':
		case 'NetConnection.Connect.Rejected':
		case 'NetConnection.Connect.Closed':
			errorHandler(event);
			break;
			
		case 'NetStream.Play.Stop':
			if (_remote != null) {
				currentTime = _remote.time;
				if (!isNaN(duration) && currentTime < duration)
					currentTime = duration;
			}
			playing = false;
			if (loop)
				playing = true;
			break;
			
		case 'NetGroup.Connect.Success':
			if (autoplay && (publish != null || play != null))
				createStream();
			break;
			
		case 'NetGroup.Posting.Notify':
			try {
				var event1:DynamicEvent = new DynamicEvent("postingNotify");
				event1.user = event.info.message.user;
				event1.text = event.info.message.text;
				trace("CallProxy dispatchEvent type=postingNotify");
				dispatchEvent(event1);
			}
			catch (e:Error) {
				trace("CallProxy.callProperty(" + name + ") exception\n" + e.getStackTrace());
			}
			break;
		}
	}
	
	private function errorHandler(event:Event):void 
	{
		if (_dispatchDisconnect) {
			if (event is ErrorEvent) {
				trace('errorHandler() ' + ErrorEvent(event).type + ' ' + ErrorEvent(event).text);
			}
			else if (event is NetStatusEvent) {
				if ('description' in NetStatusEvent(event).info)
					trace("reason: " + NetStatusEvent(event).info.description);
			}
			
			if (nc != null)
				nc.close();
			nc = null;
			playing = recording = false;
			
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "src", src, null));
			src = null;
		}
	}
	
	private function cameraChangeHandler(event:Event):void
	{
		if (_video != null)
			_video.attachCamera(_cameraObject);
		if (_local != null)
			_local.attachCamera(_cameraObject);
	}
	private function micChangeHandler(event:Event):void
	{
		if (_local != null)
			_local.attachAudio(_microphoneObject);
	}
	
	private function onMetaData(obj:Object):void
	{
		if (obj.duration != undefined)
			duration = obj.duration;
		if (obj.width != undefined)
			setProperty("videoWidth", obj.width);
		if (obj.height != undefined)
			setProperty("videoHeight", obj.height);
	}
	
	private function onSendData(data:String):void
	{
		dispatchEvent(new DataEvent("receiveData", false, false, data));
	}
	
	CONFIG::sdk4
	private function createGroup():void
	{
		try {
			_groupspec = new flash.net.GroupSpecifier(group);
			_groupspec.serverChannelEnabled = true;
			_groupspec.postingEnabled = true;
			_groupspec.multicastEnabled = true;
//			_groupspec.ipMulticastMemberUpdatesEnabled = true;
//			_groupspec.addIPMulticastAddress("224.1.2.3", 8082);
			
			_netGroup = new flash.net.NetGroup(nc, _groupspec.groupspecWithAuthorizations());
			_netGroup.addEventListener(NetStatusEvent.NET_STATUS, netStatusHandler, false, 0, true);
		} catch (e:Error) {
			// ignore
			trace("error in creating GroupSpecifier or NetGroup, disabled group: " + e.message);
			Alert.show("You need Flash Player 10.1 or\nhigher for group communication", "Disabled group!");
			
			var oldValue:String = _group;
			_group = null;
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "group", oldValue, null));
			
			if (autoplay && (publish != null || play != null))
				createStream();
		}
	}
	
	private function createStream():void
	{
		var oldPlaying:Boolean = _playing, oldRecording:Boolean = _recording;
		var createLocal:Boolean = _local == null && publish != null;
		var createRemote:Boolean = (_bidirection || !createLocal) && _remote == null && play != null;
		
		if ((createLocal || createRemote) && nc != null && nc.connected) {
			if (scheme == 'rtmfp') {
				if (group == null) {
					if (createLocal) {
						trace("creating rtmfp publish stream: nearID=" + nc.nearID);
						_local = new NetStream(nc, NetStream.DIRECT_CONNECTIONS);
					}
					if (createRemote) {
						trace("creating rtmfp play stream: farID=" + farID);
						_remote = new NetStream(nc, farID);
					}
				} else {
					if (createLocal) {
						trace("creating rtmfp publish stream: groupspec=" + _groupspec.groupspecWithoutAuthorizations());
						_local = new NetStream(nc, _groupspec.groupspecWithAuthorizations());
					}
					if (createRemote) {
						trace("creating rtmfp play stream: groupspec=" + _groupspec.groupspecWithoutAuthorizations());
						_remote = new NetStream(nc, _groupspec.groupspecWithAuthorizations());
					}
				}
			}
			else {
				if (createLocal)
					_local = new NetStream(nc);
				if (createRemote)
					_remote = new NetStream(nc);
			}
			
			if (createLocal) {
				if (CONFIG::player11) {
					_local.videoStreamSettings = createVideoStreamSettings();
				}
				_local.client = { onMetaData: onMetaData, setVideoSize: setVideoSize, sendData: onSendData };
				_local.addEventListener(NetStatusEvent.NET_STATUS, netStatusHandler, false, 0, true);
			}
			
			if (createRemote) {
				_remote.client = { onMetaData: onMetaData, setVideoSize: setVideoSize, sendData: onSendData };
				_remote.addEventListener(NetStatusEvent.NET_STATUS, netStatusHandler, false, 0, true);
				
				if (this.bufferTime >= 0) {
					_remote.bufferTime = this.bufferTime;
				}
				if (this.bufferTimeMax >= 0 && _remote.hasOwnProperty("bufferTimeMax")) {
					_remote["bufferTimeMax"] = this.bufferTimeMax;
				}
			}
			
			
			if (createLocal) {
				trace("createStream() publish=" + publish);
				if (cameraObject != null)
					_local.attachCamera(cameraObject);
				if (microphoneObject != null)
					_local.attachAudio(microphoneObject);
				_recording = true;
			}
			if (createRemote) {
				trace("createStream() play=" + play);
				if (_video != null)
					_video.attachNetStream(_remote);
				_playing = true;
			}
			
			if (createLocal)
				_local.publish(publish, (record && scheme == 'rtmp' ? "record" : null));
			if (createRemote)
				_remote.play(play);
				
			startPlayheadTimer();
		}
		
		if (oldRecording != _recording)
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "recording", oldRecording, _recording));
		if (oldPlaying != _playing)
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "playing", oldPlaying, _playing));
	}
	
	private function destroyNetStream(ns:NetStream):void
	{
		trace("destroyStream()");
		try {
			ns.client = {};
			ns.close();
		} catch (e:Error) {
			// ignore
		}
		try {
//			ns.attachAudio(null);
//			ns.attachCamera(null);
		} catch (e:Error) {
			// ignore
		}
	}
	
	private function destroyStream():void
	{
		var oldPlaying:Boolean = _playing, oldRecording:Boolean = _recording;
		
		stopPlayheadTimer();
		
		if (_local != null) {
			destroyNetStream(_local);
			_local = null;
			_recording = false;
		}
		
		if (_remote != null) {
			destroyNetStream(_remote);
			if (oldPlaying && _video != null)
				_video.attachNetStream(null);
			_remote = null;
			_playing = false;
		}
		
		if (oldRecording != _recording)
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "recording", oldRecording, _recording));
		if (oldPlaying != _playing)
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "playing", oldPlaying, _playing));
	}
	
	private function startPlayheadTimer():void
	{
		if (_currentTimer == null) {
			_currentTimer = new Timer(1000, 0);
			_currentTimer.addEventListener(TimerEvent.TIMER, currentTimerHandler, false, 0, true);
			_currentTimer.start();
		}
	}
	
	private function stopPlayheadTimer():void
	{
		if (_currentTimer != null) {
			_currentTimer.stop();
			_currentTimer = null;
		}
	}
	
	private function currentTimerHandler(event:Event):void
	{
		if (_local != null || _remote != null) {
			var ns:NetStream = _local != null ? _local : _remote;
			currentTime = ns.time;
			setProperty("currentFPS", ns.currentFPS);
			quality = delayToQuality(ns.liveDelay);
			if (ns.info != null)
				setProperty("bandwidth", new Number(int(ns.info.videoBytesPerSecond + ns.info.audioBytesPerSecond)));
		}
				
		if (currentTime > (_lastSendTime + 5)) {
			sendVideoSize();
		}
	}
	
	private function delayToQuality(delay:Number):Number
	{
		var result:Number;
		if (isNaN(delay) || delay < 0)
			result = NaN;
		else if (delay < 0.05)
			result = 1.0;
		else if (delay < 0.15)
			result = 0.8;
		else if (delay < 0.5)
			result = 0.6;
		else if (delay < 1.0)
			result = 0.4;
		else if (delay < 3.0)
			result = 0.2;
		else 
			result = 0.5;
		return result;
	}
	
	private function attachVideo():void
	{
		trace("attachVideo() video=" + _video);
		unload();
		if (_video == null) {
			_video = new Video();
			_video.smoothing = this.smoothing;
			
			var parent:UIComponent = new UIComponent();
			parent.addChild(_video);
			parent.percentWidth = parent.percentHeight = 100;
			resizeVideoHandler(null);
			parent.addEventListener(ResizeEvent.RESIZE, resizeVideoHandler, false, 0, true);
			this.addChildAt(parent, 0);
		}
		
		if (_cameraObject != null)
			_video.attachCamera(_cameraObject);
		else if (_remote != null)
			_video.attachNetStream(_remote);
	}
	
	private function detachVideo():void
	{
		trace("detachVideo() video=" + _video);
		if (_video != null) {
			this.removeChild(_video.parent);
			_video.clear();
			_video.attachCamera(null);
			_video = null;
		}
	}
	
	private function sendVideoSize():void
	{
		if (recording && _local != null && (this.width != 320 || this.height != 240)) {
			_lastSendTime = currentTime;
			trace("sending setVideoSize(" + this.width + ", " + this.height + ")");
			if (_zoom == "in")
				_local.send("setVideoSize", this.width, this.height);
			else
				_local.send("setVideoSize", _cameraWidth, _cameraHeight);
		}
	}
	
	private function setVideoSize(width:Number, height:Number):void
	{
		trace("received setVideoSize(" + width + "," + height + ")");
		
		if (width != publishWidth || height != publishHeight) {
			publishWidth = width;
			publishHeight = height;
			setProperty("videoWidth", width);
			setProperty("videoHeight", height);
			
			if (!live)
				resizeVideoHandler(null);
		}
		
	}
	
	private function resizeVideoHandler(event:ResizeEvent):void
	{
		var ratio:Number = _cameraWidth/_cameraHeight;

		if (_video != null) {
			if (_live) {
				var m:Matrix = new Matrix();
				var parent:DisplayObject = _video.parent;
				trace("setting video transform parent=" + parent.width + "x" + parent.height + " camera=" + _cameraWidth + "x" + _cameraHeight + " mirrored=" + _mirrored + " zoom=" + _zoom);
				if (_mirrored) {
					if (_zoom == null) {
						m.scale(-parent.width/320, parent.height/240);
						m.translate(parent.width, 0);
					}
					else if (_zoom == "out") {
						m.scale(-Math.min(parent.width, ratio*parent.height)/320, Math.min(parent.height, (1/ratio)*parent.width)/240);
						m.translate(Math.min(parent.width, ratio*parent.height)-(Math.min(parent.width, ratio*parent.height)-parent.width)/2, -(Math.min(parent.height, (1/ratio)*parent.width)-parent.height)/2);
					}
					else if (_zoom == "in") {
						m.scale(-Math.max(parent.width, ratio*parent.height)/320, Math.max(parent.height, (1/ratio)*parent.width)/240);
						m.translate(Math.max(parent.width, ratio*parent.height)-(Math.max(parent.width, ratio*parent.height)-parent.width)/2, -(Math.max(parent.height, (1/ratio)*parent.width)-parent.height)/2);
					}
				} 
				else {
					if (_zoom == null) {
						m.scale(parent.width/320, parent.height/240);
						m.translate(0, 0);
					}
					else if (_zoom == "out") {
						m.scale(Math.min(parent.width, ratio*parent.height)/320, Math.min(parent.height, (1/ratio)*parent.width)/240);
						m.translate(-(Math.min(parent.width, ratio*parent.height)-parent.width)/2, -(Math.min(parent.height, (1/ratio)*parent.width)-parent.height)/2);
					}
					else if (_zoom == "in") {
						m.scale(Math.max(parent.width, ratio*parent.height)/320, Math.max(parent.height, (1/ratio)*parent.width)/240);
						m.translate(-(Math.max(parent.width, ratio*parent.height)-parent.width)/2, -(Math.max(parent.height, (1/ratio)*parent.width)-parent.height)/2);
					}
				}
				_video.transform.matrix = m; 
			}
			else {
				if (_zoom == null || isNaN(publishWidth) || isNaN(publishHeight)) {
					_video.width = _video.parent.width;
					_video.height = _video.parent.height;
				}
				else {
					var ratio1:Number = this.width/this.height;
					var originalWidth:Number = _zoom == "in" ? Math.max(publishWidth, publishHeight*ratio) : Math.min(publishWidth, publishHeight*ratio);
					var originalHeight:Number = _zoom == "in" ? Math.max(publishWidth/ratio, publishHeight) : Math.min(publishWidth/ratio, publishHeight);
					var extractedWidth:Number = _zoom == "in" ? Math.min(publishWidth, publishHeight*ratio1) : Math.max(publishWidth, publishHeight*ratio1);
					var extractedHeight:Number = _zoom == "in" ? Math.min(publishWidth/ratio1, publishHeight) : Math.max(publishWidth/ratio1, publishHeight);
					var scaled:Number = this.width / extractedWidth;
					var scaledWidth:Number = originalWidth*scaled;
					var scaledHeight:Number = originalHeight*scaled;
					_video.width = scaledWidth;
					_video.height = scaledHeight;
					_video.x = this.width/2 - scaledWidth/2;
					_video.y = this.height/2 - scaledHeight/2;
				}					
			}
		}
	}

	public function takeSnapshot(quality:Number=100):void
	{
		if (_video != null || _videoDisplay != null) {
			var snap:BitmapData = new BitmapData(this.width, this.height, true);
			var matrix:Matrix = new Matrix(1, 0, 0, 1, 0, 0);
			snap.draw(_video != null ? _video : _videoDisplay, matrix);
			var bm:Bitmap = new Bitmap(snap);
			var encoder:JPEGEncoder = new JPEGEncoder(quality);
			var jpeg:ByteArray = encoder.encode(snap);
			var b64:Base64Encoder = new Base64Encoder();
			b64.insertNewLines = false;
			b64.encodeBytes(jpeg);
			_snapshot = b64.toString();
		}
		else {
			_snapshot = null;
		}
	}
	
	private function snapshotToData():ByteArray
	{
		var b64:Base64Decoder = new Base64Decoder();
		b64.decode(_snapshot);
		return b64.drain();
	}
	
	private function attachPoster():void
	{
		if ((_poster != null || _snapshot != null) && _image == null) {
			_image = new Image();
			_image.maintainAspectRatio = true;
			_image.source = (_snapshot != null ? snapshotToData() : _poster);
			_image.addEventListener(Event.COMPLETE, posterCompleteHandler, false, 0, true);

			var parent:UIComponent = new Canvas();
			if (!isNaN(posterBackgroundAlpha)) {
				attachPosterBackground();
			}
			
			parent.addChild(_image);
			parent.percentWidth = parent.percentHeight = 100;
			resizePosterHandler(null);
			parent.addEventListener(ResizeEvent.RESIZE, resizePosterHandler, false, 0, true);
			this.addChildAt(parent, 0);
		}
	}
	
	private function detachPoster():void
	{
		if (_image != null) {
			this.removeChild(_image.parent);
			_image = null;
		}
	}
	
	private function attachPosterBackground():void
	{
		if (_image != null && _poster != null) {
			var bg:Image = new Image();
			bg.percentWidth = bg.percentHeight = 100;
			bg.maintainAspectRatio = false;
			bg.alpha = posterBackgroundAlpha;
			bg.source = _poster;
			_image.parent.addChildAt(bg, 0);
		}
	}
	
	private function detachPosterBackground():void
	{
		if (_image != null) {
			if (_image.parent.numChildren >= 2) {
				_image.parent.removeChildAt(0);
			}
		}
	}
	
	private function posterCompleteHandler(event:Event):void
	{
		resizePosterHandler(null);
	}
	
	private function resizePosterHandler(event:ResizeEvent):void
	{
		try {
			if (_image != null && _image.content != null && 
				!isNaN(_image.content.width) && !isNaN(_image.content.height) && _image.content.height > 0) {
				var ratio:Number = _image.content.width / _image.content.height;
				var width:Number = Math.min(_image.parent.width, _image.parent.height*ratio);
				var height:Number = Math.min(_image.parent.width/ratio, _image.parent.height);
				_image.width = Math.ceil(width);
				_image.height = Math.ceil(height);
				_image.x = int(_image.parent.width/2 - _image.width/2);
				_image.y = int(_image.parent.height/2 - _image.height/2);
				trace("poster size=" + _image.width + "x" + _image.height + " position=" + _image.x + "," + _image.y); 
			}
		} catch (e:SecurityError) {
			_image.percentWidth = _image.percentHeight = 100;
			if (_image.parent != null)
				_image.parent.removeEventListener(ResizeEvent.RESIZE, resizePosterHandler);
		}
	}
	
	private function load():void
	{
		trace("load() _videoDisplay=" + _videoDisplay);
		detachVideo();
		if (_videoDisplay == null) {
			_videoDisplay = new VideoDisplay();
			setProperty("playerState", VideoEvent.DISCONNECTED);
			_videoDisplay.percentWidth = _videoDisplay.percentHeight = 100;
			_videoDisplay.maintainAspectRatio = true;
			_videoDisplay.autoRewind = loop;
			_videoDisplay.autoPlay = autoplay;
			_videoDisplay.source = url;
			_videoDisplay.addEventListener(VideoEvent.CLOSE, videoCloseHandler, false, 0, true);
			_videoDisplay.addEventListener(VideoEvent.COMPLETE, videoCompleteHandler, false, 0, true);
			_videoDisplay.addEventListener(VideoEvent.READY, videoReadyHandler, false, 0, true);
			_videoDisplay.addEventListener(VideoEvent.PLAYHEAD_UPDATE, videoPlayheadUpdateHandler, false, 0, true);
			_videoDisplay.addEventListener(VideoEvent.STATE_CHANGE, videoStateChangeHandler, false, 0, true);
			_videoDisplay.addEventListener(MetadataEvent.METADATA_RECEIVED, metadataHandler, false, 0, true);
			_videoDisplay.addEventListener(ProgressEvent.PROGRESS, videoProgressHandler, false, 0, true);
			
			trace("load() videoDisplay with url=" + url + " autoplay=" + autoplay);
			this.addChildAt(_videoDisplay, 0);
			
			if (autoplay)
				playing = true;
			else
				attachPoster();
		}
	}
	
	private function unload(poster:Boolean=false):void
	{
		trace("unload() videoDisplay=" + _videoDisplay + " poster=" + poster);
		if (_videoDisplay != null) {
			_videoDisplay.close();
			this.removeChild(_videoDisplay);
			_videoDisplay = null;
			setProperty("playerState", null);
			if (poster)
				attachPoster();
		}
	}

	private function videoCompleteHandler(event:Event):void
	{
		trace("videoCompleteHandler " + event.type);
		playing = false;
		if (loop)
			playing = true;
	}

	private function videoReadyHandler(event:VideoEvent):void
	{
		trace("videoReadyHandler " + event.type);
	}

	private function videoCloseHandler(event:Event):void
	{
		trace("videoCloseHandler " + event.type);
	}

	private function videoStateChangeHandler(event:VideoEvent):void
	{
		trace("videoStateChangeHandler " + event.type + ", " + event.state + ", " + event.stateResponsive);
		setProperty("playerState", event.state);
	}

	private function videoProgressHandler(event:ProgressEvent):void
	{
		trace("videoProgressHandler " + event.type + ", " + event.bytesLoaded + "/" + event.bytesTotal);
		
		if (event.bytesLoaded != bytesTotal)
			setProperty("bytesTotal", new Number(event.bytesTotal));
		if (event.bytesLoaded != bytesLoaded)
			setProperty("bytesLoaded", new Number(event.bytesLoaded));
	}

	private function videoPlayheadUpdateHandler(event:VideoEvent):void
	{
		trace("videoPlayheadUpdateHandler " + event.type + ", " + event.playheadTime + "/" + _videoDisplay.totalTime);
		
		if (_videoDisplay.totalTime != duration && _videoDisplay.totalTime > 0)
			duration = _videoDisplay.totalTime;
		if (event.playheadTime != currentTime)
			currentTime = event.playheadTime;
	}
	
	private function metadataHandler(event:MetadataEvent):void
	{
		if (event.info != null) {
			onMetaData(event.info);
		}
	}

	private function addHandler(event:Event):void
	{
		if (stage != null) 
			stage.addEventListener(FullScreenEvent.FULL_SCREEN, fullScreenHandler, false, 0, true);
	}
	
	private function removeHandler(event:Event):void
	{
		if (stage != null)
			stage.removeEventListener(FullScreenEvent.FULL_SCREEN, fullScreenHandler);
	}
	
	private function fullScreenHandler(event:FullScreenEvent):void
	{
		if (fullscreen != event.fullScreen) 
			fullscreen = event.fullScreen;
		if (!CONFIG::player11) { // it gives ambigous reference to hasOwnProperty
			if (!event.fullScreen && stage != null && this.hasOwnProperty("fullScreenSourceRect"))
				stage.fullScreenSourceRect = null;
		}
	}
	
	private function fullScreenMenuHandler(event:Event):void
	{
		fullscreen = !fullscreen;
	}

	private function productMenuHandler(event:Event):void
	{
		try {
			navigateToURL(new URLRequest(VideoIOInternal.COMPONENT_URL), "_blank");
		} catch (e:Error) {
			trace("failed to navigate to " + VideoIOInternal.COMPONENT_URL);
		}
	}
	
	private function installContextMenu():void
	{
		var menu:ContextMenu;
		if (CONFIG::sdk4) {
			menu = mx.core.FlexGlobals.topLevelApplication.contextMenu;
		}
		else {
			menu = Application.application.contextMenu;
		}
		menu.hideBuiltInItems();
		
		var product:ContextMenuItem = new ContextMenuItem(VideoIOInternal.COMPONENT_VERSION);
		menu.customItems.push(product);
		product.addEventListener(ContextMenuEvent.MENU_ITEM_SELECT, productMenuHandler);

		var fullscreen:ContextMenuItem = new ContextMenuItem("Toggle full-screen");
		menu.customItems.push(fullscreen);
		fullscreen.addEventListener(ContextMenuEvent.MENU_ITEM_SELECT, fullScreenMenuHandler);
		
		trace("context menu installed");
	}
};

import flash.events.IEventDispatcher;
import flash.utils.Proxy;
import flash.utils.flash_proxy;

dynamic class CallProxy extends Proxy 
{
	private var obj:IEventDispatcher;
	
	public function CallProxy(value:IEventDispatcher) 
	{
		this.obj = value;
	}
	
	override flash_proxy function hasProperty(name:*):Boolean
	{
		trace("hasProperty " + name);
		return true;
	}
	
	override flash_proxy function isAttribute(name:*):Boolean
	{
		trace("isAttribute " + name);
		return false;
	}
	
	// getProperty is invoked instead of callProperty
	override flash_proxy function getProperty(name:*):*
	{
		trace("getProperty " + name);
		var func:Function = function(...rest):void {
			try {
				trace("CallProxy.callback(" + name + ") invoked");
				var event:DynamicEvent = new DynamicEvent("callback");
				event.method = name.toString();
				event.args = rest;
				trace("CallProxy dispatchEvent type=callback method=" + name);
				obj.dispatchEvent(event);
			}
			catch (e:Error) {
				trace("CallProxy.callback(" + name + ") exception\n" + e.getStackTrace());
			}
		};
		return func as Function;
	}
	
	// when a property is called, just dispatch "callback" event on associated object.
	override flash_proxy function callProperty(name:*, ...rest):* 
	{
		try {
			trace("callProperty(" + name + ") invoked");
			var event:DynamicEvent = new DynamicEvent("callback");
			event.method = name;
			event.args = rest;
			trace("CallProxy dispatchEvent type=callback method=" + name);
			obj.dispatchEvent(event);
		}
		catch (e:Error) {
			trace("CallProxy.callProperty(" + name + ") exception\n" + e.getStackTrace());
		}
	}   	
};

import flash.display.Bitmap;
import flash.display.BitmapData;
import flash.display.DisplayObject;
import flash.display.DisplayObjectContainer;
import flash.display.Graphics;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.events.TimerEvent;
import flash.geom.Matrix;
import flash.media.Video;
import flash.net.FileReference;
import flash.text.TextField;
import flash.text.TextFieldAutoSize;
import flash.text.TextFormat;
import flash.utils.ByteArray;
import flash.utils.Timer;

import mx.binding.utils.BindingUtils;
import mx.binding.utils.ChangeWatcher;
import mx.containers.Canvas;
import mx.containers.HBox;
import mx.controls.Alert;
import mx.controls.Button;
import mx.controls.HSlider;
import mx.controls.LinkButton;
import mx.controls.Spacer;
import mx.controls.Text;
import mx.core.Container;
import mx.core.UIComponent;
import mx.effects.Move;
import mx.events.DynamicEvent;
import mx.events.FlexEvent;
import mx.events.PropertyChangeEvent;
import mx.events.PropertyChangeEventKind;
import mx.events.ResizeEvent;
import mx.graphics.codec.JPEGEncoder;
import mx.resources.ResourceManager;
import mx.skins.ProgrammaticSkin;


class VideoControl extends HBox
{
	private static const HIDE_DELAY:uint = 3000;
	
	private var _parent:VideoIOInternal;
	private var _help:LinkButton;
	
	private var _playButton:Button;
	private var _recordButton:Button;
	private var _camButton:Button;
	private var _micButton:Button;
	private var _micSlider:VolumeSlider;
	private var _level:VolumeLevel;
	private var _speakerButton:Button;
	private var _speakerSlider:VolumeSlider;
	private var _qualityButton:Button;
	private var _fullscreenButton:Button;
	private var _snapButton:Button;
	private var _spacer:Button;
	private var _position:PlayPositionSlider;
	
	private var _hideTimer:Timer;
	
	private var _watchers:Array = [];
	private var _hover:Boolean = false;
	
	public function VideoControl() 
	{
		percentWidth = 100;
		height = 20;
		
		setStyle("paddingLeft", 0);
		setStyle("paddingRight", 0);
		setStyle("paddingTop", 0);
		setStyle("paddingBottom", 0);
		setStyle("horizontalGap", 0);
		setStyle("backgroundColor", 0xb7b8b9);
		setStyle("borderStyle", "solid");
		setStyle("borderThickness", 0);

		addEventListener(Event.ADDED_TO_STAGE, addedHandler);
	}
	
	private function _(format:String, ...args):String 
	{
		var result:String = ResourceManager.getInstance().getString("main", format.split(" ").join("_"), args);
		if (result == null) {
			result = format;
			for (var i:int=0; i<args.length; ++i) // use regex to replace all occurances
				result = result.replace("{" + i.toString() + "}", args[i] != null ? args[i].toString() : 'null');
		}
		return result;
	}
	
	private function createButton(skin:Class=null, toggleOn:String=null, 
		visibleOn:*=null, visibleWhen:Function=null):Button
	{
		trace("addButton(" + skin + "," + toggleOn + "," + visibleOn + ")");
		
		var button:Button = new Button();
		button.width = button.height = 20;
		button.buttonMode = true;
		button.setStyle("borderThickness", 0);
		button.setStyle("fillColors", [0xcacaca, 0xb8b8b8]);
		button.setStyle("fillOverColors", skin != null ? [0xa0a0a0, 0xa0a0a0] : [0xcacaca, 0xb8b8b8]);
		button.setStyle("skin", skin != null ? skin : ShinyButtonSkin);

		button.toggle = (toggleOn != null);
		button.includeInLayout = button.visible = (visibleOn == null);
		
		addChild(button);
		
		if (visibleOn != null) {
			if (visibleOn is String)
				_watchers.push(BindingUtils.bindProperty(button, "includeInLayout", _parent, String(visibleOn)));
			else
				for each (var property:String in visibleOn)
					_watchers.push(BindingUtils.bindProperty(button, "includeInLayout", _parent,
						{ name: property, getter: visibleWhen}));
			_watchers.push(BindingUtils.bindProperty(button, "visible", button, "includeInLayout"));
		}
		
		if (toggleOn != null) {
			_watchers.push(BindingUtils.bindProperty(button, "selected", _parent, toggleOn));
			_watchers.push(BindingUtils.bindProperty(_parent, toggleOn, button, "selected"));
		}
		
		return button;
	}
	
	private function createSpacer(button:UIComponent, position:String):Spacer
	{
		var spacer:Spacer = new Spacer();
		spacer.width = 1;
		_watchers.push(BindingUtils.bindProperty(spacer, "includeInLayout", button, "includeInLayout"));
		_watchers.push(BindingUtils.bindProperty(spacer, "visible", button, "visible"));
		if (position == "after")
			addChild(spacer);
		else if (position == "before")
			addChildAt(spacer, getChildIndex(button));
		return spacer;
	}
	
	private function addedHandler(event:Event):void
	{
		removeEventListener(Event.ADDED_TO_STAGE, addedHandler);
		addEventListener(Event.REMOVED_FROM_STAGE, removedHandler);
		
		trace('addedHandler');
		_parent = VideoIOInternal(this.parent);
		_parent.addEventListener(PropertyChangeEvent.PROPERTY_CHANGE, propertyChangeHandler, false, 0, true);
		_parent.addEventListener(MouseEvent.MOUSE_MOVE, mouseMoveHandler, false, 0, true);
		_parent.addEventListener(MouseEvent.MOUSE_DOWN, mouseMoveHandler, false, 0, true);
		_parent.addEventListener(ResizeEvent.RESIZE, resizeHandler, false, 0, true);
		addEventListener(MouseEvent.ROLL_OVER, rollOverHandler, false, 0, true);
		addEventListener(MouseEvent.ROLL_OUT, rollOutHandler, false, 0, true);

		var isPlaying:Function = function(host:Object):Boolean { return host['play'] != null || host['url'] != null && host['url'].substr(0, 4) == 'http'; };
		_playButton = createButton(PlayButtonSkin, "playing", ["play", "url"], isPlaying);
		_playButton.name = _("Play or pause");
		createSpacer(_playButton, "after");
		
		var isRecording:Function = function(host:Object):Boolean { return host['publish'] != null; }; 
		_recordButton = createButton(RecordButtonSkin, "recording", "publish", isRecording);
		_recordButton.name = _("Start/stop recording");
		createSpacer(_recordButton, "after");
			
		_camButton = createButton(CamButtonSkin, "camera", "live");
		_camButton.name = _("On/off camera");
		createSpacer(_camButton, "after");
		
		_micButton = createButton(MicButtonSkin, "microphone", "publish", isRecording);
		_micButton.name = _("On/off microphone");
		
		_micSlider = new VolumeSlider();
		_micSlider.name = _("Adjust microphone volume");
		_micSlider.width = 40;
		_micSlider.height = 20;
		_micSlider.includeInLayout = false;
		_watchers.push(BindingUtils.bindProperty(_micSlider, "visible", _micSlider, "includeInLayout"));
		_watchers.push(BindingUtils.bindProperty(_micSlider, "level", _parent, "gain"));
		_watchers.push(BindingUtils.bindProperty(_micSlider, "enabled", _parent, "microphone"));
		_micSlider.addEventListener(Event.CHANGE, sliderChangeHandler, false, 0, true);
		addChild(_micSlider);
		createSpacer(_micSlider, "after");
		
		_level = new VolumeLevel();
		_level.width = 40;
		_level.height = 20;
		_level.includeInLayout = false;
		_watchers.push(BindingUtils.bindProperty(_level, "includeInLayout", _micButton, "includeInLayout"));
		_watchers.push(BindingUtils.bindProperty(_level, "visible", _micButton, "includeInLayout"));
		_watchers.push(BindingUtils.bindProperty(_level, "level", _parent, "level"));
		_watchers.push(BindingUtils.bindProperty(_level, "enabled", _parent, "microphone"));
		addChild(_level);
		createSpacer(_level, "after");
		
		_micSlider.addEventListener(MouseEvent.ROLL_OUT, function(event:Event):void {
			if (_recordButton.includeInLayout) {
				_micSlider.includeInLayout = false;
				_level.includeInLayout = true;
			}
		});
		_level.addEventListener(MouseEvent.ROLL_OVER, function(event:Event):void {
			if (_recordButton.includeInLayout) {
				_level.includeInLayout = false;
				_micSlider.includeInLayout = true;
			}
		});
		
		_speakerButton = createButton(SpeakerButtonSkin, "sound", ["url", "play"], isPlaying);
		_speakerButton.name = _("On/off speaker sound");
		
		_speakerSlider = new VolumeSlider();
		_speakerSlider.name = _("Adjust speaker volume");
		_speakerSlider.width = 40;
		_speakerSlider.height = 20;
		_speakerSlider.includeInLayout = false;
		_watchers.push(BindingUtils.bindProperty(_speakerSlider, "includeInLayout", _speakerButton, "includeInLayout"));
		_watchers.push(BindingUtils.bindProperty(_speakerSlider, "visible", _speakerSlider, "includeInLayout"));
		_watchers.push(BindingUtils.bindProperty(_speakerSlider, "level", _parent, "volume"));
		_watchers.push(BindingUtils.bindProperty(_speakerSlider, "enabled", _parent, "sound"));
		_speakerSlider.addEventListener(Event.CHANGE, sliderChangeHandler, false, 0, true);
		//_watchers.push(BindingUtils.bindProperty(_parent, "volume", _speakerSlider, "level"));
		addChild(_speakerSlider);
		
		createSpacer(_speakerSlider, "after");

		var isStreaming:Function = function(host:Object):Boolean { 
			return host['play'] != null || host['publish'] != null || host['url'] != null && host['url'].substr(0, 4) == 'http'; 
		};
		
		var isNotStreaming:Function = function(host:Object):Boolean { 
			return !isStreaming(host); 
		};
		
		_spacer = createButton();
		_spacer.percentWidth = 100;
		_spacer.setStyle("fillDownColors", _spacer.getStyle("fillColors"));
		_spacer.buttonMode = false;
		_watchers.push(BindingUtils.bindProperty(_spacer, "includeInLayout", _parent, {name: "play", getter: isNotStreaming}));
		_watchers.push(BindingUtils.bindProperty(_spacer, "includeInLayout", _parent, {name: "publish", getter: isNotStreaming}));
		_watchers.push(BindingUtils.bindProperty(_spacer, "includeInLayout", _parent, {name: "url", getter: isNotStreaming}));
		_watchers.push(BindingUtils.bindProperty(_spacer, "visible", _spacer, "includeInLayout"));
		
		_position = new PlayPositionSlider();
		_position.percentWidth = 100;
		_position.height = 20;
		_position.buttonMode = false;
		_watchers.push(BindingUtils.bindProperty(_position, "includeInLayout", _parent, {name: "play", getter: isStreaming}));
		_watchers.push(BindingUtils.bindProperty(_position, "includeInLayout", _parent, {name: "publish", getter: isStreaming}));
		_watchers.push(BindingUtils.bindProperty(_position, "includeInLayout", _parent, {name: "url", getter: isStreaming}));
		_watchers.push(BindingUtils.bindProperty(_position, "visible", _position, "includeInLayout"));
		_watchers.push(BindingUtils.bindProperty(_position, "total", _parent, "duration"));
		_watchers.push(BindingUtils.bindProperty(_position, "position", _parent, "currentTime"));
		_position.addEventListener(Event.CHANGE, positionChangeHandler, false, 0, true);
		addChild(_position);
		
		var isAllowed:Function = function(host:Object):Boolean { return host['camera'] && !host['fullscreen']; };
		_snapButton = createButton(SnapButtonSkin, null, ["camera", "fullscreen"], isAllowed);
		_snapButton.name = _("Take camera snapshot");
		createSpacer(_snapButton, "before");
		_snapButton.addEventListener(MouseEvent.CLICK, snapshotHandler, false, 0, true);
		
		_qualityButton = createButton(QualityButtonSkin, null, ["playing", "url"], function(host:Object):Boolean { 
				return host['playing'] && host['url'] != null && host['url'].substr(0, 4) != 'http'; 
			});
		_qualityButton.name = _("Quality of play stream");
		createSpacer(_qualityButton, "before");
		_watchers.push(BindingUtils.bindSetter(function(value:Number):void {
				trace("setting level to " + value);
				_qualityButton.setStyle("level", value);
				_qualityButton.validateNow();
			}, _parent, "quality"));
		
		_fullscreenButton = createButton(FullScreenButtonSkin, "fullscreen", "enableFullscreen");
		_fullscreenButton.name = _("Toggle fullscreen mode");
		createSpacer(_fullscreenButton, "before");

		show();
	}
	
	private function removedHandler(event:Event):void
	{
		trace('removedHandler');
		removeEventListener(Event.REMOVED_FROM_STAGE, removedHandler);
		addEventListener(Event.ADDED_TO_STAGE, addedHandler);
		
		_parent.removeEventListener(PropertyChangeEvent.PROPERTY_CHANGE, propertyChangeHandler);
		_parent.removeEventListener(MouseEvent.MOUSE_MOVE, mouseMoveHandler);
		_parent.removeEventListener(MouseEvent.MOUSE_DOWN, mouseMoveHandler);
		_parent.removeEventListener(ResizeEvent.RESIZE, resizeHandler);
		_parent = null;
		
		removeEventListener(MouseEvent.ROLL_OVER, rollOverHandler);
		removeEventListener(MouseEvent.ROLL_OUT, rollOutHandler);
		
		for each (var w:ChangeWatcher in _watchers)
			w.unwatch();
		_watchers.splice(0, _watchers.length);
		
		removeAllChildren();
	}
	
	private var _file:FileReference = null;
	
	private function snapshotHandler(event:Event):void
	{
		var video:Video = _parent.video;
		if (video != null && _file == null && !_parent.fullscreen) {
			var snap:BitmapData = new BitmapData(_parent.width, _parent.height, true);
			var matrix:Matrix = new Matrix(1, 0, 0, 1, 0, 0);
			snap.draw(video.parent, matrix);
			var x0:Number = _parent.width, y0:Number = 0, scaleX:Number = -1;
			var bm:Bitmap = new Bitmap(snap);
			var encoder:JPEGEncoder = new JPEGEncoder(100);
			var jpeg:ByteArray = encoder.encode(snap);
			
			_file = new FileReference();
			_file.save(jpeg, "snap.jpg");
			_file.addEventListener(Event.COMPLETE, saveCompleteHandler, false, 0, true);
			_file.addEventListener(Event.CANCEL, saveCompleteHandler, false, 0, true);
		}
	}
	
	private function saveCompleteHandler(event:Event):void
	{
		_file = null;
	}
	
	private function sliderChangeHandler(event:Event):void
	{
		var obj:VolumeSlider = event.currentTarget as VolumeSlider;
		if (obj != null) {
			if (obj == _micSlider)
				_parent.gain = _micSlider.level;
			else
				_parent.volume = _speakerSlider.level;
		}
	}
	
	private function positionChangeHandler(event:Event):void
	{
		var obj:PlayPositionSlider = event.currentTarget as PlayPositionSlider;
		if (obj != null)
			_parent.setCurrentTime(obj.position);
	}
	
	private function propertyChangeHandler(event:PropertyChangeEvent):void
	{
		if (event.property != "level")
			trace("propertyChange " + event.property + " " + event.oldValue + "=>" + event.newValue);
	}
	
	private function mouseMoveHandler(event:Event):void
	{
		show();
	}
	
	private function resizeHandler(event:Event):void
	{
		y = _parent.height - this.height;
	}
	
	private function rollOverHandler(event:Event):void
	{
		_hover = true;
		stopHideTimer();
	}
	
	private function rollOutHandler(event:Event):void
	{
		startHideTimer();
		_hover = false;
	}
	
	private var _last_showing:Number = 0;
	private var _last_to_y:Number = 0;
	
	private function show():void
	{
		if (y != (_parent.height - this.height)) {
			if (_last_showing < ((new Date()).getTime() - 200) || _last_to_y != (_parent.height - this.height)) {
				_last_showing = (new Date()).getTime();
				_last_to_y = _parent.height - this.height;
				var effect:Move = new Move();
				effect.duration = 200;
				setStyle("moveEffect", effect);
				y = _parent.height - this.height;
			}
		}
		
		if (!_hover)
			startHideTimer();
	}
	
	private function hide():void
	{
		if (y != _parent.height) {
			var effect:Move = new Move();
			effect.duration = 500;
			setStyle("moveEffect", effect);
			
			y = _parent.height;
		}
	}

	public function startHideTimer():void
	{
		stopHideTimer();
		if (_parent.detectActivity) {
			_hideTimer = new Timer(HIDE_DELAY, 1);
			_hideTimer.addEventListener(TimerEvent.TIMER, hideTimerHandler, false, 0, true);
			_hideTimer.start();
		}
	}
	
	public function stopHideTimer():void
	{
		if (_hideTimer != null) {
			_hideTimer.stop();
			_hideTimer = null;
		}
	}
	
	private function hideTimerHandler(event:Event):void
	{
		_hideTimer = null;
		if (_parent != null && y == (_parent.height - this.height))
			hide();
	}
	
	private function setToolTip(str:String, child:DisplayObject=null):void
	{
		if (_help == null) {
			_help = new LinkButton();
			_help.setStyle("color", 0xffffff);
			_help.setStyle("fontWeight", "normal");
			_help.setStyle("bottom", 20);
			if (parent != null)
				parent.addChild(_help);
		}
		if (str != null && str != '') {
			_help.visible = true;
			_help.label = str;
			if (child != null) {
				_help.x = child.x - _help.width/2;
				if (_help.x < 0) _help.x = 0;
				else if (_help.x + _help.width > this.width) _help.x = this.width - _help.width;
			}
		}
		else {
			_help.visible = false; // hide it
		}
	}
};


/*
 * NOTE: Following classes are borrowed from the videocity project.
 * http://code.google.com/p/videocity
 */
 
class ShinyButtonSkin extends ProgrammaticSkin
{
	/**
	 * update the display list based on the style.
	 */
	protected override function updateDisplayList(w:Number, h:Number):void
	{
		var borderThickness:uint = getDefaultStyle("borderThickness", 0) as uint;
		var borderColor:uint     = getDefaultStyle("borderColor", 0xb7babc) as uint;
		var fillColors:Array	 = getDefaultStyle("fillColors", [0xcacaca, 0xb0b0b0]) as Array;
		var backgroundAlpha:Number = getDefaultStyle("backgroundAlpha", 1.0) as Number;
		var temp:uint;
		
		switch (name) {
			case "upSkin":
			case "selectedUpSkin":
				// no change
				break;
				
			case "overSkin":
			case "selectedOverSkin":
				fillColors = getDefaultStyle("fillOverColors", [fillColors[1], fillColors[1]]) as Array;
				break;
				
			case "downSkin":
			case "selectedDownSkin":
				fillColors = getDefaultStyle("fillDownColors", [fillColors[1], fillColors[0]]) as Array;
				break;
				
			case "disabledSkin":
			case "disabledDownSkin":
			case "selectedDisabledSkin":
				fillColors = getDefaultStyle("fillDownColors", [fillColors[0], fillColors[0]]) as Array;
				break;
		}
		
		drawShinySkin(graphics, fillColors, w, h, borderThickness, borderColor, backgroundAlpha);
	}	

	public static function drawShinySkin(graphics:Graphics, fillColors:Array, w:Number, h:Number, borderThickness:int, borderColor:uint, backgroundAlpha:Number):void
	{
		var lightColor:uint      = fillColors[0];
		var darkColor:uint       = fillColors[1];
		
		graphics.clear();
		
		if (borderThickness > 0) {
			graphics.beginFill(borderColor);
			graphics.drawRect(0, 0, w, h);
			graphics.endFill();
		}
		
		var half:int = Math.ceil((h-2)/2);
		graphics.beginFill(lightColor, backgroundAlpha);
		graphics.drawRect(borderThickness, borderThickness, w-2*borderThickness, half - borderThickness);
		graphics.endFill();
		
		graphics.beginFill(darkColor, backgroundAlpha);
		graphics.drawRect(borderThickness, half, w-2*borderThickness, h - half - 2*borderThickness);
		graphics.endFill();
	}
	
	protected function getDefaultStyle(prop:String, def:Object):Object
	{
		var result:Object = getStyle(prop);
		return (result != null ? result : def);
	}
};

class PlayButtonSkin extends ShinyButtonSkin
{
	override protected function updateDisplayList(w:Number, h:Number):void
	{
		super.updateDisplayList(w, h);
		
		var color:uint = getDefaultStyle("color", 0x000000) as uint;
		
		if (name != null && name.substr(0, 8) != "selected") {
			graphics.lineStyle(1, color);
			graphics.beginFill(color);
			graphics.moveTo(w/4, h/4);
			graphics.lineTo(w*3/4, h/2);
			graphics.lineTo(w/4, h*3/4);
			graphics.lineTo(w/4, h/4);
			graphics.endFill();
		}
		else {
			graphics.lineStyle(1, color);
			graphics.beginFill(color);
			graphics.moveTo(w/4, h/4);
			graphics.lineTo(w*4/10, h/4);
			graphics.lineTo(w*4/10, h*3/4);
			graphics.lineTo(w/4, h*3/4);
			graphics.lineTo(w/4, h/4);
			graphics.endFill();
			
			graphics.beginFill(color);
			graphics.moveTo(w*5/8, h/4);
			graphics.lineTo(w*3/4, h/4);
			graphics.lineTo(w*3/4, h*3/4);
			graphics.lineTo(w*6/10, h*3/4);
			graphics.lineTo(w*6/10, h/4);
			graphics.endFill();
		}
	}
};

class RecordButtonSkin extends ShinyButtonSkin
{
	override protected function updateDisplayList(w:Number, h:Number):void
	{
		super.updateDisplayList(w, h);
		
		var color:uint = (name != null && name.substr(0, 8) == "selected") ?
			getDefaultStyle("selectedColor", 0xff0000) as uint:
			getDefaultStyle("color", 0x000000) as uint;
		graphics.lineStyle(1, color);
		graphics.beginFill(color);
		graphics.drawCircle(w/2, h/2, Math.min(w, h)/4);
		graphics.endFill();
	}
};

class CamButtonSkin extends ShinyButtonSkin
{
	override protected function updateDisplayList(w:Number, h:Number):void
	{
		super.updateDisplayList(w, h);
		
		var color:uint = getDefaultStyle("color", 0x000000) as uint;
		
		var g:Graphics = graphics;
		g.lineStyle(1, color);
		
		g.beginFill(color);
		g.moveTo(w/4, h/3);
		g.lineTo(w*2/3, h/3);
		g.lineTo(w*2/3, h/2);
		g.lineTo(w*5/6, h/3);
		g.lineTo(w*5/6, h*2/3);
		g.lineTo(w*2/3, h/2);
		g.lineTo(w*2/3, h*2/3);
		g.lineTo(w/4, h*2/3);
		g.lineTo(w/4, h/3);
		g.endFill();
		
		if (name != null && name.substr(0, 8) != "selected") {
			g.lineStyle(1, 0xff0000);
			var r:Number = Math.min(w, h)/3;
			g.drawCircle(w/2, h/2, r);
			g.moveTo(w/2+r/Math.SQRT2, r/Math.SQRT2);
			g.lineTo(r/Math.SQRT2, h/2+r/Math.SQRT2);
		}
	}
};

class MicButtonSkin extends ShinyButtonSkin
{
	override protected function updateDisplayList(w:Number, h:Number):void
	{
		super.updateDisplayList(w, h);
		
		var color:uint = getDefaultStyle("color", 0x000000) as uint;
		
		graphics.lineStyle(1, color);
		
		graphics.beginFill(color);
		graphics.drawEllipse(w*5/12, h/4, w/6, h*3/8);
		graphics.endFill();
		
		graphics.moveTo(w/3, h*3/8);
		graphics.lineTo(w/3, h*2/3);
		graphics.curveTo(w/2, h*5/6, w*2/3, h*2/3);
		graphics.lineTo(w*2/3, h*3/8);
		
		if (name != null && name.substr(0, 8) != "selected") {
			graphics.lineStyle(1, 0xff0000);
			var r:Number = Math.min(w, h)/3;
			graphics.drawCircle(w/2, h/2, r);
			graphics.moveTo(w/2+r/Math.SQRT2, r/Math.SQRT2);
			graphics.lineTo(r/Math.SQRT2, h/2+r/Math.SQRT2);
		}
	}
}

class SpeakerButtonSkin extends ShinyButtonSkin
{
	override protected function updateDisplayList(w:Number, h:Number):void
	{
		super.updateDisplayList(w, h);
		
		var color:uint = getDefaultStyle("color", 0x000000) as uint;
		
		graphics.lineStyle(1, color);
		
		graphics.beginFill(color);
		graphics.moveTo(w*3/20, h*8/20);
		graphics.lineTo(w*5/20, h*8/20);
		graphics.lineTo(w*10/20, h*4/20);
		graphics.lineTo(w*10/20, h*16/20);
		graphics.lineTo(w*5/20, h*12/20);
		graphics.lineTo(w*3/20, h*12/20);
		graphics.lineTo(w*3/20, h*8/20);
		graphics.endFill();
		
		if (name != null && name.substr(0, 8) != "selected") {
			graphics.lineStyle(1, 0xff0000);
			var r:Number = Math.min(w, h)/3;
			graphics.drawCircle(w/2, h/2, r);
			graphics.moveTo(w/2+r/Math.SQRT2, r/Math.SQRT2);
			graphics.lineTo(r/Math.SQRT2, h/2+r/Math.SQRT2);
		}
		else {
			var level:int = Math.round((getDefaultStyle("level", 0.5) as Number) * 3);
			if (level >= 1) {
				graphics.moveTo(w*6/10, h*4/10);
				graphics.curveTo(w*6/10+3, h/2, w*6/10, h*6/10);
			}
			if (level >= 2) {
				graphics.moveTo(w*7/10, h*3/10);
				graphics.curveTo(w*7/10+5, h/2, w*7/10, h*7/10);
			}
			if (level >= 3) {
				graphics.moveTo(w*8/10, h*2/10);
				graphics.curveTo(w*8/10+6, h/2, w*8/10, h*8/10);
			}
		}
	}
}
	
class FullScreenButtonSkin extends ShinyButtonSkin
{
	override protected function updateDisplayList(w:Number, h:Number):void
	{
		super.updateDisplayList(w, h);
		
		var color:uint = getDefaultStyle("color", 0x000000) as uint;
		graphics.lineStyle(1, color);
		
		graphics.moveTo(w*3/4-3, h/4+1);
		graphics.lineTo(w/4, h/4+1);
		graphics.lineTo(w/4, h*3/4);
		graphics.lineTo(w*3/4-1, h*3/4);
		graphics.lineTo(w*3/4-1, h/4+3);
		graphics.moveTo(w*3/4-5, h/4+5);
		graphics.lineTo(w*3/4+1, h/4-1);
		
		if (name != null && name.substr(0, 8) != "selected") {
			graphics.moveTo(w*3/4-3, h/4-1);
			graphics.lineTo(w*3/4+1, h/4-1);
			graphics.lineTo(w*3/4+1, h/4+3);
		}
		else {
			graphics.moveTo(w*3/4-5, h/4+2);
			graphics.lineTo(w*3/4-5, h/4+5);
			graphics.lineTo(w*3/4-2, h/4+5);
		}
	}
}

class SnapButtonSkin extends ShinyButtonSkin
{
	override protected function updateDisplayList(w:Number, h:Number):void
	{
		super.updateDisplayList(w, h);
		
		var color:uint = getDefaultStyle("color", 0x000000) as uint;
		var fillColors:Array = getDefaultStyle("fillColors", [0xcacaca, 0xb8b8b8]) as Array;
		
		graphics.lineStyle(1, color);
		graphics.beginFill(color);
		graphics.moveTo(3, h/3);
		graphics.lineTo(w-4, h/3);
		graphics.lineTo(w-4, h*2/3);
		graphics.lineTo(3, h*2/3);
		graphics.lineTo(3, h/3);
		graphics.endFill();
		
		graphics.beginFill(fillColors[0]);
		graphics.drawCircle(w/2, h/2, Math.min(w, h)/4);
		graphics.drawCircle(w/2, h/2, Math.min(w, h)/4-2);
		graphics.endFill();
	}
}

class QualityButtonSkin extends ShinyButtonSkin
{
	override protected function updateDisplayList(w:Number, h:Number):void
	{
		super.updateDisplayList(w, h);
		
		var color:uint = getDefaultStyle("color", 0x404040) as uint;
		var fillColor:uint = getDefaultStyle("levelColor", 0x808080) as uint;
		var level:Number = getDefaultStyle("level", 0.0) as Number;
		
		var bars:Array = [{x:2, y:13, w:4, h:3}, {x:6, y:10, w:4, h:6}, 
						  {x:10, y:7, w:4, h:9}, {x:14, y:4, w:4, h:12}];
		
		for (var i:Number = 0; i<bars.length; ++i) {
			var o:Object = bars[i];
			var active:Boolean = (level > i/4);
			graphics.lineStyle(1, color);
			if (active)
				graphics.beginFill(fillColor);
			graphics.drawRect(o.x, o.y, o.w, o.h);
			if (active)
				graphics.endFill();
		}	

	}
};

	
[Event(name="change", type="flash.events.Event")]

class VolumeSlider extends UIComponent
{
	private var _level:Number = 0.5;
	
	public function VolumeSlider()
	{
		super();
		buttonMode = true;
		setStyle("borderThickness", 0);
		setStyle("fillColors", [0xcacaca, 0xb8b8b8]);
		setStyle("fillOverColors", [0xcacaca, 0xb8b8b8]);
		setStyle("fillDownColors", [0xcacaca, 0xb8b8b8]);
		setStyle("disabledColor", 0xa0a0a0);
		setStyle("showTrackHighlight", true);
		setStyle("skin", ShinyButtonSkin);
		addEventListener(MouseEvent.CLICK, mouseClickHandler, false, 0, true);
	}
	
	public function get level():Number
	{
		return _level;
	}
	public function set level(value:Number):void
	{
		var oldValue:Number = _level;
		if (value >= 0 && value <= 1.0)
			_level = value;
		if (oldValue != value) 
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "level", oldValue, value));
	}
	
	override protected function updateDisplayList(w:Number, h:Number):void
	{
		var g:Graphics = graphics;
		g.clear();
		
		var borderThickness:uint = getStyle("borderThickness") != null ? getStyle("borderThickness") : 0;
		var borderColor:uint     = getStyle("borderColor") != null ? getStyle("borderColor") : 0xb7babc;
		var fillColors:Array	 = getStyle("fillColors") != null ? getStyle("fillColors") : [0xcacaca, 0x989898];
		var backgroundAlpha:Number = getStyle("backgroundAlpha") != null ? getStyle("backgroundAlpha") : 1.0;
		var color:uint = getStyle("color") != null ? getStyle("color") : 0x000000;
		if (!enabled) 
			color = getStyle("disabledColor") != null ? getStyle("disabledColor") : 0x202020;
			
		ShinyButtonSkin.drawShinySkin(g, fillColors, w, h, borderThickness, borderColor, backgroundAlpha);
		
		g.lineStyle(1, color);
		g.moveTo(2, h*3/4);
		g.lineTo(w-2, h/4);
		g.lineTo(w-2, h*3/4);
		g.lineTo(2, h*3/4);
		
		g.beginFill(color);
		g.moveTo(2, h*3/4);
		g.lineTo(2+(w-4)*level, h*3/4-h/2*level);
		g.lineTo(2+(w-4)*level, h*3/4);
		g.lineTo(2, h*3/4);
		g.endFill();
	}
	
	private function mouseClickHandler(event:MouseEvent):void
	{
		if (this.enabled && this.width > 0) {
			level = this.mouseX / this.width;
			updateDisplayList(this.unscaledWidth, this.unscaledHeight);
			dispatchEvent(new Event(Event.CHANGE));
		}
	}
};


class VolumeLevel extends UIComponent
{
	private var _level:Number = 0.5;
	
	public function VolumeLevel()
	{
		super();
		setStyle("borderThickness", 0);
		setStyle("fillColors", [0xcacaca, 0xb8b8b8]);
		setStyle("fillOverColors", getStyle("fillColors"));
		setStyle("fillDownColors", getStyle("fillColors"));
		setStyle("skin", ShinyButtonSkin);
	}
	
	public function get level():Number
	{
		return _level;
	}
	public function set level(value:Number):void
	{
		var oldValue:Number = _level;
		if (value >= 0 && value <= 1.0) {
			_level = value;
			updateDisplayList(unscaledWidth, unscaledHeight);
		}
		if (oldValue != value) 
			dispatchEvent(PropertyChangeEvent.createUpdateEvent(this, "level", oldValue, value));
	}
	
	override protected function updateDisplayList(w:Number, h:Number):void
	{
		var g:Graphics = graphics;
		g.clear();
		
		var borderThickness:uint = getStyle("borderThickness") != null ? getStyle("borderThickness") : 0;
		var borderColor:uint     = getStyle("borderColor") != null ? getStyle("borderColor") : 0xb7babc;
		var fillColors:Array	 = getStyle("fillColors") != null ? getStyle("fillColors") : [0xcacaca, 0xc0c0c0];
		var backgroundAlpha:Number = getStyle("backgroundAlpha") != null ? getStyle("backgroundAlpha") : 1.0;
		var color:uint = getStyle("color") != null ? getStyle("color") : 0x000000;
		var inactiveColor:uint   = getStyle("inactiveColor") != null ? getStyle("inactiveColor") : Math.max(fillColors[1] - 0x050505, 0x000000);
		
		ShinyButtonSkin.drawShinySkin(g, fillColors, w, h, borderThickness, borderColor, backgroundAlpha);
	
		g.lineStyle(1, color);
		for (var i:int = 0; i<(w-5); i+= 6) {
			var active:Boolean = enabled && (level > i/w);
			g.lineStyle(1, active ? color : inactiveColor);
			if (active)
				g.beginFill(level > i/w ? color : fillColors[1]);
			g.drawRect(i, h/4, 4, h/2);
			if (active)
				g.endFill();
		}	
	}
};

[Event(name="change", type="flash.events.Event")]

class PlayPositionSlider extends UIComponent
{
	private var _position:Number = 0;
	private var _total:Number = 0;
	private var _text:TextField;
	
	public function PlayPositionSlider()
	{
		super();
		buttonMode = true;
		setStyle("borderThickness", 0);
		setStyle("fillColors", [0xcacaca, 0xb8b8b8]);
		setStyle("fillOverColors", [0xcacaca, 0xb8b8b8]);
		setStyle("fillDownColors", [0xcacaca, 0xb8b8b8]);
		setStyle("disabledColor", 0xa0a0a0);
		setStyle("showTrackHighlight", true);
		setStyle("skin", ShinyButtonSkin);
		addEventListener(MouseEvent.CLICK, mouseClickHandler, false, 0, true);
		
		_text = new TextField();
		_text.x = 6;
		_text.y = 4;
		var format:TextFormat = new TextFormat();
		format.font = "Arial";
		format.color = 0x606060;
		format.size = 9;
		_text.mouseEnabled = false;
		_text.defaultTextFormat = format;
		addChild(_text);
	}
	
	public function get total():Number
	{
		return _total;
	}
	public function set total(value:Number):void
	{
		_total = value;
		invalidateDisplayList();
	}
	
	public function get position():Number
	{
		return _position;
	}
	public function set position(value:Number):void
	{
		_position = value;
		invalidateDisplayList(); 
	}
	
	override protected function updateDisplayList(w:Number, h:Number):void
	{
		var g:Graphics = graphics;
		g.clear();
		
		super.updateDisplayList(w, h);
		
		var borderThickness:uint = getStyle("borderThickness") != null ? getStyle("borderThickness") : 0;
		var borderColor:uint     = getStyle("borderColor") != null ? getStyle("borderColor") : 0xb7babc;
		var fillColors:Array	 = getStyle("fillColors") != null ? getStyle("fillColors") : [0xcacaca, 0x989898];
		var backgroundAlpha:Number = getStyle("backgroundAlpha") != null ? getStyle("backgroundAlpha") : 1.0;
		var color:uint = getStyle("color") != null ? getStyle("color") : 0x000000;
		var color1:uint = Math.min(color+0x202020, 0xffffff);
		if (!enabled) 
			color = getStyle("disabledColor") != null ? getStyle("disabledColor") : 0x202020;
			
		ShinyButtonSkin.drawShinySkin(g, fillColors, w, h, borderThickness, borderColor, backgroundAlpha);
		
		if (total > 0) {
			g.lineStyle(1, color);
			g.drawRect(5, h/4, w-10, h/2);
			
			if (!isNaN(position)) {
				var pos:Number = position <= total ? position : total;
				g.beginFill(color1);
				g.drawRect(5, h/4, (w-10)*pos/total, h/4);
				g.endFill();
				g.beginFill(color);
				g.drawRect(5, h/2, (w-10)*pos/total, h/4);
				g.endFill();
			}
		}
			
		_text.text = formatDuration(position);
			
	}
	
	private function formatDuration(duration:int):String
	{
		var hh:int = Math.floor(duration / 3600);
		var mm:int = Math.floor((duration % 3600) / 60);
		var ss:int = duration % 60;
		var value:String = (mm < 10 ? '0' + mm.toString() : mm.toString()) + ":" + (ss < 10 ? '0' + ss.toString() : ss.toString());;
		if (hh > 0)
			value = hh.toString() + ":" + value;
		return value;
	}
	
	private function mouseClickHandler(event:MouseEvent):void
	{
		if (this.enabled && this.width > 0) {
			if (total > 0) {
				var value:Number = (this.mouseX - 5) / (this.width - 10) * total;
				this.position = (value < 0 ? 0 : (value > total ? total : value));
				invalidateDisplayList();
				dispatchEvent(new Event(Event.CHANGE));
			}
		}
	}
};
