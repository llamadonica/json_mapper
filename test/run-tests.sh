#!/bin/bash

# Copyright 2017 the json_mapper authors. Please see the AUTHORS file for details. All rights reserved. Use of this
# source code is governed by an MIT-style license. See the LICENSE file for details.

set -e

cleanup_1()
{
  echo "Cleaning up..."
  kill -SIGINT %1
}
cleanup_2() 
{
  cleanup_1
  kill -SIGINT %2
}


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

export DISPLAY=:99.0
if [ -f /etc/init.d/xvfb ]; then
  sh -e /etc/init.d/xvfb start
else
  Xvfb :99 -ac -screen 0 1024x768x24 &
  trap cleanup_1 EXIT
fi
t=0; until (xdpyinfo -display :99 &>/dev/null || test $t -gt 20); do sleep 1; let t=$t+1; done

echo "Running tests"
pub run test

echo "Running transformer tests"
pub serve --port=8080 test &> /tmp/pub-serve &
if [ -f /etc/init.d/xvfb ]; then
  trap cleanup_1 EXIT
else
  trap cleanup_2 EXIT
fi
timeout --signal=SIGINT 10 tail -f -n1 /tmp/pub-serve | grep -qe "Build completed"
pub run test --pub-serve=8080
kill -SIGINT %1
if [ ! -f /etc/init.d/xvfb ]; then
  kill -SIGINT %2
fi

if [ "$COVERALLS_TOKEN" ] && [ "$TRAVIS_DART_VERSION" = "stable" ]; then
    echo "Running coverage"
    pub global activate dart_coveralls
    pub global run dart_coveralls report \
        --retry 2 \
        --exclude-test-files \
        --debug \
        --token="$COVERALLS_TOKEN" \
        test/mapper_test.dart
fi
