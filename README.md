# pdpoke

`pdpoke` is a commandline tool for interrogating the PagerDuty REST API.

## Installation

    $ gem install pdpoke

## Usage

### export JSON of all incidents since November 1

    $ pdpoke incidents --since '2016-11-01'

### as above, but only match incidents within 3 minutes of 18:35 each day

    $ pdpoke incidents_around --since '2016-11-01' --hour 18 --minute 35 --width 3

### export Colourcard map showing incident times of day

    $ gem install colourcard
    $ pdpoke incident_map --since 2016-12-01 > colourcard.txt
    $ colourcard generate --across 12 --down 24 --patch-width 40 --patch-height 40 --input colourcard.txt

This would be better if `pdpoke` simply invoked `colourcard` itself. Will get there...

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/fairfaxmedia/pdpoke.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

