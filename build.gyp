{
  'includes': [ 'common.gypi' ],
  'targets': [
    {
      'target_name': 'webserver',
      'type': 'executable',
      'sources': [
        'webserver.cc',
      ],
      'dependencies': [
        './deps/libuv/uv.gyp:libuv',
        './deps/http-parser/http_parser.gyp:http_parser'
      ],
    },
    {
      'target_name': 'webclient',
      'type': 'executable',
      'sources': [
        'webclient.cc',
      ],
      'dependencies': [
        './deps/libuv/uv.gyp:libuv',
        './deps/http-parser/http_parser.gyp:http_parser'
      ],
      'conditions': [
        [ 'OS=="mac"', {
          # linking Corefoundation is needed since certain OSX debugging tools
          # like Instruments require it for some features
          'libraries': [ '-framework CoreFoundation' ]
        }],
      ]
    }
  ],
}