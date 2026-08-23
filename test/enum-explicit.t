#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: enum-explicit
  cmnd: bin/ysd -t ysd.yaml -
  stdi: |
    {
      "properties": {
        "label": {"enum": ["has space", "ok"]},
        "symbol": {"enum": ["ok", "bad/value"]},
        "mixed": {"enum": ["true", "false", true, false]}
      },
      "required": ["label", "symbol", "mixed"]
    }
  want: |
    # Converted from JSON Schema
    .open: true
    label: +Str [has space, ok]
    symbol:
      .type: +Str
      .enum:
      - ok
      - bad/value
    mixed:
      .type: +Any
      .enum:
      - 'true'
      - 'false'
      - true
      - false

- name: heterogeneous-enum-roundtrip
  cmnd: bin/ysc -R -f jsc -
  stdi: |
    {
      "type": "object",
      "properties": {
        "mixed": {"enum": ["true", "false", true, false]}
      },
      "additionalProperties": false
    }
  want: |
    OK

done:
