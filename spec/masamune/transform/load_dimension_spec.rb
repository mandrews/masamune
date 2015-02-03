require 'spec_helper'

describe Masamune::Transform::LoadDimension do
  before do
    registry.schema :postgres do
      dimension 'user_account_state', type: :mini do
        column 'name', type: :string, unique: true
        column 'description', type: :string
      end

      dimension 'department', type: :mini do
        column 'uuid', type: :uuid, surrogate_key: true
        column 'tenant_id', type: :integer, unique: true, natural_key: true
        column 'department_id', type: :integer, unique: true, natural_key: true
        row tenant_id: -1, department_id: -1, attributes: {default: true}
      end

      dimension 'user', type: :four do
        references :department, insert: true
        references :user_account_state
        column 'tenant_id', index: true, natural_key: true
        column 'user_id', index: true, natural_key: true
        column 'preferences', type: :key_value, null: true
      end

      file 'user', headers: true do
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

  let(:data) { double(path: 'output.csv') }
  let(:target) { registry.postgres.user_dimension }
  let(:source) { registry.postgres.user_file }
  let(:target_ledger) { target.ledger_table }
  let(:source_table) { source.as_table(target_ledger) }

  context 'with postgres dimension' do
    subject(:result) { transform.load_dimension(data, source, target).to_s }

    it 'should render combined template' do
      is_expected.to eq Masamune::Template.combine \
        transform.define_table(source_table, data),
        transform.insert_reference_values(source_table, target_ledger),
        transform.stage_dimension(source_table, target_ledger),
        transform.bulk_upsert(target_ledger.stage_table, target_ledger)
    end
  end
end
