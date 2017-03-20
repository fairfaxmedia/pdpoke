# pdpoke

`pdpoke` is a commandline tool for interrogating the PagerDuty REST API.

## Installation

    $ gem install pdpoke

## Configuration

You'll need to create `$HOME/.pdpoke.yaml` with some basic info in it.

    ---
    account: your-pagerduty-subdomain
    apikey: api-key-from-pagerduty-account
    email: your.pagerduty@email.address
    teams:
      - ID_of_team_1
      - ID_of_team_2

If your PagerDuty URL is `https://yourcompany.pagerduty.com/`, the
`account` setting should be `yourcompany`.

The API key you'll need to generate via the API Keys page in your
PagerDuty account.

The team IDs you can extract from the PagerDuty web URLs, or via the
API.  Don't use the team name; it won't work.

It's important to specify the email address matching your PagerDuty user
account; this is used for finding your own PagerDuty user, which is
required for some features to work.

## Usage

### list of commands

    $ pdpoke help

### more detailed help for a command

    $ pdpoke help oncall_days

### information about your PagerDuty user account

    $ pdpoke me | jq .job_title
    "DevOps Engineer"

### information about all users in your configured teams

    $ pdpoke users

### list days upon which you were on-call outside work hours

This is intended to assist in claiming on-call compensation.

    $ pdpoke oncall_days --since 2016-12-01 --until 2016-12-31

This makes the following assumptions:

* you don't work on Saturday or Sunday (PRs welcome!)
* your office hours are 0900-1700 (see help for configurable options here)
* you are only considered on-call if the elapsed time exceeds some number
  of hours (again, see help for configurability)

### export JSON of all incidents since November 1

    $ pdpoke incidents --since '2016-11-01'

### as above, but only match incidents within 3 minutes of 18:35 each day

    $ pdpoke incidents_around --since '2016-11-01' --hour 18 --minute 35 --width 3

### export Colourcard map showing incident times of day

    $ gem install colourcard
    $ pdpoke incident_map --since 2016-12-01 > colourcard.txt
    $ colourcard generate --across 12 --down 24 --patch-width 40 --patch-height 40 --input colourcard.txt

This would be better if `pdpoke` simply invoked `colourcard` itself.
Will get there...

### filtering incidents by arbitrary fields

`pdpoke`, via the `--fieldmatch` option, supports a basic regex match on
almost any fields in the JSON blob returned by the PagerDuty REST API.
The purpose here is to quickly narrow down what you want; serious
manipulation still belongs elsewhere in tools like `jq`.

It's important to note that this won't work on array constructs in JSON
as that would substantially complicate the implementation. Again, use
`jq` or similar if you need that.

Filtering rules take the form of a field specification with each level
of hash nesting delimited by a slash, followed by `~` or `!~` (the
latter being a negative match), followed by a regex to match.

It may be a good idea to surround the match rule in quotes if running in
a Unix or Linux shell, due to `!` and `~` both potentially being treated
as special characters.

Some examples:

* `--fieldmatch 'service/summary~Synthetics'` would match any incident with
  the text `Synthetics` in its service name

* `--fieldmatch 'description!~free space'` would match any incident that did
  NOT contain the text `free space` in its description field

You can specify as many filter rules as you like. `AND` logic is applied
if multiple rules are specified, ie. they must all match.

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/fairfaxmedia/pdpoke.


## License

The gem is available as open source under the terms of the [Apache-2.0 License](http://opensource.org/licenses/Apache-2.0).

