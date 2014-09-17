module Pod
  module Cordova
    class Builder < Builder

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

      # Overridden because the lib name matcher is borked upstream
      # TODO: Send PR
      def _mangle_for_pod_dependencies(pod_name, sandbox_root)
        pod_libs = Dir.glob("#{sandbox_root}/build/libPods-*.a").reject do
          |file| file == "#{sandbox_root}/build/libPods-#{@spec.name}.a"
        end

        dummy_alias = Symbols.alias_symbol "PodsDummy_Pods_#{pod_name}", pod_name
        all_syms = [dummy_alias]

        pod_libs.each do |pod_lib|
          syms = Symbols.symbols_from_library(pod_lib)
          all_syms += syms.map! { |sym| Symbols.alias_symbol sym, pod_name }
        end

        "GCC_PREPROCESSOR_DEFINITIONS='${inherited} #{all_syms.uniq.join(' ')}'"
      end

      # Overridden to use custom mangler
      def build_with_mangling
        UI.puts 'Mangling symbols'
        defines = _mangle_for_pod_dependencies(@spec.name, @sandbox_root)
        UI.puts 'Building mangled framework'
        xcodebuild(defines)
        defines
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