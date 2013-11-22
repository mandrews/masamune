require 'spec_helper'

describe Masamune::Commands::HadoopFilesystem do
  let(:configuration) { {options: options} }
  let(:options) { [] }
  let(:attrs) { {} }

  subject(:instance) { described_class.new(configuration.merge(attrs)) }

  describe '#command_args' do
    let(:attrs) { {extra: ['-ls', '/']} }

    subject { instance.command_args }

    it { should == ['hadoop', 'fs', '-ls', '/'] }

    context 'with options' do
      let(:options) { [{'--conf' => 'hadoop.conf'}] }

      it { should == ['hadoop', 'fs', '--conf', 'hadoop.conf', '-ls', '/'] }
    end
  end
end
