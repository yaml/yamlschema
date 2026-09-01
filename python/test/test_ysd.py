import json
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import pytest

from ysd import YAMLSchema, YAMLSchemaError


PERSON = {
    "type": "object",
    "properties": {"name": {"type": "string"}},
    "required": ["name"],
    "additionalProperties": False,
}

PERSON_YAML = """\
type: object
properties:
  name:
    type: string
required: [name]
additionalProperties: false
"""


@pytest.fixture(scope="module")
def ysd():
    return YAMLSchema()


def test_version(ysd):
    assert ysd.version() == Path("Version").read_text().strip()


def test_json_schema_objects_and_text(ysd):
    normalized = ysd.normalize_json_schema(PERSON)
    assert normalized["$schema"].endswith("2020-12/schema")
    assert {key: normalized[key] for key in PERSON} == PERSON
    text = ysd.normalize_json_schema_text(json.dumps(PERSON))
    assert json.loads(text) == normalized


def test_yaml_json_schema_text(ysd):
    normalized = ysd.normalize_json_schema(PERSON_YAML)
    assert {key: normalized[key] for key in PERSON} == PERSON
    normalized_text = ysd.normalize_json_schema_text(PERSON_YAML)
    assert json.loads(normalized_text) == normalized

    source = ysd.json_schema_to_ysd(PERSON_YAML)
    strict = ysd.json_schema_to_ysd(PERSON_YAML, strict=True)
    assert "name: +Str" in source
    assert "name: +Str" in strict
    assert ".open: true" not in strict
    assert ysd.json_schema_to_ysdc_data(PERSON_YAML)["name"] == "+Str"
    assert ysd.json_schema_roundtrip_works(PERSON_YAML)
    assert ysd.json_schema_roundtrip(PERSON_YAML)["works"] is True


def test_json_schema_to_ysd(ysd):
    source = ysd.json_schema_to_ysd(PERSON)
    assert "name: +Str" in source
    assert "+Str: +Any" not in source
    roundtripped = ysd.ysd_to_json_schema(source)
    assert {key: roundtripped[key] for key in PERSON} == PERSON


def test_strict_conversion(ysd):
    schema = {"type": "object", "properties": {"name": {"type": "string"}}}
    regular = ysd.json_schema_to_ysd(schema)
    strict = ysd.json_schema_to_ysd(schema, strict=True)
    assert ".open: true" in regular
    assert ".open: true" not in strict


def test_canonical_conversion(ysd):
    data = ysd.json_schema_to_ysdc_data(PERSON)
    assert data["name"] == "+Str"
    assert "name: +Str" in ysd.json_schema_to_ysdc(PERSON)


def test_boolean_schema(ysd):
    true_schema = ysd.ysd_to_json_schema(ysd.json_schema_to_ysd(True))
    false_schema = ysd.ysd_to_json_schema(ysd.json_schema_to_ysd(False))
    assert set(true_schema) == {"$schema"}
    assert false_schema["not"] == {}


def test_roundtrip_methods(ysd):
    assert ysd.json_schema_roundtrip_works(PERSON)
    assert ysd.json_schema_roundtrip(PERSON)["works"] is True
    source = ysd.json_schema_to_ysd(PERSON)
    assert ysd.ysd_roundtrip_works(source)
    assert ysd.ysd_roundtrip(source)["works"] is True


def test_unicode(ysd):
    schema = {"title": "München", "type": "string"}
    assert ysd.normalize_json_schema(schema)["title"] == "München"


def test_invalid_input(ysd):
    with pytest.raises(YAMLSchemaError, match="json-schema-normalize"):
        ysd.normalize_json_schema("not JSON")
    with pytest.raises(YAMLSchemaError, match="null byte"):
        ysd.ysd_to_json_schema("name: +Str\0")


def test_repeated_and_concurrent_calls(ysd):
    def convert(index):
        schema = {"title": f"Schema {index}", "type": "string"}
        return ysd.normalize_json_schema(schema)["title"]

    with ThreadPoolExecutor(max_workers=8) as pool:
        titles = list(pool.map(convert, range(100)))
    assert titles == [f"Schema {index}" for index in range(100)]
