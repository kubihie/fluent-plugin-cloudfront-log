require_relative '../helper'
require 'fluent/test'

class Cloudfront_LogInputTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end

  DEFAULT_CONFIG = {
    :aws_key_id        => 'AKIAZZZZZZZZZZZZZZZZ',
    :aws_sec_key       => '1234567890qwertyuiopasdfghjklzxcvbnm',
    :log_bucket        => 'bucket-name',
    :log_prefix        => 'a/b/c',
    :moved_log_bucket  => 'bucket-name-moved',
    :moved_log_prefix  => 'a/b/c_moved',
    :region            => 'ap-northeast-1',
    :tag               => 'cloudfront',
    :interval          => '500',
    :delimiter         => nil,
    :verbose           => true,
  }

  def parse_config(conf = {})
    ''.tap{|s| conf.each { |k, v| s << "#{k} #{v}\n" } }
  end

  def create_driver(conf = DEFAULT_CONFIG)
    Fluent::Test::InputTestDriver.new(Fluent::Cloudfront_LogInput).configure(parse_config conf)
  end

  def test_configure
    assert_nothing_raised { driver = create_driver }

    exception = assert_raise(Fluent::ConfigError) {
      conf = DEFAULT_CONFIG.clone
      conf.delete(:log_bucket)
      driver = create_driver(conf)
    }
    assert_equal("'log_bucket' parameter is required", exception.message)

    exception = assert_raise(Fluent::ConfigError) {
      conf = DEFAULT_CONFIG.clone
      conf.delete(:region)
      driver = create_driver(conf)
    }
    assert_equal("'region' parameter is required", exception.message)

    exception = assert_raise(Fluent::ConfigError) {
      conf = DEFAULT_CONFIG.clone
      conf.delete(:log_prefix)
      driver = create_driver(conf)
    }
    assert_equal("'log_prefix' parameter is required", exception.message)

    conf = DEFAULT_CONFIG.clone
    conf.delete(:moved_log_bucket)
    driver = create_driver(conf)
    assert_equal(driver.instance.log_bucket, driver.instance.moved_log_bucket)

    conf = DEFAULT_CONFIG.clone
    conf.delete(:moved_log_prefix)
    driver = create_driver(conf)
    assert_equal('_moved', driver.instance.moved_log_prefix)
  end

end
