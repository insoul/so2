class Option
  OPTION_NAMES = %w{
    server dir logfile
    restart_cmd start_cmd stop_cmd
    restart tailog ignore_untracked
  }

  attr_accessor :prefix

  def initialize(options)
    @options = OpenStruct.new
    set(options)
  end

  def checkin(key, value)
    return false if value.nil?
    return false if value.is_a? String and value.length == 0
    return false if (value.is_a? Hash or value.is_a? Array) and value.empty?
    @options.send("#{key}=", value)
    true
  end

  def set(options)
    if options.is_a? Hash
      OPTION_NAMES.each do |o|
        checkin(o, options[o])
      end
    elsif options.is_a? OpenStruct
      OPTION_NAMES.each do |o|
        checkin(o, options.send(o))
      end
    elsif options.is_a? self.class
      OPTION_NAMES.each do |o|
        checkin(o, options.instance_variable_get(:@options).send(o))
      end
    elsif options.nil?
    else
      raise "Unsupported class for options"
    end
  end

  def method_missing(name, *args, &block)
    @options.send(name, *args, &block)
  end

  def address
    if @options.user
      "#{@options.user}@#{@options.server}"
    else
      @options.server
    end
  end

  def ssh_opt
    opt = ''
    if @options.pem
      pem = @options.pem.gsub(/\$HOME/, ENV['HOME'])
      opt += "-i #{pem}"
    end
    opt
  end

  def ssh(command)
    system("ssh #{ssh_opt} #{address} 'cd #{@options.dir}; #{command}'")
  end

  def out(command)
    `ssh #{ssh_opt} #{address} 'cd #{@options.dir}; #{command}'`
  end

  def scp(file)
    if prefix
      local_file = File.join(prefix, file)
      remote_file = File.join(@options.dir, prefix, file)
    else
      local_file = file
      remote_file = File.join(@options.dir, file)
    end
    cmd = "scp #{ssh_opt} #{local_file} #{address}:#{remote_file}"
    puts cmd
    system cmd
  end

  def print
    puts "Current options"
    OPTION_NAMES.each do |o|
      puts "\t#{o}: #{send(o)}"
    end
    puts ""
  end
end
