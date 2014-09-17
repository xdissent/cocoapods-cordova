require 'rexml/document'
require 'pty'
require 'find'

module Pod
  module Cordova
    class Plugin

      attr_accessor :sandbox, :podfile, :lockfile, :sources, :installation_root

      def initialize(config)
        @sandbox = config.sandbox
        @podfile = config.podfile
        @lockfile = config.lockfile
        @sources = @podfile.sources.present? ? @podfile.sources : SourcesManager.master
        @installation_root = config.installation_root
      end

      def xml_path
        @xml_path ||= File.join @installation_root, 'plugin.xml'
      end

      def xml_doc
        @xml_doc ||= REXML::Document.new File.new xml_path
      end

      def xml_ios
        @xml_ios ||= REXML::XPath.first xml_doc, '//platform[@name="ios"]'
      end

      def clean_xml
        xml_ios.each_element_with_attribute('pod', 'true') { |e| e.remove }
      end

      def write_xml!
        File.open(xml_path, 'w') { |file| xml_doc.write file, 2 }
      end

      def build_xml!
        clean_xml
        add_headers
        add_source
        add_frameworks
        add_libraries
        add_resources
        write_xml!
      end

      def headers_path
        @headers_path ||= File.join sdk_build_path('iphoneos'), 'include'
      end

      def headers
        @headers ||= Find.find(headers_path).reject { |file|
          File.directory? file
        }.map { |file| file.gsub "#{installation_root}/", '' }
      end

      def add_headers
        headers.each { |file| add_element 'header-file', 'src' => file }
      end

      def product_path
        @product_path ||= File.join(build_path, product).gsub "#{installation_root}/", ''
      end

      def add_source
        add_element 'source-file', 'src' => product_path, 'framework' => true
      end

      def add_resources
        resources.each { |file| add_element 'resource-file', 'src' => file }
      end

      def add_frameworks
        frameworks.each { |name|
          add_element 'framework', 'src' => "#{name}.framework"
        }
      end

      def add_libraries
        libraries.each { |name|
          add_element 'framework', 'src' => "lib#{name}.dylib"
        }
      end

      def add_element(*args, &block)
        xml_ios.add_element pod_element *args, &block
      end

      def pod_element(tag, attrs = {})
        attrs['pod'] = 'true'
        element = REXML::Element.new tag
        element.add_attributes attrs
        element
      end

      def libraries
        @libraries ||= consumers.map(&:libraries).flatten.compact.uniq
      end

      def frameworks
        @frameworks ||= consumers.map(&:frameworks).flatten.compact.uniq
      end

      def resources
        @resources ||= Find.find(resources_path).reject { |file|
          relative = file.gsub "#{resources_path}/", ''
          File.directory? file or
            relative == product or
            relative.start_with? 'include/' or
            relative.start_with? 'libPods'
        }.map { |file| file.gsub "#{installation_root}/", '' }
      end

      def resources_path
        sdk_build_path 'iphoneos'
      end

      def workspace_path
        @workspace_path ||= Dir.glob(File.join installation_root, '*.xcworkspace').first
      end

      def workspace
        @workspace ||= Xcodeproj::Workspace.new_from_xcworkspace workspace_path
      end

      def scheme
        @scheme ||= workspace.schemes.reject { |k, v| k == 'Pods' }.keys.first
      end

      def build_path
        @build_path ||= File.join installation_root, 'build'
      end

      def sdk_build_path(sdk)
        File.join build_path, sdk
      end

      def pods_project_path
        @pods_project_path ||= workspace.schemes['Pods']
      end

      def default_defines(sdk)
        "CONFIGURATION_BUILD_DIR='#{sdk_build_path sdk}'"
      end

      def project_path
        @project_path ||= workspace.schemes.reject { |name, path|
          name == 'Pods'
        }.values.first
      end

      def build!(mangle = true)
        build_pods_project! # Always gotta build once to get names for mangling
        build_pods_project! 'iphoneos', true if mangle
        build_project! 'iphoneos', mangle
        build_pods_project! 'iphonesimulator', mangle
        build_project! 'iphonesimulator', mangle
        lipo!
      end

      def build_project!(sdk = 'iphoneos', mangle = false)
        defines = "#{default_defines sdk} OTHER_LDFLAGS='#{ldflags}'"
        defines = "#{defines} #{mangled_defines}" if mangle
        xcodebuild! project_path, scheme, "-sdk #{sdk}", defines
      end

      def build_pods_project!(sdk = 'iphoneos', mangle = false)
        defines = default_defines sdk
        defines = "#{defines} #{mangled_defines}" if mangle
        xcodebuild! pods_project_path, 'Pods', "-sdk #{sdk}", defines
      end

      def product
        "lib#{scheme}.a"
      end

      def exec!(cmd)
        PTY.spawn(cmd) do |stdin, stdout, pid|
          begin
            stdin.each { |line| UI.puts line }
          rescue Errno::EIO
            raise RuntimeError, "Command IO error: #{cmd}"
          end
          Process.wait pid
        end
        raise RuntimeError, "Command failed: #{cmd}" unless $?.exitstatus == 0
      rescue PTY::ChildExited
        raise RuntimeError, "Command exited abnormally: #{cmd}"
      end

      def lipo!
        exec! "lipo -create '#{sdk_build_path 'iphoneos'}/#{product}' '#{sdk_build_path 'iphonesimulator'}/#{product}' -output #{build_path}/#{product}"
      end

      def xcodebuild!(project, target, args = '', defines = '')
        exec! "xcodebuild #{defines} clean build #{args} -configuration Release -project '#{project}' -target '#{target}' 2>&1"
      end

      # Returns LDFLAGS for the project to statically link resolved pods
      def ldflags
        @ldflags ||= specs.map { |spec|
          "-l\"Pods-#{spec.name.gsub /\/.*/, ''}\""
        }.uniq.join ' '
      end

      def mangled_defines
        return @mangled_defines unless @mangled_defines.nil?
        dummy_alias = alias_symbol 'PodsDummy_Pods'
        all_syms = [dummy_alias]

        specs.map { |spec| spec.name.gsub /\/.*/, '' }.uniq.each do |name|
          syms = symbols_from_pod name
          all_syms += syms.map! { |sym| alias_symbol sym }
        end

        @mangled_defines = "GCC_PREPROCESSOR_DEFINITIONS='${inherited} #{all_syms.uniq.join(' ')}'"
      end

      def alias_symbol(sym)
        sym + "=CocoaPodsCordova_#{scheme.gsub '-', '_'}_" + sym
      end

      def symbols_from_pod(name)
        library = File.join sdk_build_path('iphoneos'), "libPods-#{name}.a"
        syms = `nm -g #{library}`.split("\n")

        result = classes_from_symbols syms
        result + constants_from_symbols(syms)
      end

      def classes_from_symbols(syms)
        classes = syms.select { |klass| klass[/OBJC_CLASS_\$_/] }
        classes = classes.select { |klass| klass !~ /_NS|_UI/ }
        classes = classes.uniq
        classes.map! { |klass| klass.gsub /^.*\$_/, '' }
      end

      def constants_from_symbols(syms)
        consts = syms.select { |const| const[/ S /] }
        consts = consts.select { |const| const !~ /OBJC|\.eh/ }
        consts = consts.uniq
        consts = consts.map! { |const| const.gsub /^.* _/, '' }

        other_consts = syms.select { |const| const[/ T /] }
        other_consts = other_consts.uniq
        other_consts = other_consts.map! { |const| const.gsub /^.* _/, '' }

        consts + other_consts
      end

      def resolver
        @resolver ||= Resolver.new sandbox, podfile, lockfile.dependencies, sources
      end

      def specs_by_target
        @specs_by_target ||= resolver.resolve
      end

      # Returns an array of specs for all resolved deps
      def pod_specs
        @pod_specs ||= specs_by_target.find { |k, v| k.name == 'Pods' }.last
      end

      # Returns a hash of specs for all resolved deps keyed by name
      def pod_specs_by_name
        @pod_specs_by_name ||= Hash[pod_specs.map { |spec| [spec.name, spec] }]
      end

      # Returns an array of all non-cordova pods included in the podfile
      def pod_deps
        podfile.target_definitions['Pods'].dependencies.reject { |dep|
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

      # Returns an array of specs for all resolved non-cordova deps
      def specs
        return @specs unless @specs.nil?
        @specs = recursive_specs_for_deps(pod_deps).values
      end

      # Returns an array of ios spec consumers for all resolved non-cordova deps
      def consumers
        @consumers ||= specs.map { |spec| spec.consumer 'ios' }
      end
    end
  end
end