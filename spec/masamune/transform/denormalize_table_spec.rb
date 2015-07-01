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

describe Masamune::Transform::DenormalizeTable do
  before do
    catalog.schema :postgres do
      dimension 'cluster', type: :mini do
        column 'id', type: :sequence, surrogate_key: true, auto: true
        column 'name', type: :string

        row name: 'current_database()', attributes: {default: true}
      end

      dimension 'date', type: :date do
        column 'date_id', type: :integer, unique: true, index: true, natural_key: true
      end

      dimension 'tenant', type: :two do
        column 'tenant_id', type: :integer, index: true, natural_key: true
      end

      dimension 'user', type: :two do
        column 'tenant_id', type: :integer, index: true, natural_key: true
        column 'user_id', type: :integer, index: true, natural_key: true
      end

      dimension 'user_agent', type: :mini do
        column 'name', type: :string, unique: true, index: 'shared'
        column 'version', type: :string, unique: true, index: 'shared', default: 'Unknown'
        column 'mobile', type: :boolean, unique: true, index: 'shared', default: false
        column 'description', type: :string, null: true, ignore: true
      end

      fact 'visits', partition: 'y%Ym%m' do
        references :cluster
        references :date
        references :tenant
        references :user
        references :user_agent
        measure 'total', type: :integer
      end
    end
  end

  let(:target) { catalog.postgres.visits_fact }
  let(:columns) do
    [
      'date.date_id',
      'tenant.tenant_id',
      'user.tenant_id',
      'user.user_id',
      'user_agent.name',
      'user_agent.version',
      'total',
      'time_key'
    ]
  end

  context 'with postgres fact' do
    subject(:result) { transform.denormalize_table(target, columns).to_s }

    it 'should eq render denormalize_table template' do
      is_expected.to eq <<-EOS.strip_heredoc
      SELECT
        date_dimension.date_id AS date_dimension_date_id,
        tenant_dimension.tenant_id AS tenant_dimension_tenant_id,
        user_dimension.tenant_id AS user_dimension_tenant_id,
        user_dimension.user_id AS user_dimension_user_id,
        user_agent_type.name AS user_agent_type_name,
        user_agent_type.version AS user_agent_type_version,
        visits_fact.total,
        visits_fact.time_key
      FROM
        visits_fact
      JOIN
        date_dimension
      ON
        date_dimension.id = visits_fact.date_dimension_id
      JOIN
        tenant_dimension
      ON
        tenant_dimension.id = visits_fact.tenant_dimension_id
      JOIN
        user_dimension
      ON
        user_dimension.id = visits_fact.user_dimension_id
      JOIN
        user_agent_type
      ON
        user_agent_type.id = visits_fact.user_agent_type_id
      ORDER BY
        date_dimension_date_id,
        tenant_dimension_tenant_id,
        user_dimension_tenant_id,
        user_dimension_user_id,
        user_agent_type_name,
        user_agent_type_version,
        total,
        time_key
      ;
      EOS
    end
  end
end