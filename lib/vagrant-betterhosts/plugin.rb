require_relative "BetterHosts"
require_relative "Action/BaseAction"
require_relative "Action/UpdateHosts"
require_relative "Action/RemoveHosts"

module VagrantPlugins
  module BetterHosts
    # Various Vagrant hooks
    class Plugin < Vagrant.plugin('2')
      name 'BetterHosts'
      description <<-DESC
        This plugin manages the /etc/hosts file for the host machine. An entry is
        created for the hostname attribute in the vm.config.
      DESC

      config(:betterhosts) do
        require_relative 'config'
        Config
      end

      action_hook(:betterhosts, :machine_action_up) do |hook|
        hook.append(Action::UpdateHosts)
      end

      action_hook(:betterhosts, :machine_action_boot) do |hook|
        hook.append(Action::UpdateHosts)
      end

      action_hook(:betterhosts, :machine_action_provision) do |hook|
        hook.before(Vagrant::Action::Builtin::Provision, Action::UpdateHosts)
      end

      action_hook(:betterhosts, :machine_action_halt) do |hook|
        hook.prepend(Action::RemoveHosts)
      end

      action_hook(:betterhosts, :machine_action_suspend) do |hook|
        hook.prepend(Action::RemoveHosts)
      end

      action_hook(:betterhosts, :machine_action_destroy) do |hook|
        hook.prepend(Action::RemoveHosts)
      end

      action_hook(:betterhosts, :machine_action_reload) do |hook|
        hook.prepend(Action::RemoveHosts)
        hook.append(Action::UpdateHosts)
      end

      action_hook(:betterhosts, :machine_action_resume) do |hook|
        hook.prepend(Action::RemoveHosts)
        hook.append(Action::UpdateHosts)
      end
    end
  end
end
