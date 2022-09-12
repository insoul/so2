require 'ostruct'

command_options = OpenStruct.new
opts = OptionParser.new do |opts|
  opts.banner = <<-EOS
Usage: so2 config [-e|--edit]
  By default, show #{SO2_CONFIG_FILE}

  edit options:
    run #{SO2_CONFIG_FILE} with
  EOS

  opts.on("-e", "--edit") do |f|
    command_options.edit = f
  end
end

opts.parse(ARGV)

editor = SO2_SETTING["editor"] || "vim"
if command_options.edit
  `#{editor} #{SO2_CONFIG_FILE}`
else
  config_content = `cat #{SO2_CONFIG_FILE}`
  puts config_content
end
