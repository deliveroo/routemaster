require 'spec_helper'
require 'yaml'

describe '.hopper/config.yml sanity' do
  let(:config_file_hash) do
    config_file_path = File.expand_path('../.hopper/config.yml', __dir__)
    config_file_data = File.read(config_file_path)
    YAML.load(config_file_data)
  end

  it 'is a valid YAML file' do
    expect { config_file_hash }.to_not raise_error
  end

  it 'specifies a version' do
    expect(config_file_hash).to include 'version'
  end

  it "specifies services with 'containerDefinitions'" do
    expect(config_file_hash['services']).to all(include('containerDefinitions' => instance_of(Hash)))
  end

  it "specifies 'cpu', 'memory', and 'command' for each worker entry" do
    config_file_hash['services'].each do |worker_name, worker_details|
      worker_details['containerDefinitions'].each do |worker_type, details|
        expect(details['cpu']).to be_a(Integer),
          "expected 'cpu' entry for '#{worker_name} => containerDefinitions => #{worker_type}' to be an Integer"

        expect(details['memory']).to be_a(Integer),
          "expected 'memory' entry for '#{worker_name} => containerDefinitions => #{worker_type}' to be an Integer"

        expect(details['command'] || details['image']).to be_a(String),
          "expected 'command' or 'image' entry for '#{worker_name} => containerDefinitions => #{worker_type}' to be a String"
      end
    end
  end
end
