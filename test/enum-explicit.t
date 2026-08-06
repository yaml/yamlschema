#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: enum-explicit
  cmnd: bin/ysc -t ysc.yaml -
  stdi: |
    {
      "properties": {
        "label": {"enum": ["has space", "ok"]}
      },
      "required": ["label"]
    }
  want: |
    label:
      .enum:
      - has space
      - ok

done:
