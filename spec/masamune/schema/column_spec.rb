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

require 'spec_helper'

describe Masamune::Schema::Column do
  describe '.initialize' do
    subject(:column) { described_class.new(id: 'id') }
    it { expect(column).to_not be_nil }

    context 'default' do
      context '#unique' do
        subject { column.unique }
        it { is_expected.to be_empty }
      end

      context '#index' do
        subject { column.index }
        it { is_expected.to be_empty }
      end
    end

    context 'without id' do
      subject(:column) { described_class.new }
      it { expect { column }.to raise_error ArgumentError }
    end

    context 'with default: true' do
      subject(:column) { described_class.new(id: 'boolean', type: :boolean, default: true) }
      context '#default' do
        subject { column.default }
        it { is_expected.to eq(true) }
      end
    end

    context 'with default: false' do
      subject(:column) { described_class.new(id: 'boolean', type: :boolean, default: false) }
      context '#default' do
        subject { column.default }
        it { is_expected.to eq(false) }
      end
    end

    context 'with index: false' do
      subject(:column) { described_class.new(id: 'id', index: false) }
      context '#index' do
        subject { column.index }
        it { is_expected.to be_empty }
      end
    end

    context 'with index: []' do
      subject(:column) { described_class.new(id: 'id', index: []) }
      context '#index' do
        subject { column.index }
        it { is_expected.to be_empty }
      end
    end

    context 'with index: true' do
      subject(:column) { described_class.new(id: 'id', index: true) }
      context '#index' do
        subject { column.index }
        it { is_expected.to include(:id) }
      end
    end

    context 'with index: "shared"' do
      subject(:column) { described_class.new(id: 'id', index: 'shared') }
      context '#index' do
        subject { column.index }
        it { is_expected.to include(:shared) }
      end
    end

    context 'with index: ["id", "shared"]' do
      subject(:column) { described_class.new(id: 'id', index: ['id', 'shared']) }
      context '#index' do
        subject { column.index }
        it { is_expected.to include(:id) }
        it { is_expected.to include(:shared) }
      end
    end

    context 'with index: nil' do
      subject(:column) { described_class.new(id: 'id', index: nil) }
      it { expect { column }.to raise_error ArgumentError }
    end

    context 'with unknown index: type' do
      subject(:column) { described_class.new(id: 'id', index: 1) }
      it { expect { column }.to raise_error ArgumentError }
    end
  end

  describe '#sql_type' do
    subject(:result) { column.sql_type }

    context 'with type :integer' do
      let(:column) { described_class.new(id: 'integer', type: :integer) }
      it { is_expected.to eq('INTEGER') }
    end

    context 'with type :integer and :array' do
      let(:column) { described_class.new(id: 'integer', type: :integer, array: true) }
      it { is_expected.to eq('INTEGER[]') }
    end

    context 'with type :string' do
      let(:column) { described_class.new(id: 'string', type: :string) }
      it { is_expected.to eq('VARCHAR') }
    end

    context 'with type :string and :array' do
      let(:column) { described_class.new(id: 'string', type: :string, array: true) }
      it { is_expected.to eq('VARCHAR[]') }
    end
  end

  describe '#hql_type' do
    subject(:result) { column.hql_type }

    context 'with type :integer' do
      let(:column) { described_class.new(id: 'integer', type: :integer) }
      it { is_expected.to eq('INT') }
    end

    context 'with type :integer and :array' do
      let(:column) { described_class.new(id: 'integer', type: :integer, array: true) }
      it { is_expected.to eq('ARRAY<INT>') }
    end

    context 'with type :string' do
      let(:column) { described_class.new(id: 'string', type: :string) }
      it { is_expected.to eq('STRING') }
    end

    context 'with type :string and :array' do
      let(:column) { described_class.new(id: 'string', type: :string, array: true) }
      it { is_expected.to eq('ARRAY<STRING>') }
    end
  end

  describe '#ruby_value' do
    subject(:result) { column.ruby_value(value) }

    context 'with type :boolean' do
      let(:column) { described_class.new(id: 'bool', type: :boolean) }

      context 'when 1' do
        let(:value) { 1 }
        it { is_expected.to eq(true) }
      end

      context "when '1'" do
        let(:value) { '1' }
        it { is_expected.to eq(true) }
      end

      context "when ''1''" do
        let(:value) { %Q{'1'} }
        it { is_expected.to eq(true) }
      end

      context 'when TRUE' do
        let(:value) { 'TRUE' }
        it { is_expected.to eq(true) }
      end

      context 'when true' do
        let(:value) { 'true' }
        it { is_expected.to eq(true) }
      end

      context 'when 0' do
        let(:value) { 0 }
        it { is_expected.to eq(false) }
      end

      context "when '0'" do
        let(:value) { '0' }
        it { is_expected.to eq(false) }
      end

      context "when ''0''" do
        let(:value) { %Q{'0'} }
        it { is_expected.to eq(false) }
      end

      context 'when FALSE' do
        let(:value) { 'FALSE' }
        it { is_expected.to eq(false) }
      end

      context 'when false' do
        let(:value) { 'false' }
        it { is_expected.to eq(false) }
      end

      context 'when nil ' do
        let(:value) { nil }
        it { is_expected.to be(nil) }
      end

      context 'when "junk"' do
        let(:value) { 'junk' }
        it { is_expected.to be(nil) }
      end
    end

    context 'with type :date' do
      let(:column) { described_class.new(id: 'date', type: :date) }

      context 'when nil' do
        let(:value) { nil }
        it { is_expected.to be(nil) }
      end

      context 'when unknown' do
        let(:value) { 'unknown' }
        it { expect { result }.to raise_error ArgumentError, "Could not coerce 'unknown' into :date for column 'date'" }
      end

      context 'when Date' do
        let(:value) { Date.civil(2015,01,01) }
        it { is_expected.to eq(value) }
      end

      context 'when YYYY-mm-dd' do
        let(:value) { '2015-01-01' }
        it { is_expected.to eq(Date.civil(2015,01,01)) }
      end

      context 'when ISO8601' do
        let(:value) { Date.parse('2015-01-01').iso8601 }
        it { is_expected.to eq(Date.civil(2015,01,01)) }
      end
    end

    context 'with type :timestamp' do
      let(:column) { described_class.new(id: 'timestamp', type: :timestamp) }

      context 'when nil' do
        let(:value) { nil }
        it { is_expected.to be(nil) }
      end

      context 'when Date' do
        let(:value) { Date.civil(2015,01,01) }
        it { is_expected.to eq(value.to_time) }
      end

      context 'when DateTime' do
        let(:value) { DateTime.civil(2015,01,01) }
        it { is_expected.to eq(value.to_time) }
      end

      context 'when Time' do
        let(:value) { Time.now }
        it { is_expected.to eq(value) }
      end

      context 'when Integer' do
        let(:value) { Time.now.utc.to_i }
        it { is_expected.to eq(Time.at(value)) }
      end

      context 'when String encoded Integer' do
        let(:value) { "#{Time.now.utc.to_i}" }
        it { is_expected.to eq(Time.at(value.to_i)) }
      end

      context 'when YYYY-mm-dd' do
        let(:value) { '2015-01-01' }
        it { is_expected.to eq(Time.parse(value)) }
      end

      context 'when ISO8601' do
        let(:value) { Date.parse('2015-01-01').to_time.iso8601 }
        it { is_expected.to eq(Date.civil(2015,01,01).to_time) }
      end
    end

    context 'with type :integer and :array' do
      let(:column) { described_class.new(id: 'int[]', type: :integer, array: true) }

      context 'when nil' do
        let(:value) { nil }
        it { is_expected.to eq([]) }
      end

      context "when 'NULL'" do
        let(:value) { 'NULL' }
        it { is_expected.to eq([]) }
      end

      context 'when scalar' do
        let(:value) { '1' }
        it { is_expected.to eq([1]) }
      end

      context 'when array' do
        let(:value) { '[1,2]' }
        it { is_expected.to eq([1,2]) }
      end
    end

    context 'with type :json' do
      let(:column) { described_class.new(id: 'json', type: :json) }

      context 'when nil' do
        let(:value) { nil }
        it { is_expected.to eq({}) }
      end

      context "when 'NULL'" do
        let(:value) { 'NULL' }
        it { is_expected.to eq({}) }
      end

      context 'when scalar' do
        let(:value) { '1' }
        it { is_expected.to eq(1) }
      end

      context 'when array' do
        let(:value) { '{"k":"v"}' }
        it { is_expected.to eq({"k" => "v"}) }
      end
    end

    context 'with type :yaml and sub_type :boolean' do
      let(:column) { described_class.new(id: 'yaml', type: :yaml, sub_type: :boolean) }
      let(:value) do
        {
          'true'         => true,
          'one'          => '1',
          'zero'         => '0',
          'false'        => false,
          'string'       => 'string',
          'one_integer'  => 1,
          'zero_integer' => 0
        }.to_yaml
      end

      it 'should cast yaml to ruby' do
        expect(result['true']).to eq(true)
        expect(result['false']).to eq(false)
        expect(result['one']).to eq(true)
        expect(result['zero']).to eq(false)
        expect(result['one_integer']).to eq(true)
        expect(result['zero_integer']).to eq(false)
        expect(result.key?('string')).to eq(false)
      end
    end
  end

  describe '#default_ruby_value' do
    subject(:result) { column.default_ruby_value }

    [:boolean, :integer, :string].each do |type|
      context "with type :#{type}" do
        let(:column) { described_class.new(id: 'column', type: type) }
        it { is_expected.to be_nil }
      end
    end

    context 'with type :date' do
      let(:column) { described_class.new(id: 'column', type: :date) }
      it { is_expected.to eq(Date.new(0)) }
    end

    context 'with type :timestamp' do
      let(:column) { described_class.new(id: 'column', type: :timestamp) }
      it { is_expected.to eq(Time.new(0)) }
    end

    [:json, :yaml, :key_value].each do |type|
      context "with type :#{type}" do
        let(:column) { described_class.new(id: 'column', type: type) }
        it { is_expected.to eq({}) }
      end
    end

    context 'with array' do
      let(:column) { described_class.new(id: 'column', type: :integer, array: true) }
      it { is_expected.to eq([]) }
    end
  end

  describe '#csv_value' do
    subject(:result) { column.csv_value(value) }

    context 'with type :string' do
      let(:column) { described_class.new(id: 'string', type: :string) }

      context 'when nil' do
        let(:value) { nil }
        it { is_expected.to eq(nil) }
      end

      context 'when blank' do
        let(:value) { '' }
        it { is_expected.to eq(nil) }
      end

      context 'when present' do
        let(:value) { 'value' }
        it { is_expected.to eq('value') }
      end
    end

    context 'with type :boolean' do
      let(:column) { described_class.new(id: 'bool', type: :boolean) }

      context 'when true' do
        let(:value) { true }
        it { is_expected.to eq('TRUE') }
      end

      context 'when false' do
        let(:value) { false }
        it { is_expected.to eq('FALSE') }
      end
    end

    context 'with type :boolean with store :hive' do
      let(:column) { described_class.new(id: 'bool', type: :boolean) }

      before do
        allow(column).to receive_message_chain(:parent, :store, :type).and_return(:hive)
      end

      context 'when true' do
        let(:value) { true }
        it { is_expected.to eq('TRUE') }
      end

      context 'when false' do
        let(:value) { false }
        it { is_expected.to eq(nil) }
      end
    end

    context 'with type :integer and :array' do
      let(:column) { described_class.new(id: 'int[]', type: :integer, array: true) }

      context 'when nil' do
        let(:value) { nil }
        it { is_expected.to eq('[]') }
      end

      context 'when scalar integer' do
        let(:value) { 1 }
        it { is_expected.to eq('[1]') }
      end

      context 'when scalar string' do
        let(:value) { '1' }
        it { is_expected.to eq('[1]') }
      end

      context 'when array of integer' do
        let(:value) { [1,2] }
        it { is_expected.to eq('[1,2]') }
      end

      context 'when array of string' do
        let(:value) { ['1','2'] }
        it { is_expected.to eq('[1,2]') }
      end
    end

    context 'with type :string and :array' do
      let(:column) { described_class.new(id: 'string[]', type: :string, array: true) }

      context 'when nil' do
        let(:value) { nil }
        it { is_expected.to eq('[]') }
      end

      context 'when scalar string' do
        let(:value) { '1' }
        it { is_expected.to eq('["1"]') }
      end

      context 'when scalar integer' do
        let(:value) { 1 }
        it { is_expected.to eq('["1"]') }
      end

      context 'when array of string' do
        let(:value) { ['1','2'] }
        it { is_expected.to eq('["1","2"]') }
      end

      context 'when array of integer' do
        let(:value) { [1,2] }
        it { is_expected.to eq('["1","2"]') }
      end
    end

    context 'with type :timestamp' do
      let(:column) { described_class.new(id: 'timestamp', type: :timestamp) }

      context 'when nil' do
        let(:value) { nil }
        it { is_expected.to be_nil }
      end

      context 'when Time' do
        let(:value) { Time.now }
        it { is_expected.to eq(value.utc.iso8601(3)) }
      end

      context 'when unknown' do
        let(:value) { 'unknown' }
        it { expect { result }.to raise_error ArgumentError, "Could not coerce 'unknown' into :timestamp for column 'timestamp'" }
      end
    end
  end

  describe '#==' do
    subject { column == other }

    context 'when identical reference' do
      let(:column) { described_class.new id: 'name', type: :string }
      let(:other) { column }
      it { is_expected.to eq(true) }
    end

    context 'when identical value' do
      let(:column) { described_class.new id: 'name', type: :string }
      let(:other) { column.dup }
      it { is_expected.to eq(true) }
    end

    context 'when different value' do
      let(:column) { described_class.new id: 'name', type: :string }
      let(:other) { described_class.new id: 'name', type: :integer }
      it { is_expected.to eq(false) }
    end
  end

  describe '#required_value?' do
    subject { column.required_value? }

    context 'by default' do
      let(:column) { described_class.new id: 'name', type: :string }
      it { is_expected.to eq(false) }
    end

    context 'when surrogate_key' do
      let(:column) { described_class.new id: 'name', type: :string, surrogate_key: true }
      it { is_expected.to eq(true) }

      context 'when reference allow null' do
        before do
          allow(column).to receive(:reference).and_return(double(null: true, default: nil))
        end
        it { is_expected.to eq(false) }
      end

      context 'when reference has default' do
        before do
          allow(column).to receive(:reference).and_return(double(null: false, default: 'Unknown'))
        end
        it { is_expected.to eq(false) }
      end
    end

    context 'when natural_key' do
      let(:column) { described_class.new id: 'name', type: :string, natural_key: true }
      it { is_expected.to eq(true) }

      context 'when reference allow null' do
        before do
          allow(column).to receive(:reference).and_return(double(null: true, default: nil))
        end
        it { is_expected.to eq(false) }
      end

      context 'when reference has default' do
        before do
          allow(column).to receive(:reference).and_return(double(null: false, default: 'Unknown'))
        end
        it { is_expected.to eq(false) }
      end
    end
  end
end
