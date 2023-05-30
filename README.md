# MetaCsv 

Simple CSV file transformation via a DSL. Supports inferencing of a
columns types for value coercion and data validation. Supports
generation of a new CSV by defining `fill_column "NEW_COLUMN_NAME"`
functions that are run on each row, the row that is given to the
`fill_column` block knows how to access its values via a method call
to an old column name in snake case.

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add meta_csv

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install meta_csv

## Usage

Supports CSV transformation via a DSL `fill_column`. `fill_column` describes the new column
to generate on the new csv. `fill_column` is given a row of data that
responds to method calls for the old headers snakified, e.g. if the
source CSV had a column `Date` then we could do something like:

``` ruby
fill_column 'New Date' do |row|
  row.date + row.other_column_name
end
```

The order in which you define your `fill_column` pertains to the order
in which those columns will appear in the new CSV, e.g. using the same
`fill_column` from above would generate a CSV file with:

``` csv
New Date
10/20/1998
```

To run a transformation you need to look @
`MetaCsv::Manager.run(file_path:, transformations_file_path:,
schema_file_path:)`. `file_path` is the file path for the CSV file to
transform. `transformations_file_path` are your `fill_column`
functions to generate a new CSV with different columns. The
`schema_file_path` is a `Dry::Schema::Params` object which I will
explain later. If you're lazy then you can leave that file out and
MetaCsv will infer a schema for your data and try to coerce those
values appropriately.

There is a cli which supports transform_csv command which takes the file_path,
transformations_file_path and an optional schema_file_path. The
optional schema_file_path might need to be mandatory if inferring
types turns out to be messed up.
TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/meta_csv. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/meta_csv/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Meta_Csv project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/meta_csv/blob/master/CODE_OF_CONDUCT.md).
