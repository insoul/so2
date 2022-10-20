require 'shell_option'

options = ShellOption.new(SO2_CONFIG['default'])

command_options = OpenStruct.new

opts = OptionParser.new do |opts|
  opts.on("-s", "--stage STAGE", "Target server to upload") do |f|
    command_options.stage = f
  end
end

opts.parse!(ARGV)
stage = command_options.stage || 'default'
options.set(SO2_CONFIG[stage])
options.set(command_options)
puts ""
options.print

options.run
