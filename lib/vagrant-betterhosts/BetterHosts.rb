# The core of the plugin
require "rbconfig"
require "open3"
require "resolv"
require "os"

module VagrantPlugins
  module BetterHosts
    # Plugin module
    module BetterHosts
      def get_ips
        ips = []

        if @machine.provider_name == :docker
            @ui.info '[vagrant-betterhosts] Docker detected, adding 127.0.0.1 and ::1 IP addresses'
            ip = "127.0.0.1"
            ips.push(ip) unless ip.nil? or ips.include? ip
            ip = "::1"
            ips.push(ip) unless ip.nil? or ips.include? ip
            return ips
        end

        if @machine.config.vm.networks.length == 0
            @ui.error("[vagrant-betterhosts] No ip address found for this virtual machine")
            exit
        end
        
        @machine.config.vm.networks.each do |network|
          key, options = network[0], network[1]
          if options[:betterhosts] == "skip"
            @ui.info '[vagrant-betterhosts] Skipped adding host entries (config.vm.network betterhosts: "skip" is set)'
          end
          ip = options[:ip] if (key == :private_network || key == :public_network) && options[:betterhosts] != "skip"
          ips.push(ip) if ip
        end
        if @machine.provider_name == :hyperv
          ip = @machine.provider.driver.read_guest_ip["ip"]
          @ui.info "[vagrant-betterhosts] Read guest IP #{ip} from Hyper-V provider"
          ips.push(ip) unless ip.nil? or ips.include? ip
        end
        return ips
      end

      def get_os_binary
        if OS.windows?
          return 'cli.exe'
        elsif OS.mac?
          if Etc.uname[:version].include? 'ARM64'
            return 'cli_arm64_osx'
          else
            return 'cli_amd64_osx'
          end
        elsif OS.linux?
          if Etc.uname[:version].include? 'ARM64'
            return 'cli_arm64_linux'
          else
            return 'cli_amd64_linux'
          end
        else
          raise Error::WebDriverError, "unknown os: #{host_os.inspect}"
        end
      end

      def get_cli
        binary = get_os_binary
        path = format('%s%s', File.expand_path(File.dirname(File.dirname(__FILE__))), "/vagrant-betterhosts/bundle/")
        path = "#{path}#{binary}"

        return path
      end

      # Get a hash of hostnames indexed by ip, e.g. { 'ip1': ['host1'], 'ip2': ['host2', 'host3'] }
      def get_hostnames(ips)
        hostnames = Hash.new { |h, k| h[k] = [] }

        case @machine.config.betterhosts.aliases
        when Array
          hostnames[ips[0]] += @machine.config.betterhosts.aliases
        when Hash
          # complex definition of aliases for various ips
          @machine.config.betterhosts.aliases.each do |ip, hosts|
            hostnames[ip] += Array(hosts)
          end
        end

        # handle default hostname(s) if not already specified in the aliases
        Array(@machine.config.vm.hostname).each do |host|
          next unless hostnames.none? { |_, v| v.include?(host) }

          hostnames[ips[0]].unshift host
        end

        hostnames
      end

      def disable_clean(ip_address)
        unless ip_address.nil?
          return @machine.config.betterhosts.disable_clean
        end
        return true
      end

      def check_hostnames_to_add(ip_address, hostnames)
        hostnames_to_add = Array.new
        hostnames = hostnames.split
        # check which hostnames actually need adding
        hostnames.each do |hostname|
          begin
            address = Resolv.getaddress(hostname)
            if address != ip_address
              hostnames_to_add.append(hostname)
            end
          rescue StandardError => _e
            hostnames_to_add.append(hostname)
          end
        rescue StandardError => _e
          hostnames_to_add.append(hostname)
        end
        return hostnames_to_add.join(' ')
      end

      def add_betterhost_entries(ip_address, hostnames)
        cli = get_cli
        if cli.include? ".exe"
          clean = get_clean_parameter_by_system(ip_address, true)
          command = "Start-Process '#{cli}' -ArgumentList \"add\",#{clean}\"#{ip_address}\",\"#{hostnames}\" -Verb RunAs"
          stdin, stdout, stderr, wait_thr = Open3.popen3("powershell", "-Command", command)
        else
          clean = get_clean_parameter_by_system(ip_address, false)
          command = "sudo '#{cli}' add #{clean} #{ip_address} #{hostnames}"
          stdin, stdout, stderr, wait_thr = Open3.popen3(command)
        end
        return stdin, stdout, stderr, wait_thr, command
      end

      def add_host_entries
        error = false
        error_text = ''
        command = ''
        hostnames_by_ips = generate_hostnames_by_ips
        
        return if hostnames_by_ips.none?

        @ui.info "[vagrant-betterhosts] Checking for host entries"

        hostnames_by_ips.each do |ip_address, hostnames|
          if ip_address.nil?
            @ui.error "[vagrant-betterhosts] Error adding some hosts, no IP was provided for the following hostnames: #{hostnames}"
            next
          end

          # filter out the hosts we've already added
          hosts_to_add = check_hostnames_to_add(ip_address, hostnames)
          next if hosts_to_add.empty?

          _stdin, _stdout, stderr, wait_thr, command = add_betterhost_entries(ip_address, hosts_to_add)
          unless wait_thr.value.success?
            error = true
            error_text = stderr.read.strip
          end
        end
        print_readme(error, error_text, command)
      end

      def remove_betterhost_entries(ip_address, hostnames)
        cli = get_cli
        if cli.include? ".exe"
          clean = get_clean_parameter_by_system(ip_address, true)
          command = "Start-Process '#{cli}' -ArgumentList \"remove\",#{clean}\"#{ip_address}\",\"#{hostnames}\" -Verb RunAs"
          stdin, stdout, stderr, wait_thr = Open3.popen3("powershell", "-Command", command)
        else
          clean = get_clean_parameter_by_system(ip_address, false)
          command = "sudo '#{cli}' remove #{clean} #{ip_address} #{hostnames}"
          stdin, stdout, stderr, wait_thr = Open3.popen3(command)
        end
        return stdin, stdout, stderr, wait_thr, command
      end

      def remove_host_entries
        error = false
        error_text = ''
        command = ''
        hostnames_by_ips = generate_hostnames_by_ips

        return if hostnames_by_ips.none?

        @ui.info "[vagrant-betterhosts] Removing hosts"

        hostnames_by_ips.each do |ip_address, hostnames|
          if ip_address.nil?
            @ui.error "[vagrant-betterhosts] Error adding some hosts, no IP was provided for the following hostnames: #{hostnames}"
            next
          end

          _stdin, _stdout, stderr, wait_thr, command = remove_betterhost_entries(ip_address, hostnames)
          unless wait_thr.value.success?
            error = true
            error_text = stderr.read.strip
          end
        end
        print_readme(error, error_text, command)
      end

      def get_clean_parameter_by_system(ip_address, is_win)
        clean = "--clean"
        if is_win
          clean = "\"--clean\","
        end

        if disable_clean(ip_address)
          clean = ''
        end
        return clean
      end

      def print_readme(error, error_text, command)
        unless error
          @ui.info "[vagrant-betterhosts] Finished processing"
          return false
        end

        cli = get_cli
        @ui.error "[vagrant-betterhosts] Issue executing goodhosts CLI: #{error_text}"
        @ui.error "[vagrant-betterhosts] Command: #{command}"
        @ui.error "[vagrant-betterhosts] Cli path: #{cli}"
        if cli.include? ".exe"
          @ui.error "[vagrant-betterhosts] Check the readme at https://github.com/betterhosts/vagrant#windows-uac-prompt"
          exit
        else
          @ui.error "[vagrant-betterhosts] Check the readme at https://github.com/betterhosts/vagrant#passwordless-sudo"
        end
      end

      def generate_hostnames_by_ips
        ips = get_ips
        return [] unless ips.any?

        hostnames_by_ips = {}
        hostnames = get_hostnames(ips)
        ips.each do |ip|
          hostnames_by_ips[ip] = hostnames[ip].join(' ') if hostnames[ip].any?
        end

        hostnames_by_ips
      end
    end
  end
end
