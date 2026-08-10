#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: succinct-description-to-schema.json
  cmnd: bin/ysc -t schema.json -
  stdi: |
    repository?: +Str "Repository path without registry host"
    right: +Str "This isn't wrong"
    folded?: +Str
      "Description folded by YAML"
    possessive?: +Str "James'"
    escaped?: +Str "this:\ that \# the other"
    literal?: +Str "foo\ bar and foo\nbar and foo\tbar"
    dbRepository?: +Str[] "Repositories for the vulnerability DB"
    quoted?: 'Description'
  want: |
    {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "type": "object",
      "properties": {
        "dbRepository": {
          "description": "Repositories for the vulnerability DB",
          "type": "array",
          "items": {
            "type": "string"
          }
        },
        "escaped": {
          "description": "this: that # the other",
          "type": "string"
        },
        "folded": {
          "description": "Description folded by YAML",
          "type": "string"
        },
        "literal": {
          "description": "foo\\ bar and foo\\nbar and foo\\tbar",
          "type": "string"
        },
        "possessive": {
          "description": "James'",
          "type": "string"
        },
        "quoted": {
          "const": "Description"
        },
        "repository": {
          "description": "Repository path without registry host",
          "type": "string"
        },
        "right": {
          "description": "This isn't wrong",
          "type": "string"
        }
      },
      "required": [
        "right"
      ],
      "additionalProperties": false
    }

- name: schema.json-to-succinct-description
  cmnd: bin/ysc -t ysd.yaml -
  stdi: |
    {
      "properties": {
        "dbRepository": {
          "type": "array",
          "items": {"type": "string"},
          "description": "Repositories for the vulnerability DB"
        },
        "enabled": {
          "type": "boolean",
          "description": "Pod-level TLS"
        },
        "repository": {
          "type": "string",
          "description": "Repository path without registry host"
        },
        "right": {
          "type": "string",
          "description": "This isn't wrong"
        },
        "colon": {
          "type": "string",
          "description": "Unsafe: colon"
        },
        "hash": {
          "type": "string",
          "description": "Unsafe # hash"
        }
      }
    }
  want: |
    dbRepository?: +Str[] "Repositories for the vulnerability DB"
    enabled?: +Bool "Pod-level TLS"
    repository?: +Str "Repository path without registry host"
    right?: +Str "This isn't wrong"
    colon?: +Str "Unsafe:\ colon"
    hash?: +Str "Unsafe \# hash"

done:
