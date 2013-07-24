# libuv-webserver

Pure C (or C++) webserver based on libuv and http-parser

Based on http://vimeo.com/24713213


## Warning

This is not a real server and never will be - purely experimental.

git ci -a -m "update to latest libuv + move to gyp for building"
## Build

    mkdir deps && cd deps
    git clone git://github.com/joyent/http-parser.git
    git clone git://github.com/joyent/libuv.git
    git clone https://chromium.googlesource.com/external/gyp.git
    cd ../
    ./configure
    make

## TODO

 - leverage threadpool
 - build using pure gyp
 - build as c++ 
 - signal(SIGPIPE, SIG_IGN)
