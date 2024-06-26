require 'option'
require 'i18n'

class ShellOption < Option
  OPTION_NAMES = %w{
    user server kube
    shell_ssh_command
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
      svr = kube_servers.last
      cmd = [kube_env, "kubectl exec -n #{@kube['namespace']} --context #{@kube['context']} -c #{@kube['container'] || 'main'} -it #{svr} -- /bin/bash"].join(' ')
      puts cmd
      system cmd
    else
      if @options.shell_ssh_command
        cmd = I18n.interpolate(@options.shell_ssh_command, address: address)
      else
        cmd = "ssh #{address}"
      end
      puts cmd
      system cmd
    end
  end
end
