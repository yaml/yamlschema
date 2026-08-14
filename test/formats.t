#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: expanded-short-formats
  cmnd: |
    sh -c '
      input="foo: +Str"
      printf "%s\n" "$input" | bin/ysc -t yscj -C -
      printf "%s\n" "$input" | bin/ysc -t yscy -
    '
  want: |
    {"foo":"+Str"}
    foo: +Str

- name: expanded-long-formats
  cmnd: |
    sh -c '
      input="foo: +Str"
      printf "%s\n" "$input" | bin/ysc -t ysc.json -C -
      printf "%s\n" "$input" | bin/ysc -t ysc.yaml -
    '
  want: |
    {"foo":"+Str"}
    foo: +Str

- name: collapse-sole-type-pairs
  cmnd: bin/ysc -f yscy -t yscy -
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
      printf "%s\n" "$input" | bin/ysc -t ysd -
      printf "%s\n" "$input" | bin/ysc -t ysd.yaml -
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
      printf "%s\n" "$input" | bin/ysc -t jsc -C - |
        ys -e "say: IN:read:json/load.type"
      printf "%s\n" "$input" | bin/ysc -t schema.json -C - |
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
        printf "%s\n" "$dsl" | bin/ysc -f "$format" -t jsc -C - |
          ys -e "say: IN:read:json/load.type"
      done
      for format in yscy ysc.yaml; do
        printf "%b\n" "$canonical_yaml" |
          bin/ysc -f "$format" -t jsc -C - |
          ys -e "say: IN:read:json/load.type"
      done
      for format in yscj ysc.json; do
        printf "%s\n" "$canonical_json" |
          bin/ysc -f "$format" -t jsc -C - |
          ys -e "say: IN:read:json/load.type"
      done
      for format in jsc schema.json; do
        printf "%s\n" "$json_schema" |
          bin/ysc -f "$format" -t yscj -C - |
          jq -r ".\"foo?\""
      done
    '
  want: |
    object
    object
    object
    object
    object
    object
    +Str
    +Str

- name: json-schema-to-expanded-yaml
  cmnd: bin/ysc -f jsc -t yscy -
  stdi: |
    {
      "properties": {"foo": {"type": "string"}},
      "required": ["foo"]
    }
  want: |
    .open: true
    foo: +Str

- name: expanded-output-extension-inference
  cmnd: |
    sh -c '
      dir=$(mktemp -d)
      printf "foo: +Str\n" | bin/ysc -C -o "$dir/out.ysc.json"
      cat "$dir/out.ysc.json"
      printf "foo: +Str\n" | bin/ysc -o "$dir/out.ysc.yaml"
      cat "$dir/out.ysc.yaml"
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
        bin/ysc -o "$dir/out.ysd.yaml"
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
      bin/ysc -t yscy "$dir/in.schema.json"
      rm -r "$dir"
    '
  want: |
    .open: true
    foo?: +Str

- name: expanded-from-values
  cmnd: |
    sh -c '
      printf "%s\n" "{\"foo\":{\".type\":\"+Str\"}}" |
        bin/ysc -f yscj -t jsc -C - | fold -w 72
      printf "foo:\n  .type: +Str\n" |
        bin/ysc -f yscy -t jsc -C - | fold -w 72
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
      printf "%b\n" "$input" | bin/ysc -f yscy -t yscj -C -
      printf "%b\n" "$input" | bin/ysc -f yscy -t jsc -C - |
        ys -e "say: IN:read:json/load.properties.foo.pattern"
      printf "%s\n" "{\"foo\":{\".like\":\"^x$\"}}" |
        bin/ysc -f yscj -t jsc -C - |
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
        bin/ysc -f ysd -t yscj -C - 2>&1 | sed -n 1p
      for key in .match .find; do
        printf "foo:\n  %s: a\n" "$key" |
          bin/ysc -f yscy -t jsc -C - 2>&1 | sed -n 1p
      done
    '
  want: |
    ysc: unsupported YSD directive: .like; use .match or .find
    ysc: unsupported YSC directive: .match; use .like
    ysc: unsupported YSC directive: .find; use .like

- name: expanded-input-extension-inference
  cmnd: |
    sh -c '
      dir=$(mktemp -d)
      printf "foo:\n  .type: +Str\n" > "$dir/in.ysc.yaml"
      printf "%s\n" "{\"foo\":{\".type\":\"+Str\"}}" \
        > "$dir/in.ysc.json"
      bin/ysc -t yscj -C "$dir/in.ysc.yaml"
      bin/ysc -t yscy "$dir/in.ysc.json"
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
      bin/ysc -t jsc -C "$dir/in.ysd.yaml" |
        ys -e "say: IN:read:json/load.properties.foo.type"
      rm -r "$dir"
    '
  want: |
    string

- name: reject-old-format-slugs
  cmnd: |
    sh -c '
      for format in ysc ysxy ysxj; do
        printf "foo: +Str\n" |
          bin/ysc -t "$format" - 2>&1 | sed -n 1p
      done
      for format in ysc ysxy ysxj; do
        printf "foo: +Str\n" |
          bin/ysc -f "$format" -t jsc - 2>&1 | sed -n 1p
      done
    '
  want: |
    ysc: unsupported format: ysc
    ysc: unsupported format: ysxy
    ysc: unsupported format: ysxj
    ysc: unsupported format: ysc
    ysc: unsupported format: ysxy
    ysc: unsupported format: ysxj

- name: reject-old-expanded-extension
  cmnd: |
    sh -c '
      dir=$(mktemp -d)
      for extension in ysx.yaml ysx.json; do
        printf "foo: +Str\n" > "$dir/in.$extension"
        bin/ysc -t jsc "$dir/in.$extension" 2>&1 | sed -n 1p
        printf "foo: +Str\n" |
          bin/ysc -o "$dir/out.$extension" 2>&1 | sed -n 1p
      done
      rm -r "$dir"
    '
  want: |
    ysc: unsupported file extension: .ysx.yaml
    ysc: unsupported file extension: .ysx.yaml
    ysc: unsupported file extension: .ysx.json
    ysc: unsupported file extension: .ysx.json

done:
