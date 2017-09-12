require 'spec_helper'
require 'routemaster/models/user'

describe Routemaster::Models::User do
  shared_examples 'failure' do |title,value|
    context "with #{title} (#{value.inspect})" do
      it { expect { described_class.new(value) }.to raise_error(ArgumentError) }
    end
  end

  shared_examples 'success' do |title,value|
    context "with #{title} (#{value.inspect})" do
      it { expect { described_class.new(value) }.not_to raise_error }
      it { expect(described_class.new(value)).to eq value }
    end
  end

  include_examples 'success', 'a short string', 'foobar'
  include_examples 'success', 'a service name with UUID', 'foobar--59709301-9bb4-49dd-8d42-74b865c47804'

  include_examples 'failure', 'too long a string', (['foo']*20).join('-')
  include_examples 'failure', 'trailing newline', "foobar\n"
  include_examples 'failure', 'non-string', :foobar
  include_examples 'failure', 'spaces', 'foo bar'
  include_examples 'failure', 'invalid characters', 'fôøbar'
end
