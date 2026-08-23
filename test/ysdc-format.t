#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: scalar-enums-use-flow-style
  cmnd: bin/ysd -f ysdc -t ysdc -
  stdi: |
    first:
      .type: +Str
      .enum:
      - ReadWriteOnce
      - ReadOnlyMany
      - ReadWriteMany
      .init: ReadWriteOnce
    second:
      .type: +Str
      .enum:
      - a
    empty:
      .type: +Str
      .enum: []
    deep:
      child:
        leaf:
          .type: +Str
          .enum:
          - x
          - y
  want: |
    first:
      .type: +Str
      .enum: [ReadWriteOnce, ReadOnlyMany, ReadWriteMany]
      .init: ReadWriteOnce
    second:
      .type: +Str
      .enum: [a]
    empty:
      .type: +Str
      .enum: []
    deep:
      child:
        leaf:
          .type: +Str
          .enum: [x, y]

- name: flow-enums-preserve-scalar-types
  cmnd: bin/ysd -f ysdc -t ysdc -
  stdi: |
    native:
      .type: +Any
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
      .type: +Any
      .enum: [plain, has space, 'true', true, 'null', null, 12, 1.5]

- name: flow-enums-quote-flow-punctuation
  cmnd: bin/ysd -f ysdc -t ysdc -
  stdi: |
    punctuation:
      .type: +Str
      .enum:
      - comma, value
      - brackets [] and braces {}
      - 'colon: value'
      - 'hash # value'
      - 'it''s, fine'
      - "tab,\tvalue"
  want: |
    punctuation:
      .type: +Str
      .enum: ['comma, value', 'brackets [] and braces {}', 'colon: value',
        'hash # value', 'it''s, fine', "tab,\tvalue"]

- name: structured-and-multiline-enums-stay-block-style
  cmnd: bin/ysd -f ysdc -t ysdc -
  stdi: |
    structured:
      .type: +Any
      .enum:
      - - a
        - b
      - x: y
    empty-collections:
      .type: +Any
      .enum:
      - {}
      - []
    multiline:
      .type: +Str
      .enum:
      - |-
        first
        second
    after: +Str
  want: |
    structured:
      .type: +Any
      .enum:
      - - a
        - b
      - x: y
    empty-collections:
      .type: +Any
      .enum:
      - {}
      - []
    multiline:
      .type: +Str
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
        printf "x:\n  .type: +Str\n  .enum:\n  - %s\n  - b\n" "$word" |
          bin/ysd -f ysdc -t ysdc - |
          awk "/^  \\.enum:/ {print length(\$0), \"enum\"}
            /^    b]$/ {print length(\$0), \"continuation\"}"
      done
      word=$(printf "%090d" 0 | tr 0 a)
      printf "x:\n  .type: +Str\n  .enum:\n  - %s\n" "$word" |
        bin/ysd -f ysdc -t ysdc - |
        awk "/^  \\.enum:/ {print length(\$0), \"indivisible\"}"
    '
  want: |
    79 enum
    80 enum
    78 enum
    6 continuation
    101 indivisible

- name: range-and-size-use-flow-style
  cmnd: bin/ysd -f ysdc -t ysdc -
  stdi: |
    lower:
      .type: +Int
      .range:
      - 0
    upper:
      .type: +Int
      .range:
      - null
      - 10
    bounded:
      .type: +Float
      .range:
      - 0.5
      - 1
    minimum-length:
      .type: +Str
      .size:
      - 1
    length-range:
      .type: +Str
      .size:
      - 1
      - 10
  want: |
    lower:
      .type: +Int
      .range: [0]
    upper:
      .type: +Int
      .range: [null, 10]
    bounded:
      .type: +Float
      .range: [0.5, 1]
    minimum-length:
      .type: +Str
      .size: [1]
    length-range:
      .type: +Str
      .size: [1, 10]

- name: other-sequences-are-not-reformatted
  cmnd: bin/ysd -f ysdc -t ysdc -
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
  cmnd: bin/ysd -t ysd -
  stdi: |
    {
      "properties": {
        "value": {"enum": ["bad/value", "ok"]}
      }
    }
  want: |
    # Converted from JSON Schema
    .open: true
    value?:
      .type: +Str
      .enum:
      - bad/value
      - ok

- name: formatted-enum-reparses-with-original-values
  cmnd: |
    sh -c '
      bin/ysd -f ysdc -t ysdc - |
        ys -e "data =: IN:read:yaml/load" \
          -e "say: json/dump(data.values.get(\".enum\"))"
    '
  stdi: |
    values:
      .type: +Any
      .enum:
      - comma, value
      - 'true'
      - true
      - null
      - 42
  want: |
    ["comma, value","true",true,null,42]

done:
