
all: ./build server client

./build:
	./configure

client:
	make -C ./build/ webclient
	cp ./build/out/Release/webclient ./webclient

server:
	make -C ./build/ webserver
	cp ./build/out/Release/webserver ./webserver

distclean:
	rm -rf ./build

test:
	./build/out/Release/webserver & ./build/out/Release/webclient

clean:
	rm -rf ./build/out/Release/obj.target/webserver/
	rm -f ./build/out/Release/webserver
	rm -f ./webserver
	rm -rf ./build/out/Release/obj.target/webclient/
	rm -f ./build/out/Release/webclient
	rm -f ./webclient

.PHONY: test