require 'cocoapods-cordova/builder'
require 'pod/command/package'

module Pod

  class Command
    class Cordova < Package
      self.summary = "Short description of cocoapods-cordova."

      self.description = <<-DESC
        Longer description of cocoapods-cordova.
      DESC

      self.arguments = []

      def self.options
        [
          ['--force',     'Overwrite existing files.'],
          ['--no-mangle', 'Do not mangle symbols of depedendant Pods.'],
          ['--subspecs',  'Only include the given subspecs']
        ]
      end

      def initialize(argv)
        super
        path = Dir.glob(File.join config.installation_root, '*.podspec').first
        @spec ||= spec_with_path path
        @embedded = false
        @library = true
      end

      # Overridden to remove deps from other cordova-plugins and cordova itself
      def install_pod(platform_name)
        podfile = podfile_from_spec(
          File.basename(@path),
          @spec.name,
          platform_name,
          @spec.deployment_target(platform_name),
          @subspecs)

        # Adjust external source path for podspec to local path
        dep = podfile.dependencies.find { |dep| dep.name == @spec.name }
        dep.external_source.clear
        dep.external_source[:path] = File.dirname @path

        sandbox = Sandbox.new(config.sandbox_root)
        installer = Installer.new(sandbox, podfile)
        installer.install!

        # Find all dependencies resolved through non-cordova specs
        @installer = installer
        dep_specs = recursive_specs_for_deps(pod_deps).values.map { |spec|
          "Pods-#{spec.name}"
        }.uniq

        # Remove all target dependencies from cordova and cordova plugins
        installer.pods_project.targets.select { |target|
          ["Pods-#{@spec.name}", 'Pods'].include? target.display_name
        }.each { |target|
          target.dependencies.select! { |dep|
            dep_specs.include? dep.display_name
          }
        }
        installer.pods_project.save

        sandbox
      end

      # Overridden to use custom builder
      def perform_build(platform, sandbox)
        builder = Pod::Cordova::Builder.new(
          @source_dir,
          config.sandbox_root,
          sandbox.public_headers.root,
          @spec,
          @embedded,
          @mangle)

        builder.build(platform, @library)

        return unless @embedded
        builder.link_embedded_resources
      end

      # Returns an array of specs for all resolved deps
      def pod_specs
        @installer.analysis_result.specs_by_target.find { |k, v|
          k.name == 'Pods'
        }.last
      end

      # Returns a hash of specs for all resolved deps keyed by name
      def pod_specs_by_name
        Hash[pod_specs.map { |spec| [spec.name, spec] }]
      end

      # Returns an array of all non-cordova pods included in the podfile
      def pod_deps
        pod_specs_by_name[@spec.name].dependencies.reject { |dep|
          dep.name == 'Cordova' or dep.name.start_with? 'CordovaPlugin-'
        }
      end

      # Returns specs for an array of deps
      def specs_for_deps(deps)
        deps.map { |dep| pod_specs_by_name[dep.name] }
      end

      # Returns a map of all specs and their deps keyed by name
      def recursive_specs_for_deps(deps, seen = {})
        new_specs = specs_for_deps(deps).reject {
          |spec| seen.has_key? spec.name
        }
        seen.merge! Hash[new_specs.map { |spec| [spec.name, spec] }]
        new_deps = new_specs.map(&:dependencies).flatten.compact.uniq(&:name).reject { |dep|
          seen.has_key? dep.name
        }
        return seen unless new_deps.present?
        recursive_specs_for_deps new_deps, seen
      end
    end
  end
end
