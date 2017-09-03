#!/usr/bin/perl -w
#
# Alexander Avtanski, 2011
#
# Thanks to Jonas Haggqvist for the idea and code changes regarding using
# multiple folders in the SRCDIR parameter.
#
# See http://avtanski.net/gps for information


use strict;
use GD;

my $DEG_TO_RAD = 3.14159/180;

my $cfg=&parseArgs(@ARGV);
&setDefaults($cfg);
&showSettings($cfg);
if ($cfg->{MINMAX_DISABLING_NPOINTS}) {
  $cfg->{NUMPOINTS}=$cfg->{MINMAX_DISABLING_NPOINTS};
} else {
  &minmaxFiles($cfg);
}
&calculateSizesAndScales($cfg);
exit 1 if $cfg->{MINMAX_ONLY};
&createImage($cfg);
&drawFiles($cfg);
&drawGrid($cfg);
&saveImage($cfg);
exit 1;

sub setDefaults {
  my ($cfg)=@_;
  $cfg->{SRCDIR}="input" unless defined $cfg->{SRCDIR};
  $cfg->{OUTPUT}="output.png" unless defined $cfg->{OUTPUT};
  $cfg->{RUNNERS_OUTPUT}="" unless defined $cfg->{RUNNERS_OUTPUT};
  $cfg->{BREAK_DISTANCE}=0.8 unless defined $cfg->{BREAK_DISTANCE} ;
  $cfg->{IMAGE_SIZE}=2000 unless defined $cfg->{IMAGE_SIZE};
  $cfg->{RUNNER_DIAMETER}=5 unless defined $cfg->{RUNNER_DIAMETER};
  $cfg->{BORDER}=10 unless defined $cfg->{BORDER};
  $cfg->{TRACK_COLOR}="#FFFFFF78" unless defined $cfg->{TRACK_COLOR};
  $cfg->{RUNNER_COLOR}="#FFFFFF00" unless defined $cfg->{RUNNER_COLOR};
  $cfg->{RUNNER_TAIL_LENGTH}="1000" unless defined $cfg->{RUNNER_TAIL_LENGTH};
  $cfg->{COLOR_RANGE_STEPS}="128" unless defined $cfg->{COLOR_RANGE_STEPS};
  $cfg->{TRACK_THICKNESS}=1 unless defined $cfg->{TRACK_THICKNESS};
  $cfg->{BACKGROUND_COLOR}="#000000" unless defined $cfg->{BACKGROUND_COLOR};
  $cfg->{GRID_COLOR}="" unless defined $cfg->{GRID_COLOR};
  $cfg->{DEBUG}="0" unless defined $cfg->{DEBUG};
  $cfg->{CROP}="" unless defined $cfg->{CROP};
  $cfg->{MINMAX_ONLY}="" unless defined $cfg->{MINMAX_ONLY};
  $cfg->{MINMAX_DISABLING_NPOINTS}="" unless defined $cfg->{MINMAX_DISABLING_NPOINTS};
  $cfg->{RUNNERS}="" unless defined $cfg->{RUNNERS};
  $cfg->{GEOM_OVERRIDES}="" unless defined $cfg->{GEOM_OVERRIDES};
  $cfg->{MINSPEED}=0 unless defined $cfg->{MINSPEED};
  $cfg->{MAXSPEED}=0 unless defined $cfg->{MAXSPEED};
}


sub showSettings {
  my ($settings)=@_;
  printf STDERR "Settings:\n\n";
  foreach my $key (sort keys %$settings) {
    printf STDERR "  %-20s = %s\n",$key,$settings->{$key};
  }
  printf STDERR "\n";
} 


sub minmaxFiles {
  my ($cfg)=@_;
  my $box = $cfg->{CROP};

  foreach my $dir (split(/,/, $cfg->{SRCDIR})) {
    opendir DIR,$dir or die "Cannot open the input folder '".$dir."'\n";
    my @files=readdir DIR;
    closedir DIR;
    $cfg->{POINTS}=[];
    foreach my $file (sort @files) {
      next unless $file=~/\.gpx$/;
      &minmaxFile($cfg,$dir."/".$file);
    }
  }

  if (defined $box and $box=~/([0-9.-]+),([0-9.-]+),([0-9.-]+),([0-9.-]+)/) {
    ($cfg->{MINLON},$cfg->{MINLAT},$cfg->{MAXLON},$cfg->{MAXLAT})=($1,$2,$3,$4);
  }

}


sub minmaxFile {
  my ($cfg, $fname)=@_;
  printf STDERR "MinMaxing %s...\n",$fname if $cfg->{DEBUG};
  my $points=$cfg->{POINTS};
  my $numPoints=0;
  open F,$fname or die "Cannot open '$fname' for reading.\n";
  while (<F>) {
    chomp;
    next unless /trkpt (lat|lon)="([0-9.-]+)" (lon|lat)="([0-9.-]+)"/;
    my $lat;
    my $lon;
    if ($1 eq "lat") {
      $lat=$2;
      $lon=$4;
    } else {
      $lat=$4;
      $lon=$2;
    }
    $_=<F>;
    if (/<ele>([0-9.-]+)<\/ele>/) {
      $_=<F>;
    }
    next unless /<time>([^<]+)<\/time>/;
    my $time=&parseTime($1);
    $cfg->{MINLAT}=$lat unless defined $cfg->{MINLAT} and $cfg->{MINLAT}<$lat;
    $cfg->{MINLON}=$lon unless defined $cfg->{MINLON} and $cfg->{MINLON}<$lon;
    $cfg->{MAXLAT}=$lat unless defined $cfg->{MAXLAT} and $cfg->{MAXLAT}>$lat;
    $cfg->{MAXLON}=$lon unless defined $cfg->{MAXLON} and $cfg->{MAXLON}>$lon;
    $cfg->{MINTIME}=$time unless defined $cfg->{MINTIME} and $cfg->{MINTIME} lt $time;
    $cfg->{MAXTIME}=$time unless defined $cfg->{MAXTIME} and $cfg->{MAXTIME} gt $time;
    $numPoints++;
  }
  close F;
  $cfg->{NUMPOINTS}=0  unless defined $cfg->{NUMPOINTS};
  $cfg->{NUMPOINTS}+=$numPoints;
}


sub calculateSizesAndScales {
  if (defined $cfg->{GEOM_OVERRIDES} and $cfg->{GEOM_OVERRIDES}=~/\d/) {
    $cfg->{GEOM_OVERRIDES}=~s/\s+//;
    my @cpa=split ",",$cfg->{GEOM_OVERRIDES};
    die "GEOM_OVERRIDES format error - must be a four element CSV: imgWidth,imgHeight,cenLon,cenLat,pixelsPerDegreeLat,rotationAngle.\n" unless $#cpa==5;
    ($cfg->{IMAGE_WIDTH},$cfg->{IMAGE_HEIGHT},$cfg->{CENLON},$cfg->{CENLAT},$cfg->{LATSCALE},$cfg->{ROT_ANGLE})=@cpa;
    my $lonCompression=cos($cfg->{CENLAT}*$DEG_TO_RAD);
    $cfg->{LONSCALE}=$cfg->{LATSCALE}*$lonCompression;
    my $halfLonSpan = 0.5*$cfg->{IMAGE_WIDTH}/$cfg->{LONSCALE};
    $cfg->{MINLON}=$cfg->{CENLON}-$halfLonSpan;
    $cfg->{MAXLON}=$cfg->{CENLON}+$halfLonSpan;
    my $halfLatSpan = 0.5*$cfg->{IMAGE_HEIGHT}/$cfg->{LATSCALE};
    $cfg->{MINLAT}=$cfg->{CENLAT}-$halfLatSpan;
    $cfg->{MAXLAT}=$cfg->{CENLAT}+$halfLatSpan;
  } else {
    $cfg->{CENLON}=($cfg->{MINLON}+$cfg->{MAXLON})/2;
    $cfg->{CENLAT}=($cfg->{MINLAT}+$cfg->{MAXLAT})/2;
    my $lonCompression=cos($cfg->{CENLAT}*$DEG_TO_RAD);
    my $dLon=($cfg->{MAXLON}-$cfg->{MINLON})*$lonCompression;
    my $dLat=$cfg->{MAXLAT}-$cfg->{MINLAT};
    my $drawableWidth = $cfg->{IMAGE_SIZE}*sqrt($dLon/$dLat);
    my $drawableHeight = $cfg->{IMAGE_SIZE}*sqrt($dLat/$dLon);
    $cfg->{IMAGE_WIDTH}=sprintf "%d",$drawableWidth+2*$cfg->{BORDER};
    $cfg->{IMAGE_HEIGHT}=sprintf "%d",$drawableHeight+2*$cfg->{BORDER};
    $cfg->{LONSCALE}=$drawableWidth/$dLon*$lonCompression;
    $cfg->{LATSCALE}=$drawableHeight/$dLat;
    $cfg->{ROT_ANGLE}=0;
  }
  if ($cfg->{RUNNERS}) {
    my @runners=split /,/,$cfg->{RUNNERS};
    $cfg->{RUNNER_LIST}=\@runners;
  }
  printf STDERR "Number of points:     %d\n",$cfg->{NUMPOINTS};
  printf STDERR "Timestamp range:      %s to %s\n",$cfg->{MINTIME},$cfg->{MAXTIME} if defined $cfg->{MINTIME} and defined $cfg->{MAXTIME};
  printf STDERR "Lon/Lat Bounding Box: %f/%f to %f/%f\n",$cfg->{MINLON},$cfg->{MINLAT},$cfg->{MAXLON},$cfg->{MAXLAT};
  printf STDERR "Lon/Lat Center: %f/%f\n",$cfg->{CENLON},$cfg->{CENLAT};
  printf STDERR "Lon/Lat Scales: %f/%f\n",$cfg->{LONSCALE},$cfg->{LATSCALE};
  printf STDERR "Image Size: %d x %d\n",$cfg->{IMAGE_WIDTH},$cfg->{IMAGE_HEIGHT};
  printf STDERR "Rotation angle: %f\n",$cfg->{ROT_ANGLE};
}


sub createImage {
  my ($cfg)=@_;
  $cfg->{IMAGE}=GD::Image->newTrueColor($cfg->{IMAGE_WIDTH},$cfg->{IMAGE_HEIGHT});
  $cfg->{IMAGE}->alphaBlending(1);
  $cfg->{IMAGE}->setThickness($cfg->{TRACK_THICKNESS});

  if ($cfg->{RUNNERS_OUTPUT}) {
    $cfg->{RUNNERS_IMAGE}=GD::Image->newTrueColor($cfg->{IMAGE_WIDTH},$cfg->{IMAGE_HEIGHT});
    $cfg->{RUNNERS_IMAGE}->alphaBlending(0);
  }

  &allocateColors($cfg);
  &paintBackground($cfg) if defined $cfg->{BACKGROUND_COLOR}; 
}


sub drawFiles {
  my ($cfg)=@_;
  foreach my $dir (split(/,/, $cfg->{SRCDIR})) {
    opendir DIR,$dir or die "Cannot open the input folder '".$dir."\n";
    my @files=readdir DIR;
    closedir DIR;
    $cfg->{POINT_COUNTER}=0;
    foreach my $file (sort @files) {
      next unless $file=~/\.gpx$/;
      &loadFile($cfg,$dir."/".$file);
      &drawFile($cfg);
    }
  }
}

sub saveImage {
  my ($cfg)=@_;
  if (defined $cfg->{OUTPUT} and $cfg->{OUTPUT}=~/\w/) {
    open F,">".$cfg->{OUTPUT} or die "Cannot open ".$cfg->{OUTPUT}." for writing.";
    binmode F;
    print F $cfg->{IMAGE}->png;
    close F;
  }
  if (defined $cfg->{RUNNERS_OUTPUT} and $cfg->{RUNNERS_OUTPUT}=~/\w/) {
    open F,">".$cfg->{RUNNERS_OUTPUT} or die "Cannot open ".$cfg->{RUNNERS_OUTPUT}." for writing.";
    binmode F;
    print F $cfg->{RUNNERS_IMAGE}->png;
    close F;
  }
}

sub allocateColors {
  my ($cfg)=@_;
  $cfg->{TRACK_COLORS_ALLOCATED}=&allocateColorRange($cfg,$cfg->{TRACK_COLOR},$cfg->{RUNNER_COLOR}) if defined $cfg->{TRACK_COLOR} and $cfg->{TRACK_COLOR}=~/\w/;
  $cfg->{BACKGROUND_COLOR_ALLOCATED}=&allocateColor($cfg,$cfg->{BACKGROUND_COLOR}) if defined $cfg->{BACKGROUND_COLOR} and $cfg->{BACKGROUND_COLOR}=~/\w/;
  $cfg->{GRID_COLOR_ALLOCATED}=&allocateColor($cfg,$cfg->{GRID_COLOR}) if defined $cfg->{GRID_COLOR} and $cfg->{GRID_COLOR}=~/\w/;
  $cfg->{RUNNER_WHITE_ALLOCATED}=$cfg->{RUNNERS_IMAGE}->colorAllocate(255,255,255) if defined $cfg->{RUNNERS_IMAGE};
}


sub loadFile {
  my ($cfg, $fname)=@_;
  printf STDERR "Loading %s...\n",$fname if $cfg->{DEBUG};
  my $points=[];
  open F,$fname or die "Cannot open '$fname' for reading.\n";
  while (<F>) {
    chomp;
    next unless /trkpt (lat|lon)="([0-9.-]+)" (lon|lat)="([0-9.-]+)"/;
    my $lat;
    my $lon;
    if ($1 eq "lat") {
      $lat=$2;
      $lon=$4;
    } else {
      $lat=$4;
      $lon=$2;
    }
    $_=<F>;
    my $elevation=0;
    if (/<ele>([0-9.-]+)<\/ele>/) {
      $elevation=$1;
      $_=<F>;
    }
    next unless /<time>([^<]+)<\/time>/;
    my $time=&parseTime($1);
    push @$points,[$lat,$lon,$elevation,$time];
  }
  close F;
  $cfg->{POINTS}=$points;
}


sub drawFile {
  my ($cfg)=@_;
  printf STDERR "  ... drawing data ...\n" if $cfg->{DEBUG};
  my $oldLat=undef;
  my $oldLon=undef;
  my $oldTime=undef;
  my $oldX=undef;
  my $oldY=undef;
  my $x=undef;
  my $y=undef;
  my $breakDistance=$cfg->{BREAK_DISTANCE};
  my $border=$cfg->{BORDER};
  my $minLon=$cfg->{MINLON};
  my $maxLat=$cfg->{MAXLAT};
  my $lonScale=$cfg->{LONSCALE};
  my $latScale=$cfg->{LATSCALE};
  my $segmentPoints=[];
  my $color=$cfg->{TRACK_COLORS_ALLOCATED}->[0];
  my $alphaBlending=$cfg->{ALPHABLENDING};
  my $pointCounter=$cfg->{POINT_COUNTER};
  my $runnersImage=$cfg->{RUNNERS_IMAGE};
  my $runners=$cfg->{RUNNER_LIST};
  my $cenX=0.5*$cfg->{IMAGE_WIDTH};
  my $cenY=0.5*$cfg->{IMAGE_HEIGHT};
  my $sinA=sin($cfg->{ROT_ANGLE});
  my $cosA=cos($cfg->{ROT_ANGLE});
  foreach my $point (@{$cfg->{POINTS}}) {
    $x = $border+($point->[1]-$minLon)*$lonScale;
    $y = $border+($maxLat-$point->[0])*$latScale;
    my $ddx=$x-$cenX;
    my $ddy=$y-$cenY;
    $x=$cenX+$ddx*$cosA-$ddy*$sinA;
    $y=$cenY+$ddx*$sinA+$ddy*$cosA;
    if (defined $oldLat and defined $oldLon) {
      my $d = &calculateDistance($oldLat,$oldLon,$point->[0],$point->[1]);
      if ($d>$breakDistance) {
        &drawSegmentPoints($cfg,$segmentPoints,$pointCounter);
        $segmentPoints=[];
      }
      my $speed = undef;
      if (defined $oldTime) {
        my $dt = $oldTime-$point->[3];
        $dt=-$dt if $dt<0;
        $dt=1 if $dt==0;
        $speed = ($d/$dt)*3600;
      }
      if ($cfg->{MINSPEED}>0 || $cfg->{MAXSPEED}>0) {
        if (defined $speed and ($cfg->{MINSPEED}<=0 || $speed>=$cfg->{MINSPEED}) && ($cfg->{MAXSPEED}<=0 || $speed<$cfg->{MAXSPEED})) {
          push @$segmentPoints,[$x,$y];
        } else {
          &drawSegmentPoints($cfg,$segmentPoints,$pointCounter);
          $segmentPoints=[];
        }
      } else {
        push @$segmentPoints,[$x,$y];
      }
    }
    $pointCounter++;
    if (defined $runnersImage) {
      for my $runner (@$runners) {
        if ($runner == $pointCounter) {
          $runnersImage->filledEllipse($x, $y, $cfg->{RUNNER_DIAMETER}, $cfg->{RUNNER_DIAMETER}, $cfg->{RUNNER_WHITE_ALLOCATED});
          last;
        }
      }
    }
    $oldLat=$point->[0];
    $oldLon=$point->[1];
    $oldTime=$point->[3];
    $oldX=$x;
    $oldY=$y;
  }
  &drawSegmentPoints($cfg,$segmentPoints,$pointCounter);
  $cfg->{POINT_COUNTER}=$pointCounter;
}


sub drawSegmentPoints {
  my ($cfg,$points,$pointCounterAtEnd)=@_;
  return unless $#$points>0;
  my $drawRunners=$cfg->{RUNNER_LIST} ? 1 : 0;
  if (!$drawRunners && $cfg->{ALPHABLENDING}) {
    my $poly = new GD::Polygon;
    foreach my $pt (@$points) {
      $poly->addPt($pt->[0],$pt->[1]);
    }
    $cfg->{IMAGE}->unclosedPolygon($poly,$cfg->{TRACK_COLORS_ALLOCATED}->[0]);
  } else {
    for (my $i=0; $i<$#$points; $i++) {
      $cfg->{IMAGE}->line($points->[$i]->[0],$points->[$i]->[1],$points->[$i+1]->[0],$points->[$i+1]->[1],&getTrackColor($cfg,$pointCounterAtEnd-$#$points+$i));
    }
  }
}


sub getTrackColor {
  my ($cfg,$point)=@_;
  my $colors=$cfg->{TRACK_COLORS_ALLOCATED};
  #--------?-------R-----------------
  #     |---tail---|
  # $d = distance from the nearest runner ahead of this point, with wrap
  my $numberOfPoints=$cfg->{NUMPOINTS};
  my $d=$numberOfPoints;
  for my $runner (@{$cfg->{RUNNER_LIST}}) {
    my $dRunner = $runner-$point;
    $dRunner+=$numberOfPoints if $dRunner<0;
    $d=$dRunner if $dRunner<$d;
  }
  my $tail = $cfg->{RUNNER_TAIL_LENGTH};
  if ($d>$tail) {
    return $colors->[0];
  } else {
    my $colorIndex = $#$colors*($tail-$d)/$tail;
    return $colors->[$colorIndex];
  }
}


sub calculateDistance {
  my ($lat1,$lon1,$lat2,$lon2)=@_;
  my $r = 6371;
  my $dLat = ($lat2-$lat1)*$DEG_TO_RAD;
  my $dLon = ($lon2-$lon1)*$DEG_TO_RAD; 
  my $a = sin($dLat/2) * sin($dLat/2) +
          cos($lat1*$DEG_TO_RAD) * cos($lat2*$DEG_TO_RAD) * 
          sin($dLon/2) * sin($dLon/2); 
  my $c = 2 * atan2(sqrt($a), sqrt(1-$a)); 
  my $d = $r * $c;
  return $d;
}


sub parseTime {
  my ($timeString)=@_;
  return $timeString unless $timeString=~/(\d+)-(\d+)-(\d+)[A-Z](\d+):(\d+):(\d+)/;
  my ($year,$mon,$day,$h,$m,$s)=($1,$2,$3,$4,$5,$6);
  my $ts=(((($year*12+$mon)*31+$day)*24+$h)*60+$m)*60+$s;
  return $ts;
}


sub drawGrid {
  my ($cfg)=@_;
  return unless defined $cfg->{GRID_COLOR} and $cfg->{GRID_COLOR}=~/\w/g;
  my $minLon=$cfg->{MINLON};
  my $maxLon=$cfg->{MAXLON};
  my $minLat=$cfg->{MINLAT};
  my $maxLat=$cfg->{MAXLAT};
  my $dLon=$maxLon-$minLon;
  my $dLat=$maxLat-$minLat;
  my $lonScale=$cfg->{LONSCALE};
  my $latScale=$cfg->{LATSCALE};
  my $border=$cfg->{BORDER};
  my $lonDiv=(10**sprintf "%d",(log($dLon)/log(10)));
  my $latDiv=(10**(sprintf "%d",(log($dLat)/log(10))));
  while ($dLon/$lonDiv<4) {
    $lonDiv/=2;
  }
  while ($dLat/$latDiv<4) {
    $latDiv/=2;
  }
  my $minI = sprintf "%d",$minLon/$lonDiv;
  my $maxI = sprintf "%d",$maxLon/$lonDiv;
  for (my $i=$minI; $i<=$maxI; $i++) {
    my $lon=$i*$lonDiv;
    my $label=sprintf "%f",$lon;
    my $x = $border+($lon-$minLon)*$lonScale;
    $cfg->{IMAGE}->line($x,$border,$x,$cfg->{IMAGE_HEIGHT}-$border,$cfg->{GRID_COLOR_ALLOCATED});
    $cfg->{IMAGE}->stringUp(gdSmallFont,$x+5,$cfg->{IMAGE_HEIGHT}-$border,$label,$cfg->{GRID_COLOR_ALLOCATED});
  }
  $minI = sprintf "%d",$minLat/$latDiv;
  $maxI = sprintf "%d",$maxLat/$latDiv;
  for (my $i=$minI; $i<=$maxI; $i++) {
    my $lat=$i*$latDiv;
    my $label=sprintf "%f",$lat;
    my $y = $border+($maxLat-$lat)*$latScale;
    $cfg->{IMAGE}->line($border,$y,$cfg->{IMAGE_WIDTH}-$border,$y,$cfg->{GRID_COLOR_ALLOCATED});
    $cfg->{IMAGE}->string(gdSmallFont,$border,$y+5,$label,$cfg->{GRID_COLOR_ALLOCATED});
  }
}


sub allocateColorRange {
  my ($cfg,$colorString1,$colorString2)=@_;
  my $colors=[];
  if ($colorString2=~/\w/) {
    my ($r1,$g1,$b1,$a1,$r2,$g2,$b2,$a2);
    if (($colorString1."-".$colorString2)=~/#([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})-#([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})$/) {
      ($r1,$g1,$b1,$a1,$r2,$g2,$b2,$a2)=(hex $1,hex $2,hex $3,hex $4,hex $5,hex $6,hex $7,hex $8);
    } elsif (($colorString1."-".$colorString2)=~/#([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})-#([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})$/) {
      ($r1,$g1,$b1,$a1,$r2,$g2,$b2,$a2)=(hex $1,hex $2,hex $3,0,hex $4,hex $5,hex $6,0);
    } else {
      die "Mismatched colors for color range: '".$colorString1."' and '".$colorString2."'.\n";
    }
    for (my $i=0; $i<=$cfg->{COLOR_RANGE_STEPS}; $i++) {
      my $r=$r1+($r2-$r1)*$i/$cfg->{COLOR_RANGE_STEPS};
      my $g=$g1+($g2-$g1)*$i/$cfg->{COLOR_RANGE_STEPS};
      my $b=$b1+($b2-$b1)*$i/$cfg->{COLOR_RANGE_STEPS};
      my $a=$a1+($a2-$a1)*$i/$cfg->{COLOR_RANGE_STEPS};
      push @$colors,$cfg->{IMAGE}->colorAllocateAlpha($r,$g,$b,$a);
    }
  } else {
    push @$colors,&allocateColor($cfg,$colorString1);
  }
  return $colors;
}


sub allocateColor {
  my ($cfg,$colorString)=@_;
  if ($colorString=~/#([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})/) {
    $cfg->{ALPHABLENDING}=1;
    return $cfg->{IMAGE}->colorAllocateAlpha(hex $1,hex $2,hex $3,hex $4);
  } elsif ($colorString=~/#([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})/) {
    return $cfg->{IMAGE}->colorAllocate(hex $1,hex $2,hex $3);
  } else { 
    die "Invalid color $colorString.";
  }
}


sub paintBackground {
  my ($cfg)=@_;
  $cfg->{IMAGE}->filledRectangle(0,0,$cfg->{IMAGE_WIDTH},$cfg->{IMAGE_HEIGHT},$cfg->{BACKGROUND_COLOR_ALLOCATED});
}


sub parseArgs {
  my (@arg)=@_;
  my $settings={};
  while ($#arg>=0) {
    my $param=shift @arg;
    my $value=shift @arg;
    $param=~s/^-//g or die 'Parameter name "'.$param.'" should be preceeded by "-"';
    $param=uc($param);
    die 'Undefined value for param '.$param.'\n' unless defined $value;
    $settings->{$param}=$value;
  }
  return $settings;
}


