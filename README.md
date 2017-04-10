# LevelDB storage plugin for Fluent

[![Build Status](https://travis-ci.org/cosmo0920/fluent-plugin-storage-leveldb.svg?branch=master)](https://travis-ci.org/cosmo0920/fluent-plugin-storage-leveldb)

fluent-plugin-storage-leveldb is a fluent plugin to store plugin state into LevelDB.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'fluent-plugin-storage-leveldb'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install fluent-plugin-storage-leveldb

Then Fluentd automatically loads the plugin installed.

## Configuration

```aconf
<storage>
  @type leveldb

  path /path/to/leveldb/dbpath # or conf.arg will be used as leveldb's db files directory path
  dir_mode 755     # 0755 is default.
  root_key leveldb # leveldb is default.
</storage>
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/cosmo0920/fluent-plugin-storage-leveldb.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
