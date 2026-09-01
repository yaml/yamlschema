#!/usr/bin/env python3

import os
from pathlib import Path

from setuptools.command.bdist_wheel import bdist_wheel
from setuptools import setup


base_dir = Path(__file__).parent
version = (base_dir / "Version").read_text(encoding="utf-8").strip()


class PlatformWheel(bdist_wheel):
    """Build a Python-independent wheel containing a native library."""

    def finalize_options(self):
        super().finalize_options()
        self.root_is_pure = False

    def get_tag(self):
        return "py3", "none", os.environ["YSD_WHEEL_PLAT"]


setup(
    name="ysd",
    version=version,
    description="Python bindings for YAMLSchema",
    long_description=(base_dir / "ReadMe.md").read_text(encoding="utf-8"),
    long_description_content_type="text/markdown",
    url="https://github.com/yaml/yamlschema",
    packages=["ysd"],
    package_dir={"": "lib"},
    package_data={"ysd": ["libysd.*"]},
    include_package_data=True,
    cmdclass={"bdist_wheel": PlatformWheel},
    python_requires=">=3.10, <4",
    classifiers=[
        "Development Status :: 3 - Alpha",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Programming Language :: Python :: 3.12",
        "Programming Language :: Python :: 3.13",
        "Programming Language :: Python :: 3.14",
        "Topic :: Software Development :: Libraries",
    ],
)
