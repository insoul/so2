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

require 'send_option'
require 'git_repo'

options = SendOption.new(SO2_CONFIG["default"])

command_options = OpenStruct.new
opts = OptionParser.new do |opts|
  opts.banner = <<-EOS

Usage: so2 send [stage] [options]
  server, user, dir option:
    orverride .so2.yml configuration

  commit option:
    commit option does not have default value.
    But if you does not pass commit option parameter,
    as default, upload modified and created files of current git status.
    Naturally, this option value pass to `git diff --name-status \#{options.commit}`
    So if passed commit sha, uplaod files of output of above command.
    Refer to `git diff --name-status`
    (git 1.7 or higher version required)

  ignore untracked option:
    use this option to ignore untracked files.

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
  opts.on("-p", "--pod-regex POD", "Target kube pod to upload as regular expression") do |f|
    command_options.pod_regex = f
  end
  opts.on("-u", "--user USER", "User to ssh login") do |f|
    command_options.user = f
  end
  opts.on("-d", "--dir DIR", "Directory for deployment") do |f|
    command_options.dir = f
  end
  opts.on("-u", "--ignore-untracked", "ignore untracked files") do |f|
    command_options.ignore_untracked = true
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
  opts.on("--dry", "Donot restart server") do |f|
    command_options.restart = !f
    command_options.restart_force = !f
    command_options.taillog = !f
  end
  opts.on_tail('-h', "--help", "Show this message") do
    puts opts.help
    exit
  end
end

opts.parse!(ARGV)
stage = opts.default_argv.first
stage = 'default' if stage.nil? || stage.start_with?('-')
options.set(SO2_CONFIG[stage])
options.set(command_options)
puts ""
options.print

if options.server.nil? or options.server.empty?
  puts "ERROR: server option is not defined\n"
  exit
end

available_servers = SO2_CONFIG['available_servers'] + ['kube']
unless available_servers
  puts "ERROR: #{SO2_CONFIG_FILE} doesn't have available_servers configuration"
  puts "  #{available_servers.join(' ')}"
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


# TODO generate js files if js_changed
git_repo = GitRepo.new(File.expand_path('.'), options)
git_repo.upload

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
