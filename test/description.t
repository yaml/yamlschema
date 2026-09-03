#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: succinct-description-to-schema.json
  cmnd: bin/ysd -t jsc -
  stdi: |
    repository?: +Str --"Repository path without registry host"
    right: --"This isn't wrong" +Str
    folded?: +Str
      --"Description folded by YAML"
    possessive?: +Str --"James'"
    escaped?: +Str --"this:\ that \# the other"
    literal?: +Str --"foo\ bar and foo\nbar and foo\tbar"
    dbRepository?: --"Repositories for the vulnerability DB" +Str[]
    middle?: +Str --"Description before size" 1-40
    quoted?: 'Description'
  want: |
    {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "right"
      ],
      "properties": {
        "repository": {
          "description": "Repository path without registry host",
          "type": "string"
        },
        "right": {
          "description": "This isn't wrong",
          "type": "string"
        },
        "folded": {
          "description": "Description folded by YAML",
          "type": "string"
        },
        "possessive": {
          "description": "James'",
          "type": "string"
        },
        "escaped": {
          "description": "this: that # the other",
          "type": "string"
        },
        "literal": {
          "description": "foo\\ bar and foo\\nbar and foo\\tbar",
          "type": "string"
        },
        "dbRepository": {
          "description": "Repositories for the vulnerability DB",
          "type": "array",
          "items": {
            "type": "string"
          }
        },
        "middle": {
          "description": "Description before size",
          "type": "string",
          "minLength": 1,
          "maxLength": 40
        },
        "quoted": {
          "const": "Description"
        }
      }
    }

- name: schema.json-to-succinct-description
  cmnd: bin/ysd -t ysd -
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
    # Converted from JSON Schema
    .open: true
    dbRepository?: +Str[] --"Repositories for the vulnerability DB"
    enabled?: +Bool --"Pod-level TLS"
    repository?: +Str --"Repository path without registry host"
    right?: +Str --"This isn't wrong"
    colon?: +Str --"Unsafe:\ colon"
    hash?: +Str --"Unsafe \# hash"

- name: description-compatibility-aliases
  cmnd: bin/ysd -t ysdc -Y -
  stdi: |
    trailing: +Str "Trailing alias"
    labeled: +Str desc:"Labeled alias"
    explicit:
      .desc: Block alias
      .type: +Str
  want: |
    trailing:
      .desc: Trailing alias
      .type: +Str
    labeled:
      .desc: Labeled alias
      .type: +Str
    explicit:
      .desc: Block alias
      .type: +Str

- name: marked-description-blocks
  cmnd: bin/ysd -t ysdc -Y -
  stdi: |
    --: Document description
    value:
      --: Value description
      .type: +Str
  want: |
    .desc: Document description
    value:
      .desc: Value description
      .type: +Str

- name: reject-invalid-description-markers
  cmnd: |
    sh -c '
      printf "foo:\n  --: Nope\n  .type: +Str\n" |
        bin/ysd -f ysdc -t jsc -C - 2>&1 |
        perl -ne "print if \$. == 1"
      printf "foo:\n  --: First\n  .desc: Second\n  .type: +Str\n" |
        bin/ysd -t jsc -C - 2>&1 |
        perl -ne "print if \$. == 1"
      printf "foo: +Str --broken\n" |
        bin/ysd -t jsc -C - 2>&1 |
        perl -ne "print if \$. == 1"
    '
  want: |
    ysd: unsupported .ysdc directive: --; use .desc
    ysd: duplicate yamlschema directive: .desc in description aliases
    ysd: invalid description clause; use --"description"

- name: description-marker-skips-passthrough-data
  cmnd: sh -c 'bin/ysd -f jsc -t ysd - 2>/dev/null'
  stdi: |
    {
      "properties": {
        "value": {
          "type": "object",
          "description": "Schema description",
          "examples": [{".desc": "Literal data key"}]
        }
      }
    }
  want: |
    # Converted from JSON Schema
    .open: true
    value?:
      --: Schema description
      .type: +Map{}
      .examples:
      - .desc: Literal data key

done:
