#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: expanded-short-formats
  cmnd: |
    sh -c '
      input="foo: +Str"
      printf "%s\n" "$input" | bin/ysc -t ysxj -C -
      printf "%s\n" "$input" | bin/ysc -t ysxy -
    '
  want: |
    {"foo":{".base":"+Str"}}
    foo:
      .base: +Str

- name: expanded-long-formats
  cmnd: |
    sh -c '
      input="foo: +Str"
      printf "%s\n" "$input" | bin/ysc -t ysx.json -C -
      printf "%s\n" "$input" | bin/ysc -t ysx.yaml -
    '
  want: |
    {"foo":{".base":"+Str"}}
    foo:
      .base: +Str

- name: json-schema-to-expanded-yaml
  cmnd: bin/ysc -f jsc -t ysxy -
  stdi: |
    {
      "properties": {"foo": {"type": "string"}},
      "required": ["foo"]
    }
  want: |
    foo:
      .base: +Str

- name: expanded-output-extension-inference
  cmnd: |
    sh -c '
      dir=$(mktemp -d)
      printf "foo: +Str\n" | bin/ysc -C -o "$dir/out.ysx.json"
      cat "$dir/out.ysx.json"
      printf "foo: +Str\n" | bin/ysc -o "$dir/out.ysx.yaml"
      cat "$dir/out.ysx.yaml"
      rm -r "$dir"
    '
  want: |
    {"foo":{".base":"+Str"}}
    foo:
      .base: +Str

- name: json-schema-input-extension-inference
  cmnd: |
    sh -c '
      dir=$(mktemp -d)
      printf "%s\n" \
        "{\"properties\":{\"foo\":{\"type\":\"string\"}}}" \
        > "$dir/in.schema.json"
      bin/ysc -t ysxy "$dir/in.schema.json"
      rm -r "$dir"
    '
  want: |
    foo?:
      .base: +Str

- name: expanded-from-values
  cmnd: |
    sh -c '
      printf "%s\n" "{\"foo\":{\".base\":\"+Str\"}}" |
        bin/ysc -f ysxj -t jsc -C - | fold -w 72
      printf "foo:\n  .base: +Str\n" |
        bin/ysc -f ysxy -t jsc -C - | fold -w 72
    '
  want: |
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"o
    bject","properties":{"foo":{"type":"string"}},"required":["foo"],"additi
    onalProperties":false}
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"o
    bject","properties":{"foo":{"type":"string"}},"required":["foo"],"additi
    onalProperties":false}

- name: expanded-input-extension-inference
  cmnd: |
    sh -c '
      dir=$(mktemp -d)
      printf "foo:\n  .base: +Str\n" > "$dir/in.ysx.yaml"
      printf "%s\n" "{\"foo\":{\".base\":\"+Str\"}}" \
        > "$dir/in.ysx.json"
      bin/ysc -t ysxj -C "$dir/in.ysx.yaml"
      bin/ysc -t ysxy "$dir/in.ysx.json"
      rm -r "$dir"
    '
  want: |
    {"foo":{".base":"+Str"}}
    foo:
      .base: +Str

- name: reject-old-expanded-formats
  cmnd: |
    sh -c '
      printf "foo: +Str\n" |
        bin/ysc -t yscj - 2>&1 | sed -n 1p
      printf "foo: +Str\n" |
        bin/ysc -t ysc.json - 2>&1 | sed -n 1p
      printf "foo: +Str\n" |
        bin/ysc -f yscj -t jsc - 2>&1 | sed -n 1p
      printf "foo: +Str\n" |
        bin/ysc -f ysc.json -t jsc - 2>&1 | sed -n 1p
    '
  want: |
    ysc: unsupported format: yscj; use ysxj
    ysc: unsupported format: ysc.json; use ysx.json
    ysc: unsupported format: yscj; use ysxj
    ysc: unsupported format: ysc.json; use ysx.json

- name: reject-old-expanded-extension
  cmnd: |
    sh -c '
      dir=$(mktemp -d)
      printf "%s\n" "{\"foo\":{\".base\":\"+Str\"}}" > "$dir/in.ysc.json"
      bin/ysc -t jsc "$dir/in.ysc.json" 2>&1 | sed -n 1p
      printf "foo: +Str\n" |
        bin/ysc -o "$dir/out.ysc.json" 2>&1 | sed -n 1p
      rm -r "$dir"
    '
  want: |
    ysc: unsupported file extension: .ysc.json; use .ysx.json
    ysc: unsupported file extension: .ysc.json; use .ysx.json

done:
