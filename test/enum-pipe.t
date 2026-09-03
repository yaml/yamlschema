#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: compact-enum
  cmnd: bin/ysd -t ysd -
  stdi: |
    {
      "properties": {
        "role": {"enum": ["admin", "user", "guest"]},
        "level": {"enum": ["LOW", "MED", "HIGH"]}
      },
      "required": ["role", "level"]
    }
  want: |
    # Converted from JSON Schema
    .open: true
    role: +Str [admin, user, guest]
    level: +Str [LOW, MED, HIGH]

- name: string-compact-enum
  cmnd: bin/ysd -t ysd -
  stdi: |
    {
      "properties": {
        "type": {"type": "string", "enum": ["8p8c", "8p6c", "8p4c"]}
      }
    }
  want: |
    # Converted from JSON Schema
    .open: true
    type?: +Str [8p8c, 8p6c, 8p4c]

- name: dotted-compact-enum
  cmnd: bin/ysd -t ysd -
  stdi: |
    {
      "properties": {
        "type": {
          "type": "string",
          "enum": ["ieee802.11a", "1.6tbase-cr8"]
        }
      }
    }
  want: |
    # Converted from JSON Schema
    .open: true
    type?: +Str [ieee802.11a, 1.6tbase-cr8]

- name: list-compact-enum
  cmnd: bin/ysd -t ysd -
  stdi: |
    {
      "type": "object",
      "properties": {
        "tags": {
          "type": "array",
          "items": {
            "type": "string",
            "enum": ["good", "bad", "ugly"]
          }
        }
      }
    }
  want: |
    # Converted from JSON Schema
    .open: true
    tags?: +Str[] [good, bad, ugly]

- name: list-compact-enum-default
  cmnd: bin/ysd -t ysd -
  stdi: |
    {
      "type": "object",
      "properties": {
        "tags": {
          "type": "array",
          "default": "good",
          "items": {
            "type": "string",
            "enum": ["good", "bad", "ugly"]
          }
        }
      }
    }
  want: |
    # Converted from JSON Schema
    .open: true
    tags?: +Str[] [=good, bad, ugly]

- name: compact-enum-default-expansion
  cmnd: bin/ysd -t ysdc -J -
  stdi: |
    logLevel?: +Str [debug,=info,warning,error,fatal]
      --"Log level for all components"
    count?: +Int [1,=2,3]
  want: |
    {
      "logLevel?": {
        ".desc": "Log level for all components",
        ".type": "+Str",
        ".enum": [
          "debug",
          "info",
          "warning",
          "error",
          "fatal"
        ],
        ".init": "info"
      },
      "count?": {
        ".type": "+Int",
        ".enum": [
          1,
          2,
          3
        ],
        ".init": 2
      }
    }

- name: reject-multiple-compact-enum-defaults
  cmnd: |
    sh -c 'bin/ysd -t ysdc -J -C - 2>&1 | sed -n 1p'
  stdi: |
    level: +Str [=debug,=info,error]
  want: |
    ysd: compact enum can mark only one default

done:
