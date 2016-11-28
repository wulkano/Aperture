#!/usr/bin/env bash

arecord -l | grep "card [0-9]:" | sed "s/,.*//" | sed "s/: /:/g" | sed "s/card //g" | uniq
