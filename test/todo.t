#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: any-of
  cmnd: bin/ysd -t ysd -
  stdi: |
    {
      "properties": {
        "auth": {
          "anyOf": [
            {"type": "object", "properties": {"token": {"type": "string"}}},
            {"type": "object", "properties": {"api_key": {"type": "string"}}}
          ]
        }
      },
      "required": ["auth"]
    }
  want: |
    # Converted from JSON Schema
    .open: true

    auth:
      .any:
      - token?: +Str
      - api_key?: +Str

- name: closed-object
  cmnd: bin/ysd -t ysd -
  stdi: |
    {
      "type": "object",
      "additionalProperties": false
    }
  want: |
    # Converted from JSON Schema
    {}

- name: open-object
  cmnd: bin/ysd -t ysd -
  stdi: |
    {
      "type": "object",
      "additionalProperties": true
    }
  want: |
    # Converted from JSON Schema
    .open: true

- name: typed-wildcard
  cmnd: bin/ysd -t ysd -
  stdi: |
    {
      "type": "object",
      "properties": {
        "fixed": {"type": "integer"}
      },
      "additionalProperties": {
        "type": "string",
        "minLength": 1
      }
    }
  want: |
    # Converted from JSON Schema
    fixed?: +Int
    +Str: +Str 1+

done:
