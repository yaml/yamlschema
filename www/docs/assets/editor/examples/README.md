# JSON Schema examples

These schemas come from the official
[JSON Schema examples](https://json-schema.org/learn/json-schema-examples)
page.
They were copied from the
[JSON Schema website repository](https://github.com/json-schema-org/website)
at commit `6c0b00cfc3484d7d34bd7e935dfa7d1465924fe4`.

The Device Type page code block contains three schema documents.
Only its first document, the top-level device schema, is included here.

The examples are distributed under the BSD 3-Clause License in
[LICENSE](LICENSE).

`petstore.schema.json` is derived from the
[ReadMe OpenAPI PetStore example](https://github.com/readmeio/oas-examples/blob/060d4ffbbe63003f923c8cd7268ee39a495cf21f/3.0/json/petstore.json).
The `Pet` component is the root schema and the other component schemas are in
`$defs`.
OpenAPI references were rewritten as JSON Schema references, and OpenAPI-only
`xml` and `example` metadata was removed.
The source is distributed under the MIT License in
[LICENSE-READMEIO](LICENSE-READMEIO).

`openapi-3-schema.schema.json` is the official
[JSON Schema for OpenAPI 3.0](https://spec.openapis.org/oas/3.0/schema/2024-10-18.html),
copied from OpenAPI Initiative repository commit
`b43f858dc9131f4111e72457d48e781549561c9a`.
It is distributed under the Apache License 2.0 in
[LICENSE-OAI](LICENSE-OAI).
