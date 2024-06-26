require 'option'
require 'i18n'

class ServersOption < Option
  OPTION_NAMES = %w{
    user server kube
    shell_ssh_command
    pod_regex
  }
  def self.option_names; OPTION_NAMES end

  def address
    if @options.user
      "#{@options.user}@#{@options.server}"
    else
      @options.server
    end
  end

  def run
    if kube?
      kube_servers.each do |svr|
        puts svr
      end
    else
      puts address
    end
  end
end
