#!/bin/bash

/usr/src/app/bin/logdraw.pl -SRCDIR /usr/src/app/gpx -TRACK_COLOR "#FFFFFF00" -IMAGE_SIZE 1000 -OUTPUT /usr/src/app/output/output.png
/usr/src/app/bin/logdraw.pl -SRCDIR /usr/src/app/gpx -TRACK_COLOR "#FFFFFF00" -TRACK_THICKNESS 10 -OUTPUT /usr/src/app/output/thick.png -IMAGE_SIZE 1000

matrix=""
matrix="${matrix} 0.0 0.0 0.0 0.0 0.0"
matrix="${matrix} 0.0 0.3 0.0 0.0 0.0"
matrix="${matrix} 0.0 0.0 0.6 0.0 0.0"
matrix="${matrix} 0.0 0.0 0.0 0.0 0.0"
matrix="${matrix} 0.0 0.0 0.0 0.0 0.0"

convert /usr/src/app/output/thick.png -gaussian-blur 30x10 -color-matrix "${matrix}" /usr/src/app/output/halo.png
convert /usr/src/app/output/halo.png /usr/src/app/output/output.png /usr/src/app/output/output.png -composite /usr/src/app/output/final.png
