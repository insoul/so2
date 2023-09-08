require 'option'
require 'i18n'

class ExecOption < Option
  OPTION_NAMES = %w{
    user server kube
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
        cmd = [kube_env, "kubectl exec -n #{@kube['namespace']} -it #{svr} -c #{@kube['container'] || 'main'} -- #{ARGV.join(' ')}"].join(' ')
        puts cmd
        Kernel.print("Execute? [Y/n] ")
        inp = STDIN.getch
        puts inp
        if ['y', 'Y'].include?(inp)
          out = system(cmd)
          puts out
          next
        else
          puts 'STOP!!'
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
