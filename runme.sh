#!/bin/bash

perl logdraw.pl -SRCDIR sample_gpx -TRACK_COLOR "#FFFFFF00" -IMAGE_SIZE 1000
perl logdraw.pl -SRCDIR sample_gpx -TRACK_COLOR "#FFFFFF00" -TRACK_THICKNESS 10 -OUTPUT thick.png -IMAGE_SIZE 1000

matrix=""
matrix="${matrix} 0.0 0.0 0.0 0.0 0.0"
matrix="${matrix} 0.0 0.3 0.0 0.0 0.0"
matrix="${matrix} 0.0 0.0 0.6 0.0 0.0"
matrix="${matrix} 0.0 0.0 0.0 0.0 0.0"
matrix="${matrix} 0.0 0.0 0.0 0.0 0.0"

convert thick.png -gaussian-blur 30x10 -color-matrix "${matrix}" halo.png
convert halo.png output.png output.png -composite final.png
