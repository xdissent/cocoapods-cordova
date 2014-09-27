require 'pty'

module Pod
  module Cordova
    class Builder < Builder

      def build(platform, library)
        super
        copy_headers platform
        copy_resources platform
        copy_resource_bundles platform
      end

      def copy_headers(platform)
        header_path = Pathname.new(platform.name.to_s) + Pathname.new('include')
        header_path.mkdir unless header_path.exist?
        headers_source_root = "#{@public_headers_root}/#{@spec.name}"

        Dir.glob("#{headers_source_root}/**/*.h").each { |h|
          `ditto #{h} #{header_path}/#{h.sub(headers_source_root, '')}`
        }
      end

      def copy_resources(platform)
        resources_path = Pathname.new platform.name.to_s
        resources_path.mkdir unless resources_path.exist?

        Dir.glob("#{@sandbox_root}/build/**/*").reject { |file|
          File.basename(file).end_with?('.a') or
            File.basename(file).end_with?('.h') or
            File.directory?(file) or
            file =~ /\/?[^\/]+.bundle\// or
            file =~ /\/?[^\/]+.build\//
        }.each { |h|
          `ditto #{h} #{resources_path}/#{File.basename h}`
        }
      end

      def copy_resource_bundles(platform)
        resources_path = Pathname.new platform.name.to_s
        resources_path.mkdir unless resources_path.exist?

        Dir.glob("#{@sandbox_root}/build/*.bundle").each { |h|
          `ditto #{h} #{resources_path}/#{File.basename h}`
        }
      end

      # Execute a command, showing output, and raise an error if it fails
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

      # Overridden to use custom exec with output
      def build_static_lib_for_ios(static_libs, defines, output)
        exec! "libtool -static -o #{@sandbox_root}/build/package.a #{static_libs.join(' ')}"
        xcodebuild defines, '-sdk iphonesimulator', 'build-sim'
        sim_libs = static_libs_in_sandbox 'build-sim'
        exec! "libtool -static -o #{@sandbox_root}/build-sim/package.a #{sim_libs.join(' ')}"
        exec! "lipo #{@sandbox_root}/build/package.a #{@sandbox_root}/build-sim/package.a -create -output #{output}"
      end

      def xcodebuild(defines = '', args = '', build_dir = 'build')
        exec! "xcodebuild #{defines} CONFIGURATION_BUILD_DIR=#{build_dir} clean build #{args} -configuration Release -target Pods -project #{@sandbox_root}/Pods.xcodeproj 2>&1"
      end
    end
  end
end