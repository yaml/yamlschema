#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: expanded-json-root-order-over-eight-keys
  cmnd: |
    sh -c '
      bin/ysd -t ysdc -J - |
        ys -e "say: IN:read:yaml/load:keys:joins"
    '
  stdi: |
    a: +Str
    b: +Str
    c: +Str
    d: +Str
    e: +Str
    f: +Str
    g: +Str
    h: +Str
    i: +Str
    j: +Str
  want: |
    a b c d e f g h i j

- name: expanded-yaml-root-order-over-eight-keys
  cmnd: |
    sh -c '
      bin/ysd -t ysdc - |
        ys -e "say: IN:read:yaml/load:keys:joins"
    '
  stdi: |
    a: +Str
    b: +Str
    c: +Str
    d: +Str
    e: +Str
    f: +Str
    g: +Str
    h: +Str
    i: +Str
    j: +Str
  want: |
    a b c d e f g h i j

- name: expanded-nested-order-over-eight-keys
  cmnd: |
    sh -c '
      bin/ysd -t ysdc - |
        ys -e "say: IN:read:yaml/load.parent:keys:joins"
    '
  stdi: |
    parent:
      a: +Str
      b: +Str
      c: +Str
      d: +Str
      e: +Str
      f: +Str
      g: +Str
      h: +Str
      i: +Str
      j: +Str
  want: |
    a b c d e f g h i j

- name: canonical-directive-order-over-eight-keys
  cmnd: |
    sh -c '
      bin/ysd -t ysdc - |
        ys -e "say: IN:read:yaml/load.rich:keys:joins"
    '
  stdi: |
    rich:
      .desc: Words
      .title: Title
      .init: x
      .null: true
      .uniq: true
      .solo: true
      .size: [1, 3]
      .item: +Str
      .match: word
      .type: +Str[]
  want: |
    .type .item .like .size .solo .uniq .null .init .title .desc

- name: json-schema-definition-and-property-order
  cmnd: |
    sh -c '
      bin/ysd -f jsc -t ysdc - |
        ys -e "say: IN:read:yaml/load:keys:joins" |
        tr " " "\n"
    '
  stdi: |
    {
      "$id": "example",
      "title": "Ordered",
      "$defs": {
        "d1": {"type": "string"},
        "d2": {"type": "string"},
        "d3": {"type": "string"},
        "d4": {"type": "string"},
        "d5": {"type": "string"},
        "d6": {"type": "string"},
        "d7": {"type": "string"},
        "d8": {"type": "string"},
        "d9": {"type": "string"},
        "d10": {"type": "string"}
      },
      "properties": {
        "p1": {"type": "string"},
        "p2": {"type": "string"},
        "p3": {"type": "string"},
        "p4": {"type": "string"},
        "p5": {"type": "string"},
        "p6": {"type": "string"},
        "p7": {"type": "string"},
        "p8": {"type": "string"},
        "p9": {"type": "string"},
        "p10": {"type": "string"}
      }
    }
  want: |
    .ysid
    .title
    .open
    +d1
    +d2
    +d3
    +d4
    +d5
    +d6
    +d7
    +d8
    +d9
    +d10
    p1?
    p2?
    p3?
    p4?
    p5?
    p6?
    p7?
    p8?
    p9?
    p10?

- name: json-schema-properties-before-definitions
  cmnd: |
    sh -c '
      bin/ysd -f jsc -t ysdc - |
        ys -e "say: IN:read:yaml/load:keys:joins" |
        tr " " "\n"
    '
  stdi: |
    {
      "properties": {
        "first": {"type": "string"},
        "second": {"type": "integer"}
      },
      "$defs": {
        "alpha": {"type": "string"},
        "beta": {"type": "integer"}
      }
    }
  want: |
    .open
    first?
    second?
    +alpha
    +beta

- name: ysd-root-between-definitions-goes-last
  cmnd: |
    sh -c '
      bin/ysd -t jsc - |
        jq -r "
          \"root \" + (keys_unsorted | join(\" \")),
          \"defs \" + (.\"\$defs\" | keys_unsorted | join(\" \"))
        "
    '
  stdi: |
    +before: +Str
    root?: +Bool
    +after: +Int
  want: |
    root $schema type additionalProperties $defs properties
    defs before after

- name: ysd-root-after-many-definitions-goes-last
  cmnd: |
    sh -c '
      bin/ysd -t jsc - |
        jq -r "keys_unsorted | join(\" \")"
    '
  stdi: |
    +one: +Str
    +two: +Str
    +three: +Str
    +four: +Str
    +five: +Str
    +six: +Str
    +seven: +Str
    +eight: +Str
    +nine: +Str
    root?: +Bool
  want: |
    $schema type additionalProperties $defs properties

- name: ysd-root-before-definitions-goes-first
  cmnd: |
    sh -c '
      bin/ysd -t jsc - |
        jq -r "keys_unsorted | join(\" \")"
    '
  stdi: |
    root?: +Bool
    +before: +Str
    +after: +Int
  want: |
    $schema type additionalProperties properties $defs

- name: ysd-root-patterns-precede-definitions
  cmnd: |
    sh -c '
      bin/ysd -t jsc - |
        jq -r "keys_unsorted | join(\" \")" |
        tr " " "\n"
    '
  stdi: |
    name: +Str
    /^x-/: +Any
    +thing: +Str
  want: |
    $schema
    type
    additionalProperties
    required
    patternProperties
    properties
    $defs

- name: normalized-json-schema-key-order
  cmnd: |
    sh -c '
      bin/ysd -NC - |
        jq -r "
          \"root \" + (keys_unsorted | join(\" \")),
          \"nested \" +
            (.properties.nested | keys_unsorted | join(\" \"))
        " |
        tr " " "\n"
    '
  stdi: |
    {
      "title": "All keywords",
      "$defs": {"item": {"type": "string"}},
      "properties": {
        "nested": {
          "properties": {"leaf": {"type": "string"}},
          "x-zeta": 2,
          "maxLength": 10,
          "description": "Nested schema",
          "type": "object",
          "x-alpha": 1,
          "minLength": 1
        }
      },
      "x-zeta": true,
      "required": ["nested"],
      "dependentRequired": {"nested": ["other"]},
      "enum": [{}],
      "patternProperties": {"^x": {"type": "string"}},
      "additionalProperties": false,
      "items": {"type": "string"},
      "maxProperties": 8,
      "minProperties": 1,
      "uniqueItems": true,
      "maxItems": 7,
      "minItems": 2,
      "maxLength": 6,
      "minLength": 3,
      "maximum": 5,
      "minimum": 4,
      "default": {"z": 1, "a": 2},
      "const": "fixed",
      "$ref": "#/$defs/item",
      "format": "custom",
      "type": "object",
      "description": "Every preferred keyword",
      "$anchor": "root",
      "$comment": "Comment",
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://example.com/all.schema.json",
      "x-alpha": true
    }
  want: |
    root
    $id
    $schema
    $comment
    $anchor
    title
    description
    type
    format
    $ref
    const
    default
    minimum
    maximum
    minLength
    maxLength
    minItems
    maxItems
    uniqueItems
    minProperties
    maxProperties
    items
    additionalProperties
    required
    patternProperties
    enum
    dependentRequired
    $defs
    x-alpha
    x-zeta
    properties
    nested
    description
    type
    minLength
    maxLength
    x-alpha
    x-zeta
    properties

- name: normalization-preserves-json-object-key-order
  cmnd: |
    sh -c '
      bin/ysd -NC - |
        jq -r "
          \"properties \" + (.properties | keys_unsorted | join(\" \")),
          \"required \" + (.required | join(\" \")),
          \"default \" +
            (.properties.data.default | keys_unsorted | join(\" \"))
        "
    '
  stdi: |
    {
      "type": "object",
      "properties": {
        "z": {"type": "string"},
        "a": {"type": "string"},
        "m": {"type": "string"},
        "y": {"type": "string"},
        "b": {"type": "string"},
        "x": {"type": "string"},
        "c": {"type": "string"},
        "w": {"type": "string"},
        "d": {"type": "string"},
        "v": {"type": "string"},
        "data": {"default": {"z": 1, "a": 2, "m": 3}}
      },
      "required": ["orphan-z", "m", "z", "orphan-a", "a"]
    }
  want: |
    properties z a m y b x c w d v data
    required z a m orphan-a orphan-z
    default z a m

- name: succinct-to-json-property-order-over-eight-keys
  cmnd: |
    sh -c '
      bin/ysd -t jsc - |
        jq -r ".properties | keys_unsorted | join(\" \")"
    '
  stdi: |
    z: +Str
    a: +Str
    m: +Str
    y: +Str
    b: +Str
    x: +Str
    c: +Str
    w: +Str
    d: +Str
    v: +Str
  want: |
    z a m y b x c w d v

- name: json-succinct-json-property-order-over-eight-keys
  cmnd: |
    sh -c '
      bin/ysd -f jsc -t ysd - |
        bin/ysd -f ysd -t jsc - |
        jq -r ".properties | keys_unsorted | join(\" \")"
    '
  stdi: |
    {
      "type": "object",
      "properties": {
        "z": {"type": "string"},
        "a": {"type": "string"},
        "m": {"type": "string"},
        "y": {"type": "string"},
        "b": {"type": "string"},
        "x": {"type": "string"},
        "c": {"type": "string"},
        "w": {"type": "string"},
        "d": {"type": "string"},
        "v": {"type": "string"}
      },
      "additionalProperties": false
    }
  want: |
    z a m y b x c w d v

done:
