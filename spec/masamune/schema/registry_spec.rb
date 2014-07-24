require 'spec_helper'
require 'active_support/core_ext/string/strip'

describe Masamune::Schema::Registry do
  let(:instance) { described_class.new }

  describe '#schema' do
    context 'when schema contains dimensions' do
      before do
        instance.schema do
          dimension name: 'foo'
          dimension name: 'bar'
        end
      end

      subject { instance.dimensions }

      it { is_expected.to include :foo }
      it { is_expected.to include :bar }
    end

    context 'when schema contains columns' do
      before do
        instance.schema do
          dimension name: 'foo' do
            column name: 'bar'
            column name: 'baz'
          end
        end
      end

      subject { instance.dimensions[:foo].columns }

      it { is_expected.to include :bar }
      it { is_expected.to include :baz }
    end

    context 'when schema contains columns and values' do
      before do
        instance.schema do
          dimension name: 'table_one' do
            column name: 'column_one', type: :integer
            column name: 'column_two', type: :string
            value column_one: 1, column_two: 'a'
            value column_one: 2, column_two: 'b'
          end
        end
      end

      subject { instance.dimensions[:table_one].values }

      it { is_expected.to include(column_one: 1, column_two: 'a') }
      it { is_expected.to include(column_one: 2, column_two: 'b') }
    end

    context 'when schema contains references' do
      before do
        instance.schema do
          dimension name: 'foo'
          dimension name: 'bar'
          dimension name: 'baz' do
            references :foo
            references :bar
          end
        end
      end

      subject { instance.dimensions[:baz].references }

      it { is_expected.to include :foo }
      it { is_expected.to include :bar }
    end

    context 'when schema contains overrides' do
      before do
        instance.schema do
          dimension name: 'cluster', type: :mini do
            column name: 'uuid', type: :uuid, primary_key: true
            column name: 'name', type: :string, unique: true
            column name: 'description', type: :string

            value name: 'current_database()', default_record: true
          end
        end
      end

      subject { instance.dimensions[:cluster].columns }

      it { is_expected.to include :uuid }
      it { is_expected.to include :default_record }
      it { is_expected.to_not include :id }
    end
  end
end
