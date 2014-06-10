require 'thread'
require 'tmpdir'
require 'logger'

require 'masamune/version'
require 'masamune/multi_io'

module Masamune
  class Context
    attr_accessor :parent
    attr_accessor :filesystem

    def initialize(parent = nil)
      self.parent = parent
    end

    def version
      "masamune #{Masamune::VERSION}"
    end

    def configure
      yield configuration
    end

    def configuration
      @configuration ||= Masamune::Configuration.new(self)
    end

    def mutex
      @mutex ||= Mutex.new
    end

    def with_exclusive_lock(name, &block)
      raise 'filesystem path :run_dir not defined' unless filesystem.has_path?(:run_dir)
      logger.debug("acquiring lock '#{name}'")
      lock_file = lock_file(name)
      lock_status = lock_file.flock(File::LOCK_EX | File::LOCK_NB)
      if lock_status == 0
        yield if block_given?
      else
        logger.error "acquire lock attempt failed for '#{name}'"
      end
    ensure
      if lock_file
        logger.debug("releasing lock '#{name}'")
        lock_file.flock(File::LOCK_UN)
      end
    end

    def log_file_template
      @log_file_template || "#{Time.now.to_i}-#{$$}.log"
    end

    def log_file_template=(log_file_template)
      @log_file_template = log_file_template
      reload_logger!
    end

    def reload_logger!
      @logger = nil
    end

    def log_enabled?
      if parent && parent.respond_to?(:log_enabled?)
        parent.log_enabled?
      else
        true
      end
    end

    def logger
      @logger ||= begin
        log_file_io = if log_enabled? && filesystem.has_path?(:log_dir)
          log_file = File.open(File.join(filesystem.path(:log_dir), log_file_template), 'a')
          log_file.sync = true
          FileUtils.ln_s(log_file, File.join(filesystem.path(:log_dir), 'latest'), force: true)
          configuration.debug ? Masamune::MultiIO.new($stderr, log_file) : log_file
        else
          configuration.debug ? $stderr : nil
        end
        Logger.new(log_file_io)
      end
    end

    def console(*a)
      line = a.join(' ').chomp
      mutex.synchronize do
        logger.info(line)
        $stdout.puts line unless configuration.quiet || configuration.debug
        $stdout.flush
        $stderr.flush
      end
    end

    def trace(*a)
      line = a.join(' ').chomp
      mutex.synchronize do
        logger.info(line)
        $stdout.puts line if configuration.verbose && !configuration.debug
        $stdout.flush
        $stderr.flush
      end
    end

    def filesystem
      @filesystem ||= begin
        filesystem = Masamune::Filesystem.new
        filesystem.add_path :root_dir, File.expand_path('../../../', __FILE__)
        filesystem = Masamune::MethodLogger.new(filesystem, :copy_file, :remove_dir, :move_file, :move_dir)
        Masamune::CachedFilesystem.new(filesystem)
      end
    end

    def postgres_helper
      @postgres_helper ||= Masamune::Helpers::Postgres.new(self)
    end

    def clear!
      filesystem.clear!
      postgres_helper.clear!
    end

    private

    def lock_file(name)
      path = filesystem.get_path(:run_dir, "#{name}.lock")
      File.open(path, File::CREAT, 0644)
    end
  end
end
