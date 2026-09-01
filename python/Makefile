R := https://github.com/makeplus/makes
M := ../.cache/makes
$(shell [ -d '$M' ] || git clone -q $R '$M')

include $M/init.mk

export UV_CACHE_DIR := $(abspath ../.cache/uv)
PYTHON-VENV := $(CURDIR)/.venv

include $M/python.mk
include $M/clean.mk
include $M/shell.mk

WHEEL-PLAT-linux-int64 := manylinux_2_28_x86_64
WHEEL-PLAT-linux-arm64 := manylinux_2_28_aarch64
WHEEL-PLAT-macos-int64 := macosx_13_0_x86_64
WHEEL-PLAT-macos-arm64 := macosx_14_0_arm64
WHEEL-PLAT-windows-int64 := win_amd64
WHEEL-PLAT := $(WHEEL-PLAT-$(OS-ARCH))

NATIVE-LIB := ../libysd.$(SO)
PACKAGE-LIB := lib/ysd/libysd.$(SO)

PYTHON-DEPS := $(PYTHON-VENV)/.ysd-python-deps

test: $(PACKAGE-LIB) $(PYTHON-DEPS) Version
	$(VENV) && PYTHONPATH=lib python -m pytest test

wheel: $(PACKAGE-LIB) $(PYTHON-DEPS) Version
	@test -n '$(WHEEL-PLAT)' || { \
	  echo 'No Python wheel platform tag for $(OS-ARCH)' >&2; \
	  exit 1; \
	}
	$(VENV) && YSD_WHEEL_PLAT='$(WHEEL-PLAT)' \
	  python -m build --wheel --no-isolation

sdist: $(PYTHON-DEPS) Version
	$(VENV) && python -m build --sdist

publish-wheels: $(PYTHON-DEPS)
	@test -n "$$(find dist -maxdepth 1 -name '*.whl' -print -quit)" || { \
	  echo 'No Python wheels found in python/dist' >&2; \
	  exit 1; \
	}
	$(VENV) && \
	  TWINE_USERNAME=__token__ \
	  TWINE_PASSWORD="$${PYPI_API_TOKEN:?PYPI_API_TOKEN is required}" \
	  twine upload --skip-existing dist/*.whl

$(PACKAGE-LIB): $(NATIVE-LIB)
	cp -p '$<' '$@'

$(NATIVE-LIB):
	$(MAKE) -C .. libysd

$(PYTHON-DEPS): $(PYTHON-VENV)
	$(UV) pip install --python $(PYTHON-VENV) \
	  build pytest setuptools twine wheel
	touch '$@'

Version: ../Makefile
	$(MAKE) -C .. --no-print-directory -s version > '$@'

MAKES-CLEAN += \
  .pytest_cache build dist Version \
  lib/ysd/libysd.* lib/ysd/__pycache__ test/__pycache__ \
  lib/ysd.egg-info

MAKES-REALCLEAN += .venv
