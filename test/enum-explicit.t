#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: enum-explicit
  cmnd: bin/ysc -t ysc.yaml -
  stdi: |
    {
      "properties": {
        "label": {"enum": ["has space", "ok"]},
        "symbol": {"enum": ["ok", "bad/value"]}
      },
      "required": ["label", "symbol"]
    }
  want: |
    label: +Str [has space,ok]
    symbol:
      .base: +Str
      .enum:
      - ok
      - bad/value

done:
