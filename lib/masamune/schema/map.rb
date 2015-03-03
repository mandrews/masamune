#  The MIT License (MIT)
#
#  Copyright (c) 2014-2015, VMware, Inc. All Rights Reserved.
#
#  Permission is hereby granted, free of charge, to any person obtaining a copy
#  of this software and associated documentation files (the "Software"), to deal
#  in the Software without restriction, including without limitation the rights
#  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#  copies of the Software, and to permit persons to whom the Software is
#  furnished to do so, subject to the following conditions:
#
#  The above copyright notice and this permission notice shall be included in
#  all copies or substantial portions of the Software.
#
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#  THE SOFTWARE.

require 'csv'

module Masamune::Schema
  class Map
    class Buffer
      extend Forwardable

      def_delegators :@io, :flush, :path

      def initialize(table)
        @table  = table
        @store  = table.store
        @lines  = 0
      end

      def bind(io)
        @io = io.set_encoding('binary', 'UTF-8', undef: :replace)
        @csv = nil
      end

      def each(&block)
        raise 'must call Buffer#bind first' unless @io
        CSV.parse(@io, options.merge(headers: @store.headers || @table.columns.keys)) do |data|
          row = Masamune::Schema::Row.new(parent: @table, values: data.to_hash, strict: false)
          yield row.to_hash
        end
      end

      def append(data)
        raise 'must call Buffer#bind first' unless @io
        row = Masamune::Schema::Row.new(parent: @table, values: data.to_hash)
        write_headers = @store.headers && @lines < 1
        @csv ||= CSV.new(@io, options.merge(headers: row.headers, write_headers: write_headers))
        @csv << row.serialize
        @lines += 1
      end

      def options
        if @store.format == :tsv
          { col_sep: "\t" }
        else
          {}
        end
      end
    end

    DEFAULT_ATTRIBUTES =
    {
      source:    nil,
      target:    nil,
      store:     nil,
      function:  ->(row) { row },
      debug:     false
    }

    DEFAULT_ATTRIBUTES.keys.each do |attr|
      attr_accessor attr
    end

    def initialize(opts = {})
      opts.symbolize_keys!
      raise ArgumentError, 'required parameter source: missing' unless opts.key?(:source)
      raise ArgumentError, 'required parameter target: missing' unless opts.key?(:target)
      DEFAULT_ATTRIBUTES.merge(opts).each do |name, value|
        public_send("#{name}=", value)
      end
    end

    def source=(source)
      @source = source
    end

    # FIXME: avoid implict conversions
    def target=(target)
      @target = target.type == :four ? target.ledger_table : target
    end

    # TODO: pass a default hash to function with expected default ruby value types, e.g, h[k] = {} for :key_value
    def columns
      Array.wrap(function.call({})).first.keys
    end

    def intermediate
      target.stage_table(columns: columns, inherit: false)
    end

    def apply(input_files, output_file)
      input_buffer  = Buffer.new(source)
      output_buffer = Buffer.new(intermediate)
      self.class.convert_files(input_files).each do |input_file|
        open_stream(input_file, 'r') do |input_stream|
          input_buffer.bind(input_stream)
          open_stream(output_file, 'a+') do |output_stream|
            output_buffer.bind(output_stream)
            apply_buffer(input_buffer, output_buffer)
          end
        end
      end
      intermediate
    end

    def open_stream(file, mode, &block)
      case file
      when IO, StringIO
        file.flush
        yield file
      when String, Tempfile
        File.open(file, mode) do |io|
          yield io
        end
      end
    end

    class << self
      def convert_file(file)
        if file.respond_to?(:path)
          file.flush if file.respond_to?(:flush) && file.respond_to?(:open?) && file.open?
          file.path
        else
          file
        end
      end

      def convert_files(files)
        case files
        when Set
          files.map { |file| convert_file(file) }.to_a
        when Array
          files.map { |file| convert_file(file) }.to_a
        else
          [convert_file(files)]
        end
      end
    end

    private

    def apply_buffer(input_buffer, output_buffer)
      input_buffer.each do |input|
        Array.wrap(function.call(input)).each do |output|
          output_buffer.append output
        end
      end
      output_buffer.flush
    end
  end
end
