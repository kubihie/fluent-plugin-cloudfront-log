class Fluent::Cloudfront_LogInput < Fluent::Input
  Fluent::Plugin.register_input('cloudfront_log', self)

  config_param :aws_key_id,        :string,  :default => nil, :secret => true
  config_param :aws_sec_key,       :string,  :default => nil, :secret => true
  config_param :log_bucket,        :string
  config_param :log_prefix,        :string,  :default => nil
  config_param :moved_log_bucket,  :string,  :default => @log_bucket
  config_param :moved_log_prefix,  :string,  :default => '_moved'
  config_param :region,            :string
  config_param :tag,               :string,  :default => 'cloudfront.access'
  config_param :interval,          :integer,    :default => 300

  def initialize
    super
    require 'logger'
    require 'aws-sdk'
    require 'zlib'
    require 'time'
    require 'uri'
  end

  def configure(conf)
    super

    raise Fluent::ConfigError.new unless @log_bucket
    raise Fluent::ConfigError.new unless @region

    @moved_log_bucket = @log_bucket unless @moved_log_bucket
    @moved_log_prefix = @log_prefix + '_moved' unless @moved_log_prefix
    
    log.info('@log_bucket:' + @log_bucket)
    log.info('@moved_log_bucket:' + @moved_log_bucket)
    log.info('@log_prefix:' + @log_prefix)
    log.info('@moved_log_prefix:' + @moved_log_prefix)
  end

  def start
    super
    client

    @loop = Coolio::Loop.new
    #timer = TimerWatcher.new(@interval, true, log) do
    #  input
    #end
    timer = TimerWatcher.new(@interval, true, log, &method(:input)) 

    @loop.attach(timer)
    @thread = Thread.new(&method(:run))
  end

  def shutdown
    @loop.stop
    @thread.join
  end

  def run
    @loop.run
  end

  def client
    begin
      options = {:region => @region}
      if @aws_key_id and @aws_sec_key
        options[:access_key_id] = @aws_key_id
        options[:secret_access_key] = @aws_sec_key
      end
      @client = Aws::S3::Client.new(options)
    rescue => e
      log.warn("S3 client error. #{e.message}")
    end
  end

  def parse_header(line)
    case line
    when /^#Version:.+/i then
      @version = line.sub(/^#Version:/i, '').strip
    when /^#Fields:.+/i then
      @fields = line.sub(/^#Fields:/i, '').strip.split("\s")
    end  
  end

  def purge(filename)
    log.info('copy_src:' + @log_bucket + '/' + @log_prefix + filename)
    log.info('copy_dst:' + @moved_log_bucket + '/' + @moved_log_prefix + '/' + filename)
    client.copy_object(:bucket => @moved_log_bucket, :copy_source => @log_bucket + '/' + @log_prefix + filename, :key => @moved_log_prefix + '/' + filename)
    client.delete_object(:bucket => @log_bucket, :key => @log_prefix + filename)
  end

  def input
    client.list_objects(:bucket => @log_bucket, :prefix => @log_prefix , :delimiter => '/').each do |list|
      list.contents.each do |content|
        filename = content.key.sub(/#{@log_prefix}/, '')
        #log.info('filename:' + filename)
        next if filename[-1] == '/'  #skip directory/
        next unless filename[-2, 2] == 'gz'  #skip without gz file

        access_log_gz = client.get_object(:bucket => @log_bucket, :key => content.key).body
        access_log = Zlib::GzipReader.new(access_log_gz).read

        access_log.split("\n").each do |line|
          if line[0.1] == '#'
            parse_header(line)
            next
          end
          line = URI.unescape(line)  #hoge%2520fuga -> hoge%20fuga
          line = URI.unescape(line)  #hoge%20fuga   -> hoge fuga
          line = line.split("\t")
          record = Hash[@fields.collect.zip(line)]
          timestamp = Time.parse("#{record['date']} #{record['time']} +0900").to_i
          router.emit(@tag, timestamp, record)
        end
        purge(filename)
      end
    end
  end

  class TimerWatcher < Coolio::TimerWatcher
    def initialize(interval, repeat, log, &callback)
      @callback = callback
      @log = log
      super(interval, repeat)
    end

    def on_timer
      @callback.call
    end
  end
end
