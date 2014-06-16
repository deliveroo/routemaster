require 'spec_helper'
require 'spec/support/persistence'
require 'routemaster/client'
require 'pathname'

describe 'integration' do

  class SubProcess
    def initialize(name:, command:)
      @name    = name
      @command = command
      @pid     = nil
      @reader  = nil
      @loglines = []
    end

    def start
      raise 'already started' if @pid
      $stderr.puts "\t-> start for #{@name}"
      @loglines = []
      rd, wr = IO.pipe
      if @pid = fork
        # parent
        wr.close
        @reader = Thread.new { _read_log(rd) }
      else
        $stderr.puts "\t-> forked for #{@name}"
        # child
        rd.close
        ENV['ROUTEMASTER_LOG_FILE'] = nil
        $stdin.reopen('/dev/null')
        $stdout.reopen(wr)
        $stderr.reopen(wr)
        exec @command
      end
      self
    end

    def stop
      return if @pid.nil?
      Process.kill('TERM', @pid)
      Process.wait(@pid)
      @reader.join
      @pid = nil
      self
    end

    def wait_log(regexp)
      Timeout::timeout(25) do
        until @loglines.pop =~ regexp
          sleep 50e-3
        end
      end
    end

    private

    def _read_log(io)
      while line = io.gets
        $stderr.write line # REMOVE ME
        $stderr.flush      #
        @loglines.push line
      end
    end
  end

  WatchProcess = SubProcess.new(
    name:    'watch',
    command: 'ruby -I. watch.rb'
  )

  WebProcess = SubProcess.new(
    name:    'web',
    command: 'unicorn -c config/unicorn.rb'
  )

  ClientProcess = SubProcess.new(
    name:    'client',
    command: 'unicorn -c spec/support/client.rb -p 17892 spec/support/client.ru'
  )

  TunnelProcess = SubProcess.new(
    name:    'ssl-tunnel',
    command: 'tunnels 127.0.0.1:17893 127.0.0.1:17891'
  )

  Processes = [WatchProcess, WebProcess, ClientProcess, TunnelProcess]

  before { Processes.each(&:start) }
  after  { Processes.each(&:stop) }

  context 'watch worker' do
    subject { WatchProcess }
    it 'starts cleanly' do
      subject.wait_log /INFO: starting watch service/
    end

    it 'stops cleanly' do
      subject.wait_log /INFO: starting watch service/
      subject.stop
      subject.wait_log /INFO: watch completed/
    end
  end

  context 'web worker' do
    subject { WebProcess }
    it 'starts cleanly' do
      subject.wait_log /worker=1 ready/
    end

    it 'stops cleanly' do
      subject.wait_log /worker=1 ready/
      subject.stop
      subject.wait_log /master complete/
    end
  end

  context 'client worker' do
    subject { ClientProcess }
    it 'starts cleanly' do
      subject.wait_log /worker=1 ready/
    end

    it 'stops cleanly' do
      subject.wait_log /worker=1 ready/
      subject.stop
      subject.wait_log /master complete/
    end
  end


  context 'ruby client' do
    let(:client) {
      Routemaster::Client.new(url: 'https://127.0.0.1:17893', uuid: 'demo')
    }

    before do
      WebProcess.wait_log /worker=1 ready/
    end

    it 'connects' do
      expect { client }.not_to raise_error
    end
  end
end
