#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: one-of-to.pick
  cmnd: bin/ysc -t ysc.yaml -
  stdi: |
    {
      "properties": {
        "auth": {
          "oneOf": [
            {
              "type": "object",
              "properties": {
                "token": {"type": "string"}
              },
              "required": ["token"]
            },
            {
              "type": "object",
              "properties": {
                "api_key": {"type": "string"}
              },
              "required": ["api_key"]
            }
          ]
        }
      },
      "required": ["auth"]
    }
  want: |
    auth:
      .pick:
      - token: +Str
      - api_key: +Str

done:
