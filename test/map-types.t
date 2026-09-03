#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: typed-map-expansion
  cmnd: sh -c 'bin/ysd -t ysdc -J -C - | fold -w 72'
  stdi: |
    empty: +Map{}
    any: +Map{+Any}
    explicit: +Map{+Str,+Any}
    strings: +Map{+Str}~
    explicitStrings: +Map{+Str,+Str}
    custom: +Map{+types/value}
    many: +Map{+Str}[]
    hybrid:
      .type: +Map{+Str}
      fixed?: +Str
  want: |
    {"empty":{"+Str":"+Any"},"any":{"+Str":"+Any"},"explicit":{"+Str":"+Any"
    },"strings":{".null":true,"+Str":"+Str"},"explicitStrings":{"+Str":"+Str
    "},"custom":{"+Str":"+types\/value"},"many":{".type":"+Map[]","+Str":"+S
    tr"},"hybrid":{"fixed?":"+Str","+Str":"+Str"}}

- name: open-map-modifiers
  cmnd: sh -c 'bin/ysd -t ysdc -J -C - | fold -w 72'
  stdi: |
    nullable: +Map{}~
    many: +Map{}[]
    oneOrMany: +Map{}[$]
    described: +Map{} "Open values"
  want: |
    {"nullable":{".null":true,"+Str":"+Any"},"many":{".type":"+Map[]","+Str"
    :"+Any"},"oneOrMany":{".type":"+Map[]",".solo":true,"+Str":"+Any"},"desc
    ribed":{".desc":"Open values","+Str":"+Any"}}

- name: typed-map-to-json-schema
  cmnd: sh -c 'bin/ysd -t jsc -C - | fold -w 72'
  stdi: |
    +flag: +Bool

    empty: +Map{}
    any: +Map{+Any}
    explicit: +Map{+Str,+Any}
    strings: +Map{+Str}
    explicitStrings: +Map{+Str,+Str}
    custom: +Map{+flag}
    many: +Map{+Str}[]
  want: |
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"o
    bject","additionalProperties":false,"required":["empty","any","explicit"
    ,"strings","explicitStrings","custom","many"],"$defs":{"flag":{"type":"b
    oolean"}},"properties":{"empty":{"type":"object"},"any":{"type":"object"
    },"explicit":{"type":"object"},"strings":{"type":"object","additionalPro
    perties":{"type":"string"}},"explicitStrings":{"type":"object","addition
    alProperties":{"type":"string"}},"custom":{"type":"object","additionalPr
    operties":{"$ref":"#\/$defs\/flag"}},"many":{"type":"array","items":{"ty
    pe":"object","additionalProperties":{"type":"string"}}}}}

- name: json-schema-to-typed-maps
  cmnd: bin/ysd -t ysd -
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

    config?: +Map{} --"Primary component config."
    labels?: +Map{+Str}
    custom?: +Map{+flag}
    hybrid?:
      fixed?: +Str
      +Str: +Str
    fallback?:
      +Str: +Str 1+

- name: canonical-open-maps-in-value-types
  cmnd: bin/ysd -f jsc -t ysd -
  stdi: |
    {
      "$defs": {"open": {"type": "object"}},
      "properties": {
        "direct": {"type": "object"},
        "titleOnly": {"type": "object", "title": "Open"},
        "list": {"type": "array", "items": {"type": "object"}},
        "tuple": {
          "type": "array",
          "prefixItems": [{"type": "object"}],
          "items": false
        },
        "choice": {
          "oneOf": [{"type": "object"}, {"type": "string"}]
        }
      }
    }
  want: |
    # Converted from JSON Schema
    .open: true

    +open: +Map{}

    direct?: +Map{}
    titleOnly?:
      .type: +Map{}
      .title: Open
    list?: +Map{}[]
    tuple?: +Tup{+Map{}?}
    choice?: +One(+Map{},+Str)

- name: bare-map-is-rejected
  cmnd: |
    sh -c 'bin/ysd -t jsc -C - 2>&1 | sed -n 1p'
  stdi: |
    data: +Map
  want: |
    ysd: incomplete +Map type requires key/value pairs

- name: reject-invalid-map-value-type
  cmnd: |
    sh -c 'bin/ysd -t ysdc -J -C - 2>&1 | sed -n 1p'
  stdi: |
    bad: +Map{Str}
  want: |
    ysd: +Map value type must be a type reference

- name: reject-parenthesized-map-parameters
  cmnd: |
    sh -c '
      for value in "+Map(" "+Map(+Any)"; do
        printf "bad: %s\n" "$value" |
          bin/ysd -t ysdc -J -C - 2>&1 |
          perl -ne "print if \$. == 1"
      done
    '
  want: |
    ysd: unsupported map parameter syntax: +Map(; use +Map{+Type}
    ysd: unsupported map parameter syntax: +Map(+Any); use +Map{+Type}

- name: map-parameter-errors
  cmnd: |
    sh -c '
      for value in "+Map{,+Any}" "+Map{+Str,+Any,+Bool}"; do
        printf "bad: %s\n" "$value" |
          bin/ysd -t ysdc -J -C - 2>&1 |
          perl -ne "print if \$. == 1"
      done
    '
  want: |
    ysd: +Map parameters cannot be empty
    ysd: +Map requires zero, one, or two type references

- name: reject-non-string-map-key-type
  cmnd: |
    sh -c '
      bin/ysd -t ysdc -J -C - 2>&1 |
        perl -ne "print if \$. == 1"
    '
  stdi: |
    bad: +Map{+Any,+Str}
  want: |
    ysd: +Map key type must be +Str

- name: reject-old-map-parameter-delimiters
  cmnd: |
    sh -c 'bin/ysd -t ysdc -J -C - 2>&1 | sed -n 1p'
  stdi: |
    bad: +Map[+Any]
  want: |
    ysd: unsupported map parameter syntax: +Map[+Any]; use +Map{+Type}

- name: shaped-map-list-base
  cmnd: sh -c 'bin/ysd -t ysdc -J -C - | fold -w 72'
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
  cmnd: bin/ysd -t ysdc -J -
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
    sh -c 'bin/ysd -t ysdc -J -C - 2>&1 | sed -n 1p'
  stdi: |
    bad:
      .type: +Map
      .desc: Old marker
  want: |
    ysd: incomplete +Map type requires key/value pairs

- name: pure-object-generation
  cmnd: bin/ysd -t ysd -
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
    implicit?: +Map{}
    explicit?: +Map{}
    closed?:
      .open: false

- name: nullable-object-generation
  cmnd: bin/ysd -t ysd -
  stdi: |
    {
      "properties": {
        "startup": {"type": ["object", "null"]},
        "probes": {
          "type": ["object", "null"],
          "description": "Container probes.",
          "properties": {
            "liveness": {"type": ["object", "null"]}
          }
        }
      }
    }
  want: |
    # Converted from JSON Schema
    .open: true
    startup?: +Map{}~
    probes?:
      --: Container probes.
      .null: true
      liveness?: +Map{}~

- name: nullable-any-map-to-json-schema
  cmnd: bin/ysd -t jsc -C -
  stdi: |
    startup?: +Map{+Any}~
  want: |
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"object","additionalProperties":false,"properties":{"startup":{"type":["object","null"]}}}

- name: reserved-str-definition-collision
  cmnd: |
    sh -c 'bin/ysd -t ysd - 2>&1 | sed -n 1p'
  stdi: |
    {"$defs": {"Str": {"type": "string"}}}
  want: |
    ysd: JSON Schema definition name Str conflicts with the +Str wildcard

- name: reserved-str-property-collision
  cmnd: |
    sh -c 'bin/ysd -t ysd - 2>&1 | sed -n 1p'
  stdi: |
    {"properties": {"+Str": {"type": "string"}}}
  want: |
    ysd: JSON Schema property name +Str is reserved for the wildcard

done:
