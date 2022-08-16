class Option
  OPTION_NAMES = %w{
    user server kube dir logfile
    restart_cmd start_cmd stop_cmd
    restart tailog ignore_untracked
    pod_regex
  }

  attr_accessor :prefix

  def initialize(options)
    @options = OpenStruct.new
    set(options)
  end

  def kube?
    @options.server == 'kube'
  end

  def preprocess
    if kube?
      @kube = @options.kube
      raise 'kube.context is blank' if @kube['context'].nil?
      cmd = "kubectl config use-context #{@kube['context']}"
      puts cmd
      system cmd
    end
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

  def local_file(file)
    prefix ? File.join(prefix, file) : file
  end

  def remote_file(file)
    prefix ? File.join(@options.dir, prefix, file) : File.join(@options.dir, file)
  end

  def kube_pod_regex
    @options.pod_regex || @kube['pod_regex']
  end

  def kube_servers
    raise 'kube.namespace is blank' if @kube['namespace'].nil?
    cmd = "kubectl get pods --namespace #{@kube['namespace']} --output name"
    res = `#{cmd}`
    res = res.split
    raise 'kube.pod_regex or --pod-regex option is blank' if kube_pod_regex.nil?
    res = res.select{|l| l =~ /#{@kube['pod_regex']}/}
    res.map{|l| l.split('/').last}
  end

  def kube_remote_files(file)
    Hash[kube_servers.map{|svr| [svr, "#{@kube['namespace']}/#{svr}:#{@kube['path']}#{local_file(file)}"]}]
  end

  def scp(file)
    if kube?
      kube_remote_files(file).each_pair do |svr, remote_file|
        cmd0 = "kubectl cp #{local_file(file)} #{remote_file} -c #{@kube['container'] || 'main'}"
        puts cmd0
        system cmd0
        cmd1 = "kubectl exec -it #{svr} -c #{@kube['container'] || 'main'} -- chown root:root #{local_file(file)}"
        puts cmd1
        system cmd1
      end
    else
      cmd = "scp #{ssh_opt} #{local_file(file)} #{address}:#{remote_file(file)}"
      puts cmd
      system cmd
    end
  end

  def print
    puts "Current options"
    OPTION_NAMES.each do |o|
      puts "\t#{o}: #{send(o)}"
    end
    puts ""
  end
end
