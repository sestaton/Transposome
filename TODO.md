# TRANSPOSOME TODO

This file is for logging feature requests and bugs during development.

## `SeqIO` class

- [ ] Fix issue with Illumina header not being parsed correctly when initializing from a config file

## Meta
 - [ ] It would be helpful to log the number of families relative to an input database to show
       the percent of diversity that is captured. This may be challenging given the variety of input formats,
       but it should be considered.
 - [ ] Write HTML output and upload to Heroku.
 - [ ] Automate filtering of organellar sequences to reduce the false inflation of repetitiveness in the nuclear
       genome. Or, document easy ways to accomplish this task.
 - [ ] Change 1/0 boolean arguments in config file to yes/no for clarity.
 - [ ] Change full pipeline approach to run subcommands. This would greatly reduce memory usage.
 - [ ] Update Wiki, starting with: https://github.com/sestaton/Transposome/wiki/Specifications-and-example-usage
 - [x] Document required sequence format and provide reference in warnings
