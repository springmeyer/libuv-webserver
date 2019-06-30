#include <cstdio>
#include <cstdlib>
#include <cassert>
#include "uv.h"
#include "http_parser.h"
// posix only
#include <sys/resource.h> // setrlimit, getrlimit
#include <string>
#include <iostream>
#include <sstream>


static uv_loop_t* uv_loop;
static http_parser_settings req_parser_settings;
static int request_num = 1;
// http://serverfault.com/questions/145907/does-mac-os-x-throttle-the-rate-of-socket-creation
//static int req_num = 16000;
static int req_num = 100;

#ifdef DEBUG
#define CHECK(status, msg) \
  if (status != 0) { \
    fprintf(stderr, "%s: %s\n", msg, uv_err_name(status)); \
    exit(1); \
  }
#define UVERR(err, msg) fprintf(stderr, "%s: %s\n", msg, uv_err_name(err))
#define LOG_ERROR(msg) puts(msg);
#define LOG(msg) puts(msg);
#define LOGF(...) printf(__VA_ARGS__);
#else
#define CHECK(status, msg)
#define UVERR(err, msg)
#define LOG_ERROR(msg)
#define LOG(msg)
#define LOGF(...)
#endif

struct client_t {
  client_t() :
    body() {}
  http_parser parser;
  int request_num;
  uv_tcp_t tcp;
  uv_connect_t connect_req;
  uv_shutdown_t shutdown_req;
  uv_write_t write_req;
  std::stringstream body;
};

void alloc_cb(uv_handle_t * /*handle*/, size_t suggested_size, uv_buf_t* buf) {
    *buf = uv_buf_init((char*) malloc(suggested_size), suggested_size);
}

void on_close(uv_handle_t* handle) {
  client_t* client = (client_t*) handle->data;
  LOG("on close")
  //client->tcp.data = NULL;
  delete client;
}

void on_read(uv_stream_t *tcp, ssize_t nread, const uv_buf_t * buf) {
    ssize_t parsed;
    client_t* client = (client_t*) tcp->data;
    LOGF("on read: %ld\n",nread);
    LOGF("on read buf.size: %ld\n",buf->len);
    if (nread > 0) {
        http_parser * parser = &client->parser;
        /*if (parser->http_errno == HPE_PAUSED) {
             LOG("PAUSED");
             return ;
        }*/
        parsed = (ssize_t)http_parser_execute(parser, &req_parser_settings, buf->base, nread);
        if (parser->upgrade) {
            LOG("We do not support upgrades yet")
        }
        else if (parsed != nread) {
          LOGF("parsed incomplete data: %ld/%ld bytes parsed\n", parsed, nread);
          LOGF("\n*** %s ***\n",
              http_errno_description(HTTP_PARSER_ERRNO(parser)));
        }
    } else {
        if (nread != UV_EOF) {
          UVERR(nread, "read");
        }
    }
    // if not keepalive
    //if (!http_should_keep_alive(parser)) {
        //if (!uv_is_closing((uv_handle_t*)tcp))
            //uv_close((uv_handle_t*)tcp, on_close);
    //}
    free(buf->base);
}

void after_write(uv_write_t* /*req*/, int status) {
    LOG("after write")
    CHECK(status, "write");
}

void on_connect(uv_connect_t *req, int status) {
    client_t *client = (client_t*)req->handle->data;
    if (status < 0) {
        fprintf(stderr, "connect failed error %s\n", uv_err_name(status));
        uv_close((uv_handle_t*)req->handle, on_close);
        return;
    }
  
    client->request_num++;

    LOGF("[ %5d ] new connection\n", request_num);

    uv_buf_t resbuf;
    std::string res =
         "GET /hello HTTP/1.1\r\n"
         "Host: 0.0.0.0=8000\r\n"
         "User-Agent: webclient.c\r\n"
         "Keep-Alive: 100\r\n"
         "Connection: keep-alive\r\n"
         "\r\n";
    resbuf.base = (char *)res.c_str();
    resbuf.len = res.size();

    int rr = uv_read_start(req->handle, alloc_cb, on_read);
    CHECK(rr, "bind");
    
    int r = uv_write(&client->write_req,
            req->handle,
            &resbuf,
            1,
            after_write);
    CHECK(r, "bind");
}

int on_message_begin(http_parser* /*parser*/) {
  LOGF("\n***MESSAGE BEGIN***\n");
  return 0;
}

int on_headers_complete(http_parser* /*parser*/) {
  LOGF("\n***HEADERS COMPLETE***\n");
  return 0;
}

int on_url(http_parser* /*parser*/, const char* at, size_t length) {
  LOGF("Url: %.*s\n", (int)length, at);
  return 0;
}

int on_header_field(http_parser* /*parser*/, const char* at, size_t length) {
  LOGF("Header field: %.*s\n", (int)length, at);
  return 0;
}

int on_header_value(http_parser* /*parser*/, const char* at, size_t length) {
  LOGF("Header value: %.*s\n", (int)length, at);
  return 0;
}

int on_body(http_parser* parser, const char* at, size_t length) {
  LOGF("Body: %d\n", (int)length);
  client_t *client = (client_t*)parser->data;
  if (at && client)
  {
      client->body << std::string(at,length);
  }

  //fprintf("Body: %.*s\n", (int)length, at);
  /*if (http_body_is_final(parser)) {
      LOG("body is final!")
      std::cerr << "on-body len: " << length << "\n";
  } else {
      LOG("body not final\n")
      std::cerr << "non final on-body len: " << length << "\n";
  }*/

  return 0;
}

int on_message_complete(http_parser* parser) {
  LOGF("\n***MESSAGE COMPLETE***\n");
  client_t *client = (client_t*)parser->data;
  ssize_t total_len = client->body.str().size();
  LOGF("total length parsed: %ld\n",total_len)
  if (http_should_keep_alive(parser)) {
      LOGF("\n***SHOULD CLOSE keepalive HERE \n");
      uv_stream_t* tcp = (uv_stream_t*)&client->tcp;
      uv_close((uv_handle_t*)tcp, on_close);
  }
  return 0;
}

void on_resolved(uv_getaddrinfo_t *req, int status, struct addrinfo *res) {
    if (status == -1) {
        fprintf(stderr, "getaddrinfo callback error %s\n", uv_err_name(status));
        return;
    }

    char addr[17] = {'\0'};
    uv_ip4_name((struct sockaddr_in*) res->ai_addr, addr, 16);
    LOGF("resolved to %s\n", addr);
    uv_freeaddrinfo(res);
    struct sockaddr_in dest;
    int r = uv_ip4_addr(addr, 8000, &dest);
    CHECK(r, "ip4_addr");

    for (int i=0;i<req_num;++i) {
        client_t* client = new client_t();
        client->request_num = request_num;
        client->tcp.data = client;
        http_parser_init(&client->parser, HTTP_RESPONSE);
        client->parser.data = client;
        r = uv_tcp_init(uv_loop, &client->tcp);
        CHECK(r, "tcp_init");
        r = uv_tcp_keepalive(&client->tcp,1,60);
        CHECK(r, "tcp_keepalive");
        r = uv_tcp_connect(&client->connect_req, &client->tcp, (const struct sockaddr*)&dest, on_connect);
        CHECK(r, "tcp_connect");
    }
    LOG("listening on port 8000");
}

int main() {
    // mainly for osx, bump up ulimit
    struct rlimit limit;
    getrlimit(RLIMIT_NOFILE,&limit);
    LOGF("current ulimit: %lld\n",limit.rlim_cur);
    req_parser_settings.on_message_begin = on_message_begin;
    req_parser_settings.on_url = on_url;
    req_parser_settings.on_header_field = on_header_field;
    req_parser_settings.on_header_value = on_header_value;
    req_parser_settings.on_headers_complete = on_headers_complete;
    req_parser_settings.on_body = on_body;
    req_parser_settings.on_message_complete = on_message_complete;
    struct addrinfo hints;
    hints.ai_family = PF_INET;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_protocol = IPPROTO_TCP;
    hints.ai_flags = 0;
    uv_loop = uv_default_loop();
    uv_getaddrinfo_t req;
    int r = uv_getaddrinfo(uv_loop, &req, on_resolved, "localhost", "8000", &hints);
    uv_run(uv_loop,UV_RUN_DEFAULT);
}
