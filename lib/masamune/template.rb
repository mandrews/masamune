require 'tilt'

module Masamune
  class Template
    def initialize(paths = [])
      @paths = Array.wrap(paths)
    end

    def render(template, parameters = {})
      resolved_template = resolve_file(template)
      Tilt.new(resolved_template).render(self, parameters)
    end

    private

    # TODO unify with resolve_path
    def resolve_file(partial_file)
      return partial_file if Pathname.new(partial_file).absolute?
      @paths.each do |path|
        file = File.expand_path(File.join(path, partial_file))
        return file if File.exists?(file) && File.file?(file)
      end
      raise IOError, "File not found: #{partial_file}"
    end

    class << self
      def render_to_file(template, parameters = {})
        raise IOError, "File not found: #{template}" unless File.exists?(template)
        instance = Template.new(File.dirname(template))
        Tempfile.new('masamune').tap do |file|
          file.write(instance.render(template, parameters))
          file.close
        end.path
      end
    end
  end
end