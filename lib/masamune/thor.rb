require 'date'

module Masamune
  module Thor
    def self.included(thor)
      thor.class_eval do
        include Masamune::Actions::Filesystem

        namespace :masamune
        class_option :help, :type => :boolean, :aliases => '-h', :desc => 'Show help', :default => false
        class_option :quiet, :type => :boolean, :aliases => '-q', :desc => 'Suppress all output', :default => false
        class_option :verbose, :type => :boolean, :aliases => '-v', :desc => 'Print command execution information', :default => false
        class_option :debug, :type => :boolean, :aliases => '-d', :desc => 'Print debugging information', :default => false
        class_option :no_op, :type => :boolean, :desc => 'Do not execute commands that modify state', :default => false
        class_option :dry_run, :type => :boolean, :aliases => '-n', :desc => 'Combination of --no-op and --verbose', :default => false
        class_option :jobflow, :aliases => '-j', :desc => 'Elastic MapReduce jobflow ID (Hint: elastic-mapreduce --list)', :required => Masamune.configuration.elastic_mapreduce[:enabled]
        class_option :config, :desc => 'Configuration file'
        class_option :version, :desc => 'Print version and exit'
        def initialize(*a)
          super

          if options[:help] || current_command.name == 'help' || ARGV.include?('-h') || ARGV.include?('--help')
            help
            exit
          end

          Masamune.configure do |config|
            # TODO also try /etc/masamune/config.yml, /etc/masamune/config.yml.erb, $HOME/.masamune/config.yml
            if options[:config]
              config.load(options[:config])
            end

            config.quiet    = options[:quiet]
            config.verbose  = options[:verbose] || options[:dry_run]
            config.debug    = options[:debug]
            config.no_op    = options[:no_op] || options[:dry_run]
            config.dry_run  = options[:dry_run]
            config.jobflow  = options[:jobflow]

            if options[:version]
              puts config.version
              puts config.to_s if options[:verbose]
              exit
            end
          end

          after_initialize
        end

        private

        def after_initialize(*a); end
      end

      def current_command
        @_initializer.last[:current_command]
      end
    end
  end
end

