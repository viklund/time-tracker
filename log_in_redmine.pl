#!/usr/bin/env perl
use strict;
use warnings;

use feature qw( :5.18 );

use JSON qw( from_json to_json );

my $file = shift // die "Need input file\n";
my $json = from_json(slurp($file));

my $apikey = get_apikey();
my $redmine_url = 'https://projects.bils.se';

my %issue_of = (
    'BILS:AstraZeneca DB:Meeting'            => [3486, 'Admin'],
    'BILS:AstraZeneca DB:Background reading' => [3486, 'Admin'],
    'BILS:WGS-Structvar:WGS-Structvar'       => [3131, 'Development'],
    'BILS:Beacon:Beacon'                     => [2990, 'Development'],
    'BILS:Tryggve:Sftp squid'                => [2489, 'Development'],
    'BILS:Mosler:R on Mosler'                => [2403, 'Development'],

    'BILS:Tryggve:Meeting'                   => ['NONE', 'Admin'],
    'BILS:Own Education'                     => ['NONE', 'Own Education'],
    'BILS:Admin:SysDev meeting'              => ['NONE', 'Admin'],
    'BILS:Admin:Admin'                       => ['NONE', 'Admin'],
    'None:None:LocalEGA'                     => ['NONE', 'Admin'],
    'None:None:EGA'                          => ['NONE', 'Development'],

    'BILS:Tryggve:Fred Bollplank'            => ['NONE', 'Admin'],
    'BILS:Admin:Bioinfo support'             => ['NONE', 'Support?'],
    'BILS:Tryggve:Tryggve'                   => ['NONE', 'Meeting'],
    'None:None:Teaching NGS-Course'          => ['NONE', 'Teaching'],
);
    ## Maybe this is tryggve general

for my $week (@$json) {
    my $dt = $week->{'week'};
    for my $entry ( keys %{ $week->{'work'} } ) {
        my $issue = get_issue_of( $entry );
    }
}


sub get_issue_of {
    my $entry = shift;
    my @parts = split /:/, $entry;
    for my $l (2,1,0) {
        my $entry = join ':', @parts[0..$l];
        if (exists $issue_of{ $entry } ) {
            return $issue_of{ $entry };
        }
    }
    die "Can't find an entry for $entry\n";
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
