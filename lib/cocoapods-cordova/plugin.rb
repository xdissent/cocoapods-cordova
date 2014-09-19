require 'rexml/document'
require 'pty'
require 'find'

module Pod
  module Cordova
    class Plugin

      attr_accessor :name, :sandbox, :podfile, :lockfile, :installer,
        :xml_path, :target_dir

      def initialize(name, sandbox, podfile, lockfile = nil)
        @name = name
        @sandbox = sandbox
        @podfile = podfile
        @lockfile = lockfile
        @installer = Pod::Cordova::Installer.new name, sandbox, podfile, lockfile
      end

      def install!
        @installer.install!
      end

      def update_xml!(target_dir, xml_path = nil)
        @target_dir = target_dir
        xml_path ||= find_xml_path
        @xml_path = xml_path
        clean_xml
        add_sources
        add_headers
        add_resources
        add_resource_bundles
        add_frameworks
        add_libraries
        write_xml!
      end

      def find_xml_path
        Pathname.new(target_dir).ascend { |dir|
          file = dir + 'plugin.xml'
          break file.realpath.to_s if file.file?
        }
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

      def plugin_relative_path(file)
        Pathname.new(file).relative_path_from(Pathname.new(xml_path).dirname).to_s
      end

      def add_headers
        headers.each { |file|
          add_element 'header-file', 'src' => plugin_relative_path(file)
        }
      end

      def add_sources
        sources.each { |file|
          add_element 'source-file', 'framework' => true,
            'src' => plugin_relative_path(file)
        }
      end

      def add_resources
        resources.each { |file|
          add_element 'resource-file', 'src' => plugin_relative_path(file)
        }
      end

      def add_resource_bundles
        resource_bundles.each { |file|
          add_element 'resource-file', 'src' => plugin_relative_path(file),
              'target-dir' => File.basename(file)
        }
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

      def sources
        Dir.glob(File.join sources_path, '*.a').map { |file|
          File.absolute_path file
        }
      end

      def headers
        Dir.glob(File.join headers_path, '**/*.h').reject { |file|
          File.directory? file
        }.map { |file| File.absolute_path file }
      end

      def resources
        Dir.glob(File.join resources_path, '**/*').reject { |file|
          File.basename(file).end_with?('.a') or
            File.basename(file).end_with?('.h') or
            File.directory?(file) or
            plugin_relative_path(file) =~ /\/?[^\/]+.bundle\//
        }.map { |file| File.absolute_path file }
      end

      def resource_bundles
        Dir.glob(File.join resources_path, '**/*.bundle').map { |file|
          File.absolute_path file
        }
      end

      def libraries
        consumers.map(&:libraries).flatten.compact.uniq
      end

      def frameworks
        consumers.map(&:frameworks).flatten.compact.uniq
      end

      def sources_path
        File.join target_dir, 'ios'
      end

      def headers_path
        File.join target_dir, 'ios', 'include'
      end

      def resources_path
        File.join target_dir, 'ios'
      end

      def consumers
        installer.plugin_target_specs.push(installer.plugin_spec).map { |spec|
          spec.consumer :ios
        }
      end
    end
  end
end