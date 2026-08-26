#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: const
  cmnd: bin/ysd -t ysd -
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
    # Converted from JSON Schema
    .open: true
    version: +Str ==v1
    kind: +Str ==User
    fixed: +Str ==User =User

done:
