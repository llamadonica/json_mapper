#!/bin/bash

# Copyright 2017 the json_mapper authors. Please see the AUTHORS file for details. All rights reserved. Use of this
# source code is governed by an MIT-style license. See the LICENSE file for details.

set -e

echo "Running dartanalyzer..."
dartanalyzer $DARTANALYZER_FLAGS \
    lib/json_mapper.dart \
    lib/transformer.dart \
    lib/metadata.dart \
    lib/mapper_factory.dart

echo "Checking dartfmt"
if [[ $(dartfmt -n --set-exit-if-changed lib/ test/) ]]; then
    echo "Failed dartfmt. Run "'"'"dartfmt -w lib/ test/"'"'
    exit 1
fi

echo "Running tests"
pub run test

echo "Running transformer tests"
pub serve --port=8080 &>/dev/null &
sleep 2
pub run test --pub-serve=8080
kill -SIGINT %1


if [ "$COVERALLS_TOKEN" ] && [ "$TRAVIS_DART_VERSION" = "stable" ]; then
    echo "Running coverage"
    pub global activate dart_coveralls
    pub global run dart_coveralls report \
        --retry 2 \
        --exclude-test-files \
        --debug \
        test/mapper_test.dart
fi
