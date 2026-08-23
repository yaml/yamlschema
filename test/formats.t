#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: expanded-short-formats
  cmnd: |
    sh -c '
      input="foo: +Str"
      printf "%s\n" "$input" | bin/ysd -t ysdc.json -C -
      printf "%s\n" "$input" | bin/ysd -t ysdc -
    '
  want: |
    {"foo":"+Str"}
    foo: +Str

- name: expanded-long-formats
  cmnd: |
    sh -c '
      input="foo: +Str"
      printf "%s\n" "$input" | bin/ysd -t ysdc.json -C -
      printf "%s\n" "$input" | bin/ysd -t ysdc.yaml -
    '
  want: |
    {"foo":"+Str"}
    foo: +Str

- name: collapse-sole-type-pairs
  cmnd: bin/ysd -f ysdc -t ysdc -
  stdi: |
    namespace?:
      .type: +Str
    topologySpreadConstraints?:
      .type: +Any[]
    labels?:
      +Str:
        .type: +Str
    annotated?:
      .type: +Str
      .desc: Kept explicit
  want: |
    namespace?: +Str
    topologySpreadConstraints?: +Any[]
    labels?:
      +Str: +Str
    annotated?:
      .type: +Str
      .desc: Kept explicit

- name: succinct-short-and-long-formats
  cmnd: |
    sh -c '
      input="{\"properties\":{\"foo\":{\"type\":\"string\"}}}"
      printf "%s\n" "$input" | bin/ysd -t ysd -
      printf "%s\n" "$input" | bin/ysd -t ysd.yaml -
    '
  want: |
    # Converted from JSON Schema
    .open: true
    foo?: +Str
    # Converted from JSON Schema
    .open: true
    foo?: +Str

- name: json-schema-short-and-long-formats
  cmnd: |
    sh -c '
      input="foo: +Str"
      printf "%s\n" "$input" | bin/ysd -t jsc -C - |
        ys -e "say: IN:read:json/load.type"
      printf "%s\n" "$input" | bin/ysd -t schema.json -C - |
        ys -e "say: IN:read:json/load.type"
    '
  want: |
    object
    object

- name: all-short-and-long-input-formats
  cmnd: |
    sh -c '
      dsl="foo: +Str"
      canonical_yaml="foo:\n  .type: +Str"
      canonical_json="{\"foo\":{\".type\":\"+Str\"}}"
      json_schema="{\"properties\":{\"foo\":{\"type\":\"string\"}}}"
      for format in ysd ysd.yaml; do
        printf "%s\n" "$dsl" | bin/ysd -f "$format" -t jsc -C - |
          ys -e "say: IN:read:json/load.type"
      done
      for format in ysdc ysdc.yaml; do
        printf "%b\n" "$canonical_yaml" |
          bin/ysd -f "$format" -t jsc -C - |
          ys -e "say: IN:read:json/load.type"
      done
      for format in ysdc.json; do
        printf "%s\n" "$canonical_json" |
          bin/ysd -f "$format" -t jsc -C - |
          ys -e "say: IN:read:json/load.type"
      done
      for format in jsc schema.json; do
        printf "%s\n" "$json_schema" |
          bin/ysd -f "$format" -t ysdc.json -C - |
          jq -r ".\"foo?\""
      done
    '
  want: |
    object
    object
    object
    object
    object
    +Str
    +Str

- name: json-schema-to-expanded-yaml
  cmnd: bin/ysd -f jsc -t ysdc -
  stdi: |
    {
      "properties": {"foo": {"type": "string"}},
      "required": ["foo"]
    }
  want: |
    .open: true
    foo: +Str

- name: json-schema-to-json-schema
  cmnd: |
    sh -c '
      dir=$(mktemp -d)
      printf "%s\n" \
        "{\"title\":\"Harbor Next Helm Chart Values\",\"type\":\"object\"}" \
        > "$dir/values.schema.json"
      bin/ysd "$dir/values.schema.json" -t jsc -C
      rm -r "$dir"
    '
  want: |
    {"title":"Harbor Next Helm Chart Values","type":"object"}

- name: normalize-all-input-formats-to-json-schema
  cmnd: |
    sh -c '
      dir=$(mktemp -d)
      printf "foo: +Str\n" > "$dir/in.ysd.yaml"
      printf "foo:\n  .type: +Str\n" > "$dir/in.ysdc.yaml"
      printf "%s\n" "{\"foo\":{\".type\":\"+Str\"}}" \
        > "$dir/in.ysdc.json"
      printf "%s\n" \
        "{\"type\":\"object\",\"properties\":{\"foo\":{\"type\":\"string\"}},\
    \"required\":[\"foo\"],\"additionalProperties\":false}" \
        > "$dir/in.schema.json"
      for file in \
        "$dir/in.ysd.yaml" \
        "$dir/in.ysdc.yaml" \
        "$dir/in.ysdc.json" \
        "$dir/in.schema.json"
      do
        bin/ysd -NC "$file"
      done
      rm -r "$dir"
    '
  want: |
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"object","properties":{"foo":{"type":"string"}},"required":["foo"],"additionalProperties":false}
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"object","properties":{"foo":{"type":"string"}},"required":["foo"],"additionalProperties":false}
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"object","properties":{"foo":{"type":"string"}},"required":["foo"],"additionalProperties":false}
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"object","properties":{"foo":{"type":"string"}},"required":["foo"],"additionalProperties":false}

- name: expanded-output-extension-inference
  cmnd: |
    sh -c '
      dir=$(mktemp -d)
      printf "foo: +Str\n" | bin/ysd -C -o "$dir/out.ysdc.json"
      cat "$dir/out.ysdc.json"
      printf "foo: +Str\n" | bin/ysd -o "$dir/out.ysdc.yaml"
      cat "$dir/out.ysdc.yaml"
      rm -r "$dir"
    '
  want: |
    {"foo":"+Str"}
    foo: +Str

- name: succinct-output-extension-inference
  cmnd: |
    sh -c '
      dir=$(mktemp -d)
      printf "%s\n" \
        "{\"properties\":{\"foo\":{\"type\":\"string\"}}}" |
        bin/ysd -o "$dir/out.ysd.yaml"
      cat "$dir/out.ysd.yaml"
      rm -r "$dir"
    '
  want: |
    # Converted from JSON Schema
    .open: true
    foo?: +Str

- name: json-schema-input-extension-inference
  cmnd: |
    sh -c '
      dir=$(mktemp -d)
      printf "%s\n" \
        "{\"properties\":{\"foo\":{\"type\":\"string\"}}}" \
        > "$dir/in.schema.json"
      bin/ysd -t ysdc "$dir/in.schema.json"
      rm -r "$dir"
    '
  want: |
    .open: true
    foo?: +Str

- name: expanded-from-values
  cmnd: |
    sh -c '
      printf "%s\n" "{\"foo\":{\".type\":\"+Str\"}}" |
        bin/ysd -f ysdc.json -t jsc -C - | fold -w 72
      printf "foo:\n  .type: +Str\n" |
        bin/ysd -f ysdc -t jsc -C - | fold -w 72
    '
  want: |
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"o
    bject","properties":{"foo":{"type":"string"}},"required":["foo"],"additi
    onalProperties":false}
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"o
    bject","properties":{"foo":{"type":"string"}},"required":["foo"],"additi
    onalProperties":false}

- name: canonical-like-input
  cmnd: |
    sh -c '
      input="foo:\n  .like: /a.*b/"
      printf "%b\n" "$input" | bin/ysd -f ysdc -t ysdc.json -C -
      printf "%b\n" "$input" | bin/ysd -f ysdc -t jsc -C - |
        ys -e "say: IN:read:json/load.properties.foo.pattern"
      printf "%s\n" "{\"foo\":{\".like\":\"^x$\"}}" |
        bin/ysd -f ysdc.json -t jsc -C - |
        ys -e "say: IN:read:json/load.properties.foo.pattern"
    '
  want: |
    {"foo":{".type":"+Str",".like":"\/a.*b\/"}}
    /a.*b/
    ^x$

- name: reject-regex-directives-in-wrong-source-form
  cmnd: |
    sh -c '
      printf "foo:\n  .like: a\n" |
        bin/ysd -f ysd -t ysdc.json -C - 2>&1 | sed -n 1p
      for key in .match .find; do
        printf "foo:\n  %s: a\n" "$key" |
          bin/ysd -f ysdc -t jsc -C - 2>&1 | sed -n 1p
      done
    '
  want: |
    ysd: unsupported YSD directive: .like; use .match or .find
    ysd: unsupported YSDC directive: .match; use .like
    ysd: unsupported YSDC directive: .find; use .like

- name: expanded-input-extension-inference
  cmnd: |
    sh -c '
      dir=$(mktemp -d)
      printf "foo:\n  .type: +Str\n" > "$dir/in.ysdc.yaml"
      printf "%s\n" "{\"foo\":{\".type\":\"+Str\"}}" \
        > "$dir/in.ysdc.json"
      bin/ysd -t ysdc.json -C "$dir/in.ysdc.yaml"
      bin/ysd -t ysdc "$dir/in.ysdc.json"
      rm -r "$dir"
    '
  want: |
    {"foo":"+Str"}
    foo: +Str

- name: succinct-input-extension-inference
  cmnd: |
    sh -c '
      dir=$(mktemp -d)
      printf "foo?: +Str\n" > "$dir/in.ysd.yaml"
      bin/ysd -t jsc -C "$dir/in.ysd.yaml" |
        ys -e "say: IN:read:json/load.properties.foo.type"
      rm -r "$dir"
    '
  want: |
    string

- name: reject-old-format-slugs
  cmnd: |
    sh -c '
      for format in ysc yscy yscj ysc.yaml ysc.json ysxy ysxj; do
        printf "foo: +Str\n" |
          bin/ysd -t "$format" - 2>&1 | sed -n 1p
      done
      for format in ysc yscy yscj ysc.yaml ysc.json ysxy ysxj; do
        printf "foo: +Str\n" |
          bin/ysd -f "$format" -t jsc - 2>&1 | sed -n 1p
      done
    '
  want: |
    ysd: unsupported format: ysc
    ysd: unsupported format: yscy
    ysd: unsupported format: yscj
    ysd: unsupported format: ysc.yaml
    ysd: unsupported format: ysc.json
    ysd: unsupported format: ysxy
    ysd: unsupported format: ysxj
    ysd: unsupported format: ysc
    ysd: unsupported format: yscy
    ysd: unsupported format: yscj
    ysd: unsupported format: ysc.yaml
    ysd: unsupported format: ysc.json
    ysd: unsupported format: ysxy
    ysd: unsupported format: ysxj

- name: reject-old-expanded-extension
  cmnd: |
    sh -c '
      dir=$(mktemp -d)
      for extension in ysc.yaml ysc.json ysx.yaml ysx.json; do
        printf "foo: +Str\n" > "$dir/in.$extension"
        bin/ysd -t jsc "$dir/in.$extension" 2>&1 | sed -n 1p
        printf "foo: +Str\n" |
          bin/ysd -o "$dir/out.$extension" 2>&1 | sed -n 1p
      done
      rm -r "$dir"
    '
  want: |
    ysd: unsupported file extension: .ysc.yaml
    ysd: unsupported file extension: .ysc.yaml
    ysd: unsupported file extension: .ysc.json
    ysd: unsupported file extension: .ysc.json
    ysd: unsupported file extension: .ysx.yaml
    ysd: unsupported file extension: .ysx.yaml
    ysd: unsupported file extension: .ysx.json
    ysd: unsupported file extension: .ysx.json

done:
