#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: annotations-to-ysdc-yaml
  cmnd: bin/ysd -t ysd.yaml -
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
        },
        "profile": {
          "type": "object",
          "description": "Profile settings.",
          "properties": {
            "visible": {
              "type": "boolean"
            }
          }
        }
      },
      "required": ["name"]
    }
  want: |
    # Converted from JSON Schema
    .ysid: https://example.com/arrays.ysd.yaml
    .title: Arrays
    .desc: Arrays of strings and objects
    .open: true
    name:
      .type: +Str
      .title: Full name
      .desc: Display name.
    profile?:
      .desc: Profile settings.
      visible?: +Bool

- name: json-schema-id-to-ysdc
  cmnd: bin/ysd -f jsc -t ysdc -
  stdi: |
    {"$id":"https://example.com/device.schema.json","type":"object"}
  want: |
    .ysid: https://example.com/device.ysd.yaml
    .open: true

- name: json-schema-id-to-ysdc-json
  cmnd: bin/ysd -f jsc -t ysdc.json -C -
  stdi: |
    {"$id":"https://example.com/device.schema.json","type":"object"}
  want: |
    {".ysid":"https:\/\/example.com\/device.ysd.yaml",".open":true}

- name: ysid-is-first-in-canonical-output
  cmnd: bin/ysd -f ysd -t ysdc -
  stdi: |
    .title: Device
    name: +Str
    .ysid: https://example.com/device.ysd.yaml
  want: |
    .ysid: https://example.com/device.ysd.yaml
    .title: Device
    name: +Str

- name: ysid-query-and-fragment-to-json-schema
  cmnd: bin/ysd -t jsc -
  stdi: |
    .ysid: https://example.com/device.ysdc.yaml?view=full#root
    name: +Str
  want: |
    {
      "$id": "https://example.com/device.schema.json?view=full#root",
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "type": "object",
      "properties": {
        "name": {
          "type": "string"
        }
      },
      "required": [
        "name"
      ],
      "additionalProperties": false
    }

- name: extensionless-json-id-is-canonicalized
  cmnd: bin/ysd -N -
  stdi: |
    {"$id":"https://example.com/device","type":"object"}
  want: |
    {
      "$id": "https://example.com/device.schema.json",
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "type": "object"
    }

- name: extensionless-json-id-roundtrips
  cmnd: sh -c 'bin/ysd -Rq - && echo OK'
  stdi: |
    {"$id":"https://example.com/device","type":"object"}
  want: |
    OK

- name: legacy-json-id-is-rejected
  cmnd: |
    sh -c 'bin/ysd -t jsc - 2>&1 | perl -ne "print if \$. == 1"'
  stdi: |
    .json:
      $id: https://example.com/device.schema.json
  want: |
    ysd: unsupported yamlschema directive: .json; use .ysid

- name: invalid-ysid-is-rejected
  cmnd: |
    sh -c 'bin/ysd -t jsc - 2>&1 | perl -ne "print if \$. == 1"'
  stdi: |
    .ysid: 42
  want: |
    ysd: .ysid must be a non-empty string

- name: unsupported.json-schema-dialect
  cmnd: |
    sh -c 'printf "%s\n" \
      "{\"\$schema\":\"https://example.com/unsupported-draft\"}" |
      bin/ysd -t ysd.yaml - >/dev/null 2>&1; test $? -eq 2 && echo ok'
  want: |
    ok

done:
