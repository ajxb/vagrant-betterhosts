require "vagrant-betterhosts/version"
require "vagrant-betterhosts/plugin"

module VagrantPlugins
  module BetterHosts
    def self.source_root
      @source_root ||= Pathname.new(File.expand_path('../../', __FILE__))
    end
  end
end

