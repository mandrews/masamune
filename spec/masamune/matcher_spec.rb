require 'spec_helper'

describe Masamune::Matcher do
  let(:rule) { 'report/%Y-%m-%d/%H' }
  let(:instance) { Masamune::Matcher.new(rule) }

=begin
  describe '#bind_date' do
    subject do
      instance.bind_date(input)
    end

    context 'with DateTime' do
      let(:input) { DateTime.civil(2013,04,05,23,13) }
      it { should == 'report/2013-04-05/23' }
    end
  end
=end

  describe '#bind' do
    let(:template) { 'table/y=%Y/m=%m/d=%d/h=%H' }

    subject do
      instance.bind(input, template)
    end

    context 'with match and full expansion' do
      let(:input) { 'report/2013-01-02/00' }
      it { should == 'table/y=2013/m=01/d=02/h=00' }
    end

    context 'with match and partial expansion' do
      let(:template) { 'table/%Y-%m' }
      let(:input) { 'report/2013-01-02/00' }
      it { should == 'table/2013-01' }
    end

    context 'with no match' do
      let(:input) { 'report' }
      it { should be_nil }
    end
  end

  describe '#matches' do
    subject do
      instance.matches?(input)
    end

    context 'when matches' do
      let(:input) { 'report/2013-01-02/00' }
      it { should be_true }
    end

    context 'when no match' do
      let(:input) { 'report' }
      it { should be_false }
    end

    context 'with alternative hour' do
      let(:rule) { 'requests/y=%Y/m=%-m/d=%-d/h=%-k' }
      let(:input) { 'requests/y=2013/m=5/d=1/h=1' }
      it { should be_true }
    end

    context 'with alternative hour' do
      let(:rule) { 'requests/y=%Y/m=%-m/d=%-d/h=%-k' }
      let(:input) { 'requests/y=2013/m=4/d=30/h=20' }
      it { should be_true }
    end
  end
end