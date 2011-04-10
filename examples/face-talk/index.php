<?php

require 'facebook-php-sdk/src/facebook.php';

define('FACEBOOK_APP_ID', 'XXXXXXXXXXXXXXX');
define('FACEBOOK_SECRET', 'YYYYYYYYYYYYYYYYYYYYYY');

// Create our Application instance (replace this with your appId and secret).
$facebook = new Facebook(array(
  'appId'  => 'XXXXXXXXXXXXXXX',
  'secret' => 'YYYYYYYYYYYYYYYYYYYYYY',
  'cookie' => true,
));

// session or if the user logged out of Facebook.
$session = $facebook->getSession();

$me = null;
// Session based API call.
if ($session) {
  try {
    $uid = $facebook->getUser();
    $me = $facebook->api('/me');
  } catch (FacebookApiException $e) {
    // error_log($e);
    // print '<pre>';
    // print "This is the Error:  ";
    // print_r($e);
    // print '</pre>';
    $session = null;
  }
}

if (!empty($_GET["send"]) && $_GET["send"] == "true") {

    if($session && !empty($_POST) && !empty($_POST["uid"]) 
       && !empty($_POST["nearid"]) && !empty($_POST["event"])) {

        $to = substr($_POST['uid'], 10);
        $param = array( 'method' => 'liveMessage.send', 
                    'access_token' => $session["access_token"] , 
                    'recipient' => $to, 
                    'event_name' => $_POST["event"], 
                    'message' => json_encode(array(
                        "receiver"=>$_POST['uid'],
                        "sender"=>$_POST["stream"], 
                        "nearid"=>$_POST["nearid"], 
                        "name"=>$me['first_name'] . " " . $me['last_name']
                 )));
        $result =  $facebook->api($param);
    }
    
    exit(0);
}

$media_url = 'rtmfp://stratus.rtmfp.net/d1e1e5b3f17e90eb35d244fd-c711881365d9/';
    
$stream = "" . rand(1000000000, 9999999999) . $uid;
$publish_url = $media_url .  "?publish=" . $stream;
    
$site_url = 'http://myprojectguide.org/p/face-talk/';
$base_url = 'http://apps.facebook.com/face-talk/';
$invite_url = $base_url . '?caller='. $stream;

?>

<script type="text/javascript">
<!--
    var nearid = null;
    var active = false; // whether in an active call or not?
    var play_stream = null; 

    <?php if (!empty($_GET["caller"])): ?>
        var caller = "<?php echo $_GET["caller"]; ?>";
    <?php else: ?>
        var caller = null;
    <?php endif ?>

    function testFunc(arg) {
       // document.getElementById('actionDiv').setInnerXHTML('<p>test called</p>');
    }

    function onCreationComplete(event) {
       // document.getElementById('actionDiv').setInnerXHTML('<p>creation complete</p>');
    }

    function onPropertyChange(event) {
        // document.getElementById('actionDiv').setInnerXHTML('<p>property change</p>');

        if (event.property == "nearID" && event.objectID.indexOf("video1")>=0) {
           // document.getElementById('actionDiv').setInnerXHTML('<p>video1.nearID set ' + event.newValue + '</p>');
           nearid = event.newValue;

           if (caller) {
              sendMessage("joinRequest", caller);

              document.getElementById('videobox2').setInnerFBML(connectingmessage);
           }
        }
    }

    function sendMessage(event, receiver) {
        if (receiver == null)
            return;
        //document.getElementById('actionDiv').setInnerXHTML('<p> sending ' + event + ' to ' + receiver + '</p>');
        var ajax = new Ajax();
        ajax.responseType = Ajax.FBML;
        ajax.ondone = function(data) {
            //document.getElementById('actionDiv').setInnerXHTML('<p>received response</p>');
        };
        ajax.onerror = function(data) {  
            //document.getElementById('actionDiv').setInnerXHTML('<p>received error</p>');
        };

        var params = {"uid":receiver,
                      "stream":"<? echo $stream; ?>",
                      "nearid":nearid,
                      "event":event };
        ajax.post("<?php echo $site_url; ?>index.php?send=true", params);
    }
    
    var a = new LiveMessage('joinRequest', function(data) {
        // document.getElementById('actionDiv').setInnerXHTML('<p>received joinRequest</p>');

        if (data.receiver != "<? echo $stream; ?>") {
            // document.getElementById('actionDiv').setInnerXHTML('<p>Invalid receiver stream in joinAccept ' + data.receiver + ' <? echo $stream; ?></p>');
            return;
        }

        if (active) {
            if (play_stream != data.sender) {
                sendMessage("joinReject", data.sender);
                // document.getElementById('actionDiv').setInnerXHTML('<p>sending reject because already active</p>');
            }
            return;
        }
	
        // document.getElementById('actionDiv').setInnerXHTML('<p>showing play video</p>');
        showPlayVideo(data.nearid, data.sender);

        play_stream = data.sender;
        active = true;

        sendMessage("joinAccept", data.sender);
    });


    var b = new LiveMessage('joinAccept', function(data) {
        // document.getElementById('actionDiv').setInnerXHTML('<p>received joinAccept</p>');

        if (data.receiver != "<? echo $stream; ?>") {
            // document.getElementById('actionDiv').setInnerXHTML('<p>Invalid receiver stream in joinAccept</p>');
            return;
        }

        if (active)
            return;
            
        showPlayVideo(data.nearid, data.sender);

        play_stream = data.sender;
        active = true;
    });

    var c = new LiveMessage('joinReject', function(data) {
        // document.getElementById('actionDiv').setInnerXHTML('<p>received joinReject</p>');

        if (data.receiver != "<? echo $stream; ?>") {
            return;
        }

        document.getElementById('videobox2').setInnerFBML(rejectmessage);

    });

    var d = new LiveMessage('leaveRequest', function(data) {
        if (active) {
            active = false;
            play_stream = null;
            showInviteList();
        }
    });

    function endChat() {
       if (play_stream != null) {
           sendMessage('leaveRequest', play_stream);
           active = false;
           play_stream = null;
           showInviteList();
       }
    }

    function showInviteList() {
        caller = null;
        document.getElementById('videobox2').setStyle('background-color','#ffffff');   
        document.getElementById('videobox2').setInnerFBML(invitelist);
        document.getElementById('helpbox1').setInnerFBML(helptext1);
        document.getElementById('helpbox2').setInnerXHTML('<span></span>');
    }

    function showPlayVideo(nearid, sender) {
        var swf = document.createElement('fb:swf');
        swf.setId('video2');
        swf.setWidth('320');
        swf.setHeight('240');
        swf.setSWFSrc("<?php echo $site_url; ?>VideoIO.swf");
        //swf.setQuality('high');
        //swf.setSWFBGColor('#000000');
        swf.setFlashVar('controls','true');
        swf.setFlashVar('enableFullscreen','false');
        swf.setFlashVar('farID', nearid);
        swf.setFlashVar('url', "<? echo $media_url; ?>");
        swf.setFlashVar('play', sender);
        swf.setFlashVar('smoothing', 'true');

        document.getElementById('videobox2').setInnerXHTML('<span></span>');
        document.getElementById('videobox2').appendChild(swf);
        document.getElementById('videobox2').setStyle('background-color','#000000');   
        document.getElementById('helpbox1').setInnerFBML(helptext2);
        document.getElementById('helpbox2').setInnerFBML(endchat);
    }

//-->
</script>

<fb:fbjs-bridge/>

<?php if ($me): ?>

<table style="left: 0px; top: 0px;">
    <tr valign="top"><td width="320">
    
        <div id="videobox1" 
            style="width: 320px; height: 240px; background-color: #000000;">
        </div>
        <br/>
        <div id="helpbox1">
        </div>

    </td><td width="320">
    
        <div id="videobox2" 
            style="width: 320px;">
        </div>
        <br/>
        <div id="helpbox2" style="padding-top: 10px;">
        </div>

    </td></tr>

</table>

<fb:js-string var="connectingmessage">
     <h1>Connecting...</h1>
     <p>Please wait while connecting to the caller.</p>
     <ol>
        <li><a href="#" onClick="showInviteList(); return false;">Cancel the connection</a></li>
     </ol>
</fb:js-string>

<fb:js-string var="rejectmessage">
     <h1>Cannot connect</h1>
     <p>Your invitation is either expired or invalid, or the caller is gone.</p>
     <ol>
        <li><a href="#" onClick="showInviteList(); return false;">See list of online friends to invite</a></li>
     </ol>
</fb:js-string>

<fb:js-string var="errorself">
     <h1>Invalid invitation</h1>
     <p>This invitation was generated by you, but cannot be clicked by you.
     Please send the invitation using Facebook text chat to the appropriate 
     online friend.</p>
     <ol>
         <li><a href="#" onClick="showInviteList(); return false;">See list of online friends to invite</a></li>
     </ol>
</fb:js-string>

<fb:js-string var="swf1">
     <fb:swf 
         id="video1" width="320" height="240"
         swfsrc="<?php echo $site_url; ?>VideoIO.swf"
         quality="high"
         swfbgcolor="#000000"
         wmode="opaque"
         flashvars="controls=true&enableFullscreen=false&cameraQuality=80&&url=<? echo $media_url; ?>&publish=<? echo $stream; ?>"
     />
</fb:js-string>

<fb:js-string var="endchat">
    <input type='button' onClick='endChat(); return false;' value='End Chat'/>
</fb:js-string>

<fb:js-string var="helptext1">
     <h1><a href="http://code.google.com/p/flash-videoio" target="_blank">Face Talk</a></h1>
     <p>Select a friend and send him or her a text invitation for a video call.</p>
</fb:js-string>

<fb:js-string var="helptext2">
     <h1><a href="http://code.google.com/p/flash-videoio" target="_blank">Face Talk</a></h1>
</fb:js-string>

<fb:js-string var="invitelist">
     <fb:chat-invite msg="Join me in a video chat! <? echo $invite_url; ?>" condensed="false"/>
</fb:js-string>

<fb:title>Face Talk: video chat with online friends on Facebook</fb:title>

<fb:user-agent includes="chrome, macintosh">
<hr></hr>
<p>Flash player may not detect your camera on Macintosh if you used the Chrome browser. 
Please see
(<a href="http://discussions.apple.com/thread.jspa?messageID=12579808" target="_blank">details</a>) on how to fix this.
</p>
</fb:user-agent>

<script type="text/javascript">
    document.getElementById("videobox1").setInnerFBML(swf1);
    document.getElementById("helpbox1").setInnerFBML(caller ? helptext2 : helptext1);
    if (caller != null && caller.substr(10) == "<?php echo $uid; ?>") {
        // this invitation is generated by you and is not for you.
        caller = null;
        document.getElementById('videobox2').setInnerFBML(errorself);
    } 
    else if (caller == null) {
        showInviteList();
    }

</script>

<?php else: ?>

    <table><tr valign="top"><td>
        <img src="<?php echo $site_url; ?>logo.jpg"></img>
    </td><td>
        <h1>Face Talk</h1>
        <p>This application allows you to video chat with your online friends
        using technology based on the
        <a href="http://code.google.com/p/flash-videoio" target="_blank">Flash VideoIO</a>
        project. Please connect to this application using your facebook login.</p>

    <?php
    $next_url = $base_url;
    if ($_GET["caller"]) {
        $next_url = $next_url . "?caller=" . $_GET["caller"];
    }
    $cancel_url = $base_url;

    $loginUrl = $facebook->getLoginUrl(array("next" => $next_url, "cancel_url" => $cancel_url));
    ?>
    
    <a href="<?php echo $loginUrl; ?>">
        <img src="http://static.ak.fbcdn.net/rsrc.php/zB6N8/hash/4li2k73z.gif"></img>
    </a>
    </td></tr></table>

<?php endif ?>

<!--
<hr/>
Debug Trace:<br/>
<div id="actionDiv"></div>
<br/>
-->

<script>
 <!--
 //-->
</script>

