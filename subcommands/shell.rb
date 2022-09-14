require 'shell_option'

options = ShellOption.new(SO2_CONFIG['default'])

command_options = OpenStruct.new

opts = OptionParser.new do |opts|
  opts.on("-s", "--server HOSTNAME", "Target server to upload") do |f|
    command_options.server = f
  end
end

opts.parse!(ARGV)
stage = opts.default_argv.first
stage = 'default' if stage.nil? || stage.start_with?('-')
options.set(SO2_CONFIG[stage])
options.set(command_options)
puts ""
options.print

options.run
