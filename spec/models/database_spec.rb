require 'spec_helper'
require 'routemaster/models/database'
require 'spec/support/env'
require 'spec/support/persistence'

describe Routemaster::Models::Database do
  subject { described_class.instance }
  
  let(:start_mem) { subject.bytes_used }
  let(:max_mem) { start_mem + 3_000_000 }
  let(:min_free) { 1_000_000 }

  before do
    ENV['ROUTEMASTER_REDIS_MIN_FREE'] = min_free.to_s
    ENV['ROUTEMASTER_REDIS_MAX_MEM'] = max_mem.to_s
  end

  def fill_up_to(size)
    until subject.bytes_used >= size
      _redis.rpush('foobar', SecureRandom.random_bytes(10_000))
    end
  end

  it { expect(subject.max_mem).to eq(max_mem) }
  it { expect(subject.high_mark).to eq(max_mem - min_free) }
  it { expect(subject.low_mark).to eq(max_mem - 2 * min_free) }

  describe '#empty_enough?' do
    it 'is true when the db is empty' do
      expect(subject).to be_empty_enough
    end

    it 'is still true under 2*min_free' do
      fill_up_to(start_mem + 950_000)
      expect(subject).to be_empty_enough
    end

    it 'turns false above 2*min_free' do
      fill_up_to(start_mem + 1_050_000)
      expect(subject).not_to be_empty_enough
    end
  end

  describe '#too_full?' do
    it 'is false when the db is empty' do
      expect(subject).not_to be_too_full
    end

    it 'is still true undes min_free' do
      fill_up_to(start_mem + 1_950_000)
      expect(subject).not_to be_too_full
    end

    it 'turns false above min_free' do
      fill_up_to(start_mem + 2_050_000)
      expect(subject).to be_too_full
    end
  end

  describe '#used_cpu_*' do
    it { expect(subject.used_cpu_sys).to  be_a_kind_of(Integer) }
    it { expect(subject.used_cpu_user).to be_a_kind_of(Integer) }
  end
end
