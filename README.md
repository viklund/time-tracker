# Sync toggl timings into NBIS redmine system

## Prerequisites

### Python 2.7

Just the core modules.

### Ruby

```bash
gem install rmclient
```

### Perl

The following modules need to be installed, for example with `cpan`.

    DateTime
    JSON

```bash
cpan DateTime JSON
```

## Initialize the code

```bash
git clone git@github.com:viklund/time-tracker.git
cd time-tracker
```

## Configure the json file

Copy the `config_sample.json` file into `config.json` and update according to
below.

### API keys

Find the API keys in your redmine and toggl account and add them to the
`config.json` file.

### Use toggl in a way that is compatible with the redmine system

In toggl there are 4 different fields for each running task:

 - Client
 - Project
 - Task comment/description
 - Tags

In redmine we have 3 different things that we want to log:

 - Issue number (task)
 - Activity (Admin, Support, OwnTraining and so forth)
 - Comment

For the automation to work toggl needs to be used in a consistent manner and
the script needs to know how to map each of the different types of toggl fields
into redmine. For this you use the `entry_map` and `issue_map` fields in the
`config.json`.

#### Entry map

The entry map is used to map the 4 different toggl fields into the redmine
fields. The keys should be the redmine fields and the values are the names of
the toggl fields.

I use the client field to identify issue number, project to identify type of
activity and the comment field to specify a short comment on what I'm doing
("testing patch", "Updating the time-tracker README", "Email" and so forth).
So in my case the entry map looks like this:

```json
    "entry_map": {
        "task": "client",
        "activity": "project",
        "comment": "description"
    },
```

#### Issue map

To map the different tasks into redmine issues, this mapping needs to be
specified. So you have to come up with names for all the issues you are
working on and then specify to what issue this should be mapped in the redmine
system. I for example have the client as the issue mapping so when I'm working
on issue number 3534 which is the LocalEGA project I instead write LocalEGA in
the client field in toggle and then have this line in the `issue_map`:

```json
    "issue_map": {
        "LocalEGA":      3534
    }
```

#### What about activity

To specify whether I am doing _administration_ or _development_ I just write
that in the project field in the toggl (but you can have it somewhere else if
you change the `entry_map`). These mappings are hardcoded in the perl script,
the available categories are:

        Design
        Development
        Own Training
        Teaching
        Presenting
        Support
        Implementation
        Administration
        Admin
        Absence
        Core Facility Support

## Running the scripts

### Fetch information from toggl

The `get_weekly_toggls.py` has two command line options options, `--from` and
`--to` which are used to specify how far back you want to go. From is how many
weeks ago you should start fetching things and to is how many weeks ago you
should stop, working backwards (hrmmm). The scripts stores the results in a
subdirectory called `json` which one file per week.

This will fetch last weeks work:

```bash
$ ./get_weekly_toggl.py --from 1 --to 1
```

This will fetch the last 3 weeks work:

```bash
$ ./get_weekly_toggl.py --from 1 --to 3
```

### Quality control of the files

Check the `.json` files in the `json` subdirectory so that everything looks
ok.

### Sync everything into redmine

First make a test sync to make sure that you have everything setup correctly:

```bash
$ ./log_in_redmine.pl json/info_2017-10-06.json
```

This will warn about unkown issue mappings which you should add to the
`config.json`

When that seems to work ok, you can run the script with `--insert`:


```bash
$ ./log_in_redmine.pl --insert json/info_2017-10-06.json
```


# TODO

* Make a docker container of everything for ease of use
* The from/to specification for the python script is very illogical.
