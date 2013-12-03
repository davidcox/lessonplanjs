# => SRC FOLDER
toast 'src'

  # EXCLUDED FOLDERS (optional)
  # exclude: ['folder/to/exclude', 'another/folder/to/exclude', ... ]

  # => VENDORS (optional)
  vendors: [#'third-party/jquery-1.8.3.js',
            # 'common/third-party/knockout-2.2.0.js',
            # 'third-party/jquery-ui-1.9.2.custom.js',
            # 'third-party/jquery.tipsy.js',
            'third-party/jquery.qtip.min.js',
            # 'third-party/howler.min.js',
            'third-party/buzz.js'
          ]

  # => OPTIONS (optional, default values listed)
  # bare: false
  # packaging: false
  # expose: 'window'
  # minify: true

  # => HTTPFOLDER (optional), RELEASE / DEBUG (required)
  httpfolder: '/static/lessonplan'
  release: 'js/lessonplan.js'
  debug: 'js/lessonplan-debug.js'