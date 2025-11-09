# libuv-webserver

Pure C (or C++) webserver based on libuv and llhttp

Based on http://vimeo.com/24713213

See also https://github.com/mafintosh/turbo-net


## Warning

This is not a real server and never will be - purely experimental.


## Build

Requires CMake 3.10 or later.

    make

This will:
- Download llhttp v9.3.0 (release tarball with pre-generated C sources)
- Download libuv v1.51.0 (release tarball)
- Configure and build using CMake
- Create `webserver` and `webclient` executables

To test with AddressSanitizer and UndefinedBehaviorSanitizer:

    make sanitizer

## TODO

 - leverage threadpool
 - sysctl -w net.inet.tcp.msl=1000 on OS X
 - SO_REUSEPORT http://lwn.net/Articles/542629/
