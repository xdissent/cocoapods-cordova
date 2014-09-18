module Pod

  class Command
    class Cordova < Package

      # Inherit from Package but act like a top-level command
      Package.subcommands.delete self
      Command.subcommands.push self

      self.summary = "Build a cordova plugin"

      self.description = <<-DESC
        Build a cordova plugin from podspec. The plugin is compiled as a single
        static library.
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
    end
  end
end
