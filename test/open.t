#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: json-schema-open-default-and-local-overrides
  cmnd: bin/ysc -t ysd -
  stdi: |
    {
      "title": "Open rules",
      "description": "Open object test",
      "$defs": {
        "person": {
          "type": "object",
          "properties": {"name": {"type": "string"}}
        },
        "closed": {
          "type": "object",
          "additionalProperties": false,
          "properties": {
            "child": {
              "type": "object",
              "properties": {"flag": {"type": "boolean"}}
            }
          }
        }
      },
      "type": "object",
      "properties": {
        "explicitAny": {
          "type": "object",
          "additionalProperties": true
        },
        "explicitStr": {
          "type": "object",
          "additionalProperties": {"type": "string"}
        }
      },
      "additionalProperties": false
    }
  want: |
    # Converted from JSON Schema
    .title: Open rules
    .desc: Open object test
    .open: true

    +person:
      name?: +Str

    +closed:
      .open: false
      child?:
        .open: true
        flag?: +Bool

    explicitAny?: +Map{+Any}
    explicitStr?: +Map{+Str}

- name: expanded-form-resolves-inherited-open-state
  cmnd: bin/ysc -t yscy -
  stdi: |
    .open: true
    +person:
      name: +Str
    closed:
      .open: false
      child:
        flag: +Bool
    wildcard:
      +Str: +Any
  want: |
    .open: true
    +person:
      .open: true
      name: +Str

    closed:
      child:
        flag: +Bool
    wildcard:
      +Str: +Any

- name: open-export-semantics
  cmnd: |
    sh -c '
      bin/ysc -t schema.json -C - |
        jq -r ".additionalProperties,
          (.\"\u0024defs\".person | has(\"additionalProperties\")),
          .properties.closed.additionalProperties,
          (.properties.closed.properties.child |
            has(\"additionalProperties\")),
          .properties.wildcard.additionalProperties"
    '
  stdi: |
    .open: true
    +person:
      name: +Str
    closed:
      .open: false
      child:
        flag: +Bool
    wildcard:
      +Str: +Any
  want: |
    false
    false
    false
    true
    null

- name: open-validation-errors
  cmnd: |
    sh -c '
      for input in \
        ".open: 1" \
        "bad:\n  .open: false\n  +Str: +Any" \
        "bad:\n  .type: +Str\n  .open: true"; do
        printf "%b\n" "$input" |
          bin/ysc -t yscy - 2>&1 | sed -n 1p
      done
    '
  want: |
    ysc: yamlschema .open must be true or false
    ysc: yamlschema .open: false conflicts with an explicit +Str wildcard
    ysc: yamlschema .open requires an anonymous mapping type

done:
