require 'option'
require 'i18n'

class SendOption < Option
  OPTION_NAMES = %w{
    user server kube dir logfile
    restart_cmd start_cmd stop_cmd
    restart tailog ignore_untracked
    ignore files
    send_scp_command
  }
  def self.option_names; OPTION_NAMES end

  attr_accessor :prefix

  def address
    if @options.user
      "#{@options.user}@#{@options.server}"
    else
      @options.server
    end
  end

  def ssh_opt
    opt = ''
    if @options.pem
      pem = @options.pem.gsub(/\$HOME/, ENV['HOME'])
      opt += "-i #{pem}"
    end
    opt
  end

  def ssh(command)
    system("ssh #{ssh_opt} #{address} 'cd #{@options.dir}; #{command}'")
  end

  def out(command)
    `ssh #{ssh_opt} #{address} 'cd #{@options.dir}; #{command}'`
  end

  def local_file(file)
    prefix ? File.join(prefix, file) : file
  end

  def remote_file(file)
    prefix ? File.join(@options.dir, prefix, file) : File.join(@options.dir, file)
  end

  def kube_remote_files(file)
    Hash[kube_servers.map{|svr| [svr, "#{@kube['namespace']}/#{svr}:#{@kube['path']}#{local_file(file)}"]}]
  end

  def scp(file)
    if @options.ignore && @options.ignore.find{|ig| file.start_with?(ig)}
      puts "ignored: #{file}"
      return
    end
    if kube?
      kube_remote_files(file).each_pair do |svr, remote_file|
        cmd0 = "kubectl cp #{local_file(file)} #{remote_file} -c #{@kube['container'] || 'main'}"
        puts cmd0
        system cmd0
        cmd1 = "kubectl exec -n #{@kube['namespace']} -it #{svr} -c #{@kube['container'] || 'main'} -- chown root:root #{local_file(file)}"
        puts cmd1
        system cmd1
      end
    else
      if @options.send_scp_command
        cmd = I18n.interpolate(@options.send_scp_command, local: local_file(file), remote: "#{address}:#{remote_file(file)}")
      else
        cmd = "scp #{ssh_opt} #{local_file(file)} #{address}:#{remote_file(file)}"
      end
      puts cmd
      system cmd
    end
  end
end
