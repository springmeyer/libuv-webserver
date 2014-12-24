
all: ./build ./webclient ./webserver

./deps/http-parser:
	git clone --depth 1 git://github.com/joyent/http-parser.git ./deps/http-parser

./deps/libuv:
	git clone --depth 1 git://github.com/libuv/libuv.git ./deps/libuv

./deps/gyp:
	git clone --depth 1 https://chromium.googlesource.com/external/gyp.git ./deps/gyp
	# TODO: patch no longer applies
	#cd ./deps/gyp && curl -o issue_292.diff https://codereview.chromium.org/download/issue14887003_1_2.diff && patch pylib/gyp/xcode_emulation.py issue_292.diff

./build: ./deps/gyp ./deps/libuv ./deps/http-parser
	deps/gyp/gyp --depth=. -Goutput_dir=./out -Icommon.gypi --generator-output=./build -Dlibrary=static_library -Duv_library=static_library -f make -Dclang=1

./webclient: webclient.cc
	make -C ./build/ webclient
	cp ./build/out/Release/webclient ./webclient

./webserver: webserver.cc
	make -C ./build/ webserver
	cp ./build/out/Release/webserver ./webserver

distclean:
	make clean
	rm -rf ./build

test:
	./build/out/Release/webserver & ./build/out/Release/webclient && killall webserver
	#./build/out/Release/webserver & wrk -d10 -t24 -c24 --latency http://127.0.0.1:8000

clean:
	rm -rf ./build/out/Release/obj.target/webserver/
	rm -f ./build/out/Release/webserver
	rm -f ./webserver
	rm -rf ./build/out/Release/obj.target/webclient/
	rm -f ./build/out/Release/webclient
	rm -f ./webclient

.PHONY: test
