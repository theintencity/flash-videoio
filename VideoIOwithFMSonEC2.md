Contributed by [Mayank Mehta](mailto:mayankdbit@gmail.com)

# Objective #
Capturing Video from Users Browser via Webcam and send it to Server. Similar to how you it is done on YouTube

  1. Silverlight 4 would let you access users Webcam via browser but you have to create custom class to     convert that raw data into desired video format which is a big hassle.
  1. Flash Player: open Source project available that you can plug-in and start using it.  On development used Flash-VideoIO with rtmplite locally and on production used Flash-VideoIO with FMS on Amazon EC2.

# References #
  1. Flash-videoIO binary download from http://code.google.com/p/flash-videoio/
  1. Flash RTMP server in Python download from http://code.google.com/p/rtmplite/
  1. Flash Media Server on Amazon EC2 http://www.adobe.com/products/flashmediaserver/amazonwebservices/
  1. How to use Flash-VideoIO with rtmplite http://myprojectguide.org/p/flash-videoio/1.html.
  1. How to use FMS 4 http://help.adobe.com/en_US/flashmediaserver/amazonec2/index.html

# Setup of FMS on EC2 #

Following steps show you how to setup FMS on EC2.

  1. Read [3](http://www.adobe.com/products/flashmediaserver/amazonwebservices/) and subscribe to it.
  1. While setting up an account you would be able to download `.pem` file that would be later useful for accessing FMS on EC2 via Putty
  1. Once you have created your account on EC2, login into EC2 console portal.
  1. Now we can create our own FMS on EC2 and connect to it. Please follow the steps as shown [here](http://help.adobe.com/en_US/flashmediaserver/amazonec2/WS6fc2df2b6d2ce24359910e2812c396a83eb-7fff.html).
  1. Once you finish above step you will have an FMS instance created on EC2 that you can access via public DNS that you can get by clicking that instance on the console.
  1. Now open the DNS in the browser and try to access administrative console. You would need to update files on FMS before you can login in via Admin Console.
  1. Follow the steps [here](http://help.adobe.com/en_US/flashmediaserver/amazonec2/WS6fc2df2b6d2ce2431afba23c12c3967d3ca-7ff1.html) that will show you how to access FMS depending upon your OS. One of the main steps in link is to convert your `.pem` file to `.ppk` and keep your public DNS from the instance that you created handy will need that.
  1. If you have finished previous step successfully now you should have access to FMS via `Putty` or `ssh`. Now we need to configure FMS so that we can access FMS Administrative Console via browser. Click [here](http://help.adobe.com/en_US/flashmediaserver/amazonec2/WS6fc2df2b6d2ce2431afba23c12c3967d3ca-7ff6.html) to know how to manage the server.
  1. Whatever admin user you have created in previous step can be used to access FMS Admin Console from the browser. Just browse to your public DNS and click administrative console.
  1. [Read](http://help.adobe.com/en_US/flashmediaserver/amazonec2/WS6fc2df2b6d2ce2431afba23c12c3967d3ca-7ff1.html) about managing content on FMS.

Following steps show how to use Flash-VideoIO to save webcam stream on FMS on EC2.

  1. For storing `flv` file from videoIO you need to create a new folder. If you use live folder on `/mnt/applications/live` to store your `flv` you will get error "Application doesn't have permissions for server-side record/append of streams; access denied to stream….”
  1. Once you create a new folder under `/mnt/application/new-folder` copy all the files from `/mnt/applications/live` to `/mnt/application/new-folder`.
  1. Before you start using this you need to replace `main.far` file in your `new-folder` with `main.asc` `FMS-Install-Dir/samples/applications/live/`  or else it won’t work.
  1. Now you can start using your FMS in the VideoIO `src` string, e.g. - Assume your public DNS in EC2 instance is `http://ec2.abc.amazon.com` and new folder you created under `/mnt/applications/` is `MLive` your `src` string would be `rtmp://ec2.abc.amazon.com/MLive?publish=File1&record=true` for record and `rtmp://ec2.abc.amazon.com/MLive?play=File1` for play.

# FAQ #

**Why does recorded video via Flash-videoIO not play audio with VLC?**
VLC cannot play FLVs with speex audio, you can try changing the `codec` property to "NellyMoser" using the Javascript `setProperty` API or using the `flashVars` "codec=NellyMoser" when using VideoIO. This will use the older "NellyMoser" codec when recording, which hopefully can be played by VLC.

**How to hide RTMP URL visible in page source of VideoIO or avoid anyone else use it for uploading data?**
For stream publish from VideoIO, you need to specify either (1) `flashVar` with `url=` and `publish=` , or (2) use `setProperty("src", ...)` with dynamically generated value. (1) If you are using media server for rtmp, then you can supply application authentication arguments using the "arg" parameter in "src" property using option (2) above. These arg may be dynamically generated using some secure/authenticated web service or yours, and set using Javascript to VideoIO. The server such as rtmplite can be modified to use additional authentication arguments in NetConnection.connect if needed. (2) Create a wrapper Flash application that uses VideoIO.swf as child swf using SWFLoader. Please see one of the tutorial articles on Flash-videoIO project page about this. Then you can hardcode the URL in your wrapper, and make it not visible to the Javascript/HTML application. (3) In case of rtmfp, even if two VideoIO instances are publishing with the same URL, e.g., `rtmfp://.../?publish=something`, you still need the dynamically generated and secure nearID/farID to play this stream. Another user who publishes with the same stream name, generates a different stream I believe.

**How to restrict User access for uploading and stream files?**
If you are using Flash Media Server you can block domain on server itself. You can block domain uploading the files and domain streaming request by updating `allowedHTMLdomains.txt` and `allowedSWFdomains.txt` files in FMS folder which you are using in RTMP string.
Or read [this](http://help.adobe.com/en_US/flashmediaserver/devguide/WS5b3ccc516d4fbf351e63e3d11a0773d37a-7fea.html).

**Why is the delay before recording starts is high?**
Check if port 1935 is open or not on the server. The port 1935 is the default port for rtmp. If blocked, it causes the client to timeout in the connection attempt and eventually fallback to rtmpt which uses port 80. This succeeds but takes a long time to connect.

**Why does Javascript access to Flash-videoIO not work in Firefox or chrome?**
The nested object and embed tag is needed to enable communication from your Flash application to JavaScript embedded on your HTML page using `ExternalInterface`. Please follow the [this](http://myprojectguide.org/p/flash-videoio/1.html).

**How to set time limit on Video Recording?**
You can use Javascript to put a limit, e.g. keep monitoring  `currentTime` property in `onPropertyChange` callback and `setProperty` "src" to null when limit is reached. Details about the properties and callbacks are explained [here](http://myprojectguide.org/p/flash-videoio/10.html).