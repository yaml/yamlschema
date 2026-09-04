#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: pattern
  cmnd: bin/ysd -t ysd -
  stdi: |
    {
      "properties": {
        "email": {"type": "string", "pattern": "^\\S+@\\S+$"},
        "zip":   {"pattern": "^[0-9]{5}$"},
        "externalURL": {
          "type": "string",
          "description": "External URL for Harbor",
          "pattern": "^https?://.*$",
          "minLength": 1
        },
        "spaced": {"type": "string", "pattern": "^a b$"},
        "quoted": {"type": "string", "pattern": "^a \"b$"},
        "simpleFind": {"type": "string", "pattern": "[A-Z][a-z]+"},
        "slashFind": {"type": "string", "pattern": "foo/bar"},
        "spacedFind": {"type": "string", "pattern": "foo bar"},
        "quotedFind": {"type": "string", "pattern": "foo \"bar"}
      },
      "required": [
        "email", "zip", "externalURL", "spaced", "quoted",
        "simpleFind", "slashFind", "spacedFind", "quotedFind"
      ]
    }
  want: |
    # Converted from JSON Schema
    .open: true
    email: +Str ~"\S+@\S+"
    zip: +Str ~"{digit}{5}"
    externalURL: +Str ~"https?://.*" 1+ -"External URL for Harbor"
    spaced: +Str ~"a b"
    quoted:
      .type: +Str
      .match: a "b
    simpleFind: +Str ~~"{upper}{lower}+"
    slashFind: +Str ~~"foo/bar"
    spacedFind: +Str ~~"foo bar"
    quotedFind:
      .type: +Str
      .find: foo "bar

- name: digit-pattern-normalization-roundtrip
  cmnd: sh -c 'bin/ysd -Rq -f jsc - && echo OK'
  stdi: |
    {
      "type": "object",
      "properties": {
        "code": {
          "type": "string",
          "pattern": "^\\d+[0-9]$"
        }
      },
      "required": ["code"],
      "additionalProperties": false
    }
  want: |
    OK

done:
