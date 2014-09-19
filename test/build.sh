#!/bin/bash

pushd plugins/A
bundle install
bundle exec pod cordova
popd

pushd plugins/B
bundle install
bundle exec pod cordova
popd

pushd app
cordova plugin add ../plugins/A ../plugins/B
cordova build
popd