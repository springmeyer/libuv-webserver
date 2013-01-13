UNAME := $(shell uname)

ifeq ($(UNAME), Darwin)
LDFLAGS=-F/ -framework CoreFoundation -F/ -framework CoreServices
endif

ifeq ($(UNAME), Linux)
LDFLAGS+=-pthread -lrt
endif

CFLAGS=-O2 -g -DNDEBUG -Wall

webserver: webserver.cc libuv/libuv.a http-parser/http_parser.o
	$(CXX) -I libuv/include \
    $(CFLAGS) \
    -o webserver webserver.cc \
    libuv/libuv.a http-parser/http_parser.o \
    $(LDFLAGS)

libuv/libuv.a:
	$(MAKE) -C libuv

http-parser/http_parser.o:
	$(MAKE) -C http-parser http_parser.o

clean:
	rm libuv/libuv.a
	rm http-parser/http_parser.o
	rm webserver
