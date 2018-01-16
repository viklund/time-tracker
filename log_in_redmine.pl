#!/usr/bin/env perl
use strict;
use warnings;

use feature qw( :5.18 );

use Getopt::Long;
use DateTime;

use JSON qw( from_json to_json );


my $insert = '';
my $check = '';
GetOptions(
    'insert' => \$insert,
    'check'  => \$check,
) or die "Could not parse options\n";

my $file = shift // die "Need input file\n";
my $json = from_json(slurp($file));

if ( ref($json) ne "ARRAY" ) {
    $json = [ $json ];
}

my $config = load_config();

my $apikey = $config->{'secrets'}{'redmine'};
my $redmine_url = 'https://projects.nbis.se';
my $rmclient = 'rmclient';

my %issue_of = %{ $config->{issue_map} };
our %entry_mapping = %{ $config->{entry_map} };

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
    "Consultation"          => 33,
);

my %activity_of_id = map { ($activity_id_of{$_}, $_) } keys %activity_id_of;

my @ok_entries;
my $error = '';

my $tot_time = 0;

for my $week (@$json) {
    my $dt = $week->{'week'};
    for my $entry ( values %{ $week->{'work'} } ) {
        my $issue = get_issue_of( $entry );
        if ( ! $issue ) {
            $error = 1;
            next;
        }

        my $comment = $entry->{ $entry_mapping{comment} };
        if ($comment eq 'None') { $comment = ''; }

        my $activity_id = $activity_id_of{ $entry->{ $entry_mapping{activity} } };

        my $issue_title = issue_lookup($issue);
        if ( ! $issue_title ) {
            say STDERR "WARNING: Can't find title of $issue";
            $issue_title = "N/A ($issue)" . ' 'x30;
        }

        my %data = (
            issue    => $issue,
            activity => $activity_id,
            activity_text => $activity_of_id{$activity_id},
            dt       => $dt,
            time     => $entry->{duration},
            comment  => $comment,
            entry    => $entry,
            title    => $issue_title,
        );

        push @ok_entries, \%data;
    }
}


if ( $error ) {
    say STDERR "Errors in file $file";
    exit 1;
}
exit 0 if $check;

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

    printf "%-5d Logging %5.2fh of <%20s> (%2d) on <%30.30s> (\"%s\")\n",
        $entry->{issue}, $entry->{time},
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
    my $task = $entry->{ $entry_mapping{task} };


    if (exists $issue_of{ $task } ) {
        my $issue = $issue_of{$task};
        return $issue;
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

sub load_config {
    my $json = from_json(slurp('config.json'));
    return $json;
}

sub get_apikey {
    my $config = shift;
    return $config->{'secrets'}{'redmine'};
}

sub load_entry_map {
    my $config = shift;
    return $config->{'entry_map'};
}

sub load_issue_map {
    my $config = shift;
    return $config->{'issue_map'};
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

my $issue_lookup;
sub issue_lookup {
    my $issue = shift;
    if (! ref $issue_lookup) {
        $issue_lookup = get_all_issues();
    }
    if ( ! exists $issue_lookup->{$issue} ) {
        my $text = _get_specific_issue( $issue );
        if ( ! $text ) {
            die "Can't find issue $issue!";
        }
        $issue_lookup->{$issue} = $text;
    }
    return $issue_lookup->{$issue};
}
