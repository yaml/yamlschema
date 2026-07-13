#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: todo
  cmnd: bin/ysc -t ysc.yaml -
  stdi: |
    {
      "properties": {
        "auth": {
          "oneOf": [
            {"type": "object", "properties": {"token": {"type": "string"}}},
            {"type": "object", "properties": {"api_key": {"type": "string"}}}
          ]
        }
      },
      "required": ["auth"]
    }
  want: |
    auth:
      # TODO: oneOf

- name: additional-properties
  cmnd: bin/ysc -t ysc.yaml -
  stdi: |
    {
      "type": "object",
      "additionalProperties": false
    }
  want: |
    -additionalProperties: false

done:
