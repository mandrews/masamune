module Masamune::Actions
  module Streaming
    def streaming(opts = {})
      opts = opts.to_hash.symbolize_keys

      jobflow = opts[:jobflow] || Masamune.configuration.jobflow

      command = if jobflow
        Masamune::Commands::Streaming.new(opts.merge(quote: true, file_args: false))
      else
        Masamune::Commands::Streaming.new(opts)
      end

      command = Masamune::Commands::ElasticMapReduce.new(command, jobflow: jobflow) if jobflow
      command = Masamune::Commands::RetryWithBackoff.new(command)
      command = Masamune::Commands::Shell.new(command, fail_fast: true)
      command.execute
    end
  end
end
