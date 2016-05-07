require 'ostruct'

command_options = OpenStruct.new
opts = OptionParser.new do |opts|
  opts.banner = <<-EOS
Usage: gitup config [-e|--edit]
  By default, show #{GITUP_CONFIG_FILE}

  edit options:
    run #{GITUP_CONFIG_FILE} with
  EOS

  opts.on("-e", "--edit") do |f|
    command_options.edit = f
  end
end

opts.parse(ARGV)

editor = GITUP_SETTING["editor"] || "vim"
if command_options.edit
  `#{editor} #{GITUP_CONFIG_FILE}`
else
  config_content = `cat #{GITUP_CONFIG_FILE}`
  puts config_content
end
