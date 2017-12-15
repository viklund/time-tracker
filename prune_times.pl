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

my $json = from_json(slurp($file));

if ( ref($json) ne "ARRAY" ) {
    $json = [ $json ];
}

my $paskanakki = "Infrastructure:NBIS General:Admin::";
my $roundoff_tally = 0;

for my $week (@$json) {
    my $dt = $week->{'week'};
    while (my ($key, $entry) = each ($week->{'work'}) ) {
      print "$key: $entry->{'duration'}\n";
      my $dur = $entry->{'duration'};
      # my $dur1000 = 1000 * $dur;
      # my $rem = $dur1000 % 500;
      # print "$dur1000, rem: $rem\n";
      # $dur =~  /\d+\.(\d*)/;
      # my $tail = $1;
      # print "$tail\n";
      # $tail = "0.$tail";

      my $hour_int = int($dur);
      my $tail = $dur - $hour_int;
      print "$tail\n";

      # my $left = $tail - 0.5;
      # print "$left\n";
      my $rounded;
      if ($tail < 0.25) {
        $rounded = floor($dur);
        $roundoff_tally += $tail;
      } elsif ($tail < 0.5) {
        $rounded = floor($dur) + 0.5;
        $roundoff_tally -= 0.5 - $tail;
      } elsif ($tail < 0.75) {
        $rounded = floor($dur) + 0.5;
        $roundoff_tally += $tail - 0.5;
      } else {
        $rounded = ceil($dur);
        $roundoff_tally -= 1.0 - $tail;
      }
      print "rounded: $rounded; tally: $roundoff_tally\n";
    }
    # for my $entry ( values %{ $week->{'work'} } ) {
    #   print $entry;
        # my $issue = get_issue_of( $entry );
        # if ( ! $issue ) {
        #     $error = 1;
        #     next;
        # }
        #
        # my $comment = $entry->{ $entry_mapping{comment} };
        # if ($comment eq 'None') { $comment = ''; }
        #
        # my $activity_id = $activity_id_of{ $entry->{ $entry_mapping{activity} } };
        #
        # my $issue_title = issue_lookup($issue);
        # if ( ! $issue_title ) {
        #     say STDERR "WARNING: Can't find title of $issue";
        #     $issue_title = "N/A ($issue)" . ' 'x30;
        # }
        #
        # my %data = (
        #     issue    => $issue,
        #     activity => $activity_id,
        #     activity_text => $activity_of_id{$activity_id},
        #     dt       => $dt,
        #     time     => $entry->{duration},
        #     comment  => $comment,
        #     entry    => $entry,
        #     title    => $issue_title,
        # );
        #
        # push @ok_entries, \%data;
    # }
}

sub slurp {
    my $file = shift;
    open my $F, '<', $file or die;
    local $/ = '';
    my $data = <$F>;
    return $data;
}
