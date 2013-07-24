#include <cstdio>
#include <cstdlib>
#include <cassert>
#include "uv.h"
#include "http_parser.h"

// stl
#include <string>
#include <sstream>

#define CHECK(status, msg) \
  if (status != 0) { \
    fprintf(stderr, "%s: %s\n", msg, uv_err_name(status)); \
    exit(1); \
  }
#define UVERR(err, msg) fprintf(stderr, "%s: %s\n", msg, uv_err_name(err))
#define LOG_ERROR(msg) puts(msg);
#define LOG(msg) puts(msg);
#define LOGF(fmt, params...) printf(fmt "\n", params);

static int request_num = 1;
static uv_loop_t* uv_loop;
static uv_tcp_t server;
static http_parser_settings parser_settings;

typedef struct {
  uv_tcp_t handle;
  http_parser parser;
  uv_write_t write_req;
  int request_num;
} client_t;

void on_close(uv_handle_t* handle) {
  client_t* client = (client_t*) handle->data;
  LOGF("[ %5d ] connection closed\n\n", client->request_num);
  free(client);
}

uv_buf_t alloc_buffer(uv_handle_t * /*handle*/, size_t suggested_size) {
    return uv_buf_init((char*) malloc(suggested_size), suggested_size);
}

void on_read(uv_stream_t* tcp, ssize_t nread, uv_buf_t buf) {
  ssize_t parsed;
  LOGF("on read: %ld",nread);
  client_t* client = (client_t*) tcp->data;
  if (nread >= 0) {
    parsed = (ssize_t)http_parser_execute(
        &client->parser, &parser_settings, buf.base, nread);
    if (parsed < nread) {
      LOG_ERROR("parse error");
      uv_close((uv_handle_t*) &client->handle, on_close);
    }
  } else {
    if (nread != UV_EOF) {
      UVERR(nread, "read");
    }
    uv_close((uv_handle_t*) &client->handle, on_close);
  }
  free(buf.base);
}

typedef struct {
    uv_work_t request;
    client_t* client;
    bool error;
    std::string result;
} render_baton_t;

void after_write(uv_write_t* req, int status) {
  CHECK(status, "write");
  if (!uv_is_closing((uv_handle_t*)req->handle))
  {
      // free render_baton_t
      render_baton_t *closure = static_cast<render_baton_t *>(req->data);
      delete closure;
      uv_close((uv_handle_t*)req->handle, on_close);
  }
}

void render(uv_work_t* req) {
   render_baton_t *closure = static_cast<render_baton_t *>(req->data);
   client_t* client = (client_t*) closure->client;

   LOGF("[ %5d ] render", client->request_num);
   closure->result = "hello world";
}

void after_render(uv_work_t* req) {
  render_baton_t *closure = static_cast<render_baton_t *>(req->data);
  client_t* client = (client_t*) closure->client;

  LOGF("[ %5d ] after render", client->request_num);

  std::ostringstream rep;
  rep << "HTTP/1.1 200 OK\r\n"
      << "Content-Type: text/plain\r\n"
      << "Connection: keep-alive\r\n"
      //<< "Connection: close\r\n"
      //<< "Transfer-Encoding: chunked\r\n"
      << "Content-Length: " << closure->result.size() << "\r\n"
      << "\r\n";
  rep << closure->result;
  std::string res = rep.str();
  uv_buf_t resbuf;
  resbuf.base = (char *)res.c_str();
  resbuf.len = res.size();

  client->write_req.data = closure;

  // https://github.com/joyent/libuv/issues/344
  int r = uv_write(&client->write_req,
          (uv_stream_t*)&client->handle,
          &resbuf,
          1,
          after_write);
  CHECK(r, "write buff");
}

int on_message_begin(http_parser* /*parser*/) {
  printf("\n***MESSAGE BEGIN***\n\n");
  return 0;
}

int on_headers_complete(http_parser* /*parser*/) {
  printf("\n***HEADERS COMPLETE***\n\n");
  return 0;
}

int on_url(http_parser* /*parser*/, const char* at, size_t length) {
  printf("Url: %.*s\n", (int)length, at);
  return 0;
}

int on_header_field(http_parser* /*parser*/, const char* at, size_t length) {
  printf("Header field: %.*s\n", (int)length, at);
  return 0;
}

int on_header_value(http_parser* /*parser*/, const char* at, size_t length) {
  printf("Header value: %.*s\n", (int)length, at);
  return 0;
}

int on_body(http_parser* /*parser*/, const char* at, size_t length) {
  printf("Body: %.*s\n", (int)length, at);
  return 0;
}
int on_message_complete(http_parser* parser) {
  printf("\n***MESSAGE COMPLETE***\n\n");

  client_t* client = (client_t*) parser->data;
  
  LOGF("[ %5d ] on_message_complete", client->request_num);
  render_baton_t *closure = new render_baton_t();
  closure->request.data = closure;
  closure->client = client;
  closure->error = false;
  int status = uv_queue_work(uv_default_loop(),
                 &closure->request,
                 render,
                 (uv_after_work_cb)after_render);
  CHECK(status, "uv_queue_work");
  assert(status == 0);

  return 0;
}


void on_connect(uv_stream_t* server_handle, int status) {
  CHECK(status, "connect");
  assert((uv_tcp_t*)server_handle == &server);

  client_t* client = (client_t*)malloc(sizeof(client_t));
  client->request_num = request_num;
  request_num++;

  LOGF("[ %5d ] new connection", request_num);

  uv_tcp_init(uv_loop, &client->handle);
  http_parser_init(&client->parser, HTTP_REQUEST);

  client->parser.data = client;
  client->handle.data = client;

  int r = uv_accept(server_handle, (uv_stream_t*)&client->handle);
  CHECK(r, "accept");

  uv_read_start((uv_stream_t*)&client->handle, alloc_buffer, on_read);
}

#define MAX_WRITE_HANDLES 1000

int main() {
  //setenv("UV_THREADPOOL_SIZE","100",1);
  parser_settings.on_message_begin = on_message_begin;
  parser_settings.on_url = on_url;
  parser_settings.on_header_field = on_header_field;
  parser_settings.on_header_value = on_header_value;
  parser_settings.on_headers_complete = on_headers_complete;
  parser_settings.on_body = on_body;
  parser_settings.on_message_complete = on_message_complete;
  uv_loop = uv_default_loop();
  int r = uv_tcp_init(uv_loop, &server);
  CHECK(r, "tcp_init");
  r = uv_tcp_keepalive(&server,1,60);
  CHECK(r, "tcp_keepalive");
  struct sockaddr_in address = uv_ip4_addr("0.0.0.0", 8000);
  r = uv_tcp_bind(&server, address);
  CHECK(r, "tcp_bind");
  uv_listen((uv_stream_t*)&server, MAX_WRITE_HANDLES, on_connect);
  LOG("listening on port 8000");
  uv_run(uv_loop,UV_RUN_DEFAULT);
}
