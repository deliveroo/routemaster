require 'spec_helper'
require 'routemaster/models/event'

describe Routemaster::Models::Event do
  let(:options) {{ type: 'create', url: 'https://example.com/widgets/123' }}
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

    it 'adds timestamps'  # should be an Event spec
  end
end
