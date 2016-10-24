# Fluent::Plugin::Cloudfront::Log
This plugin will connect to the S3 bucket that you store your cloudfront logs in. Once the plugin processes them and ships them to FluentD, it moves them to another location(either another bucket or sub directory).

## Example config
```
<source>
@type       cloudfront_log
log_bucket  cloudfront-logs
log_prefix  production
region      us-east-1
interval    300
aws_key_id  xxxxxx
aws_sec_key xxxxxx
tag         reverb.cloudfront
verbose     true
</source>
```

## Configuration options

#### log_bucket
This option tells the plugin where to look for the cloudfront logs

#### log_prefix
For example if your logs are stored in a folder called "production" under the "cloudfront-logs" bucket, your logs would be stored in cloudfront like "cloudfront-logs/production/log.gz".
In this case, you'd want to use the prefix "production".

#### moved_log_bucket
Here you can specify where you'd like the log files to be moved after processing. If left blank this defaults to a folder called `_moved` under the bucket configured for `@log_bucket`.

#### moved_log_prefix
This specifices what the log files will be named once they're processed. This defaults to `_moved`.

#### region
The region where your cloudfront logs are stored.

#### interval
This is the rate in seconds at which we check the bucket for updated logs. This defaults to 300.
#### aws_sec_id
The ID of your AWS keypair. Note: Since this plugin uses aws-sdk under the hood you can leave these two aws fields blank if you have an IAM role applied to your FluentD instance.

#### aws_sec_key
The secret key portion of your AWS keypair

#### tag
This is a FluentD builtin.

#### thread_num
The number of threads to create to concurrently process the S3 objects. Defaults to 4.

#### s3_get_max
Control the size of the S3 fetched list on each iteration. Default to 200.

#### delimiter
You shouldn't have to specify delimiter at all but this option is provided and passed to the S3 client in the event that you have a weird delimiter in your log file names. Defaults to `nil`.

#### verbose
Turn this on if you'd like to see verbose information about the plugin and how it's processing your files.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'fluent-plugin-cloudfront-log'
```

And then execute:

$ bundle

Or install it yourself as:

$ gem install fluent-plugin-cloudfront-log

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/kubihie/fluent-plugin-cloudfront-log.

