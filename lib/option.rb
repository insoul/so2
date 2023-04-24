class Option
  def self.option_names
    raise 'not implemented'
  end

  def option_names
    self.class.option_names
  end


  def initialize(options)
    @options = OpenStruct.new
    set(options)
  end

  def method_missing(name, *args, &block)
    @options.send(name, *args, &block)
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
      option_names.each do |o|
        checkin(o, options[o])
      end
    elsif options.is_a? OpenStruct
      option_names.each do |o|
        checkin(o, options.send(o))
      end
    elsif options.is_a? self.class
      option_names.each do |o|
        checkin(o, options.instance_variable_get(:@options).send(o))
      end
    elsif options.nil?
    else
      raise "Unsupported class for options"
    end
  end

  def print
    puts "Current options"
    option_names.each do |o|
      puts "\t#{o}: #{send(o)}"
    end
    puts ""
  end

  def kube?
    @options.server == 'kube'
  end

  def kube_pod_regex
    @options.pod_regex || @kube['pod_regex']
  end

  def kube_servers
    puts "kube servers"
    raise 'kube.namespace is blank' if @kube['namespace'].nil?
    cmd = "kubectl get pods --context #{@kube['context']} --namespace #{@kube['namespace']} --output name"
    puts cmd
    res = `#{cmd}`
    puts res
    res = res.split
    if @kube['pod_regex']
      res = res.select{|l| l =~ /#{@kube['pod_regex']}/}
      res = res.map{|l| l.split('/').last}
      puts (["pod_regex '#{@kube['pod_regex']}' filtered servers"] + res).join("\n  ")
    end
    res
  end

  def kube_init!
    if kube?
      @kube = @options.kube
      raise 'kube.context is blank' if @kube['context'].nil?
      cmd = "kubectl config use-context #{@kube['context']}"
      puts cmd
      system cmd
    end
  end
end
