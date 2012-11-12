#include <cstdio>
#include <cstdlib>
#include <cassert>
#include "libuv/include/uv.h"
#include "http-parser/http_parser.h"

// stl
#include <string>
#include <sstream>

#define CHECK(r, msg) \
  if (r) { \
    uv_err_t err = uv_last_error(uv_loop); \
    fprintf(stderr, "%s: %s\n", msg, uv_strerror(err)); \
    exit(1); \
  }
#define UVERR(err, msg) fprintf(stderr, "%s: %s\n", msg, uv_strerror(err))
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
  LOGF("[ %5d ] connection closed", client->request_num);
  free(client);
}

uv_buf_t on_alloc(uv_handle_t* client, size_t suggested_size) {
  uv_buf_t buf;
  buf.base = (char *)malloc(suggested_size);
  buf.len = suggested_size;
  return buf;
}

void on_read(uv_stream_t* tcp, ssize_t nread, uv_buf_t buf) {
  size_t parsed;

  client_t* client = (client_t*) tcp->data;
  LOGF("[ %5d ] on read", client->request_num);


  if (nread >= 0) {
    parsed = http_parser_execute(
        &client->parser, &parser_settings, buf.base, nread);
    if (parsed < nread) {
      LOG_ERROR("parse error");
      uv_close((uv_handle_t*) &client->handle, on_close);
    }
  } else {
    uv_err_t err = uv_last_error(uv_loop);
    if (err.code != UV_EOF) {
      UVERR(err, "read");
    }
  }
  free(buf.base);
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

  uv_read_start((uv_stream_t*)&client->handle, on_alloc, on_read);
}

void after_write(uv_write_t* req, int status) {
  CHECK(status, "write");
  uv_close((uv_handle_t*)req->handle, on_close);
}

typedef struct {
    uv_work_t request;
    client_t* client;
    bool error;
    std::string result;
} render_baton_t;

void render(uv_work_t* req) {
   render_baton_t *closure = static_cast<render_baton_t *>(req->data);
   client_t* client = (client_t*) closure->client;

   LOGF("[ %5d ] render", client->request_num);
   closure->result = "hello world";
}

void after_render(uv_work_t* req) {
  render_baton_t *closure = static_cast<render_baton_t *>(req->data);
  client_t* client = (client_t*) closure->client;
  static uv_buf_t resbuf;

  LOGF("[ %5d ] after render", client->request_num);

  std::ostringstream rep;
  int data_size = closure->result.size();
  rep << "HTTP/1.1 200 OK\r\n"
      << "Content-Type: text/plain\r\n"
      //<< "Connection: keep-alive\r\n"
      //<< "Connection: close\r\n"
      //<< "Transfer-Encoding: chunked\r\n"
      << "Content-Length: " << data_size << "\r\n"
      << "\r\n";
  int header_size = rep.str().size();
  rep << closure->result;
  resbuf.base = (char *)rep.str().c_str();
  resbuf.len = closure->result.size() + header_size;

  int r = uv_write(&client->write_req,
          (uv_stream_t*)&client->handle,
          &resbuf,
          1,
          after_write);
  CHECK(r, "write buff");
}

int on_message_complete(http_parser* parser) {
  client_t* client = (client_t*) parser->data;
  
  LOGF("[ %5d ] on_message_complete", client->request_num);
  render_baton_t *closure = new render_baton_t();
  closure->request.data = closure;
  closure->client = client;
  closure->error = false;
  uv_queue_work(uv_default_loop(), &closure->request, render, after_render);

  return 0;
}


int main() {
  parser_settings.on_message_complete = on_message_complete;
  uv_loop = uv_default_loop();
  int r = uv_tcp_init(uv_loop, &server);
  CHECK(r, "bind");
  struct sockaddr_in address = uv_ip4_addr("0.0.0.0", 8000);
  r = uv_tcp_bind(&server, address);
  CHECK(r, "bind");
  uv_listen((uv_stream_t*)&server, 128, on_connect);
  LOG("listening on port 8000");
  uv_run(uv_loop);
}
