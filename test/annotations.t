#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: annotations-to-ysc-yaml
  cmnd: bin/ysc -t ysd.yaml -
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
    .title: Arrays
    .desc: Arrays of strings and objects
    name:
      .type: +Str
      .title: Full name
      .desc: Display name.
    .json:
      $id: https://example.com/arrays.schema.json

- name: unsupported.json-schema-dialect
  cmnd: |
    sh -c 'printf "%s\n" \
      "{\"\$schema\":\"https://example.com/unsupported-draft\"}" |
      bin/ysc -t ysd.yaml - >/dev/null 2>&1; test $? -eq 2 && echo ok'
  want: |
    ok

done:
