#!/usr/bin/env perl
use strict;
use warnings;

use POSIX qw(floor ceil);

use feature qw( :5.18 );

use DateTime;

use JSON qw( from_json to_json );

my $config = load_config();

my $accumulated_time_file = $config->{prune_times}{accumulated_time_file};
my $paskanakki = $config->{prune_times}{paskanakki}; # https://translate.google.se/?source=osdd#auto/en/paskanakki

my $file = shift // die "Need input file\n";

my $outfile = $file =~ s/(.+)\.(.+)/$1_pruned.$2/r;
open my $OF, '>', $outfile or die;

my $json = from_json(slurp($file));

if ( ref($json) ne "ARRAY" ) {
    $json = [ $json ];
}

my $at = 0;
if ( -f $accumulated_time_file ) {
    $at = slurp($accumulated_time_file);
    chomp($at);
}
print STDERR "accumulated time: $at\n";
# my $roundoff_tally = 0;
my $roundoff_tally = $at;

my $rounded_sum = 0;

for my $week (@$json) {
    while (my ($key, $entry) = each %{$week->{'work'}} ) {
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

        delete $week->{'work'}{$key} if $rounded == 0;
        $entry->{'duration'} = $rounded;
        $rounded_sum += $rounded;
        printf STDERR "%-3s %40s: %6.2f; rounded: %6.2f; tally: %6.2f\n",
            ($rounded == 0 ? 'DEL' : ''), $key, $dur, $rounded, $roundoff_tally;
    }

    # Number of halfhours left, will be negative if we overcommit
    my $half_hours_left = floor( abs($roundoff_tally / 0.5 ) ) * ($roundoff_tally > 0 ? 1 : -1);
    my $addition = $half_hours_left * 0.5;

    $week->{work}{$paskanakki}{duration} += $addition;
    $rounded_sum                         += $addition;
    $roundoff_tally                      -= $addition;

    printf STDERR "Added %3.1f to $paskanakki\n", $addition;

    $week->{'rounded_sum'} = $rounded_sum;
}

print $OF to_json(@$json[0], {utf8 => 1, pretty => 1}) . "\n";
close $OF;

open my $AT, '>', $accumulated_time_file;
print $AT $roundoff_tally;
close $AT;

sub slurp {
    my $file = shift;
    open my $F, '<', $file or die "Couldn't open $file\n";
    local $/ = '';
    my $data = <$F>;
    return $data;
}

sub load_config {
    my $json = from_json(slurp('config.json'));
    return $json;
}
