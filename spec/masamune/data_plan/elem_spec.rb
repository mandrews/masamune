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

describe Masamune::DataPlan::Elem do
  let(:engine) { Masamune::DataPlan::Engine.new }
  let(:name) { 'primary' }
  let(:type) { :target }
  let(:rule) { Masamune::DataPlan::Rule.new(engine, name, type, {path: 'report/%Y-%m-%d/%H'}) }
  let(:other_rule) { Masamune::DataPlan::Rule.new(engine, name, type, {path: 'log/%Y%m%d.*.log'}) }

  let(:start_time) { DateTime.civil(2013,07,19,11,07) }
  let(:other_start_time) { DateTime.civil(2013,07,20,0,0) }

  let(:options) { {tz: 'EST'} }
  let(:other_options) { {tz: 'PST'} }

  let(:instance) { described_class.new(rule, start_time, options) }

  describe '#path' do
    subject do
      instance.path
    end
    it { is_expected.to eq('report/2013-07-19/11') }
  end

  describe '#==' do
    subject do
      instance == other
    end

    context 'when rule, options, and start_time match' do
      let(:other) { described_class.new(rule, start_time, options) }
      it { is_expected.to eq(true) }
      it 'should have same hash' do
        expect(instance.hash).to eq(other.hash)
      end
    end

    context 'when rules differ' do
      let(:other) { described_class.new(other_rule, start_time) }
      it { is_expected.to eq(false) }
    end

    context 'when options differ' do
      let(:other) { described_class.new(rule, start_time, other_options) }
      it { is_expected.to eq(false) }
    end

    context 'when start_times differ' do
      let(:other) { described_class.new(rule, other_start_time) }
      it { is_expected.to eq(false) }
    end
  end

  describe '#last_modified_at' do
    let(:early) { Time.parse("2014-05-01 00:00:00 +0000") }
    let(:later) { Time.parse("2014-06-01 00:00:00 +0000") }

    subject do
      instance.last_modified_at.utc
    end

    context 'with missing mtime' do
      before do
        expect(rule.engine.filesystem).to receive(:stat).with(instance.path).
          and_return(nil)
      end

      it { is_expected.to eq(Masamune::DataPlan::Elem::MISSING_MODIFIED_AT) }
    end

    context 'with single mtime' do
      before do
        expect(rule.engine.filesystem).to receive(:stat).with(instance.path).
          and_return(OpenStruct.new(mtime: early))
      end

      it { is_expected.to eq(early) }
    end
  end
end
