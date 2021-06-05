module VagrantPlugins
  module BetterHosts
    module Action
      class RemoveHosts < BaseAction

        def run(env)
          machine_action = env[:machine_action]
          if machine_action != :destroy || !@machine.id
            if machine_action != :suspend || false != @machine.config.betterhosts.remove_on_suspend
              if machine_action != :halt || false != @machine.config.betterhosts.remove_on_suspend
                @ui.info "[vagrant-betterhosts] Removing hosts"
                removeHostEntries
              else
                @ui.info "[vagrant-betterhosts] Removing hosts on suspend disabled"
              end
            end
          end
        end

      end
    end
  end
end
