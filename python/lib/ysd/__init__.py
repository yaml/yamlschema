"""Python bindings for the bundled libysd shared library."""

from __future__ import annotations

import ctypes
import json
import sys
import threading
from importlib.metadata import PackageNotFoundError
from importlib.metadata import version as package_version
from importlib.resources import files
from typing import Any


try:
    __version__ = package_version("ysd")
except PackageNotFoundError:
    __version__ = "0+unknown"


class YAMLSchemaError(RuntimeError):
    """An error returned by the native YAMLSchema converter."""

    def __init__(self, operation: str, message: str):
        self.operation = operation
        self.message = message
        super().__init__(f"{operation}: {message}")


def _library_filename() -> str:
    if sys.platform == "linux":
        return "libysd.so"
    if sys.platform == "darwin":
        return "libysd.dylib"
    if sys.platform == "win32":
        return "libysd.dll"
    raise YAMLSchemaError("load", f"unsupported platform '{sys.platform}'")


def _load_c_free():
    if sys.platform == "win32":
        names = ("ucrtbase.dll", "msvcrt.dll")
    else:
        names = (None,)

    for name in names:
        try:
            runtime = ctypes.CDLL(name)
            free = runtime.free
            free.argtypes = [ctypes.c_void_p]
            free.restype = None
            return free
        except (AttributeError, OSError):
            continue
    raise YAMLSchemaError("load", "cannot locate the platform C free function")


_library_path = files(__package__).joinpath(_library_filename())
try:
    _library = ctypes.CDLL(str(_library_path))
except OSError as error:
    raise YAMLSchemaError("load", str(error)) from error

_native_call = _library.ysd_call
_native_call.argtypes = [ctypes.c_char_p, ctypes.c_char_p]
_native_call.restype = ctypes.c_void_p

_native_version = _library.ysd_version
_native_version.argtypes = []
_native_version.restype = ctypes.c_void_p

_free = _load_c_free()
_call_lock = threading.RLock()


def _take_string(pointer: int | None, operation: str) -> str:
    if not pointer:
        raise YAMLSchemaError(operation, "native call returned a null pointer")
    try:
        return ctypes.string_at(pointer).decode("utf-8")
    finally:
        _free(pointer)


def _schema_text(schema: Any) -> str:
    if isinstance(schema, str):
        return schema
    try:
        return json.dumps(schema, ensure_ascii=False, separators=(",", ":"))
    except (TypeError, ValueError) as error:
        raise YAMLSchemaError("encode", str(error)) from error


class YAMLSchema:
    """Convert and roundtrip YAMLSchema and JSON Schema documents."""

    def _call(self, operation: str, source: str) -> Any:
        if "\0" in source:
            raise YAMLSchemaError(operation, "input contains a null byte")
        operation_bytes = operation.encode("utf-8")
        source_bytes = source.encode("utf-8")
        with _call_lock:
            pointer = _native_call(operation_bytes, source_bytes)
            response_text = _take_string(pointer, operation)

        try:
            response = json.loads(response_text)
        except json.JSONDecodeError as error:
            raise YAMLSchemaError(
                operation, "native call returned invalid JSON"
            ) from error

        if not isinstance(response, dict):
            raise YAMLSchemaError(operation, "native response is not an object")
        if not response.get("ok"):
            raise YAMLSchemaError(
                operation, response.get("error", "unknown native error")
            )
        if "value" not in response:
            raise YAMLSchemaError(operation, "native response has no value")
        return response["value"]

    def version(self) -> str:
        """Return the bundled native library version."""
        with _call_lock:
            return _take_string(_native_version(), "version")

    def normalize_json_schema_text(self, schema: Any) -> str:
        """Normalize a JSON Schema and return JSON text."""
        return self._call("json-schema-normalize", _schema_text(schema))

    def normalize_json_schema(self, schema: Any) -> Any:
        """Normalize a JSON Schema and return a Python value."""
        return json.loads(self.normalize_json_schema_text(schema))

    def json_schema_to_ysd(self, schema: Any, *, strict: bool = False) -> str:
        """Convert JSON Schema to concise YAMLSchema text."""
        suffix = "-strict" if strict else ""
        return self._call(
            f"json-schema-to-ysd{suffix}", _schema_text(schema)
        )

    def json_schema_to_ysdc(self, schema: Any, *, strict: bool = False) -> str:
        """Convert JSON Schema to canonical YAMLSchema YAML text."""
        suffix = "-strict" if strict else ""
        return self._call(
            f"json-schema-to-ysdc{suffix}", _schema_text(schema)
        )

    def json_schema_to_ysdc_data(
        self, schema: Any, *, strict: bool = False
    ) -> Any:
        """Convert JSON Schema to decoded canonical YAMLSchema data."""
        suffix = "-strict" if strict else ""
        text = self._call(
            f"json-schema-to-ysdc-json{suffix}", _schema_text(schema)
        )
        return json.loads(text)

    def ysd_to_json_schema_text(self, source: str) -> str:
        """Convert concise YAMLSchema to JSON Schema text."""
        return self._call("ysd-to-json-schema", source)

    def ysd_to_json_schema(self, source: str) -> Any:
        """Convert concise YAMLSchema to a Python JSON Schema value."""
        return json.loads(self.ysd_to_json_schema_text(source))

    def json_schema_roundtrip(self, schema: Any) -> dict[str, Any]:
        """Return the JSON Schema roundtrip report."""
        text = self._call(
            "json-schema-roundtrip-report", _schema_text(schema)
        )
        return json.loads(text)

    def json_schema_roundtrip_works(self, schema: Any) -> bool:
        """Return whether a JSON Schema roundtrip is lossless."""
        return bool(
            self._call(
                "json-schema-roundtrip-works", _schema_text(schema)
            )
        )

    def ysd_roundtrip(self, source: str) -> dict[str, Any]:
        """Return the concise YAMLSchema roundtrip report."""
        return json.loads(self._call("ysd-roundtrip-report", source))

    def ysd_roundtrip_works(self, source: str) -> bool:
        """Return whether a concise YAMLSchema roundtrip is lossless."""
        return bool(self._call("ysd-roundtrip-works", source))


__all__ = ["YAMLSchema", "YAMLSchemaError", "__version__"]
