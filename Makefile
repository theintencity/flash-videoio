VERSION:=3.2
MXMLC45:=/Applications/Adobe\ Flash\ Builder\ 4/sdks/4.5/bin/mxmlc -define=CONFIG::version,${VERSION} 
MXMLC:=/Applications/Adobe\ Flash\ Builder\ 4/sdks/3.5/bin/mxmlc -define=CONFIG::version,${VERSION} 

#all:
#	echo "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<custom:VideoIO xmlns:custom=\"*\" xmlns:mx=\"http://www.adobe.com/2006/mxml\"/>\n" > Wrapper.mxml
#	${MXMLC45} -output bin-release/VideoIO11.swf -compiler.debug=false -define=CONFIG::sdk4,true  -define=CONFIG::player11,true  -target-player 11.0   -swf-version=13 -static-link-runtime-shared-libraries=true -- Wrapper.mxml
	
all:
	echo "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<custom:VideoIO xmlns:custom=\"*\" xmlns:mx=\"http://www.adobe.com/2006/mxml\"/>\n" > Wrapper.mxml
	${MXMLC}   -output bin-debug/VideoIO.swf     -compiler.debug=true  -define=CONFIG::sdk4,false -define=CONFIG::player11,false -target-player 10.0.0 -static-link-runtime-shared-libraries=true -- Wrapper.mxml
	${MXMLC}   -output bin-release/VideoIO.swf   -compiler.debug=false -define=CONFIG::sdk4,false -define=CONFIG::player11,false -target-player 10.0.0 -static-link-runtime-shared-libraries=true -- Wrapper.mxml
	${MXMLC45} -output bin-debug/VideoIO45.swf   -compiler.debug=true  -define=CONFIG::sdk4,true  -define=CONFIG::player11,false -target-player 10.3.0 -swf-version=12 -static-link-runtime-shared-libraries=true -- Wrapper.mxml
	${MXMLC45} -output bin-release/VideoIO45.swf -compiler.debug=false -define=CONFIG::sdk4,true  -define=CONFIG::player11,false -target-player 10.3.0 -swf-version=12 -static-link-runtime-shared-libraries=true -- Wrapper.mxml
	${MXMLC45} -output bin-debug/VideoIO11.swf   -compiler.debug=true  -define=CONFIG::sdk4,true  -define=CONFIG::player11,true  -target-player 11.0   -swf-version=13 -static-link-runtime-shared-libraries=true -- Wrapper.mxml
	${MXMLC45} -output bin-release/VideoIO11.swf -compiler.debug=false -define=CONFIG::sdk4,true  -define=CONFIG::player11,true  -target-player 11.0   -swf-version=13 -static-link-runtime-shared-libraries=true -- Wrapper.mxml
	${MXMLC45} -output bin-debug/VideoPIP.swf    -compiler.debug=true  -swf-version=12 -target-player 10.3.0 -static-link-runtime-shared-libraries=true -- VideoPIP.mxml
	cp bin-release/VideoIO.swf bin-release/VideoIO-${VERSION}.swf
	cp bin-release/VideoIO45.swf bin-release/VideoIO45-${VERSION}.swf
	cp bin-release/VideoIO11.swf bin-release/VideoIO11-${VERSION}.swf
	cd bin-release; zip VideoIO-${VERSION}.zip VideoIO11.swf VideoIO45.swf VideoIO.swf

clean: 
	rm -f bin-debug/VideoIO.swf bin-debug/VideoIO45.swf bin-debug/VideoIO11.swf bin-release/VideoIO.swf bin-release/VideoIO45.swf bin-release/VideoIO11.swf bin-debug/VideoPIP.swf

dist: 
	tar -zcvf flash-videoio.tgz Makefile bin-release/AC_OETags.js VideoIO.as VideoPIP.mxml
	
