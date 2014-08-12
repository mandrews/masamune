require 'spec_helper'
require 'active_support/core_ext/string/strip'

describe Masamune::Schema::Fact do
  subject { fact.as_psql }

  context 'with columns' do
    let(:dimension) do
      Masamune::Schema::Dimension.new id: 'user', type: :two,
        columns: [
          Masamune::Schema::Column.new(id: 'tenant_id', index: true),
          Masamune::Schema::Column.new(id: 'user_id', index: true)
        ]
    end

    let(:fact) do
      described_class.new id: 'visits',
        references: [dimension],
        columns: [
          Masamune::Schema::Column.new(id: 'total', type: :integer)
        ]
    end

    it 'should eq template' do
      is_expected.to eq <<-EOS.strip_heredoc
        CREATE TABLE IF NOT EXISTS visits_fact
        (
          user_dimension_uuid UUID NOT NULL REFERENCES user_dimension(uuid),
          total INTEGER NOT NULL,
          time_key INTEGER NOT NULL,
          last_modified_at TIMESTAMP NOT NULL DEFAULT NOW()
        );

        DO $$ BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_class c WHERE c.relname = 'visits_fact_user_dimension_uuid_index') THEN
        CREATE INDEX visits_fact_user_dimension_uuid_index ON visits_fact (user_dimension_uuid);
        END IF; END $$;

        DO $$ BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_class c WHERE c.relname = 'visits_fact_time_key_index') THEN
        CREATE INDEX visits_fact_time_key_index ON visits_fact (time_key);
        END IF; END $$;
      EOS
    end
  end
end
