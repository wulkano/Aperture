#!/usr/bin/env bash

if [ "$#" -ne 2 ] && [ "$#" -ne 3 ]; then
  echo "usage: main destinationPath fps [crop rect coordinates]"
  echo "examples: main ./file.mp4 30"
  echo "          main ./file.mp4 30 0:0:100:100"
  exit 1
fi

destination="$1"
fps="$2"
originX=0
originY=0

width=1024
height=768

if [ "$#" == 3 ]; then
  tmp="$3" # I'm not sure how to do the splitting without assigning this to a variable
  coordinates=(${tmp//:/ })
  if [ ${#coordinates[@]} -ne 4 ]; then
      echo "The coordinates for the crop rect must be in the format 'originX:originY:width:height'"
      exit 2
  fi
  originX="${coordinates[0]}"
  originY="${coordinates[1]}"
  width="${coordinates[2]}"
  height="${coordinates[3]}"
fi

echo "R" # we switch over to ffmpeg now

ffmpeg -video_size "$width"x"$height" -framerate 25 -f x11grab -i ":0.0+$originX,$originY" -y "$destination" &

read -p "Waiting for enter.." # when enter is pressed, we tell ffmpeg to stop

kill "$!"
