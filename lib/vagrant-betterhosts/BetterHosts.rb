require "rbconfig"
require "open3"

module VagrantPlugins
  module BetterHosts
    module BetterHosts
      def getIps
        ips = []

        if @machine.config.vm.networks.length == 0
            @ui.error("[vagrant-betterhosts] No ip address found for this virtual machine")
            exit
        end
        
        @machine.config.vm.networks.each do |network|
          key, options = network[0], network[1]
          ip = options[:ip] if (key == :private_network || key == :public_network) && options[:betterhosts] != "skip"
          ips.push(ip) if ip
          if options[:betterhosts] == "skip"
            @ui.info '[vagrant-betterhosts] Skipped adding host entries (config.vm.network betterhosts: "skip" is set)'
          end

          @machine.config.vm.provider :hyperv do |v|
            timeout = @machine.provider_config.ip_address_timeout
            @ui.output("[vagrant-betterhosts] Waiting for the guest machine to report its IP address ( this might take some time, have patience )...")
            @ui.detail("Timeout: #{timeout} seconds")

            options = {
              vmm_server_address: @machine.provider_config.vmm_server_address,
              proxy_server_address: @machine.provider_config.proxy_server_address,
              timeout: timeout,
              machine: @machine,
            }
            network = @machine.provider.driver.read_guest_ip(options)
            if network["ip"]
              ips.push(network["ip"]) unless ips.include? network["ip"]
            end
          end


        end
        return ips
      end

      # https://stackoverflow.com/a/13586108/1902215
      def get_os_binary
        return os ||= (host_os = RbConfig::CONFIG["host_os"]
                 case host_os
               when /mswin|msys|mingw|cygwin|bccwin|wince|emc/
                 :'cli.exe'
               when /darwin|mac os/
                 :'cli_osx'
               when /linux/
                 :'cli'
               else
                 raise Error::WebDriverError, "unknown os: #{host_os.inspect}"
               end)
      end

      def get_cli
        binary = get_os_binary
        path = File.expand_path(File.dirname(File.dirname(__FILE__))) + "/vagrant-betterhosts/bundle/"
        path = "#{path}#{binary}"

        return path
      end

      # Get a hash of hostnames indexed by ip, e.g. { 'ip1': ['host1'], 'ip2': ['host2', 'host3'] }
      def getHostnames(ips)
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

      def disableClean(ip_address)
        unless ip_address.nil?
          return @machine.config.betterhosts.disable_clean
        end
        return true
      end

      def addHostEntries
        error = false
        errorText = ""
        cli = get_cli
        hostnames_by_ips = generateHostnamesByIps
        
        return if not hostnames_by_ips.any?

        hostnames_by_ips.each do |ip_address, hostnames|
          if ip_address.nil?
            @ui.error "[vagrant-betterhosts] Error adding some hosts, no IP was provided for the following hostnames: #{hostnames}"
            next
          end
          @ui.info "[vagrant-betterhosts] Adding #{hostnames} for address #{ip_address}"
          if cli.include? ".exe"
            clean = "\"--clean\","
            if disableClean(ip_address)
                clean = ''
            end
            stdin, stdout, stderr, wait_thr = Open3.popen3("powershell", "-Command", "Start-Process '#{cli}' -ArgumentList \"add\",#{clean}\"#{ip_address}\",\"#{hostnames}\" -Verb RunAs")
          else
            clean = "--clean"
            if disableClean(ip_address)
                clean = ''
            end
            stdin, stdout, stderr, wait_thr = Open3.popen3("sudo '#{cli}' add #{clean} #{ip_address} #{hostnames}")
          end
          if !wait_thr.value.success?
            error = true
            errorText = stderr.read.strip
          end
        end
        printReadme(error, errorText)
      end

      def removeHostEntries
        error = false
        errorText = ""
        cli = get_cli
        hostnames_by_ips = generateHostnamesByIps

        return if not hostnames_by_ips.any?

        hostnames_by_ips.each do |ip_address, hostnames|
          if ip_address.nil?
            @ui.error "[vagrant-betterhosts] Error adding some hosts, no IP was provided for the following hostnames: #{hostnames}"
            next
          end
          if cli.include? ".exe"
            clean = "\"--clean\","
            if disableClean(ip_address)
                clean = ''
            end
            stdin, stdout, stderr, wait_thr = Open3.popen3("powershell", "-Command", "Start-Process '#{cli}' -ArgumentList \"remove\",#{clean}\"#{ip_address}\",\"#{hostnames}\" -Verb RunAs")
          else
            clean = "\"--clean\","
            if disableClean(ip_address)
                clean = ''
            end
            stdin, stdout, stderr, wait_thr = Open3.popen3("sudo '#{cli}' remove #{clean} #{ip_address} #{hostnames}")
          end
          if !wait_thr.value.success?
            error = true
            errorText = stderr.read.strip
          end
        end
        printReadme(error, errorText)
      end

      def printReadme(error, errorText)
        if error
          cli = get_cli
          @ui.error "[vagrant-betterhosts] Issue executing goodhosts CLI: #{errorText}"
          @ui.error "[vagrant-betterhosts] Cli path: #{cli}"
          if cli.include? ".exe"
            @ui.error "[vagrant-betterhosts] Check the readme at https://github.com/ajxb/vagrant-betterhosts#windows-uac-prompt"
            exit
          else
            @ui.error "[vagrant-betterhosts] Check the readme at https://github.com/ajxb/vagrant-betterhosts#passwordless-sudo"
          end
        end
      end

      def generateHostnamesByIps()
        ips = getIps
        return [] unless ips.any?

        hostnames_by_ips = {}
        hostnames = getHostnames(ips)
        ips.each do |ip|
          hostnames_by_ips[ip] = hostnames[ip].join(' ') if hostnames[ip].any?
        end

        hostnames_by_ips
      end
    end
  end
end
