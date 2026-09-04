#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: import-pattern-properties
  cmnd: sh -c 'bin/ysd -f jsc -t ysd - 2>&1'
  stdi: |
    {
      "$defs": {"path": {"type": "string"}},
      "type": "object",
      "properties": {"name": {"type": "string"}},
      "required": ["name"],
      "patternProperties": {
        "^x-": {},
        "^\\/": {"$ref": "#/$defs/path"},
        "a: b": {"type": "integer"},
        "/foo/": {"type": "boolean"}
      },
      "additionalProperties": false
    }
  want: |
    # Converted from JSON Schema

    +path: +Str

    name: +Str
    /^x-/: +Any
    /^\//: +path
    '/a: b/': +Int
    //foo//: +Bool

- name: export-pattern-properties
  cmnd: bin/ysd -f ysd -t jsc -C -
  stdi: |
    +path: +Str

    name: +Str
    /^x-/: +Any
    /^\//: +path
    '/a: b/': +Int
    //foo//: +Bool
  want: |
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"object","additionalProperties":false,"required":["name"],"patternProperties":{"^x-":{},"^\\\/":{"$ref":"#\/$defs\/path"},"a: b":{"type":"integer"},"\/foo\/":{"type":"boolean"}},"$defs":{"path":{"type":"string"}},"properties":{"name":{"type":"string"}}}

- name: pattern-properties-roundtrip
  cmnd: bin/ysd -R -f jsc -
  stdi: |
    {
      "$defs": {"path": {"type": "string"}},
      "type": "object",
      "properties": {"name": {"type": "string"}},
      "required": ["name"],
      "patternProperties": {
        "^x-": {},
        "^\\/": {"$ref": "#/$defs/path"},
        "a: b": {"type": "integer"},
        "/foo/": {"type": "boolean"}
      },
      "additionalProperties": false
    }
  want: |
    OK

- name: succinct-open-pattern-map
  cmnd: bin/ysd -f jsc -t ysd -
  stdi: |
    {
      "type": "object",
      "patternProperties": {
        "^\\.[a-z0-9_]+$": {
          "type": "object",
          "description": "Definitions that can be re-used"
        }
      },
      "additionalProperties": false
    }
  want: |
    # Converted from JSON Schema
    /^\.[a-z0-9_]+$/: +Map{} -"Definitions that can be re-used"

- name: empty-pattern-properties-normalize-away
  cmnd: bin/ysd -R -f jsc -
  stdi: |
    {
      "type": "object",
      "patternProperties": {},
      "additionalProperties": false
    }
  want: |
    OK

- name: open-and-closed-pattern-mappings
  cmnd: bin/ysd -f ysd -t jsc -C -
  stdi: |
    .open: true
    root?: +Str
    /^x-/: +Any
    closed:
      .open: false
      known?: +Int
      /^p-/: +Bool
    local:
      /^q-/: +Num
      +Str: +Any
  want: |
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"object","required":["closed","local"],"patternProperties":{"^x-":{}},"properties":{"root":{"type":"string"},"closed":{"type":"object","additionalProperties":false,"patternProperties":{"^p-":{"type":"boolean"}},"properties":{"known":{"type":"integer"}}},"local":{"type":"object","patternProperties":{"^q-":{"type":"number"}}}}}

- name: pattern-mapping-sizes
  cmnd: bin/ysd -f jsc -t ysd -
  stdi: |
    {
      "$defs": {
        "bounded": {
          "type": "object",
          "minProperties": 1,
          "maxProperties": 2,
          "patternProperties": {"^b": {}},
          "additionalProperties": false
        }
      },
      "type": "object",
      "minProperties": 1,
      "properties": {
        "nested": {
          "type": "object",
          "maxProperties": 3,
          "patternProperties": {"^x": {}}
        }
      },
      "patternProperties": {"^r": {}},
      "additionalProperties": false
    }
  want: |
    # Converted from JSON Schema
    .size: 1+

    +bounded:
      .size: 1-2
      /^b/: +Any

    nested?:
      .size: 0-3
      /^x/: +Any
      +Str: +Any
    /^r/: +Any

- name: pattern-mapping-sizes-roundtrip
  cmnd: bin/ysd -R -f jsc -
  stdi: |
    {
      "$defs": {
        "bounded": {
          "type": "object",
          "minProperties": 1,
          "maxProperties": 2,
          "patternProperties": {"^b": {}},
          "additionalProperties": false
        }
      },
      "type": "object",
      "minProperties": 1,
      "properties": {
        "nested": {
          "type": "object",
          "maxProperties": 3,
          "patternProperties": {"^x": {}},
          "additionalProperties": false
        }
      },
      "patternProperties": {"^r": {}},
      "additionalProperties": false
    }
  want: |
    OK

- name: boolean-pattern-schema-stays-passthrough
  cmnd: sh -c 'bin/ysd -f jsc -t ysd - 2>&1'
  stdi: |
    {
      "type": "object",
      "patternProperties": {"^x-": true},
      "additionalProperties": false
    }
  want: |
    ysd: warning: unsupported JSON Schema keyword "patternProperties" at /patternProperties
    # Converted from JSON Schema
    .patternProperties:
      ^x-: true

- name: boolean-pattern-schema-roundtrip
  cmnd: sh -c 'bin/ysd -R -f jsc - 2>&1'
  stdi: |
    {
      "type": "object",
      "patternProperties": {"^x-": true},
      "additionalProperties": false
    }
  want: |
    ysd: warning: unsupported JSON Schema keyword "patternProperties" at /patternProperties
    OK

- name: regex-key-warning-path
  cmnd: sh -c 'bin/ysd -f ysd -t jsc -C - 2>&1'
  stdi: |
    /^x-/: +Float
  want: |
    ysd: warning: +Float at /patternProperties/^x- exports as JSON Schema "number", which also accepts integers
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"object","additionalProperties":false,"patternProperties":{"^x-":{"type":"number"}}}

- name: reject-regex-key-need
  cmnd: |
    sh -c '
      bin/ysd -f ysd -t jsc - 2>&1 |
        perl -ne "print if /regex keys/"
    '
  stdi: |
    /^x-/: +Str :need(foo)
  want: |
    ysd: yamlschema regex keys cannot use .need

- name: reject-regex-key-in-key-rules
  cmnd: |
    sh -c '
      bin/ysd -f ysd -t jsc - 2>&1 |
        perl -ne "print if /branch keys/"
    '
  stdi: |
    .keys:
    - .any:
      - /^x-/: +Any
      - foo: +Str
  want: |
    ysd: yamlschema .keys .any branch keys must be property names

- name: reject-mixed-pattern-property-forms
  cmnd: |
    sh -c '
      bin/ysd -f ysd -t jsc - 2>&1 |
        perl -ne "print if /cannot mix/"
    '
  stdi: |
    .patternProperties:
      ^x-: {}
    /^y-/: +Any
  want: |
    ysd: yamlschema cannot mix regex keys with .patternProperties

- name: reject-exact-regex-shaped-json-property
  cmnd: |
    sh -c '
      bin/ysd -f jsc -t ysd - 2>&1 |
        perl -ne "print if /conflicts with regex/"
    '
  stdi: |
    {
      "type": "object",
      "properties": {"/foo/": {"type": "string"}}
    }
  want: |
    ysd: JSON Schema property name /foo/ conflicts with regex key syntax

- name: reject-exact-regex-shaped-ysd-property
  cmnd: |
    sh -c '
      bin/ysd -f ysd -t jsc - 2>&1 |
        perl -ne "print if /conflicts with regex/"
    '
  stdi: |
    /foo/?: +Str
  want: |
    ysd: yamlschema exact property name /foo/ conflicts with regex key syntax

done:
