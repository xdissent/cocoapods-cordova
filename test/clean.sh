#!/bin/bash

rm -rf app/{plugins,platforms} plugins/{A,B}/dist plugins/{A/src/ios,B}/Pods
git checkout .