#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: annotations-to-ysc-yaml
  cmnd: bin/ysc -t ysc.yaml -
  stdi: |
    {
      "$id": "https://example.com/arrays.schema.json",
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "title": "Arrays",
      "description": "Arrays of strings and objects",
      "properties": {
        "name": {
          "type": "string",
          "title": "Full name",
          "description": "Display name."
        }
      },
      "required": ["name"]
    }
  want: |
    -Name: Arrays
    -desc: Arrays of strings and objects
    name:
      -type: +Str
      -Name: Full name
      -desc: Display name.
    -json:
      $id: https://example.com/arrays.schema.json

- name: unsupported-json-schema-dialect
  cmnd: |
    sh -c 'printf "%s%s" \
      "eyIkc2NoZW1hIjoiaHR0cDovL2pzb24tc2NoZW1hLm9yZy" \
      "9kcmFmdC0wNy9zY2hlbWEjIn0=" |
      base64 -d |
      bin/ysc -t ysc.yaml - >/dev/null 2>&1; test $? -eq 2 && echo ok'
  want: |
    ok

done:
