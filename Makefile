webserver: webserver.cc libuv/libuv.a http-parser/http_parser.o
	$(CXX) -I libuv/include -O2 -g\
    -F/ -framework CoreFoundation -F/ -framework CoreServices \
    -o webserver webserver.cc \
    libuv/libuv.a http-parser/http_parser.o

libuv/libuv.a:
	$(MAKE) -C libuv

http-parser/http_parser.o:
	$(MAKE) -C http-parser http_parser.o

clean:
	rm libuv/libuv.a
	rm http-parser/http_parser.o
	rm webserver
