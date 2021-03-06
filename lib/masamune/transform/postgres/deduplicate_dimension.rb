#  The MIT License (MIT)
#
#  Copyright (c) 2014-2016, VMware, Inc. All Rights Reserved.
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

module Masamune::Transform::Postgres
  class DeduplicateDimension
    def initialize(options = {})
      @target   = options[:target]
      @source   = options[:source]
    end

    def locals
      { target: target, source: @source }
    end

    def target
      TargetPresenter.new(@target)
    end

    class TargetPresenter < SimpleDelegator
      def insert_columns(_source = nil)
        consolidated_columns.map { |_, column| column.name }
      end

      def insert_view_values
        consolidated_columns.map do |_, column|
          column.name
        end
      end

      def insert_view_last_values(window)
        consolidated_columns.map do |_, column|
          if column.default.nil?
            "LAST_VALUE(#{column.name}) OVER #{window} AS #{column.name}"
          else
            "COALESCE(LAST_VALUE(#{column.name}) OVER #{window}, #{column.sql_value(column.default)}) AS #{column.name}"
          end
        end
      end

      def duplicate_value_conditions(window)
        [].tap do |result|
          consolidated_columns.map do |_, column|
            result <<
            if column.null
              "((LAG(#{column.name}) OVER #{window} = #{column.name}) OR (LAG(#{column.name}) OVER #{window} IS NULL AND #{column.name} IS NULL))"
            else
              "(LAG(#{column.name}) OVER #{window} = #{column.name})"
            end
          end
        end
      end

      def window(*extra)
        (columns.values.select { |column| extra.delete(column.name) || column.natural_key || column.auto_reference }.map(&:name) + extra).uniq
      end

      def start_at_with_grain
        case grain
        when :hourly
          "date_trunc('hour', start_at)"
        when :daily
          "date_trunc('day', start_at)"
        when :monthly
          "date_trunc('month', start_at)"
        end
      end

      private

      def consolidated_columns
        unreserved_columns.reject { |_, column| column.surrogate_key }
      end
    end
  end
end
