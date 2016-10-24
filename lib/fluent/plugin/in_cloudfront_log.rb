class Fluent::Cloudfront_LogInput < Fluent::Input
  Fluent::Plugin.register_input('cloudfront_log', self)

  config_param :aws_key_id,        :string,  :default => nil, :secret => true
  config_param :aws_sec_key,       :string,  :default => nil, :secret => true
  config_param :log_bucket,        :string
  config_param :log_prefix,        :string
  config_param :moved_log_bucket,  :string,  :default => @log_bucket
  config_param :moved_log_prefix,  :string,  :default => '_moved'
  config_param :region,            :string
  config_param :tag,               :string,  :default => 'cloudfront.access'
  config_param :interval,          :integer, :default => 300
  config_param :delimiter,         :string,  :default => nil
  config_param :verbose,           :string,  :default => false
  config_param :thread_num,        :integer, :default => 4
  config_param :s3_get_max,        :integer, :default => 200

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
    raise Fluent::ConfigError.new unless @log_prefix

    @moved_log_bucket = @log_bucket unless @moved_log_bucket
    @moved_log_prefix = @log_prefix + '_moved' unless @moved_log_prefix

    if @verbose
      log.info("@log_bucket: #{@log_bucket}")
      log.info("@moved_log_bucket: #{@moved_log_bucket}")
      log.info("@log_prefix: #{@log_prefix}")
      log.info("@moved_log_prefix: #{@moved_log_prefix}")
      log.info("@thread_num: #{@thread_num}")
    end
  end

  def start
    super
    log.info("Cloudfront verbose logging enabled") if @verbose
    client

    @loop = Coolio::Loop.new
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
    # Key is the name of the object without the bucket prefix, e.g: asdf/asdf.jpg
    source_object_key       = [@log_prefix, filename].join('/')

    # Full path includes bucket name in addition to object key, e.g: bucket/asdf/asdf.jpg
    source_object_full_path = [@log_bucket, source_object_key].join('/')

    dest_object_key         = [@moved_log_prefix, filename].join('/')
    dest_object_full_path   = [@moved_log_bucket, dest_object_key].join('/')

    log.info("Copying object: #{source_object_full_path} to #{dest_object_full_path}") if @verbose

    begin
      client.copy_object(:bucket => @moved_log_bucket, :copy_source => source_object_full_path, :key => dest_object_key)
    rescue => e
      log.warn("S3 Copy client error. #{e.message}")
      return
    end


    log.info("Deleting object: #{source_object_key} from #{@log_bucket}") if @verbose
    begin
      client.delete_object(:bucket => @log_bucket, :key => source_object_key)
    rescue => e
      log.warn("S3 Delete client error. #{e.message}")
      return
    end
  end


  def process_content(content)
    filename = content.key.sub(/^#{@log_prefix}\//, "")
    log.info("CloudFront Currently processing: #{filename}") if @verbose
    return if filename[-1] == '/'  #skip directory/
    return unless filename[-2, 2] == 'gz'  #skip without gz file

    begin
      access_log_gz = client.get_object(:bucket => @log_bucket, :key => content.key).body
      access_log = Zlib::GzipReader.new(access_log_gz).read
    rescue => e
      log.warn("S3 GET client error. #{e.message}")
      return
    end

    access_log.split("\n").each do |line|
      if line[0.1] == '#'
        parse_header(line)
        next
      end
      line = URI.unescape(line)  #hoge%2520fuga -> hoge%20fuga
      line = URI.unescape(line)  #hoge%20fuga   -> hoge fuga
      line = line.split("\t")
      record = Hash[@fields.collect.zip(line)]
      timestamp = Time.parse("#{record['date']}T#{record['time']}+00:00").to_i
      router.emit(@tag, timestamp, record)
    end
    purge(filename)
  end

  def input
    log.info("CloudFront Begining input going to list S3")
    begin
      s3_list = client.list_objects(:bucket => @log_bucket, :prefix => @log_prefix , :delimiter => @delimiter, :max_keys => @s3_get_max)
    rescue => e
      log.warn("S3 GET list error. #{e.message}")
      return
    end
    log.info("Finished S3 get list")
    queue = Queue.new
    threads = []
    log.debug("S3 List size: #{s3_list.contents.length}")
    s3_list.contents.each do |content|
      queue << content
    end
    # BEGINS THREADS
    @thread_num.times do
      threads << Thread.new do
        until queue.empty?
          work_unit = queue.pop(true) rescue nil
          if work_unit
            process_content(work_unit)
          end
        end
       end
     end
     log.debug("CloudFront Waiting for Threads to finish...")
     threads.each { |t| t.join }
     log.debug("CloudFront Finished")
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
