require 'option'
require 'i18n'

class RestartOption < Option
  OPTION_NAMES = %w{
    user server kube
    restart_cmd
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
        cmd = [kube_env, "kubectl exec -n #{@kube['namespace']} -it #{svr} -c #{@kube['container'] || 'main'} -- #{@options.restart_cmd}"].join(' ')
        puts cmd
        out = system(cmd)
        puts out
        Kernel.print("Continue? [Y/n] ")
        inp = STDIN.getch
        puts inp
        if ['y', 'Y'].include?(inp)
          next
        else
          break
        end
      end
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
