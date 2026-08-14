#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: typed-map-expansion
  cmnd: sh -c 'bin/ysc -t yscj -C - | fold -w 72'
  stdi: |
    any: +Map{+Any}
    strings: +Map{+Str}~
    custom: +Map{+types/value}
    many: +Map{+Str}[]
    hybrid:
      .type: +Map{+Str}
      fixed?: +Str
  want: |
    {"any":{"+Str":"+Any"},"strings":{".null":true,"+Str":"+Str"},"custom":{
    "+Str":"+types\/value"},"many":{".type":"+Map[]","+Str":"+Str"},"hybrid"
    :{"+Str":"+Str","fixed?":"+Str"}}

- name: typed-map-to-json-schema
  cmnd: sh -c 'bin/ysc -t schema.json -C - | fold -w 72'
  stdi: |
    +flag: +Bool

    any: +Map{+Any}
    strings: +Map{+Str}
    custom: +Map{+flag}
    many: +Map{+Str}[]
  want: |
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"o
    bject","properties":{"any":{"type":"object","additionalProperties":true}
    ,"custom":{"type":"object","additionalProperties":{"$ref":"#\/$defs\/fla
    g"}},"many":{"type":"array","items":{"type":"object","additionalProperti
    es":{"type":"string"}}},"strings":{"type":"object","additionalProperties
    ":{"type":"string"}}},"required":["any","strings","custom","many"],"addi
    tionalProperties":false,"$defs":{"flag":{"type":"boolean"}}}

- name: json-schema-to-typed-maps
  cmnd: bin/ysc -t ysd.yaml -
  stdi: |
    {
      "$defs": {"flag": {"type": "boolean"}},
      "properties": {
        "config": {
          "type": "object",
          "additionalProperties": true,
          "description": "Primary component config."
        },
        "labels": {
          "type": "object",
          "additionalProperties": {"type": "string"}
        },
        "custom": {
          "type": "object",
          "additionalProperties": {"$ref": "#/$defs/flag"}
        },
        "hybrid": {
          "type": "object",
          "properties": {"fixed": {"type": "string"}},
          "additionalProperties": {"type": "string"}
        },
        "fallback": {
          "type": "object",
          "additionalProperties": {"type": "string", "minLength": 1}
        }
      }
    }
  want: |
    # Converted from JSON Schema
    .open: true

    +flag: +Bool

    config?: +Map{+Any} "Primary component config."
    labels?: +Map{+Str}
    custom?: +Map{+flag}
    hybrid?:
      fixed?: +Str
      +Str: +Str
    fallback?:
      +Str: +Str 1+

- name: bare-map-is-rejected
  cmnd: |
    sh -c 'bin/ysc -t schema.json -C - 2>&1 | sed -n 1p'
  stdi: |
    data: +Map
  want: |
    ysc: incomplete +Map type requires key/value pairs

- name: reject-invalid-map-value-type
  cmnd: |
    sh -c 'bin/ysc -t yscj -C - 2>&1 | sed -n 1p'
  stdi: |
    bad: +Map{Str}
  want: |
    ysc: +Map requires exactly one value type reference

- name: map-parameter-errors
  cmnd: |
    sh -c '
      for value in "+Map{}" "+Map{+Any,+Any}"; do
        printf "bad: %s\n" "$value" |
          bin/ysc -t yscj -C - 2>&1 | sed -n 1p
      done
    '
  want: |
    ysc: +Map requires exactly one value type reference
    ysc: +Map{+Key,+Value} is reserved but not supported yet

- name: reject-old-map-parameter-delimiters
  cmnd: |
    sh -c 'bin/ysc -t yscj -C - 2>&1 | sed -n 1p'
  stdi: |
    bad: +Map[+Any]
  want: |
    ysc: unsupported map parameter syntax: +Map[+Any]; use +Map{+Type}

- name: shaped-map-list-base
  cmnd: sh -c 'bin/ysc -t yscj -C - | fold -w 72'
  stdi: |
    extraEnv?:
      .type: +Map[1-10,$!]
      name: +Str
      value?: +Str
      valueFrom?: +Map{+Any}
  want: |
    {"extraEnv?":{".type":"+Map[]",".size":[1,10],".solo":true,".uniq":true,
    "name":"+Str","value?":"+Str","valueFrom?":{"+Str":"+Any"}}}

- name: old-shaped-map-marker-normalizes-away
  cmnd: bin/ysc -t yscj -
  stdi: |
    closed:
      .type: +Map
      fixed?: +Str
    open:
      .type: +Map
      fixed?: +Str
      +Str: +Any
  want: |
    {
      "closed": {
        "fixed?": "+Str"
      },
      "open": {
        "fixed?": "+Str",
        "+Str": "+Any"
      }
    }

- name: marker-only-map-is-rejected
  cmnd: |
    sh -c 'bin/ysc -t yscj -C - 2>&1 | sed -n 1p'
  stdi: |
    bad:
      .type: +Map
      .desc: Old marker
  want: |
    ysc: incomplete +Map type requires key/value pairs

- name: legacy-wildcard-is-rejected
  cmnd: |
    sh -c 'bin/ysc -t yscj -C - 2>&1 | sed -n 1p'
  stdi: |
    bad:
      +Str*: +Any
  want: |
    ysc: unsupported yamlschema wildcard: +Str*; use +Str

- name: pure-object-generation
  cmnd: bin/ysc -t ysd.yaml -
  stdi: |
    {
      "properties": {
        "implicit": {"type": "object"},
        "explicit": {"type": "object", "additionalProperties": true},
        "closed": {"type": "object", "additionalProperties": false}
      }
    }
  want: |
    # Converted from JSON Schema
    .open: true
    implicit?: {}
    explicit?: +Map{+Any}
    closed?:
      .open: false

- name: reserved-str-definition-collision
  cmnd: |
    sh -c 'bin/ysc -t ysd.yaml - 2>&1 | sed -n 1p'
  stdi: |
    {"$defs": {"Str": {"type": "string"}}}
  want: |
    ysc: JSON Schema definition name Str conflicts with the +Str wildcard

- name: reserved-str-property-collision
  cmnd: |
    sh -c 'bin/ysc -t ysd.yaml - 2>&1 | sed -n 1p'
  stdi: |
    {"properties": {"+Str": {"type": "string"}}}
  want: |
    ysc: JSON Schema property name +Str is reserved for the wildcard

done:
