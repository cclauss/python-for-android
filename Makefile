VIRTUAL_ENV ?= venv
PIP=$(VIRTUAL_ENV)/bin/pip
TOX=`which tox`
ACTIVATE=$(VIRTUAL_ENV)/bin/activate
PYTHON=$(VIRTUAL_ENV)/bin/python
DOCKER_IMAGE=kivy/python-for-android
DOCKER_TAG=latest
ANDROID_SDK_HOME ?= $(HOME)/.android/android-sdk
ANDROID_NDK_HOME ?= $(HOME)/.android/android-ndk
ANDROID_NDK_HOME_LEGACY ?= $(HOME)/.android/android-ndk-legacy
REBUILD_UPDATED_RECIPES_EXTRA_ARGS ?= ''


all: virtualenv

$(VIRTUAL_ENV):
	python3 -m venv $(VIRTUAL_ENV)
	$(PIP) install Cython==0.29.36
	$(PIP) install -e .

virtualenv: $(VIRTUAL_ENV)

# ignores test_pythonpackage.py since it runs for too long
test:
	$(TOX) -- tests/ --ignore tests/test_pythonpackage.py

# Also install and configure rust
rebuild_updated_recipes: virtualenv
	. $(ACTIVATE) && \
	curl https://sh.rustup.rs -sSf | sh -s -- -y && \
	. "$(HOME)/.cargo/env" && \
	rustup target list && \
	ANDROID_SDK_HOME=$(ANDROID_SDK_HOME) ANDROID_NDK_HOME=$(ANDROID_NDK_HOME) \
	$(PYTHON) ci/rebuild_updated_recipes.py $(REBUILD_UPDATED_RECIPES_EXTRA_ARGS)

# make ARCH=armeabi-v7a,arm64-v8a ARTIFACT=apk BOOTSTRAP=sdl2 MODE=debug REQUIREMENTS=python testapps-generic
testapps-generic: virtualenv
	@if [ -z "$(ARCH)" ]; then echo "ARCH is not set"; exit 1; fi
	@if [ -z "$(ARTIFACT)" ]; then echo "ARTIFACT is not set"; exit 1; fi
	@if [ -z "$(BOOTSTRAP)" ]; then echo "BOOTSTRAP is not set"; exit 1; fi
	@if [ -z "$(MODE)" ]; then echo "MODE is not set"; exit 1; fi
	@if [ -z "$(REQUIREMENTS)" ]; then echo "REQUIREMENTS is not set"; exit 1; fi
	@ARCH_FLAGS=$$(echo "$(ARCH)" | tr ',' ' ' | sed 's/\([^ ]\+\)/--arch=\1/g'); \
	. $(ACTIVATE) && cd testapps/on_device_unit_tests/ && \
    python setup.py $(ARTIFACT) \
    --sdk-dir $(ANDROID_SDK_HOME) \
    --ndk-dir $(ANDROID_NDK_HOME) \
    $$ARCH_FLAGS --bootstrap $(BOOTSTRAP) --$(MODE) --requirements $(REQUIREMENTS)

testapps-with-numpy: testapps-with-numpy/debug/apk testapps-with-numpy/release/aab

# testapps-with-numpy/MODE/ARTIFACT
testapps-with-numpy/%: virtualenv
	$(eval MODE := $(word 2, $(subst /, ,$@)))
	$(eval ARTIFACT := $(word 3, $(subst /, ,$@)))
	@echo Building testapps-with-numpy for $(MODE) mode and $(ARTIFACT) artifact
	. $(ACTIVATE) && cd testapps/on_device_unit_tests/ && \
    python setup.py $(ARTIFACT) --$(MODE) --sdk-dir $(ANDROID_SDK_HOME) --ndk-dir $(ANDROID_NDK_HOME) \
    --requirements libffi,sdl2,pyjnius,kivy,python3,openssl,requests,urllib3,chardet,idna,sqlite3,setuptools,numpy \
    --arch=armeabi-v7a --arch=arm64-v8a --arch=x86_64 --arch=x86 \
	--permission "(name=android.permission.WRITE_EXTERNAL_STORAGE;maxSdkVersion=18)" --permission "(name=android.permission.INTERNET)"

testapps-with-scipy: testapps-with-scipy/debug/apk testapps-with-scipy/release/aab

# testapps-with-scipy/MODE/ARTIFACT
testapps-with-scipy/%: virtualenv
	$(eval MODE := $(word 2, $(subst /, ,$@)))
	$(eval ARTIFACT := $(word 3, $(subst /, ,$@)))
	@echo Building testapps-with-scipy for $(MODE) mode and $(ARTIFACT) artifact
	. $(ACTIVATE) && cd testapps/on_device_unit_tests/ && \
	export LEGACY_NDK=$(ANDROID_NDK_HOME_LEGACY)  && \
    python setup.py $(ARTIFACT) --$(MODE) --sdk-dir $(ANDROID_SDK_HOME) --ndk-dir $(ANDROID_NDK_HOME) \
			--requirements python3,scipy,kivy \
    --arch=armeabi-v7a --arch=arm64-v8a

testapps-webview: testapps-webview/debug/apk testapps-webview/release/aab

# testapps-webview/MODE/ARTIFACT
testapps-webview/%: virtualenv
	$(eval MODE := $(word 2, $(subst /, ,$@)))
	$(eval ARTIFACT := $(word 3, $(subst /, ,$@)))
	@echo Building testapps-webview for $(MODE) mode and $(ARTIFACT) artifact
	. $(ACTIVATE) && cd testapps/on_device_unit_tests/ && \
    python setup.py $(ARTIFACT) --$(MODE) --sdk-dir $(ANDROID_SDK_HOME) --ndk-dir $(ANDROID_NDK_HOME) \
    --bootstrap webview \
    --requirements sqlite3,libffi,openssl,pyjnius,flask,python3,genericndkbuild \
    --arch=armeabi-v7a --arch=arm64-v8a --arch=x86_64 --arch=x86

testapps-service_library-aar: virtualenv 
	. $(ACTIVATE) && cd testapps/on_device_unit_tests/ && \
    python setup.py aar --sdk-dir $(ANDROID_SDK_HOME) --ndk-dir $(ANDROID_NDK_HOME) \
    --bootstrap service_library \
    --requirements python3 \
    --arch=arm64-v8a --arch=x86 --release

testapps-qt: testapps-qt/debug/apk testapps-qt/release/aab

# testapps-webview/MODE/ARTIFACT
testapps-qt/%: virtualenv
	$(eval MODE := $(word 2, $(subst /, ,$@)))
	$(eval ARTIFACT := $(word 3, $(subst /, ,$@)))
	@echo Building testapps-qt for $(MODE) mode and $(ARTIFACT) artifact
	. $(ACTIVATE) && cd testapps/on_device_unit_tests/ && \
    python setup.py $(ARTIFACT) --$(MODE) --sdk-dir $(ANDROID_SDK_HOME) --ndk-dir $(ANDROID_NDK_HOME) \
    --bootstrap qt \
    --requirements python3,shiboken6,pyside6 \
    --arch=arm64-v8a \
	--local-recipes ./test_qt/recipes \
	--qt-libs Core \
	--load-local-libs plugins_platforms_qtforandroid \
	--add-jar ./test_qt/jar/PySide6/jar/Qt6Android.jar \
	--add-jar ./test_qt/jar/PySide6/jar/Qt6AndroidBindings.jar \
	--permission android.permission.WRITE_EXTERNAL_STORAGE \
	--permission android.permission.INTERNET

testapps/%: virtualenv
	$(eval $@_APP_ARCH := $(shell basename $*))
	. $(ACTIVATE) && cd testapps/on_device_unit_tests/ && \
    python setup.py apk --sdk-dir $(ANDROID_SDK_HOME) --ndk-dir $(ANDROID_NDK_HOME) \
    --arch=$($@_APP_ARCH)

clean:
	find . -type d -name "__pycache__" -exec rm -r {} +
	find . -type d -name "*.egg-info" -exec rm -r {} +

clean/all: clean
	rm -rf $(VIRTUAL_ENV) .tox/

docker/pull:
	docker pull $(DOCKER_IMAGE):latest || true

docker/build:
	docker build --cache-from=$(DOCKER_IMAGE) --tag=$(DOCKER_IMAGE) .

docker/login:
	@echo $$DOCKERHUB_TOKEN | docker login --username $(DOCKERHUB_USERNAME) --password-stdin

docker/tag:
	docker tag $(DOCKER_IMAGE):latest $(DOCKER_IMAGE):$(DOCKER_TAG)

docker/push:
	docker push $(DOCKER_IMAGE):$(DOCKER_TAG)

docker/run/test: docker/build
	docker run --rm --env-file=.env $(DOCKER_IMAGE) 'make test'

docker/run/command: docker/build
	docker run --rm --env-file=.env $(DOCKER_IMAGE) /bin/sh -c "$(COMMAND)"

docker/run/make/rebuild_updated_recipes: docker/build
	docker run --name p4a-latest -e REBUILD_UPDATED_RECIPES_EXTRA_ARGS --env-file=.env $(DOCKER_IMAGE) make rebuild_updated_recipes

docker/run/make/%: docker/build
	docker run --rm --env-file=.env $(DOCKER_IMAGE) make $*

docker/run/shell: docker/build
	docker run --rm --env-file=.env -it $(DOCKER_IMAGE)
