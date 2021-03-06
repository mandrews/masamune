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

describe Masamune::DataPlan::Builder do
  describe '#build' do
    subject(:engine) do
      described_class.instance.build(namespaces, commands, sources, targets)
    end

    context 'with multiple namespaces' do
      let(:namespaces) { %w(a b) }
      let(:commands) { %w(load store) }
      let(:sources) { [{ path: 'log/%Y%m%d.*.log' }, { path: 'table/y=%Y/m=%m/d=%d' }] }
      let(:targets) { [{ path: 'table/y=%Y/m=%m/d=%d' }, { path: 'daily/%Y-%m-%d' }] }

      before do
        expect_any_instance_of(Masamune::DataPlan::Engine).to receive(:add_target_rule).with('a:load', path: 'table/y=%Y/m=%m/d=%d')
        expect_any_instance_of(Masamune::DataPlan::Engine).to receive(:add_source_rule).with('a:load', path: 'log/%Y%m%d.*.log')
        expect_any_instance_of(Masamune::DataPlan::Engine).to receive(:add_command_rule).with('a:load', an_instance_of(Proc))
        expect_any_instance_of(Masamune::DataPlan::Engine).to receive(:add_target_rule).with('b:store', path: 'daily/%Y-%m-%d')
        expect_any_instance_of(Masamune::DataPlan::Engine).to receive(:add_source_rule).with('b:store', path: 'table/y=%Y/m=%m/d=%d')
        expect_any_instance_of(Masamune::DataPlan::Engine).to receive(:add_command_rule).with('b:store', an_instance_of(Proc))
        subject
      end

      it 'should build a Masamune::DataPlan::Engine instance' do
      end
    end

    context 'with :for option' do
      let(:namespaces) { %w(a a a) }
      let(:commands) { %w(missing_before override missing_after) }
      let(:sources) { [{ path: 'log/%Y%m%d.*.log', for: 'override' }] }
      let(:targets) { [{ path: 'table/y=%Y/m=%m/d=%d', for: 'override' }] }

      before do
        expect_any_instance_of(Masamune::DataPlan::Engine).not_to receive(:add_target_rule).with('a:missing_before', anything)
        expect_any_instance_of(Masamune::DataPlan::Engine).not_to receive(:add_source_rule).with('a:missing_before', anything)
        expect_any_instance_of(Masamune::DataPlan::Engine).not_to receive(:add_command_rule).with('a:missing_before', an_instance_of(Proc))
        expect_any_instance_of(Masamune::DataPlan::Engine).to receive(:add_target_rule).with('a:override', path: 'table/y=%Y/m=%m/d=%d')
        expect_any_instance_of(Masamune::DataPlan::Engine).to receive(:add_source_rule).with('a:override', path: 'log/%Y%m%d.*.log')
        expect_any_instance_of(Masamune::DataPlan::Engine).to receive(:add_command_rule).with('a:override', an_instance_of(Proc))
        expect_any_instance_of(Masamune::DataPlan::Engine).not_to receive(:add_target_rule).with('a:missing_after', anything)
        expect_any_instance_of(Masamune::DataPlan::Engine).not_to receive(:add_source_rule).with('a:missing_after', anything)
        expect_any_instance_of(Masamune::DataPlan::Engine).not_to receive(:add_command_rule).with('a:missing_after', an_instance_of(Proc))
        subject
      end

      it 'should build a Masamune::DataPlan::Engine instance' do
      end
    end

    context 'with :skip option' do
      let(:namespaces) { %w(a a a) }
      let(:commands) { %w(missing_before override) }
      let(:sources) { [{ skip: true }, { path: 'log/%Y%m%d.*.log' }] }
      let(:targets) { [{ skip: true }, { path: 'table/y=%Y/m=%m/d=%d' }] }

      before do
        expect_any_instance_of(Masamune::DataPlan::Engine).not_to receive(:add_target_rule).with('a:missing_before', anything)
        expect_any_instance_of(Masamune::DataPlan::Engine).not_to receive(:add_source_rule).with('a:missing_before', anything)
        expect_any_instance_of(Masamune::DataPlan::Engine).not_to receive(:add_command_rule).with('a:missing_before', an_instance_of(Proc))
        expect_any_instance_of(Masamune::DataPlan::Engine).to receive(:add_target_rule).with('a:override', path: 'table/y=%Y/m=%m/d=%d')
        expect_any_instance_of(Masamune::DataPlan::Engine).to receive(:add_source_rule).with('a:override', path: 'log/%Y%m%d.*.log')
        expect_any_instance_of(Masamune::DataPlan::Engine).to receive(:add_command_rule).with('a:override', an_instance_of(Proc))
        subject
      end

      it 'should build a Masamune::DataPlan::Engine instance' do
      end
    end
  end
end
