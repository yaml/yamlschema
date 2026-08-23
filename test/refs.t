#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: refs
  cmnd: bin/ysd -t ysd.yaml -
  stdi: |
    {
      "$defs": {
        "port":  {"type": "integer", "minimum": 1, "maximum": 65535},
        "email": {"type": "string",  "pattern": "^\\S+@\\S+$"}
      },
      "properties": {
        "host":  {"type": "string"},
        "port":  {"$ref": "#/$defs/port"},
        "admin": {"$ref": "#/$defs/email"}
      },
      "required": ["host", "port"]
    }
  want: |
    # Converted from JSON Schema
    .open: true

    +port: +Int 1..65535

    +email: +Str =~"\S+@\S+"

    host: +Str
    port: +port
    admin?: +email

- name: draft-07-definitions-refs
  cmnd: bin/ysd -t ysd.yaml -
  stdi: |
    {
      "$schema": "http://json-schema.org/draft-07/schema#",
      "definitions": {
        "port":  {"type": "integer", "minimum": 1, "maximum": 65535},
        "email": {"type": "string",  "pattern": "^\\S+@\\S+$"}
      },
      "properties": {
        "host":  {"type": "string"},
        "port":  {"$ref": "#/definitions/port"},
        "admin": {"$ref": "#/definitions/email"}
      },
      "required": ["host", "port"]
    }
  want: |
    # Converted from JSON Schema
    .open: true

    +port: +Int 1..65535

    +email: +Str =~"\S+@\S+"

    host: +Str
    port: +port
    admin?: +email

- name: external-refs-to-ysd
  cmnd: bin/ysd -f jsc -t ysd -
  stdi: |
    {
      "type": "object",
      "properties": {
        "absolute": {"$ref": "https://example.com/profile.schema.json"},
        "relative": {"$ref": "profile.schema.json"},
        "anchor": {"$ref": "#profile"},
        "pointer": {"$ref": "#/properties/name"},
        "array": {
          "type": "array",
          "items": {"$ref": "#ProductSchema"}
        },
        "empty": {"$ref": ""},
        "unsafe": {"$ref": "https://example.com/a)b schema.json"},
        "annotated": {
          "$ref": "https://x.io/p.json",
          "description": "External profile"
        }
      },
      "additionalProperties": false
    }
  want: |
    # Converted from JSON Schema
    absolute?: +Ref(https://example.com/profile.schema.json)
    relative?: +Ref(profile.schema.json)
    anchor?: +Ref(#profile)
    pointer?: +Ref(#/properties/name)
    array?: +Ref(#ProductSchema)[]
    empty?:
      .xref: ''
    unsafe?:
      .xref: https://example.com/a)b schema.json
    annotated?: +Ref(https://x.io/p.json) "External profile"

- name: external-refs-to-json-schema
  cmnd: bin/ysd -f ysd -t jsc -
  stdi: |
    absolute?: +Ref(https://example.com/profile.schema.json)
    relative?: +Ref(profile.schema.json)
    anchor?: +Ref(#profile)
    pointer?: +Ref(#/properties/name)
    array?: +Ref(#ProductSchema)[]
    empty?:
      .xref: ''
    unsafe?:
      .xref: https://example.com/a)b schema.json
    annotated?:
      .xref: https://example.com/profile.schema.json
      .desc: External profile
  want: |
    {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "type": "object",
      "properties": {
        "absolute": {
          "$ref": "https://example.com/profile.schema.json"
        },
        "relative": {
          "$ref": "profile.schema.json"
        },
        "anchor": {
          "$ref": "#profile"
        },
        "pointer": {
          "$ref": "#/properties/name"
        },
        "array": {
          "type": "array",
          "items": {
            "$ref": "#ProductSchema"
          }
        },
        "empty": {
          "$ref": ""
        },
        "unsafe": {
          "$ref": "https://example.com/a)b schema.json"
        },
        "annotated": {
          "description": "External profile",
          "$ref": "https://example.com/profile.schema.json"
        }
      },
      "additionalProperties": false
    }

- name: external-ref-canonical-expansion
  cmnd: bin/ysd -f ysd -t ysdc -
  stdi: |
    author: +Ref(https://example.com/user-profile.schema.json)
    reviewer:
      .xref: ../schemas/reviewer.json#/$defs/profile
      .desc: External reviewer
  want: |
    author:
      .xref: https://example.com/user-profile.schema.json
    reviewer:
      .xref: ../schemas/reviewer.json#/$defs/profile
      .desc: External reviewer

- name: external-ref-roundtrip
  cmnd: bin/ysd -f jsc -R -
  stdi: |
    {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "type": "object",
      "properties": {
        "author": {
          "$ref": "https://example.com/user-profile.schema.json"
        }
      },
      "additionalProperties": false
    }
  want: |
    OK

- name: empty-compact-external-ref-is-rejected
  cmnd: |
    sh -c '
      output=$(bin/ysd -f ysd -t ysdc - 2>&1)
      status=$?
      test "$status" -eq 2
      printf "%s\n" "$output" | head -n 1
    '
  stdi: |
    author: +Ref()
  want: |
    ysd: compact external reference cannot be empty; use .xref

- name: non-string-canonical-external-ref-is-rejected
  cmnd: |
    sh -c '
      output=$(bin/ysd -f ysd -t ysdc - 2>&1)
      status=$?
      test "$status" -eq 2
      printf "%s\n" "$output" | head -n 1
    '
  stdi: |
    author:
      .xref: 42
  want: |
    ysd: yamlschema .xref must be a string

done:
