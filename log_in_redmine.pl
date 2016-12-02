#!/usr/bin/env perl
use strict;
use warnings;

use feature qw( :5.18 );

use Getopt::Long;
use DateTime;

my $insert = '';
GetOptions(
    'insert' => \$insert,
) or die "Could not parse options\n";

use JSON qw( from_json to_json );

my $file = shift // die "Need input file\n";
my $json = from_json(slurp($file));

my $apikey = get_apikey();
my $redmine_url = 'https://projects.bils.se';

my %issue_of = (
    'BILS:Admin:Admin'                       => [3499, 'Administration'],
    'BILS:Admin:SysDev meeting'              => [3499, 'Admin'],
    'NBIS:Admin:SickChild'                   => [3499, 'Absence'],
    'BILS:Admin:Leave'                       => [3499, 'Absence'],
    'None:None:Gitbulance'                   => [3499,'Administration'],
    'NBIS:Admin:Retreat'                     => [3499, 'Administration'],
    'BILS:Own Education'                     => [3499, 'Own Education'],
    'Bils:Admin'                             => [3499, 'Admin'],

    'BILS:Admin:Bioinfo support'             => [3502, 'Support'],
    'BILS:Admin:Bioinfo support, local'      => [3502, 'Support'],

    'BILS:AstraZeneca DB:Background reading' => [3486, 'Admin'],
    'BILS:AstraZeneca DB:Meeting'            => [3486, 'Admin'],

    'BILS:Beacon:Beacon'                     => [2990, 'Development'],
    'BILS:Beacon:Meeting'                    => [2990, 'Admin'],

    'BILS:Mosler:R on Mosler'                => [2403, 'Development'],

    'BILS:Tryggve:Fred Bollplank'            => [1707, 'Admin'],
    'BILS:Tryggve:Meeting'                   => [1707, 'Admin'],
    'BILS:Tryggve:Tryggve'                   => [1707, 'Administration'],
    'BILS:Tryggve'                           => [1707, 'Administration'],
    'BILS:Tryggve:Sftp squid'                => [2489, 'Development'],

    'BILS:WGS-Structvar:WGS-Structvar'       => [3131, 'Development'],

    'NBIS:LocalEGA:LocalEGA'                 => [3534, 'Development'],
    'NBIS:LocalEGA'                          => [3534, 'Administration'],
    'None:None:EGA'                          => [3534, 'Development'],
    'None:None:LocalEGA'                     => [3534, 'Admin'],

    'None:None:R-course'                     => [3365, 'Teaching'],
    'None:None:Teaching NGS-Course'          => [3325, 'Teaching'],

    'None:None:Git course'                   => [3542, 'Teaching'],
    'BILS:Git course'                        => [3542, 'Teaching'],
);

my %activity_id_of = (
    Admin                   => 18,
    Administration          => 18,
    Teaching                => 11,
    Absence                 => 19,
    "Core Facility Support" => 20,
    "Design"                =>  8,
    "Development"           =>  9,
    "Implementation"        => 14,
    "Own Training"          => 10,
    "Own Education"         => 10,
    "Presenting"            => 12,
    "Support"               => 13,
);

for my $week (@$json) {
    my $dt = $week->{'week'};
    for my $entry ( keys %{ $week->{'work'} } ) {
        my ($issue, $activity) = get_issue_of( $entry );
        next unless $issue;

        my $comment = (split /:/, $entry)[2];
        my $time = $week->{'work'}{$entry};
        my @command = ('rmclient',
            '--url'      => $redmine_url,
            '--apikey'   => $apikey,
            '--date'     => $dt,
            '--hours'    => $time,
            '--issue'    => $issue,
            '--activity' => $activity,
            '--comment'  => qq'"$comment"',
        );
        if ( $insert ) {
            say "Running @command";
            if ( ! run_rmclient_insert(@command) ) {
                say "FAILED: @command";
                logger("FAILED: @command");
            }
        }
        else {
            say "@command";
        }
    }
}

sub run_rmclient_insert {
    my @command = @_;
    open my $CMD, '-|', "@command" or die "Could not launch command: <@command>";
    my $exitcode;
    while (<$CMD>) {
        if (/success/) {
            $exitcode=1;
        }
        if (/error/) {
            $exitcode = 0;
        }
    }
    close($CMD);
    return $exitcode;
}
        


sub get_issue_of {
    my $entry = shift;
    my @parts = split /:/, $entry;
    for my $l (2,1,0) {
        my $entry = join ':', @parts[0..$l];
        if (exists $issue_of{ $entry } ) {
            my ($issue, $activity) = @{ $issue_of{$entry} };
            if ( ! exists $activity_id_of{ $activity } ) {
                warn "Can't find activity id for <$activity>\n";
                return;
            }

            return ($issue, $activity_id_of{ $activity });
        }
    }
    warn "Can't find an entry for $entry\n";
    return;
}

sub slurp {
    my $file = shift;
    open my $F, '<', $file or die;
    local $/ = '';
    my $data = <$F>;
    return $data;
}

sub get_apikey {
    my $json = from_json(slurp('secrets.json'));
    return $json->{'redmine'};
}

sub logger {
    my @msg = @_;
    open my $LOG, '>>', 'log.txt' or die;
    printf $LOG "%s :: %s", DateTime->now()->iso8601, "@msg";
    close $LOG;
}
