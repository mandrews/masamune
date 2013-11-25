require 'date'
require 'thor'
require 'active_support/concern'

require 'masamune/after_initialize_callbacks'

module Masamune
  module Thor
    extend ActiveSupport::Concern

    include Masamune::HasContext
    include Masamune::AfterInitializeCallbacks

    SYSTEM_CONFIG_FILES = [
      '/etc/masamune/config.yml',
      '/etc/masamune/config.yml.erb',
      '/opt/masamune/etc/config.yml',
      '/opt/masamune/etc/config.yml.erb',
      '/opt/etc/masamune/config.yml',
      '/opt/etc/masamune/config.yml.erb',
      "#{ENV['HOME']}/.masamune/config.yml"
    ]

    module ExtraArguments
      def parse_extra(argv)
        if i = argv.index('--')
          if i > 0
            [argv[0 .. i-1], argv[i+1..-1]]
          else
            [[], argv[i+1..-1]]
          end
        else
          [argv, []]
        end
      end
    end

    module RescueLogger
      def start(*a)
        super
      rescue => e
        Masamune.logger.error(e.to_s)
        raise e
      end
    end

    included do |thor|
      thor.extend ExtraArguments
      thor.extend RescueLogger
      thor.class_eval do
        include Masamune::Actions::Filesystem
        include Masamune::Actions::ElasticMapreduce

        attr_accessor :current_namespace
        attr_accessor :current_task_name
        attr_accessor :current_command_name
        attr_accessor :extra

        namespace :masamune
        class_option :help, :type => :boolean, :aliases => '-h', :desc => 'Show help', :default => false
        class_option :quiet, :type => :boolean, :aliases => '-q', :desc => 'Suppress all output', :default => false
        class_option :verbose, :type => :boolean, :aliases => '-v', :desc => 'Print command execution information', :default => false
        class_option :debug, :type => :boolean, :aliases => '-d', :desc => 'Print debugging information', :default => false
        class_option :no_op, :type => :boolean, :desc => 'Do not execute commands that modify state', :default => false
        class_option :dry_run, :type => :boolean, :aliases => '-n', :desc => 'Combination of --no-op and --verbose', :default => false
        class_option :jobflow, :aliases => '-j', :desc => 'Elastic MapReduce jobflow ID (Hint: elastic-mapreduce --list)'
        class_option :config, :desc => 'Configuration file'
        class_option :version, :desc => 'Print version and exit'
        class_option :'--', :desc => 'Extra pass through arguments'
        def initialize(_args=[], _options={}, _config={})
          self.context.parent = self
          self.current_namespace = self.class.namespace
          self.current_task_name = _config[:current_command].name
          self.current_command_name = self.current_namespace + ':' + self.current_task_name

          if _options.is_a?(Array)
            _options, self.extra = self.class.parse_extra(_options)
          end

          super _args, _options, _config

          if display_help?
            display_help
            exit
          end

          context.configure do |config|
            if options[:config]
              config.load(options[:config]) rescue raise ::Thor::MalformattedArgumentError, "Could not load file provided for '--config'"
            elsif default_config_file = config.filesystem.resolve_file([Masamune.default_config_file] + SYSTEM_CONFIG_FILES)
              config.load(default_config_file)
            else
              raise ::Thor::RequiredArgumentMissingError, 'Option --config or valid system configuration file required'
            end

            config.quiet    = options[:quiet]
            config.verbose  = options[:verbose] || options[:dry_run]
            config.debug    = options[:debug]
            config.no_op    = options[:no_op] || options[:dry_run]
            config.dry_run  = options[:dry_run]

            if options[:version]
              puts config.version
              puts options if options[:verbose]
              puts config.to_s if options[:verbose]
              exit
            end
          end

          after_initialize_invoke(options)
        end

        private

        def display_help?
          options[:help] || current_task_name == 'help'
        end

        def display_help
          help
        end
      end
    end
  end
end

