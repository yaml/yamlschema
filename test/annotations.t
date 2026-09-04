#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: annotations-to-ysdc-yaml
  cmnd: bin/ysd -t ysd -
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
    --: Arrays
    -: Arrays of strings and objects
    .id: https://example.com/arrays.ysd.yaml
    .open: true

    name:
      --: Full name
      -: Display name.
      .type: +Str
    profile?:
      -: Profile settings.
      visible?: +Bool

- name: json-schema-id-to-ysdc
  cmnd: bin/ysd -f jsc -t ysdc -
  stdi: |
    {"$id":"https://example.com/device.schema.json","type":"object"}
  want: |
    .id: https://example.com/device.ysd.yaml
    .open: true

- name: json-schema-id-to-ysdc-json
  cmnd: bin/ysd -f jsc -t ysdc -J -C -
  stdi: |
    {"$id":"https://example.com/device.schema.json","type":"object"}
  want: |
    {".id":"https:\/\/example.com\/device.ysd.yaml",".open":true}

- name: id-is-first-in-canonical-output
  cmnd: bin/ysd -f ysd -t ysdc -
  stdi: |
    .title: Device
    name: +Str
    .id: https://example.com/device.ysd.yaml
  want: |
    .id: https://example.com/device.ysd.yaml
    .title: Device
    name: +Str

- name: preferred-ysd-document-annotations
  cmnd: bin/ysd -f ysd -t ysdc -
  stdi: |
    -: Device description
    name: +Str
    --: Device title
    .id: https://example.com/device.ysd.yaml
  want: |
    .id: https://example.com/device.ysd.yaml
    .title: Device title
    .desc: Device description
    name: +Str

- name: preferred-tight-title
  cmnd: bin/ysd -f ysd -t ysdc -J -C -
  stdi: |
    name: --"Full name" +Str -"Person name"
  want: |
    {"name":{".title":"Full name",".desc":"Person name",".type":"+Str"}}

- name: title-aliases-cannot-be-duplicated
  cmnd: |
    sh -c 'bin/ysd -f ysd -t ysdc - 2>&1 | perl -ne "print if \$. == 1"'
  stdi: |
    --: Device
    .title: Duplicate
  want: |
    ysd: duplicate yamlschema directive: .title in annotation aliases

- name: ysd-title-marker-is-rejected-in-ysdc
  cmnd: |
    sh -c 'bin/ysd -f ysdc -t jsc - 2>&1 | perl -ne "print if \$. == 1"'
  stdi: |
    --: Device
  want: |
    ysd: unsupported .ysdc directive: --; use .title

- name: id-query-and-fragment-to-json-schema
  cmnd: bin/ysd -t jsc -
  stdi: |
    .id: https://example.com/device.ysdc.yaml?view=full#root
    name: +Str
  want: |
    {
      "$id": "https://example.com/device.schema.json?view=full#root",
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "name"
      ],
      "properties": {
        "name": {
          "type": "string"
        }
      }
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

- name: draft4-json-id-to-ysd
  cmnd: bin/ysd -t ysd -
  stdi: |
    {
      "id": "https://example.com/device",
      "$schema": "http://json-schema.org/draft-04/schema#",
      "type": "object"
    }
  want: |
    # Converted from JSON Schema
    .id: https://example.com/device.ysd.yaml
    .open: true

- name: draft4-json-id-is-canonicalized
  cmnd: bin/ysd -N -
  stdi: |
    {
      "id": "https://example.com/device",
      "$schema": "http://json-schema.org/draft-04/schema#",
      "type": "object"
    }
  want: |
    {
      "$id": "https://example.com/device.schema.json",
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "type": "object"
    }

- name: draft4-json-id-roundtrips
  cmnd: sh -c 'bin/ysd -Rq - && echo OK'
  stdi: |
    {
      "id": "https://example.com/device",
      "$schema": "http://json-schema.org/draft-04/schema#",
      "type": "object"
    }
  want: |
    OK

- name: modern-json-id-takes-precedence
  cmnd: bin/ysd -N -
  stdi: |
    {
      "id": "https://example.com/legacy",
      "$id": "https://example.com/modern",
      "$schema": "http://json-schema.org/draft-04/schema#",
      "type": "object"
    }
  want: |
    {
      "$id": "https://example.com/modern.schema.json",
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "type": "object"
    }

- name: legacy-json-id-is-rejected
  cmnd: |
    sh -c 'bin/ysd -t jsc - 2>&1 | perl -ne "print if \$. == 1"'
  stdi: |
    .json:
      $id: https://example.com/device.schema.json
  want: |
    ysd: unsupported yamlschema directive: .json; use .id

- name: invalid-id-is-rejected
  cmnd: |
    sh -c 'bin/ysd -t jsc - 2>&1 | perl -ne "print if \$. == 1"'
  stdi: |
    .id: 42
  want: |
    ysd: .id must be a non-empty string

- name: old-ysid-directive-is-rejected
  cmnd: |
    sh -c 'bin/ysd -t jsc - 2>&1 | perl -ne "print if \$. == 1"'
  stdi: |
    .ysid: https://example.com/device.ysd.yaml
  want: |
    ysd: unsupported yamlschema directive: .ysid; use .id

- name: unsupported.json-schema-dialect
  cmnd: |
    sh -c 'printf "%s\n" \
      "{\"\$schema\":\"https://example.com/unsupported-draft\"}" |
      bin/ysd -t ysd - >/dev/null 2>&1; test $? -eq 1 && echo ok'
  want: |
    ok

done:
