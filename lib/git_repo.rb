require 'ostruct'

class GitRepo
  attr_accessor :root, :options, :submodule

  class Change
    attr_accessor :repo, :mod, :file

    def initialize(repo, mod, file)
      @repo = repo
      @mod = mod
      @file = file
    end

    def submodule
      return nil unless repo.submodule?(file)
      return @submodule_repo if @submodule_repo
      opts = repo.options.dup
      opts.prefix = file
      @submodule_repo = GitRepo.new(File.join(repo.root, file), opts)
    end

    def this_changes
      if submodule
        submodule.this_changes
      else
        [self]
      end
    end

    def upload
      if submodule
        submodule.upload
      else
        repo.options.scp(file)
      end
    end
  end

  class Changes < Array
    attr_accessor :js_changed
  end

  def initialize(root, options = OpenStruct.new)
    @root = root
    @options = options
  end

  def submodules
    return @submodules if @submodules
    git_submodule = `cd #{root} && git submodule`
    submodule_dirs = git_submodule.split("\n").map{|e| e.split[1]}
    @submodules = submodule_dirs.map{|e| self.class.new(e)}
  end

  def submodule(path)
    submodules.find{|e| e.root == path}
  end

  def submodule?(path)
    submodules.index{|e| e.root == path}
  end

  def pull
    cmd = "cd #{root} && git pull"
    puts cmd
    system cmd
  end

  def checkout(branch)
    cmd = "cd #{root} && git checkout #{branch}"
    puts cmd
    system cmd
  end

  def this_changes
    return @this_changes if @this_changes

    status = `cd #{root} && git diff --name-status`
    status << `cd #{root} && git diff --name-status --cached`

    @this_changes = Changes.new
    status = status.split(/(\r\n|\r|\n)/)
    status.each do |st|
      next if st.chomp.empty?
      mod, file = st.strip.split(/\s+/)
      case mod
      when 'M', 'A', '??' then
        puts "\n#{mod} #{file}"
        @this_changes.js_changed = (file =~ /.*\.js/)
        change = Change.new(self, mod, file)
        @this_changes << change
      else
        puts "\n#{mod} #{file} skipped"
      end
    end

    dirties = `cd #{root} && git status --short`
    dirties.split(/(\r\n|\r|\n)/).each do |dirty|
      next if dirty.chomp.empty?
      mod, file = dirty.strip.split(/\s+/)
      if mod == "??"
        puts "\n#{mod} #{file}"
        @this_changes.js_changed = (file =~ /.*\.js/)
        change = Change.new(self, mod, file)
        @this_changes << change
      end
    end

    @this_changes
  end

  def changes
    return @changes  if @changes
    @changes = this_changes.map(&:this_changes).flatten
  end

  def changed_submodules
    this_changes.select{|e| e.mod == 'M'}.map{|e| submodule(e.file)}.compact
  end

  def upload
    this_changes.each do |change|
      if change.mod == '??' && options.ignore_untracked
        puts "ignore_untracked: #{change}"
      else
        change.upload
      end
    end
  end

  def run
    if @options.changed_submodule_update
      changed_submodules.each do |sm|
        sm.pull
      end
    elsif @options.changed_submodule_checkout
      changed_submodules.each do |sm|
        sm.checkout(@options.changed_submodule_checkout)
      end
    end
  end
end
