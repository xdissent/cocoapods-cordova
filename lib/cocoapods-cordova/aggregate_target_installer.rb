module Pod
  module Cordova
    class AggregateTargetInstaller < Pod::Installer::AggregateTargetInstaller

      attr_accessor :plugin_targets

      def initialize(sandbox, library, plugin_targets)
        super sandbox, library
        @plugin_targets = plugin_targets
      end

      def install!
        super
        add_copy_resources_script_phase
      end

      def create_copy_resources_script
        pod_targets = library.pod_targets.dup
        library.pod_targets.select! { |pod|
          plugin_targets.include? pod.pod_name
        }
        super
        library.pod_targets = pod_targets
      end

      def add_copy_resources_script_phase
        phase_name = 'Copy Pods Resources'
        phase = target.shell_script_build_phases.select { |bp| bp.name == phase_name }.first
        phase ||= target.new_shell_script_build_phase(phase_name)
        phase.shell_script = %(export PODS_ROOT="#{sandbox.root}"; "#{library.copy_resources_script_path}"\n)
        phase.show_env_vars_in_log = '0'
      end
    end
  end
end