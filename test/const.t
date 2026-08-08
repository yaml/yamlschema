#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: const
  cmnd: bin/ysc -t ysc.yaml -
  stdi: |
    {
      "properties": {
        "version": {"const": "v1"},
        "kind":    {"const": "User"},
        "fixed":   {"const": "User", "default": "User"}
      },
      "required": ["version", "kind", "fixed"]
    }
  want: |
    version: +Str ==v1
    kind: +Str ==User
    fixed: +Str ==User =User

done:
