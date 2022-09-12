class ShellOption
  OPTION_NAMES = %w{
  }

  def initialize(options)
    @options = OpenStruct.new
    set(options)
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

  def print
    puts "Current options"
    OPTION_NAMES.each do |o|
      puts "\t#{o}: #{send(o)}"
    end
    puts ""
  end
end
