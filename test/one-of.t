#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: one-of-to-oneof
  cmnd: bin/ysc -t ysd.yaml -
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
      .oneof:
      - token: +Str
      - api_key: +Str

done:
