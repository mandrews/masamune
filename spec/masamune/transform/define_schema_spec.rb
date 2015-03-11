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

describe Masamune::Transform::DefineSchema do
  context 'for postgres schema' do
    before do
      catalog.schema :postgres do
        dimension 'user_account_state', type: :mini do
          column 'name', type: :string, unique: true
          column 'description', type: :string
        end

        dimension 'user', type: :four do
          references :user_account_state
          column 'tenant_id', index: true, natural_key: true
          column 'user_id', index: true, natural_key: true
          column 'preferences', type: :key_value, null: true
        end

        file 'user' do
          column 'tenant_id', type: :integer
          column 'user_id', type: :integer
          column 'user_account_state.name', type: :string
          column 'preferences_now', type: :json
          column 'start_at', type: :timestamp
          column 'source_kind', type: :string
          column 'delta', type: :integer
        end
      end
    end

    subject(:result) { transform.define_schema(catalog, :postgres).to_s }

    it 'should render combined template' do
      is_expected.to eq Masamune::Template.combine \
        Masamune::Transform::Operator.new('define_schema', source: catalog.postgres),
        transform.define_table(catalog.postgres.dimensions['user_account_state']),
        transform.define_table(catalog.postgres.dimensions['user'])
    end
  end

  context 'for hive schema' do
    before do
      catalog.schema :hive do
        event 'tenant' do
          attribute 'tenant_id', type: :integer, immutable: true
          attribute 'account_state', type: :string
          attribute 'premium_type', type: :string
          attribute 'preferences', type: :json
        end
      end
    end

    subject(:result) { transform.define_schema(catalog, :hive).to_s }

    it 'should render combined template' do
      is_expected.to eq Masamune::Template.combine \
        Masamune::Transform::Operator.new('define_schema', source: catalog.hive),
        transform.define_event_view(catalog.hive.events['tenant'])
    end
  end
end