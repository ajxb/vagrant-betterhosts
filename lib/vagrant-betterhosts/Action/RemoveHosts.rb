# Run when is removing the hosts
module VagrantPlugins
  module BetterHosts
    module Action
      # Remove hosts
      class RemoveHosts < BaseAction
        def run(env)
          machine_action = env[:machine_action]

          return unless @machine.id
          return unless %i[destroy halt suspend].include? machine_action

          if (%i[halt suspend].include? machine_action) && (false == @machine.config.goodhosts.remove_on_suspend)
            @ui.info '[vagrant-betterhosts] Removing hosts on suspend disabled'
          else
            remove_host_entries
          end
        end
      end
    end
  end
end
