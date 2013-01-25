uname_S := $(shell sh -c 'uname -s 2>/dev/null || echo not')

ifeq (Darwin,$(uname_S))
LDFLAGS=-F/ -framework CoreFoundation -F/ -framework CoreServices
endif

ifeq (Linux,$(uname_S))
LDFLAGS+=-pthread -lrt
endif

ifneq (,$(findstring MINGW,$(uname_S)))
LDFLAGS+=-lws2_32 -lpsapi -liphlpapi
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
