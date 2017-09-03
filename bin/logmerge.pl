#!/usr/bin/perl -w
#
# Alexander Avtanski, 2011
# See http://avtanski.net/gps for information

use strict;


my $cfg={};
$cfg->{SRCDIR}=$ARGV[0] || "input";
$cfg->{OUTFILE}=$ARGV[1] || "output.gpx";

&loadFiles($cfg);
&outputFile($cfg);
exit 1;


sub loadFiles {
  my ($cfg)=@_;
  opendir DIR,$cfg->{SRCDIR} or die "Cannot open the input folder '".$cfg->{SRCDIR}."\n";
  my @files=readdir DIR;
  closedir DIR;
  $cfg->{POINTS}=[];
  foreach my $file (sort @files) {
    next unless $file=~/\.gpx$/;
    &loadFile($cfg,$cfg->{SRCDIR}."/".$file);
  }
}


sub loadFile {
  my ($cfg, $fname)=@_;
  printf STDERR "Procesing %s...\n",$fname;
  my $points=$cfg->{POINTS};
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
    next unless /<ele>([0-9.-]+)<\/ele>/;
    my $elevation=$1;
    $_=<F>;
    next unless /<time>([^<]+)<\/time>/;
    my $time=$1;
    push @$points,[$lat,$lon,$elevation,$time];
  }
  close F;
}


sub outputFile {
  my ($cfg)=@_;
  printf STDERR "Writing oputput file (%s)...\n",$cfg->{OUTFILE};
  open OUT,">".$cfg->{OUTFILE} or die "Cannot open '".$cfg->{OUTFILE}."' for writing\n";
  print OUT <<END;
<?xml version="1.0" encoding="UTF-8" standalone="no" ?>
<gpx xmlns="http://www.topografix.com/GPX/1/1" creator="" version="1.1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
 <trk>
  <name>TRK0</name>
  <trkseg>
END
  my $oldLat=undef;
  my $oldLon=undef;
  my $trkCounter=1;
  foreach my $point (@{$cfg->{POINTS}}) {
    if (defined $oldLat and defined $oldLon) {
      my $d = &calculateDistance($oldLat,$oldLon,$point->[0],$point->[1]);
      if ($d>0.5) {
        printf OUT "  </trkseg>\n";
        #printf OUT " </trk>\n";
        #printf OUT " <trk>\n";
        #printf OUT "  <name>TRK%d</name>\n",$trkCounter++;
        printf OUT "  <trkseg>\n";
      }
    }
    printf OUT "   <trkpt lat=\"%s\" lon=\"%s\">\n",$point->[0],$point->[1];
    printf OUT "    <ele>%s</ele>\n",$point->[2];
    printf OUT "    <time>%s</time>\n",$point->[3];
    printf OUT "   </trkpt>\n";
    $oldLat=$point->[0];
    $oldLon=$point->[1];
  }
  print OUT <<END;
  </trkseg>
 </trk>
</gpx>
END
}

sub calculateDistance {
  my ($lat1,$lon1,$lat2,$lon2)=@_;
  my $r = 6371;
  my $degToRad = 3.14159/180;
  my $dLat = ($lat2-$lat1)*$degToRad;
  my $dLon = ($lon2-$lon1)*$degToRad; 
  my $a = sin($dLat/2) * sin($dLat/2) +
          cos($lat1*$degToRad) * cos($lat2*$degToRad) * 
          sin($dLon/2) * sin($dLon/2); 
  my $c = 2 * atan2(sqrt($a), sqrt(1-$a)); 
  my $d = $r * $c;
  return $d;
}

