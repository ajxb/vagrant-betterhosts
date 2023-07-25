# Root file of the plugin
require "vagrant-betterhosts/version"
require "vagrant-betterhosts/plugin"

# Extend Vagrant Plugins
module VagrantPlugins
  # Load our plugin
  module BetterHosts
    def self.source_root
      @source_root ||= Pathname.new(File.expand_path('../../', __FILE__))
    end
  end
end
