# ysd for Python

The `ysd` package converts between JSON Schema and YAMLSchema using the native
`libysd` library bundled in each wheel.

```python
from ysd import YAMLSchema

ysd = YAMLSchema()

schema = {
    "type": "object",
    "properties": {"name": {"type": "string"}},
    "required": ["name"],
}

source = ysd.json_schema_to_ysd(schema)
roundtripped = ysd.ysd_to_json_schema(source)
```

Methods that accept JSON Schema accept Python JSON-compatible values, JSON
text, or YAML text.
Methods returning JSON Schema have object and `_text` forms.

```python
yaml_schema = """\
type: object
properties:
  name:
    type: string
required: [name]
"""

source = ysd.json_schema_to_ysd(yaml_schema)
```

## Validation

The package performs conversion rather than instance validation.
Its results can be used directly with the Python `jsonschema` package:

```python
from jsonschema import Draft202012Validator

Draft202012Validator(roundtripped).validate({"name": "Ada"})
```

The package requires Python 3.10 or newer.
