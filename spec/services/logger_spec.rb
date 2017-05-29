require 'spec_helper'
require 'logger'
require 'routemaster/services/logger'
require 'spec/support/env'

module Routemaster
  describe Services::Logger do
    subject { Class.new(described_class).instance }

    describe '.instance' do
      it 'creates correct instance' do
        expect(subject).to be_a_kind_of(described_class)
      end

      it 'behaves like Logger' do
        expect(subject).to respond_to(:warn)
        expect(subject).to respond_to(:info)
      end

      context 'when wrong log level provided' do
        before do
          ENV['ROUTEMASTER_LOG_LEVEL'] = 'FOO'
        end

        it 'warns about it' do
          expect_any_instance_of(::Logger)
            .to receive(:warn)
            .with('log level FOO is invalid, defaulting to INFO')

          subject
        end
      end
    end
  end
end
