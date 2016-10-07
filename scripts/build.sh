#!/usr/bin/env bash

if [[ $OSTYPE == darwin* ]]; then
  cd swift && xcodebuild && mv build/release/aperture main && rm -r build;
fi
