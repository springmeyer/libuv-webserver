# libuv-webserver

Pure C (or C++) webserver based on libuv and http-parser

Based on http://vimeo.com/24713213


## Warning

This is not a real server and never will be - purely experimental.

If you are interested in more robust server on top of libuv see [Haywire](https://github.com/kellabyte/Haywire).


## Build

    make

## TODO

 - leverage threadpool
 - signal(SIGPIPE, SIG_IGN)
 - sysctl -w net.inet.tcp.msl=1000 on OS X