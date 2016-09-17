#!/usr/bin/env bash

ffmpeg -y -i $1 -crf 28 -preset ultrafast -b:v 2000k $2
