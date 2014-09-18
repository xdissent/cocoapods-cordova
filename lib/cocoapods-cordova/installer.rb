module Pod
  module Cordova
    class Installer < Installer

      attr_accessor :plugin_name

      def initialize(plugin_name, sandbox, podfile, lockfile = nil)
        super sandbox, podfile, lockfile
        @plugin_name = plugin_name
      end

      # Filter out dependencies from cordova plugins and cordova itself
      def set_target_dependencies
        aggregate_targets.each do |aggregate_target|
          aggregate_target.pod_targets.each do |pod_target|
            if plugin_target_names.push(plugin_name).include? pod_target.pod_name
              aggregate_target.target.add_dependency(pod_target.target)
            end
            is_plugin = pod_target.pod_name == plugin_name
            pod_target.dependencies.each do |dep|
              is_excluded = (is_plugin and !plugin_target_names.include?(dep))
              unless dep == pod_target.pod_name or is_excluded 
                pod_dependency_target = aggregate_target.pod_targets.find { |target| target.pod_name == dep }
                # TODO remove me
                unless pod_dependency_target
                  puts "[BUG] DEP: #{dep}"
                end
                pod_target.target.add_dependency(pod_dependency_target.target)
              end
            end
          end
        end
      end

      # Use custom aggregate target installer
      def install_libraries
        UI.message '- Installing targets' do
          pod_targets.sort_by(&:name).each do |pod_target|
            next if pod_target.target_definition.empty?
            target_installer = PodTargetInstaller.new(sandbox, pod_target)
            target_installer.install!
          end

          aggregate_targets.sort_by(&:name).each do |target|
            next if target.target_definition.empty?
            target_installer = Pod::Cordova::AggregateTargetInstaller.new(sandbox, target, plugin_target_names)
            target_installer.install!
          end

          # TODO
          # Move and add specs
          pod_targets.sort_by(&:name).each do |pod_target|
            pod_target.file_accessors.each do |file_accessor|
              file_accessor.spec_consumer.frameworks.each do |framework|
                pod_target.target.add_system_framework(framework)
              end
            end
          end
        end
      end

      # Returns an array of specs for all resolved deps
      def pod_specs
        analysis_result.specs_by_target.find { |k, v|
          k.name == 'Pods'
        }.last
      end

      # Returns a hash of specs for all resolved deps keyed by name
      def pod_specs_by_name
        Hash[pod_specs.map { |spec| [spec.name, spec] }]
      end

      # Returns an array of all non-cordova pods included in the podfile
      def pod_deps
        pod_specs_by_name[plugin_name].dependencies.reject { |dep|
          dep.name == 'Cordova' or dep.name.start_with? 'CordovaPlugin-'
        }
      end

      def plugin_spec
        pod_specs_by_name[plugin_name]
      end

      def plugin_target_names
        plugin_target_specs.map { |spec|
          Specification.root_name spec.name
        }.uniq
      end

      def plugin_target_specs
        recursive_specs_for_deps(pod_deps).values
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