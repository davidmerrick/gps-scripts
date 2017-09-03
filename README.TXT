Perl Scripts for GPS Track Visualization
========================================

This folder contains several Perl scripts for processing and plotting
GPS track data in .GPX format.

The list of options and their default values for each script are listed
below.  Most of the options are self-explanatory.  If you are not sure
for the value of an option, leave the default value - it will work fine
in most cases.


### logdraw.pl

This script takes as an input a folder containing a number of .gpx log
files and produces a .PNG file.  The default name for the input folder
is "input/".  The default name for the output PNG is, well, "output.png".

Usage:

  perl logdraw.pl [-OPTION value]...

Example:

  perl logdraw.pl -SRCDIR "my_gps_logs_folder" -OUTPUT "gpsmap.png"

Options:

  BACKGROUND_COLOR     = #000000
  BORDER               = 10
  BREAK_DISTANCE       = 0.8
  COLOR_RANGE_STEPS    = 128
  CROP                 =
  DEBUG                = 0
  GEOM_OVERRIDES       =
  GRID_COLOR           =
  IMAGE_SIZE           = 2000
  MINMAX_DISABLING_NPOINTS =
  MINMAX_ONLY          =
  MINSPEED             = 0
  MAXSPEED             = 0
  OUTPUT               = output.png
  RUNNERS              =
  RUNNERS_OUTPUT       =
  RUNNER_COLOR         = #FFFFFF00
  RUNNER_DIAMETER      = 5
  RUNNER_TAIL_LENGTH   = 1000
  SRCDIR               = input
  TRACK_COLOR          = #FFFFFF78
  TRACK_THICKNESS      = 1

The SRCDIR parameter can contain more than one folder with GPX files -
use "," to separate folder names in this parameter.

Note that the IMAGE_SIZE parameter is just a single number.  The thing
is that because the GPS data distribution may vary, the proportions of
the output map (horizontal/vertical) may change.  In other words, for
some tracks the output map might be pretty much a square, for other -
a horizontally or vertically elongated rectangle.  The IMAGE_SIZE param
specifies the side of the map in pixels, if this map was a square (say
value of "2000" will correspond to an image of 2000x2000 pixels).  If
the map happens to be elongated, the dimensions will be changed but the
area would be preserved (in other words, a value of "2000" will get you
a map with the same area as a 2000x2000 pixel square).

If you want to be really particular what portion of the map you want
and what the exact dimensions of the output image should be, use the
GEOM_OVERRIDES parameter.  It is a comma-separated string in the
following format:

  imgWidth,imgHeight,cenLon,cenLat,pixelsPerDegreeLat,rotationAngle

Here you can specify image dimensions, map center, scale (in pixels
per degree of latitude) and even rotation angle in degrees.

The MINSPEED and MAXSPEED parameters limit the selection to parts of
the track that were traversed in a given speed range. The values are
expected to be given in km/h. If any (or both) values are 0, the
particular limit is not enforced (for example, specifying just
"-MINSPEED 5" means that everything above 5 km/h will be drawn.


### logmerge.pl

This script merges several .GPX files into one.  Sometimes my Garmin
messes up a GPX file - when the battery is low and the unit shuts down
it often leaves garbage in the GPX XML.  Such a file cannot be opened
with most programs I use.  The logmerge.pl script comes handy in this
case too, because it cleans up the data and produces a valid GPX file
even from corrupted data.

Usage:

  perl logmerge.pl <folder_with_gpx_files> <output_gpx_file>

Example:

  perl logmerge.pl my_gps_logs_folder merged.gpx



How about the "glowing halo" effect?
====================================

The scripts are producing just a line drawing from a GPX script - if
you want to add a "glowing halo" around the track, as on the sample
images on the website (http://avtanski.net/gps), you need to do some
image processing.

If you have ImageMagick (or are willing to install it - it's free),
then you can use the sample script (runme.bat) that is included in
this archive.


Thanks
======

Thanks to Jonas Häggqvist for the idea and code changes for using
multiple folders in the SRCDIR parameter, and also for the runme.sh
script.

