module Pod
  class Command
    class Cordova < Package
      :private

      # Overridden for local path in generated spec
      def podfile_from_spec(path, spec_name, platform_name, deployment_target, subspecs)
        Pod::Podfile.new do
          platform(platform_name, deployment_target)
          if path
            if subspecs
              subspecs.each do |subspec|
                pod spec_name + '/' + subspec, :path => path
              end
            else
              pod spec_name, :path => path
            end
          else
            if subspecs
              subspecs.each do |subspec|
                pod spec_name + '/' + subspec, :path => '.'
              end
            else
              pod spec_name, :path => '.'
            end
          end
        end
      end

      # Overridden for custom installer
      def install_pod(platform_name)
        podfile = podfile_from_spec(
          File.dirname(@path),
          @spec.name,
          platform_name,
          @spec.deployment_target(platform_name),
          @subspecs)

        sandbox = Sandbox.new(config.sandbox_root)
        installer = Pod::Cordova::Installer.new(sandbox, podfile)
        installer.install!

        sandbox
      end
    end
  end
end