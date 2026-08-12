#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: scalar-enums-use-flow-style
  cmnd: bin/ysc -f yscy -t yscy -
  stdi: |
    first:
      .base: +Str
      .enum:
      - ReadWriteOnce
      - ReadOnlyMany
      - ReadWriteMany
      .init: ReadWriteOnce
    second:
      .base: +Str
      .enum:
      - a
    empty:
      .base: +Str
      .enum: []
    deep:
      child:
        leaf:
          .base: +Str
          .enum:
          - x
          - y
  want: |
    first:
      .base: +Str
      .enum: [ReadWriteOnce, ReadOnlyMany, ReadWriteMany]
      .init: ReadWriteOnce
    second:
      .base: +Str
      .enum: [a]
    empty:
      .base: +Str
      .enum: []
    deep:
      child:
        leaf:
          .base: +Str
          .enum: [x, y]

- name: flow-enums-preserve-scalar-types
  cmnd: bin/ysc -f yscy -t yscy -
  stdi: |
    native:
      .base: +Any
      .enum:
      - plain
      - has space
      - 'true'
      - true
      - 'null'
      - null
      - 12
      - 1.5
  want: |
    native:
      .base: +Any
      .enum: [plain, has space, 'true', true, 'null', null, 12, 1.5]

- name: flow-enums-quote-flow-punctuation
  cmnd: bin/ysc -f yscy -t yscy -
  stdi: |
    punctuation:
      .base: +Str
      .enum:
      - comma, value
      - brackets [] and braces {}
      - 'colon: value'
      - 'hash # value'
      - 'it''s, fine'
      - "tab,\tvalue"
  want: |
    punctuation:
      .base: +Str
      .enum: ['comma, value', 'brackets [] and braces {}', 'colon: value',
        'hash # value', 'it''s, fine', "tab,\tvalue"]

- name: structured-and-multiline-enums-stay-block-style
  cmnd: bin/ysc -f yscy -t yscy -
  stdi: |
    structured:
      .base: +Any
      .enum:
      - - a
        - b
      - x: y
    empty-collections:
      .base: +Any
      .enum:
      - {}
      - []
    multiline:
      .base: +Str
      .enum:
      - |-
        first
        second
    after: +Str
  want: |
    structured:
      .base: +Any
      .enum:
      - - a
        - b
      - x: y
    empty-collections:
      .base: +Any
      .enum:
      - {}
      - []
    multiline:
      .base: +Str
      .enum:
      - |-
        first
        second
    after: +Str

- name: enum-wrap-boundaries
  cmnd: |
    sh -c '
      for width in 65 66 67; do
        word=$(printf "%0${width}d" 0 | tr 0 a)
        printf "x:\n  .base: +Str\n  .enum:\n  - %s\n  - b\n" "$word" |
          bin/ysc -f yscy -t yscy - |
          awk "/^  \\.enum:/ {print length(\$0), \"enum\"}
            /^    b]$/ {print length(\$0), \"continuation\"}"
      done
      word=$(printf "%090d" 0 | tr 0 a)
      printf "x:\n  .base: +Str\n  .enum:\n  - %s\n" "$word" |
        bin/ysc -f yscy -t yscy - |
        awk "/^  \\.enum:/ {print length(\$0), \"indivisible\"}"
    '
  want: |
    79 enum
    80 enum
    78 enum
    6 continuation
    101 indivisible

- name: range-and-size-use-flow-style
  cmnd: bin/ysc -f yscy -t yscy -
  stdi: |
    lower:
      .base: +Int
      .range:
      - 0
    upper:
      .base: +Int
      .range:
      - null
      - 10
    bounded:
      .base: +Float
      .range:
      - 0.5
      - 1
    minimum-length:
      .base: +Str
      .size:
      - 1
    length-range:
      .base: +Str
      .size:
      - 1
      - 10
  want: |
    lower:
      .base: +Int
      .range: [0]
    upper:
      .base: +Int
      .range: [null, 10]
    bounded:
      .base: +Float
      .range: [0.5, 1]
    minimum-length:
      .base: +Str
      .size: [1]
    length-range:
      .base: +Str
      .size: [1, 10]

- name: other-sequences-are-not-reformatted
  cmnd: bin/ysc -f yscy -t yscy -
  stdi: |
    choice:
      .one:
      - +Str
      - +Int
  want: |
    choice:
      .one:
      - +Str
      - +Int

- name: succinct-yaml-enums-are-not-reformatted
  cmnd: bin/ysc -t ysd -
  stdi: |
    {
      "properties": {
        "value": {"enum": ["bad/value", "ok"]}
      }
    }
  want: |
    value?:
      .base: +Str
      .enum:
      - bad/value
      - ok

- name: formatted-enum-reparses-with-original-values
  cmnd: |
    sh -c '
      bin/ysc -f yscy -t yscy - |
        ys -e "data =: IN:read:yaml/load" \
          -e "say: json/dump(data.values.get(\".enum\"))"
    '
  stdi: |
    values:
      .base: +Any
      .enum:
      - comma, value
      - 'true'
      - true
      - null
      - 42
  want: |
    ["comma, value","true",true,null,42]

done:
