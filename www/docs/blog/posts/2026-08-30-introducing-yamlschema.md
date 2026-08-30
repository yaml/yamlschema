---
title: Introducing YAMLSchema
date: 2026-08-30
slug: introducing-yamlschema
authors: [ingydotnet]
categories: [YAMLSchema]
---

YAML has always needed a schema language.
Of course there have been many attempts to create a schema language for YAML,
but never an official one from the YAML organization.

JSON Schema has been around for a while and is widely used not only for JSON,
but also for YAML, which makes sense since YAML is a superset of JSON.
Sadly JSON Schema requires a lot of definition for not so much effect.
YAML is all about getting the most out of the least, so it is time for a schema
language that is designed for YAML.

**YAMLSchema** is a new schema language for YAML (and JSON) data.
While it is still in its early stages, it is intended to be a very rich,
expressive, extensible, easy-to-read, and easy-to-write schema language.
Like YAML is a superset of JSON, YAMLSchema intends to be a superset of JSON
Schema.
Not a syntactic superset, but a semantic superset.

<!-- more -->

To get YAMLSchema off the ground, we are aiming to make it compatible with most
of JSON Schema.
While we'd like it to be a superset, we are starting by making it a _matching_
set.

YAMLSchema has implemented a CLI tool called `ysd` (YAMLSchema Definition) that
can convert JSON Schema to YAMLSchema and back.
It can already go back and forth (roundtrip) without any semantic loss for many
common JSON Schema files.

We have a [demos](../../demo/index.md) page that uses the `ysd` code compiled to
WebAssembly to convert back and forth between JSON Schema and YAMLSchema and
reveal the differences between the two.
The page has about a dozen examples of JSON Schema and YAMLSchema, and they all
roundtrip back and forth without any semantic loss.
These examples include basics from the [offical JSON Schema examples](
https://json-schema.org/learn/json-schema-examples) page, as well as some more
complex examples including:

* The [OpenAPI 3.0 schema](
  https://github.com/OAI/OpenAPI-Specification/blob/main/_archive_/schemas/v3.0/schema.yaml)
* [Harbor Next Helm Chart Values schema](
  https://github.com/container-registry/harbor-next/blob/main/deploy/chart/values.schema.json)
* [NetBox generated schema](
  https://raw.githubusercontent.com/netbox-community/netbox/refs/heads/main/contrib/generated_schema.json)

## Schema That Mimics the Data

If you had some YAML data that looked like this:

```yaml
name: John Doe
age: 42
married: true
address:
  street: 123 Main St
  city: Anytown
  state: CA
  postal code: 90909
attributes:
  strength: 8.4
  dexterity: 7.5
  wisdom: 3
```

One clear way to define a schema for this data is to mimic the data itself, like
this:

```yaml
name: string
age: integer
married: boolean
address:
  street: string
  city: string
  state: string
  postal code: string
attributes:
  strength: number
  dexterity: number
  wisdom: number
```

Essentially, this is how YAMLSchema works.
The YAMLSchema version of that would actually look like this:

```yaml
name: +Str
age: +Int
married: +Bool
address:
  street: +Str
  city: +Str
  state: +Str
  postal code: +Str
attributes:
  strength: +Num
  dexterity: +Num
  wisdom: +Num
```

<details>
  <summary>Click to see the JSON Schema equivalent</summary>

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "properties": {
    "name": {
      "type": "string"
    },
    "age": {
      "type": "integer"
    },
    "married": {
      "type": "boolean"
    },
    "address": {
      "type": "object",
      "properties": {
        "street": {
          "type": "string"
        },
        "city": {
          "type": "string"
        },
        "state": {
          "type": "string"
        },
        "postal code": {
          "type": "string"
        }
      },
      "required": [
        "street",
        "city",
        "state",
        "postal code"
      ],
      "additionalProperties": false
    },
    "attributes": {
      "type": "object",
      "properties": {
        "strength": {
          "type": "number"
        },
        "dexterity": {
          "type": "number"
        },
        "wisdom": {
          "type": "number"
        }
      },
      "required": [
        "strength",
        "dexterity",
        "wisdom"
      ],
      "additionalProperties": false
    }
  },
  "required": [
    "name",
    "age",
    "married",
    "address",
    "attributes"
  ],
  "additionalProperties": false
}
```
</details>

A simple mapping schema is defined as a similar mapping with the keys being the
same as the data and the values being the types of the data.
In the example above, the values are "type references" to types defined
somewhere else.
The ones used here are the built-in types defined in YAMLSchema, but you can
also define your own types and reference them in the same way.

If we wanted to make the `address` type reusable, we could define it as a type
and reference it in the schema like this:

```yaml
name: +Str
age: +Int
married: +Bool
address: +address
attributes:
  strength: +Num
  dexterity: +Num
  wisdom: +Num

+address:
  street: +Str
  city: +Str
  state: +Str
  postal code: +Str
```

<details>
  <summary>Click to see the JSON Schema equivalent</summary>

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "properties": {
    "name": {
      "type": "string"
    },
    "age": {
      "type": "integer"
    },
    "married": {
      "type": "boolean"
    },
    "address": {
      "$ref": "#/$defs/address"
    },
    "attributes": {
      "type": "object",
      "properties": {
        "strength": {
          "type": "number"
        },
        "dexterity": {
          "type": "number"
        },
        "wisdom": {
          "type": "number"
        }
      },
      "required": [
        "strength",
        "dexterity",
        "wisdom"
      ],
      "additionalProperties": false
    }
  },
  "required": [
    "name",
    "age",
    "married",
    "address",
    "attributes"
  ],
  "additionalProperties": false,
  "$defs": {
    "address": {
      "type": "object",
      "properties": {
        "street": {
          "type": "string"
        },
        "city": {
          "type": "string"
        },
        "state": {
          "type": "string"
        },
        "postal code": {
          "type": "string"
        }
      },
      "required": [
        "street",
        "city",
        "state",
        "postal code"
      ],
      "additionalProperties": false
    }
  }
}
```
</details>

Top-level keys that start with a `+` are the names of defined "named types" that
can be referenced elsewhere in the schema.
Everything else defines the schema's "root type".
Named types can be defined anywhere in the schema, either before or after the
root type or the other types that reference them.
Built-in type names start with a capital letter, while user-defined type names
start with a lowercase letter.


## Let's Get Specific

The simple mapping schema is a good starting point, but it is not very specific.
This seems to be a common problem with JSON Schema schemas in the wild.
For example, the most popular value type in JSON Schema is `string`, but there
are many different kinds of strings.
A binary blob, the text of War and Peace, a URL, the empty string...
These are all strings, but none of them are appropriate for a "name" field.

JSON Schema does let you get more specific, but it requires a lot of extra
definition to do so.
This JSON is already getting unwieldy, so it doesn't give you much incentive to
get more specific.

YAMLSchema wants to help you get very specific with very little definition.
That way you and others can easily read and understand everything the schema is
trying to say about the data.

Let's make our schema more specific:

```yaml
name: +Str 3-30 ~"{upper}{lower}+ {upper}{lower}+"
age: +Int 0..120
married?: +Bool =false
address: +address
phone: +Str[$1-3] ~"{plus}1-{digit}{3}-{digit}{3}-{digit}{4}"
attributes?:
  strength: +Num 0..10
  dexterity: +Num 0..10
  wisdom: +Num 0..10

+address:
  street: +Str
    ~"({digit}+ )?{upper}{lower}+( {upper}{lower}+)*
      (St|Ave|Blvd|Rd|Ln|Dr)\.?"
  city: +Str ~"{upper}{lower}+( {upper}{lower}+)*"
  state: +Str ~"{upper}{2}"
  postal code: +Str ~"{digit}{5}(-{digit}{4})?"
```

<details>
  <summary>Click to see the JSON Schema equivalent</summary>

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "properties": {
    "name": {
      "type": "string",
      "minLength": 3,
      "maxLength": 30,
      "pattern": "^[A-Z][a-z]+ [A-Z][a-z]+$"
    },
    "age": {
      "type": "integer",
      "minimum": 0,
      "maximum": 120
    },
    "married": {
      "type": "boolean",
      "default": false
    },
    "address": {
      "$ref": "#/$defs/address"
    },
    "phone": {
      "anyOf": [
        {
          "type": "string",
          "pattern": "^\\+1-\\d{3}-\\d{3}-\\d{4}$"
        },
        {
          "type": "array",
          "items": {
            "type": "string",
            "pattern": "^\\+1-\\d{3}-\\d{3}-\\d{4}$"
          },
          "minItems": 1,
          "maxItems": 3
        }
      ]
    },
    "attributes": {
      "type": "object",
      "properties": {
        "strength": {
          "type": "number",
          "minimum": 0,
          "maximum": 10
        },
        "dexterity": {
          "type": "number",
          "minimum": 0,
          "maximum": 10
        },
        "wisdom": {
          "type": "number",
          "minimum": 0,
          "maximum": 10
        }
      },
      "required": [
        "strength",
        "dexterity",
        "wisdom"
      ],
      "additionalProperties": false
    }
  },
  "required": [
    "name",
    "age",
    "address",
    "phone"
  ],
  "additionalProperties": false,
  "$defs": {
    "address": {
      "type": "object",
      "properties": {
        "street": {
          "type": "string",
          "pattern": "^^(\\d+ )?[A-Z][a-z]+( [A-Z][a-z]+)* (St|Ave|Blvd|Rd|Ln|Dr)\\.?$$"
        },
        "city": {
          "type": "string",
          "pattern": "^[A-Z][a-z]+( [A-Z][a-z]+)*$"
        },
        "state": {
          "type": "string",
          "pattern": "^[A-Z]{2}$"
        },
        "postal code": {
          "type": "string",
          "pattern": "^\\d{5}(-\\d{4})?$"
        }
      },
      "required": [
        "street",
        "city",
        "state",
        "postal code"
      ],
      "additionalProperties": false
    }
  }
}
```
</details>

Here we added come new constraints:

* `?` means the field is optional
* `=` means the field has a default value
* Regular expressions can be used to constrain strings
* `[]` means the field is an array (added a "phone" field for this)
    * `1-3` means the array must have between 1 and 3 items
    * `$` means the value can also be a single item instead of an array
* Strings can have sizes `min-max`
* Numbers can have ranges `min..max`

This is just a glimpse of what YAMLSchema can alrady do.

Less than 20 lines of YAMLSchema expressed the same thing as over 100 lines of
JSON Schema.
Using the `ysd` tool to convert this schema back and forth between YAMLSchema
and JSON Schema results in no semantic loss.
That means you can use YAMLSchema to define clear and precise schemas for your
data and use the same JSON Schema validators that you are already using to
validate your data.

That's the point, for now.
Define more about your data with less definition, and make it easy to read and
understand for you and others who look at it tomorrow.



## On YAMLScript

[YAMLScript](https://yamlscript.org) is a full featured programming language
with a YAML syntax.
It can be used both for general programming and for extending YAML files
dynamically.
It ships dynamic YAML loader modules to [over 30 programming languages](
https://yamlscript.org/doc/bindings/#currently-available-libraries).

The `ysd` tool happens to be [written in YAMLScript](
https://github.com/yaml/yamlschema/blob/main/bin/ysd).
The main reason for this is that YAMLScript can be compiled to native binary
executables, shared libraries, and WebAssembly modules.

That's what the YAMLSchema project is doing:

1. Compiling the `ysd` tool to a native binary executable [releases](
   https://github.com/yaml/yamlschema/releases) for many
   operating systems and architectures.
2. Compiling to a shared library to create FFI bindings for languages like
   [Python](https://pypi.org/project/yamlschema-yaml/).
3. Compiling to WebAssembly to run in the browser, which is what the [demos](
   ../../demo/index.md) page does.

But the potential of YAMLScript can go much deeper with regards to YAMLSchema!

YAMLSchema defines types.
You can think of types as functions.

Right now, the way to use YAMLSchema is to convert it to JSON Schema and use a
JSON Schema validator to validate your data.
But soon YAMLSchema will provide its own validator.

The validator will work by converting the YAMLSchema data into validation
functions and then applying the root function to the data.

If YAMLSchema adds YAMLScript to the mix, then the sky is the limit to what kind
of constraints you can define for your data.
This could include things like cross-field validation, conditional validation,
and even dynamic validation based on external data sources.
Also YAMLScript compiles to Go code under the hood, so potentially any Go
library could be used to extend the validation capabilities of YAMLSchema.

As complex as this sounds, at the end of the day you are just writing concise
YAML files to define your data and its constraints.


## Beyond Validation

When you define data precisely, there is so much more you can do with the schema
than just use it to validate data.

You can use it to generate code, documentation, user interfaces, line protocols,
fuzz-testing data generators, and more.
This is what OpenAPI has been doing for years, but applied much more broadly
than just REST APIs.


## Join Us!

The YAMLSchema project is all very new.
We'd like to hear your thoughts.
If you are interested in helping to define the YAMLSchema language, please join
us.
You can start at the [YAMLSchema GitHub repository](
https://github.com/yaml/yamlschema).
