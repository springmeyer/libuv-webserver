
all: server

server:
	V=1 make -C ./build/ webserver

distclean:
	rm -rf ./build

clean:
	rm -rf ./build/out/Release/obj.target/webserver/
	rm -rf ./build/out/Release/webserver
