require 'exec_option'

options = ExecOption.new(SO2_CONFIG['default'])

command_options = OpenStruct.new

opts = OptionParser.new do |opts|
  opts.on("-s", "--stage STAGE", "Target server to upload") do |f|
    command_options.stage = f
  end
end

opts.parse!(ARGV)
stage = command_options.stage || 'default'
unless (SO2_CONFIG[stage]['available_subcommands'] || []).include?('exec')
  puts "#{stage} stage not allowed command 'exec'"
  exit
end
options.set(SO2_CONFIG[stage])
options.set(command_options)
options.kube_init!
puts ""
options.print

options.run
