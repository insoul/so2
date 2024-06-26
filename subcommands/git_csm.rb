# git changed submodule (csm)

require 'git_option'
require 'git_repo'

options = GitOption.new(SO2_CONFIG['default'])

command_options = OpenStruct.new

opts = OptionParser.new do |opts|
  opts.on("-u", "--update", "Update submodule what have new commit") do |f|
    command_options.changed_submodule_update = f
  end
  opts.on("-o [BRANCH]", "--co [BRANCH]", "--checkout [BRANCH]", "Checkout submodule what have new commit") do |f|
    command_options.changed_submodule_checkout = f
  end
end

opts.parse!(ARGV)
options.set(command_options)
git_repo = GitRepo.new(File.expand_path('.'), options)

git_repo.run
