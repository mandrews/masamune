require 'active_support/concern'
require 'masamune/actions/postgres'

module Masamune::Actions
  module Transform
    extend ActiveSupport::Concern
    extend Forwardable

    include Masamune::Actions::Postgres

    def_delegators :registry, :dimensions, :maps, :files

    FILE_MODE = 0777 - File.umask

    def load_dimension(file, source_file, target_table, map)
      input = File.open(file)
      output = Tempfile.new('masamune')
      FileUtils.chmod(FILE_MODE, output.path)

      target = target_table.type == :four ? target_table.ledger_table : target_table
      intermediate  = target.as_file(map.columns)

      source_file.bind(input)
      intermediate.bind(output)

      map.apply(source_file, intermediate)

      transform = Masamune::Transform::LoadDimension.new(intermediate.path, intermediate.as_table, target)
      logger.debug(transform.output.to_s) if (source_file.debug || map.debug)
      postgres file: transform.to_psql_file, debug: (source_file.debug || target_table.debug || map.debug)
    ensure
      input.close
      output.unlink
    end

    def consolidate_dimension(target_table)
      transform = Masamune::Transform::ConsolidateDimension.new(target_table)
      postgres file: transform.to_psql_file, debug: target_table.debug
    end
  end
end
