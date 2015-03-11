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

describe Masamune::Schema::Store do
  context 'without type' do
    subject(:store) { described_class.new }
    it { expect { store }.to raise_error ArgumentError, 'required parameter type: missing' }
  end

  context 'with type :unknown' do
    subject(:store) { described_class.new(type: :unknown) }
    it { expect { store }.to raise_error ArgumentError, "unknown type: 'unknown'" }
  end

  context 'with type :postgres' do
    subject(:store) { described_class.new(type: :postgres) }
    it { expect(store.format).to eq(:csv) }
    it { expect(store.headers).to be_truthy }
  end

  context 'with type :hive' do
    subject(:store) { described_class.new(type: :hive) }
    it { expect(store.format).to eq(:tsv) }
    it { expect(store.headers).to be_falsey }
  end
end