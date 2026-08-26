#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: default
  cmnd: bin/ysd -t ysd -
  stdi: |
    {
      "properties": {
        "port": {"type": "integer", "default": 8080},
        "ratio": {"type": "number", "default": 1.5},
        "create": {"type": "boolean", "default": true},
        "host": {"type": "string", "default": "localhost"},
        "word": {"type": "string", "default": "8gcr"},
        "booleanWord": {"type": "string", "default": "true"},
        "label": {"type": "string", "default": "hello world"},
        "quoted": {"type": "string", "default": "say \"hi\""},
        "logLevel": {
          "type": "string",
          "enum": ["debug", "info", "warning", "error", "fatal"],
          "default": "info",
          "description": "Component log level"
        }
      },
      "required": [
        "port", "ratio", "create", "host", "word",
        "booleanWord", "label", "quoted", "logLevel"
      ]
    }
  want: |
    # Converted from JSON Schema
    .open: true
    port: +Int =8080
    ratio: +Num =1.5
    create: +Bool =true
    host: +Str =localhost
    word: +Str =8gcr
    booleanWord: +Str ="true"
    label: +Str ="hello world"
    quoted:
      .type: +Str
      .init: say "hi"
    logLevel: +Str [debug, =info, warning, error, fatal] "Component log level"

done:
