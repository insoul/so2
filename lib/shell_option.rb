require 'option'

class ShellOption < Option
  OPTION_NAMES = %w{
    user server kube
  }
  def self.option_names; OPTION_NAMES end

  def run
    if kube?
      svr = kube_servers.last
      cmd = "kubectl exec -n #{@kube['namespace']} -it #{svr} -c #{@kube['container'] || 'main'} -- /bin/bash"
      puts cmd
      system cmd
    end
  end
end
