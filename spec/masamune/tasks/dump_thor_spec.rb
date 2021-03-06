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

require 'masamune/tasks/dump_thor'

describe Masamune::Tasks::DumpThor do
  context 'with help command ' do
    let(:command) { 'help' }
    it_behaves_like 'command usage'
  end

  context 'with no arguments' do
    it_behaves_like 'executes with success'
  end

  context 'with --type=psql' do
    let(:options) { ['--type=psql'] }
    it_behaves_like 'executes with success'
  end

  context 'with --type=hql' do
    let(:options) { ['--type=hql'] }
    it_behaves_like 'executes with success'
  end

  context 'with --type=unknown' do
    let(:options) { ['--type=unknown'] }
    it_behaves_like 'raises Thor::MalformattedArgumentError', "Expected '--type' to be one of psql, hql; got unknown"
  end

  context 'with --section=pre' do
    let(:options) { ['--section=pre'] }
    it_behaves_like 'executes with success'
  end

  context 'with --section=post' do
    let(:options) { ['--section=post'] }
    it_behaves_like 'executes with success'
  end

  context 'with --section=all' do
    let(:options) { ['--section=all'] }
    it_behaves_like 'executes with success'
  end

  context 'with --section=unknown' do
    let(:options) { ['--section=unknown'] }
    it_behaves_like 'raises Thor::MalformattedArgumentError', "Expected '--section' to be one of pre, post, all; got unknown"
  end

  context 'with --skip-indexes' do
    let(:options) { ['--skip-indexes'] }
    it_behaves_like 'executes with success'
  end

  context 'with --no-skip-indexes' do
    let(:options) { ['--no-skip-indexes'] }
    it_behaves_like 'executes with success'
  end

  context "with --exclude='.*dimension'" do
    let(:options) { ["--exclude='.*dimension'"] }
    it_behaves_like 'executes with success'
  end

  context "with --exclude='.*dimension' '.*fact'" do
    let(:options) { ["--exclude='.*dimension' '.*fact'"] }
    it_behaves_like 'executes with success'
  end

  context 'with --start=yesterday' do
    let(:options) { ['--start=yesterday'] }
    it_behaves_like 'executes with success'
  end

  context 'with --stop=today' do
    let(:options) { ['--stop=today'] }
    it_behaves_like 'executes with success'
  end
end
