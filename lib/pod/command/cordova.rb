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
