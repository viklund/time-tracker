#!/usr/bin/env perl
use strict;
use warnings;

use POSIX;

use feature qw( :5.18 );

use DateTime;

use JSON qw( from_json to_json );


my $file = shift // die "Need input file\n";

(my $outfile = $file) =~ s/(.+)\.(.+)/$1_pruned.$2/;
print $file . "\n";
print $outfile . "\n";

open OF, ">$outfile" or die;

my $json = from_json(slurp($file));

if ( ref($json) ne "ARRAY" ) {
    $json = [ $json ];
}

my $paskanakki = "Infrastructure:NBIS General:Admin:"; # https://translate.google.se/?source=osdd#auto/en/paskanakki
my $roundoff_tally = 0;
my $rounded_sum = 0;

for my $week (@$json) {
    while (my ($key, $entry) = each ($week->{'work'}) ) {
      my $dur = $entry->{'duration'};
      my $hour_int = int($dur);
      my $tail = $dur - $hour_int;

      my $rounded;
      if ($tail < 0.33) {
        $rounded = floor($dur);
        $roundoff_tally += $tail;
      } elsif ($tail < 0.5) {
        $rounded = floor($dur) + 0.5;
        $roundoff_tally -= 0.5 - $tail;
      } elsif ($tail < 0.83) {
        $rounded = floor($dur) + 0.5;
        $roundoff_tally += $tail - 0.5;
      } else {
        $rounded = ceil($dur);
        $roundoff_tally -= 1.0 - $tail;
      }

      if($rounded == 0) {
        delete $week->{'work'}->{$key};
        print STDERR "Deleted $key: $dur\n";
      }
      $entry->{'duration'} = $rounded;
      $rounded_sum += $rounded;
      print STDERR "$key: $dur; rounded: $rounded; tally: $roundoff_tally\n";
    }
    while (abs($roundoff_tally) > 0.5) {
      if ($roundoff_tally >0) {
        $week->{'work'}->{$paskanakki}->{'duration'} += 0.5;
        $rounded_sum += 0.5;
        $roundoff_tally -= 0.5;
        print STDERR "Added 0.5 to $paskanakki\n";
      } else {
        $week->{'work'}->{$paskanakki}->{'duration'} -= 0.5;
        $rounded_sum -= 0.5;
        $roundoff_tally += 0.5;
        print STDERR "Subtrackted 0.5 from $paskanakki\n";
      }
    }

    $week->{'rounded_sum'} = $rounded_sum;
}

print OF to_json(@$json[0]) . "\n";
close OF;

sub slurp {
    my $file = shift;
    open my $F, '<', $file or die;
    local $/ = '';
    my $data = <$F>;
    return $data;
}
