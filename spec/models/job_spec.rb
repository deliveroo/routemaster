require 'spec_helper'
require 'routemaster/models/job'
require 'routemaster/jobs/null'

describe Routemaster::Models::Job do
  subject { described_class.new(name: 'null', args: args) }
  
  shared_examples 'a job' do
    describe 'serialization' do
      let(:result) { described_class.load(subject.dump) }

      it { expect { result }.not_to raise_error }
      it { expect(result.name).to eq('null') }
      it { expect(result.args).to eq(called_args) }
    end

    describe '#perform' do
      it 'runs the job' do
        expect_any_instance_of(Routemaster::Jobs::Null).to receive(:call) do |obj, *args|
          expect(args).to eq(called_args)
        end
        subject.perform
      end
    end
  end

  context 'without arguments' do
    let(:args) { [] }
    let(:called_args) { [] }
    it_behaves_like 'a job'
  end

  context 'with simple arguments' do
    let(:args) { '123' }
    let(:called_args) { ['123'] }
    it_behaves_like 'a job'
  end

  context 'with complex arguments' do
    let(:args) { ['123', 'foo' => 'bar'] }
    let(:called_args) { args }
    it_behaves_like 'a job'
  end
end

