#!/usr/bin/env perl
use strict;
use warnings;

use feature qw( :5.18 );

use Getopt::Long;
use DateTime;

use JSON qw( from_json to_json );


my $insert = '';
GetOptions(
    'insert' => \$insert,
) or die "Could not parse options\n";

my $file = shift // die "Need input file\n";
my $json = from_json(slurp($file));

if ( ref($json) ne "ARRAY" ) {
    $json = [ $json ];
}

my $apikey = get_apikey();
my $redmine_url = 'https://projects.bils.se';
my $rmclient = 'rmclient.git/bin/rmclient';


my %issue_of = (
    'BILS'          => 3499,
    'Elixir'        => 3499, ## Should probably change this
    'AZ Database'   => 3486,
    'swefreq'       => 2990,
    'LocalEGA'      => 3534,
    'Elixir-Beacon' => 3585,
    'PythonVt17'    => 3322,
);

my %issue_of_old = (
    'BILS:Admin:Admin'                       => [3499, 'Administration'],
    'BILS:Admin'                             => [3499, 'Administration'],
    'BILS:Admin:SysDev meeting'              => [3499, 'Administration'],
    'NBIS:Admin:SickChild'                   => [3499, 'Absence'],
    'BILS:Admin:Leave'                       => [3499, 'Absence'],
    'None:None:Gitbulance'                   => [3499, 'Administration'],
    'NBIS:Admin:Retreat'                     => [3499, 'Administration'],
    'BILS:Own Education'                     => [3499, 'Own Training'],
    'Bils:Admin'                             => [3499, 'Administration'],

    'BILS:Admin:Bioinfo support'             => [3502, 'Support'],
    'BILS:Admin:Bioinfo support, local'      => [3502, 'Support'],

    'BILS:AstraZeneca DB:Background reading' => [3486, 'Administration'],
    'BILS:AstraZeneca DB:Meeting'            => [3486, 'Administration'],
    'BILS:AstraZeneca DB:Schema design'      => [3486, 'Development'],

    'BILS:Beacon'                            => [2990, 'Development'],
    'BILS:Beacon:Beacon'                     => [2990, 'Development'],
    'BILS:Beacon:Meeting'                    => [2990, 'Administration'],

    'BILS:Mosler:R on Mosler'                => [2403, 'Development'],

    'BILS:Tryggve:Fred Bollplank'            => [1707, 'Administration'],
    'BILS:Tryggve:Meeting'                   => [1707, 'Administration'],
    'BILS:Tryggve:Tryggve'                   => [1707, 'Administration'],
    'BILS:Tryggve'                           => [1707, 'Administration'],
    'BILS:Tryggve:Sftp squid'                => [2489, 'Development'],
    'Tryggve:SFTP'                           => [2489, 'Development'],

    'BILS:WGS-Structvar'                     => [3131, 'Development'],

    'NBIS:LocalEGA:LocalEGA'                 => [3534, 'Development'],
    'NBIS:LocalEGA'                          => [3534, 'Administration'],
    'None:None:EGA'                          => [3534, 'Development'],
    'None:None:LocalEGA'                     => [3534, 'Administration'],

    'None:None:R-course'                     => [3365, 'Teaching'],
    'None:None:Teaching NGS-Course'          => [3325, 'Teaching'],
    'NBIS:R-course-2015'                     => [3365, 'Teaching'],

    "Elixir-Beacon:Admin"                    => [3585, 'Admin'],

    'None:None:Git course'                   => [3542, 'Teaching'],
    'BILS:Git course'                        => [3542, 'Teaching'],
);

my %activity_id_of = (
    Design                  =>  8,
    Development             =>  9,
    "Own Training"          => 10,
    Teaching                => 11,
    Presenting              => 12,
    Support                 => 13,
    Implementation          => 14,
    Administration          => 18,
    Admin                   => 18,
    Absence                 => 19,
    "Core Facility Support" => 20,
);

my %activity_of_id = map { ($activity_id_of{$_}, $_) } keys %activity_id_of;

my @ok_entries;
my $error = '';

my $tot_time = 0;

for my $week (@$json) {
    my $dt = $week->{'week'};
    for my $entry ( keys %{ $week->{'work'} } ) {
        my ($issue, $activity) = get_issue_of( $entry );
        if ( ! $issue ) {
            $error = 1;
            next;
        }

        my $comment = (split /:/, $entry)[2];

        my $issue_title = issue_lookup($issue);
        if ( ! $issue_title ) {
            say STDERR "WARNING: Can't find title of $issue";
            $issue_title = "N/A ($issue)" . ' 'x30;
        }

        my %data = (
            issue    => $issue,
            activity => $activity,
            activity_text => $activity_of_id{$activity},
            dt       => $dt,
            time     => $week->{'work'}{$entry},
            comment  => $comment,
            entry    => $entry,
            title    => $issue_title,
        );

        push @ok_entries, \%data;
    }
}


#exit if $error;

@ok_entries = sort { $a->{issue} <=> $b->{issue} ||
             $a->{activity_text} cmp $b->{activity_text}
             } @ok_entries;

for my $entry ( @ok_entries ) {
    my $comment = $entry->{comment};
    my @command = ($rmclient,
        '--url'      => $redmine_url,
        '--apikey'   => $apikey,
        '--date'     => $entry->{dt},
        '--hours'    => $entry->{time},
        '--issue'    => $entry->{issue},
        '--activity' => $entry->{activity},
        '--comment'  => qq'"$comment"',
    );

    $tot_time += $entry->{time};

    printf "%-5d Logging %5.2fh of %40.40s as <%20s> (%2d) on <%30.30s> (\"%s\")\n",
        $entry->{issue}, $entry->{time}, $entry->{entry},
        $entry->{activity_text}, $entry->{activity},
        $entry->{title}, $entry->{comment};

    if ( $insert ) {
        say "Running @command";
        if ( ! run_rmclient_insert(@command) ) {
            say "FAILED: @command";
            logger("FAILED: @command");
        }
    }
}

printf "Total %5.2fh\n", $tot_time;

sub run_rmclient_insert {
    my @command = @_;
    open my $CMD, '-|', "@command" or die "Could not launch command: <@command>";
    my $exitcode;
    while (<$CMD>) {
        if (/success/) {
            $exitcode = 1;
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
    my ($task, $activity) = split /:/, $entry;
    if (exists $issue_of{ $task } ) {
        my $issue = $issue_of{$task};
        if ( ! exists $activity_id_of{ $activity } ) {
            warn "Can't find activity id for <$activity>\n";
            return;
        }

        return ($issue, $activity_id_of{ $activity });
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

sub get_all_issues {
    open my $CLIENT, '-|', "$rmclient --url $redmine_url --apikey $apikey -qi"
        or die "Can't get issues";
    my %info;
    while (<$CLIENT>) {
        chomp;
        my ($id, $text) = /^(\d+)\s+(.*)$/;
        $info{$id} = $text;
    }

    return \%info;
}

sub _get_specific_issue {
    my $issue = shift;
    open my $CLIENT, '-|', "$rmclient --url $redmine_url --apikey $apikey -qi$issue 2>/dev/null"
        or die "Can't get issues";
    my $text;
    while (<$CLIENT>) {
        chomp;
        ($text) = /^\d+\s+(.*)$/;
    }

    return $text;
}

my $issue_lookup = get_all_issues();
sub issue_lookup {
    my $issue = shift;
    if ( ! exists $issue_lookup->{$issue} ) {
        my $text = _get_specific_issue( $issue );
        if ( ! $text ) {
            die "Can't find issue $issue!";
        }
        $issue_lookup->{$issue} = $text;
    }
    return $issue_lookup->{$issue};
}
