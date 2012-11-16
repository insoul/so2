# NOTICE:
# Environment of remote ssh command is different with terminal access
# Remote ssh load only '$HOME/.bashrc'. If you want use alias command
# for server control, you must define commmand as function, not alias.
# For example, if you have this alias in .bash_profile
#   alias restart='restart server'
# you could write a function in .bashrc
#   function restart() {
#     restart server
#   }

unless File.exists?(".git")
  puts "ERROR: There is not .git directory. run this script in git workspace."
  exit
end

class Option
  OPTION_NAMES = %w{
    server dir logfile
    restart_cmd start_cmd stop_cmd
    restart tailog untracked
  }
  
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
    elsif options.nil?
    else
      raise "Unsupported class for options"
    end
  end

  def method_missing(name, *args, &block)
    @options.send(name)
  end

  def address
    if @options.user
      "#{@options.user}@#{@options.server}"
    else
      @options.server
    end
  end

  def ssh(command)
    system("ssh #{address} 'cd #{@options.dir}; #{command}'")
  end

  def out(command)
    `ssh #{address} 'cd #{@options.dir}; #{command}'`
  end

  def scp(file)
    system("scp #{file} #{address}:#{@options.dir}/#{file}")
  end
  
  def print
    puts "Current options"
    OPTION_NAMES.each do |o|
      puts "\t#{o}: #{send(o)}"
    end
    puts ""
  end
end

options = Option.new(GITUP_CONFIG["default"])

command_options = OpenStruct.new
opts = OptionParser.new do |opts|
  opts.banner = <<-EOS
  
Usage: gitup send [options]

  server, dir options:
    these options are to define where to upload server.
    server option has no default and dir option has default, 'me2day/current'.
    if you want to set default, make [~/tmp/instant.yml]
    and set default options like this,

      server: dev.server.com
      dir: deploy/stage
      logfile: unicorn.stdout.log

    this default value be overwritten by command line option.
    pre-defined option can be named like this in [~/tmp/instant.yml]

      test:
        server: test.server.com
        dir: deploy/test
        logfile: unicorn.stdout.log

    You can use this option like this.

      $ gitup -p test

  commit option:
    commit option does not have default value.
    But if you does not pass commit option parameter,
    as default, upload modified and created files of current git status.
    Naturally, this option value pass to `git diff --name-status \#{options.commit}`
    So if passed commit sha, uplaod files of output of above command.
    Refer to `git diff --name-status`
    (git 1.7 or higher version required)

  untracked option:
    use this option to include untracked files.

  restart option:
    this option does not have value.
    if use this option, target server will be restarted after upload.
    NOTICE:
      Environment of remote ssh command is different with terminal access
      Remote ssh load only '$HOME/.bashrc'. If you want use alias command
      for server control, you must define commmand as function, not alias.
      For example, if you have this alias in .bash_profile
        alias restart='restart server'
      you could write a function in .bashrc
        function restart() {
          restart server
        }

  tailog option:
    if use this option, automatically tail unicorn log after restarting server.
    default value of log file to tail is 'log/unicorn.stdout.log'
    if you want to change this, set in [tmp/instant.yml] [logfile]

  EOS

  opts.on("-s", "--server HOSTNAME", "Target server to upload") do |f|
    command_options.server = f
  end
  opts.on("-u", "--user USER", "User to ssh login") do |f|
    command_options.user = f
  end
  opts.on("-d", "--dir DIR", "Directory for deployment") do |f|
    command_options.dir = f
  end
  opts.on("-c", "--commit SHA", "Commit SHA") do |f|
    command_options.commit = f
  end
  opts.on("-u", "--untracked", "Upload untracked files") do |f|
    command_options.untracked = f
  end
  opts.on("-r", "--restart", "Restart server") do |f|
    command_options.restart = f
  end
  opts.on("-R", "--restart-force", "Restart server with stop and start") do |f|
    command_options.restart_force = f
  end
  opts.on("-t", "--tailog", "Tail log after restarting server") do |f|
    command_options.tailog = f
  end
  opts.on_tail('-h', "--help", "Show this message") do
    puts opts.help
    exit
  end
  opts.on("-p", "--predefine NUMBER", "Predefined option") do |f|
    command_options.predefine = f
  end
end

opts.parse!(ARGV)

if command_options.predefine
  if GITUP_CONFIG["predefine"][command_options.predefine].nil?
    puts "ERROR: '#{command_options.predefine}' is not pre-defined in '#{GITUP_CONFIG_FILE}'\n"
    exit
  end
  options.set(GITUP_CONFIG["predefine"][command_options.predefine])
else
  options.set(GITUP_CONFIG['default'])
end

options.set(command_options)
puts ""
options.print

if options.server.nil? or options.server.empty?
  puts "ERROR: server option is not defined\n"
  exit
end

available_servers = GITUP_CONFIG['available_servers']
unless available_servers
  puts "ERROR: #{GITUP_CONFIG_FILE} doesn't have available_servers configuration"
  puts "  example, available_servers: ['dev1', 'dev2']"
  exit
end

available = false
available_servers.each do |svr|
  if options.server.start_with?(svr)
    available = true and break
  end
end
unless available
  puts "ERROR: #{options.server} cannot upload instantly"
  puts "  available servers are #{available_servers.inspect}"
  exit
end

puts "Parsing git status And Upload"
js_changed = false
if options.commit
  status = `git diff --name-status #{options.commit}`
else
  status = `git diff --name-status`
  status << `git diff --name-status --cached`
end
puts status

status.split(/(\r\n|\r|\n)/).each do |st|
  next if st.chomp.empty?
  mod, file = st.strip.split(/\s+/)
  case mod
    when "M", "A" then
      puts "\n#{mod} #{file}"
      js_changed = true if file =~ /.*\.js/
      options.scp(file)
    else
      puts "\n#{mod} #{file} skipped"
  end
end

if options.untracked
  dirties = `git status --short`
  dirties.split(/(\r\n|\r|\n)/).each do |dirty|
    next if dirty.chomp.empty?
    mod, file = dirty.strip.split(/\s+/)
    if mod == "??"
      puts "\n#{mod} #{file}"
      js_changed = true if file =~ /.*\.js/
      options.scp(file)
    end
  end
end
puts ""

# generate js files if js_changed

if options.restart and options.restart_cmd
  puts "Restart server"
  puts "  restart_cmd: #{options.restart_cmd}"
  options.ssh(options.restart_cmd)
elsif options.restart_force and options.start_cmd and options.stop_cmd
  options.ssh(options.stop_cmd)
  options.ssh(options.start_cmd)
end
puts ""

if options.tailog and options.restart and options.logfile
  puts "Tail server log"
  options.ssh("tail -f #{options.logfile}")

  # kill tail process
  puts "kill tail process"
  tail_process = options.out('ps x | grep tail | grep -v grep')
  tail_process.split(/(\r\n|\r|\n)/).each do |proc|
    next if proc.chomp.empty?
    proc_split = proc.strip.split(/\s+/)
    pid, tty = proc_split[0..1]
    stat = proc_split[2]
    if tty == "?" and proc =~ /tail -f #{options.logfile}/ and stat == "S"
      options.ssh("kill #{pid}")
      puts "killed #{proc}"
    else
      puts "skipped #{proc}"
      puts "\tproc: #{proc_split.inspect}"
      puts "\tpid:#{pid}, tty:#{tty}, stat:#{stat}, regex:#{proc =~ /tail -f #{options.logfile}/}"
    end
  end
end
