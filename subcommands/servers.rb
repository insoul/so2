require 'servers_option'

options = ServersOption.new(SO2_CONFIG['default'])

command_options = OpenStruct.new

opts = OptionParser.new do |opts|
  opts.on("-s", "--stage STAGE", "Target server to upload") do |f|
    command_options.stage = f
  end
  opts.on("-p", "--pod-regex POD", "Target kube pod to upload as regular expression") do |f|
    command_options.pod_regex = f
  end
end

opts.parse!(ARGV)
stage = command_options.stage || 'default'
unless (SO2_CONFIG[stage]['available_subcommands'] || []).include?('shell')
  puts "#{stage} stage not allowed command 'shell'"
  exit
end
options.set(SO2_CONFIG[stage])
options.set(command_options)
options.kube_init!
puts ""
options.print

options.run
