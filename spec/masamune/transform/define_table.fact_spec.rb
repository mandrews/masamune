require 'spec_helper'

describe Masamune::Transform::DefineTable do
  before do
    catalog.schema :postgres do
      dimension 'date', type: :date do
        column 'date_id', type: :integer, unique: true, index: true, natural_key: true
      end

      dimension 'user_agent', type: :mini do
        column 'name', type: :string, unique: true, index: 'shared'
        column 'version', type: :string, unique: true, index: 'shared', default: 'Unknown'
        column 'description', type: :string, null: true, ignore: true
      end

      dimension 'feature', type: :mini do
        column 'name', type: :string, unique: true, index: true
      end

      dimension 'tenant', type: :two do
        column 'tenant_id', type: :integer, index: true, natural_key: true
      end

      dimension 'user', type: :two do
        column 'tenant_id', type: :integer, index: true, natural_key: true
        column 'user_id', type: :integer, index: true, natural_key: true
      end

      fact 'visits', partition: 'y%Ym%m' do
        references :date
        references :tenant
        references :user
        references :user_agent, insert: true
        references :feature, insert: true
        measure 'total', type: :integer
      end

      file 'visits' do
        column 'date.date_id', type: :integer
        column 'tenant.tenant_id', type: :integer
        column 'user.user_id', type: :integer
        column 'user_agent.name', type: :string
        column 'user_agent.version', type: :string
        column 'feature.name', type: :string
        column 'time_key', type: :integer
        column 'total', type: :integer
      end
    end

    catalog.schema :hive do
      dimension 'date', type: :date, implicit: true do
        column 'date_id', type: :integer, natural_key: true
      end

      dimension 'user', type: :two, implicit: true do
        column 'user_id', type: :integer, natural_key: true
      end

      dimension 'group', type: :two, implicit: true do
        column 'group_id', type: :integer, natural_key: true
      end

      dimension 'user_agent', type: :mini do
        column 'name', type: :string
        column 'version', type: :string
        column 'description', type: :string, ignore: true
      end

      fact 'visits', grain: :hourly do
        partition :y
        partition :m
        partition :d
        references :date
        references :user
        references :group, multiple: true
        references :user_agent, denormalize: true
        measure 'total'
      end
    end
  end

  context 'for postgres fact' do
    let(:target) { catalog.postgres.visits_fact }

    subject(:result) { transform.define_table(target).to_s }

    it 'should eq render table template' do
      is_expected.to eq <<-EOS.strip_heredoc
        CREATE TABLE IF NOT EXISTS visits_fact
        (
          date_dimension_uuid UUID NOT NULL REFERENCES date_dimension(uuid),
          tenant_dimension_uuid UUID NOT NULL REFERENCES tenant_dimension(uuid),
          user_dimension_uuid UUID NOT NULL REFERENCES user_dimension(uuid),
          user_agent_type_id INTEGER NOT NULL REFERENCES user_agent_type(id),
          feature_type_id INTEGER NOT NULL REFERENCES feature_type(id),
          total INTEGER NOT NULL,
          time_key INTEGER NOT NULL,
          last_modified_at TIMESTAMP NOT NULL DEFAULT NOW()
        );

        DO $$ BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_class c WHERE c.relname = 'visits_fact_date_dimension_uuid_index') THEN
        CREATE INDEX visits_fact_date_dimension_uuid_index ON visits_fact (date_dimension_uuid);
        END IF; END $$;

        DO $$ BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_class c WHERE c.relname = 'visits_fact_tenant_dimension_uuid_index') THEN
        CREATE INDEX visits_fact_tenant_dimension_uuid_index ON visits_fact (tenant_dimension_uuid);
        END IF; END $$;

        DO $$ BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_class c WHERE c.relname = 'visits_fact_user_dimension_uuid_index') THEN
        CREATE INDEX visits_fact_user_dimension_uuid_index ON visits_fact (user_dimension_uuid);
        END IF; END $$;

        DO $$ BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_class c WHERE c.relname = 'visits_fact_user_agent_type_id_index') THEN
        CREATE INDEX visits_fact_user_agent_type_id_index ON visits_fact (user_agent_type_id);
        END IF; END $$;

        DO $$ BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_class c WHERE c.relname = 'visits_fact_feature_type_id_index') THEN
        CREATE INDEX visits_fact_feature_type_id_index ON visits_fact (feature_type_id);
        END IF; END $$;

        DO $$ BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_class c WHERE c.relname = 'visits_fact_time_key_index') THEN
        CREATE INDEX visits_fact_time_key_index ON visits_fact (time_key);
        END IF; END $$;
      EOS
    end
  end

  describe 'for fact table from file with sources files' do
    let(:files) { (1..3).map { |i| double(path: "output_#{i}.csv") } }
    let(:target) { catalog.postgres.visits_fact }
    let(:source) { catalog.postgres.visits_file }

    subject(:result) { transform.define_table(source.as_table(target), files).to_s }

    it 'should eq render table template' do
      is_expected.to eq <<-EOS.strip_heredoc
        CREATE TEMPORARY TABLE IF NOT EXISTS visits_fact_file
        (
          date_dimension_date_id INTEGER,
          tenant_dimension_tenant_id INTEGER,
          user_dimension_user_id INTEGER,
          user_agent_type_name VARCHAR,
          user_agent_type_version VARCHAR,
          feature_type_name VARCHAR,
          time_key INTEGER,
          total INTEGER
        );

        COPY visits_fact_file FROM 'output_1.csv' WITH (FORMAT 'csv');
        COPY visits_fact_file FROM 'output_2.csv' WITH (FORMAT 'csv');
        COPY visits_fact_file FROM 'output_3.csv' WITH (FORMAT 'csv');

        CREATE INDEX visits_fact_file_date_dimension_date_id_index ON visits_fact_file (date_dimension_date_id);
        CREATE INDEX visits_fact_file_tenant_dimension_tenant_id_index ON visits_fact_file (tenant_dimension_tenant_id);
        CREATE INDEX visits_fact_file_user_dimension_user_id_index ON visits_fact_file (user_dimension_user_id);
        CREATE INDEX visits_fact_file_user_agent_type_name_index ON visits_fact_file (user_agent_type_name);
        CREATE INDEX visits_fact_file_user_agent_type_version_index ON visits_fact_file (user_agent_type_version);
        CREATE INDEX visits_fact_file_feature_type_name_index ON visits_fact_file (feature_type_name);
        CREATE INDEX visits_fact_file_time_key_index ON visits_fact_file (time_key);
      EOS
    end

    context 'with file' do
      subject(:result) { transform.define_table(source.as_table(target), files.first).to_s }
      it 'should eq render table template' do
        is_expected.to_not be_nil
      end
    end

    context 'with Set' do
      subject(:result) { transform.define_table(source.as_table(target), Set.new(files)).to_s }
      it 'should eq render table template' do
        is_expected.to_not be_nil
      end
    end
  end

  context 'for hive fact' do
    let(:target) { catalog.hive.visits_hourly_fact }

    subject(:result) { transform.define_table(target).to_s }

    it 'should eq render table template' do
      is_expected.to eq <<-EOS.strip_heredoc
        CREATE TABLE IF NOT EXISTS visits_hourly_fact
        (
          date_dimension_date_id INT,
          user_dimension_user_id INT,
          group_dimension_group_id ARRAY<INT>,
          user_agent_type_name STRING,
          user_agent_type_version STRING,
          total INT,
          time_key INT
        )
        PARTITIONED BY (y INT, m INT, d INT);
      EOS
    end
  end
end
