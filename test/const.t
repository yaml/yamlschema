#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: const
  cmnd: bin/ysc -t ysc.yaml -
  stdi: |
    {
      "properties": {
        "version": {"const": "v1"},
        "kind":    {"const": "User"}
      },
      "required": ["version", "kind"]
    }
  want: |
    version: v1
    kind: User

done:
