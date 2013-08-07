require 'chronic'

module Masamune::Actions
  module DataFlow
    private

    def self.included(base)
      base.extend ClassMethods
      base.class_eval do
        attr_accessor :existing_sources, :missing_targets
        attr_accessor :desired_sources, :desired_targets

        class_option :start, :aliases => '-a', :desc => 'Start time', :default => nil
        class_option :stop, :aliases => '-b', :desc => 'Stop time', :default => Date.today.to_s
        class_option :sources, :desc => 'File of data sources to process'
        class_option :targets, :desc => 'File of data targets to process'

        private

        def desired_sources=(source_paths)
          @desired_sources = self.class.data_plan.sources_from_paths(current_command_name, source_paths)
        end

        def desired_targets=(target_paths)
          @desired_targets = self.class.data_plan.targets_from_paths(current_command_name, target_paths)
        end

        def desired_sources
          @desired_sources || []
        end

        # FIXME ensure uniqueness in spec
        def desired_targets
          @desired_targets ||
          desired_sources.map do |source|
            self.class.data_plan.targets_for_source(current_command_name, source.path)
          end.uniq.flatten
        end

        def existing_sources
          @existing_sources ||=
          desired_sources.select do |source|
            if fs.exists?(source.path)
              true
            else
              Masamune::print("skipping missing source #{source.path}")
              false
            end
          end.uniq.flatten
        end

        def missing_targets
          @missing_targets ||=
          desired_targets.reject do |target|
            if fs.exists?(target.path)
              Masamune::print("skipping existing #{target.path}")
              true
            else
              false
            end
          end.uniq.flatten
        end

        # TODO allow multiple after_initialize blocks
        def after_initialize
          raise Thor::RequiredArgumentMissingError, "No value provided for required options '--start'" unless options[:start] || options[:sources] || options[:targets]
          raise Thor::MalformattedArgumentError, "Cannot specify both option '--sources' and option '--targets'" if options[:sources] && options[:targets]

          self.desired_sources = parse_file_type(:sources, [])
          self.desired_targets = parse_file_type(:targets, [])

          if desired_targets.empty? && options[:start] && options[:stop]
            start = parse_datetime_type(:start)
            stop = parse_datetime_type(:stop)

            @desired_targets = self.class.data_plan.targets_for_date_range(current_command_name, start, stop)

            unless self.class.data_plan.resolve(current_command_name, desired_targets.map(&:path), options)
              abort "No matching missing targets #{current_command_name} between #{options[:start]} and #{options[:stop]}"
            end
            exit # NOTE resolve has executed original thor task via anonymous proc - safe to exit
          end
          # NOTE flow continues to original thor task
        end
      end
    end

    def current_command_name
      "#{self.class.namespace}:#{@_initializer.last[:current_command].name}"
    end

    def parse_datetime_type(key)
      value = options[key]
      Chronic.parse(value).tap do |datetime_value|
        Masamune::print("Using '#{datetime_value}' for --#{key}") if value != datetime_value
      end or raise Thor::MalformattedArgumentError, "Expected date time value for '--#{key}'; got #{value}"
    end

    def parse_file_type(key, default)
      return default unless key
      value = options[key] or return default
      File.exists?(value) or raise Thor::MalformattedArgumentError, "Expected file value for '--#{key}'; got #{value}"
      File.read(value).split(/\s+/)
    end

    module ClassMethods
      def source(source, loadtime_options = {})
        @@namespaces ||= []
        @@namespaces << namespace
        @@sources ||= []
        @@sources << [source, loadtime_options]
      end

      def target(target, loadtime_options = {})
        @@targets ||= []
        @@targets << [target, loadtime_options]
      end

      def create_command(*a)
        super.tap do
          @@commands ||= []
          @@commands << a
        end
      end

      def data_plan
        @@data_plan ||= Masamune::DataPlanBuilder.build_via_thor(@@namespaces, @@commands, @@sources, @@targets)
      end

      private

      # If internal call to Thor::Base.start fails, exit
      def exit_on_failure?
        true
      end
    end
  end
end
