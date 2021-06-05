module VagrantPlugins
  module BetterHosts
    module Action
      class UpdateHosts < BaseAction

        def run(env)
          @ui.info "[vagrant-betterhosts] Checking for host entries"
          addHostEntries()
        end

      end
    end
  end
end
