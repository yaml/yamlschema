#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: any-of
  cmnd: bin/ysc -t ysd.yaml -
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
  cmnd: bin/ysc -t ysd.yaml -
  stdi: |
    {
      "type": "object",
      "additionalProperties": false
    }
  want: |
    # Converted from JSON Schema
    .open: true

- name: open-object
  cmnd: bin/ysc -t ysd.yaml -
  stdi: |
    {
      "type": "object",
      "additionalProperties": true
    }
  want: |
    # Converted from JSON Schema
    .open: true
    +Str: +Any

- name: typed-wildcard
  cmnd: bin/ysc -t ysd.yaml -
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
    .open: true
    fixed?: +Int
    +Str: +Str 1+

done:
