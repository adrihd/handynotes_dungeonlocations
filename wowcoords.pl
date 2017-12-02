use warnings;
use strict;
use POSIX qw(floor);
use Win32::Clipboard;

my $cb = Win32::Clipboard();

my $line;
do {
 $line = <STDIN>;
 chomp($line);
 if ($line) {
  my ($x, $y) = split(/ /, $line);
  my $coord = (floor((($x/100) * 10000) + 0.5) * 10000) + floor((($y/100) * 10000) + 0.5);
  print "Coordinate: $coord\n";
  $cb->Set($coord);
 }
} while($line)