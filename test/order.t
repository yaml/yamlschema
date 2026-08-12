#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: expanded-json-root-order-over-eight-keys
  cmnd: |
    sh -c '
      bin/ysc -t yscj - |
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
      bin/ysc -t yscy - |
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
      bin/ysc -t yscy - |
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
      bin/ysc -t yscy - |
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
      .base: +Str[]
  want: |
    .base .item .like .size .solo .uniq .null .init .title .desc

- name: json-schema-definition-and-property-order
  cmnd: |
    sh -c '
      bin/ysc -f jsc -t yscy - |
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
    .title
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
    .json

done:
