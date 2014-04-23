require 'spec_helper'
require 'routemaster/models/event'

describe Routemaster::Models::Event do
  let(:options) {{ topic: 'widgets', type: 'create', url: 'https://example.com/widgets/123' }}
  subject { described_class.new(**options) }

  describe '#initialize' do
    it 'fails without parameters' do
      options.replace({})
      expect { subject }.to raise_error(ArgumentError)
    end

    it 'succeeds with correct parameters' do
      expect { subject }.not_to raise_error
    end

    it 'fails with incorrect event types' do
      options[:type] = 'whatever'
      expect { subject }.to raise_error(ArgumentError)
    end

    it 'fails with a non-HTTPS URL' do
      options[:url] = 'http://example.com/widgets/123'
      expect { subject }.to raise_error(ArgumentError)
    end

    it 'fails if the URL has a query string' do
      options[:url] = 'https://example.com/widgets/123?wut'
      expect { subject }.to raise_error(ArgumentError)
    end

    it 'adds timestamps' do
      t = subject.timestamp / 1_000
      expect(t).to be_within(10).of(Time.now.utc.to_i)
    end
  end

  describe '#==' do
    it 'is true for the same event' do
      expect(subject).to eq(subject)
    end

    it 'is true for an event with the same data' do
      other = described_class.new(**options)
      expect(other).to eq(subject)
    end

    it 'is false when the topic differs' do
      other_options = options.merge(topic: 'wapitis')
      other = described_class.new(**other_options)
      expect(other).not_to eq(subject)
    end
  end
end
