require 'spec_helper'
require 'spec/support/persistence'
require 'spec/support/webmock'
require 'core_ext/math'

# turn this on to get verbose tests
VERBOSE = false

module Acceptance
  class SubProcess
    def initialize(name:, command:, start: nil, stop: nil)
      @name    = name
      @command = command
      @pid     = nil
      @reader  = nil
      @loglines = []
      @start_regexp = start
      @stop_regexp  = stop
    end

    def start
      raise 'already started' if @pid
      _log 'starting'
      @loglines = []
      rd, wr = IO.pipe
      if @pid = fork
        # parent
        wr.close
        @reader = Thread.new { _read_log(rd) }
      else
        _log "forked (##{$$})"
        # child
        rd.close
        ENV['ROUTEMASTER_LOG_FILE'] = nil
        $stdin.reopen('/dev/null')
        $stdout.reopen(wr)
        $stderr.reopen(wr)
        $stdout.sync = true
        $stderr.sync = true
        exec @command
      end
      self
    end

    # politely ask the process to stop
    def stop
      return if @pid.nil?
      _log "stopping (##{@pid})"
      Process.kill('TERM', @pid)
      self
    end

    # after calling `start`, wait until the process has logged a line indicating
    # it is ready for use
    def wait_start
      return unless @start_regexp && @pid
      _log 'waiting to start'
      wait_log @start_regexp
      _log "started (##{@pid})"
      self
    end

    # after calling `stop`, wait until the log exhibits an entry indicating
    # the process has stoped cleanly
    def wait_stop
      return unless @stop_regexp && @pid
      _log "waiting to stop (##{@pid})"
      wait_log @stop_regexp
      _log 'stopped'
    ensure
      terminate
    end

    # terminate the process without waiting
    def terminate
      if @pid
        Process.kill('KILL', @pid)
        Process.wait(@pid)
      end
      @reader.join if @reader
      @pid = @reader = nil
      self
    end

    # wait until a log line is seen that matches `regexp`, up to a timeout
    def wait_log(regexp)
      Timeout::timeout(10) do
        loop do
          line = @loglines.shift
          sleep(10.ms) if line.nil?
          break if line && line =~ regexp
        end
      end
      self
    end

    private

    def _read_log(io)
      while line = io.gets
        if VERBOSE
          $stderr.write line
          $stderr.flush
        end
        @loglines.push line
      end
    end

    def _log(message)
      return unless VERBOSE
      $stderr.write("\t-> #{@name}: #{message}\n")
    end
  end

  class ProcessLibrary
    def watch
      @watch ||= SubProcess.new(
        name:    'watch',
        command: './bin/watch',
        start:   /INFO: starting watch service/,
        stop:    /INFO: watch completed/
      )
    end

    def web
      @web ||= SubProcess.new(
        name:    'web',
        command: 'unicorn -I. -c config/unicorn.rb',
        start:   /worker=1 ready/,
        stop:    /master complete/
      )
    end

    def client
      @client ||= SubProcess.new(
        name:    'client',
        command: 'unicorn -I. -c spec/support/client.rb -p 17892 spec/support/client.ru',
        start:   /worker=1 ready/,
        stop:    /master complete/
      )
    end

    def server_tunnel
      @server_tunnel ||= SubProcess.new(
        name:    'server-tunnel',
        command: 'ruby spec/support/tunnel 127.0.0.1:17893 127.0.0.1:17891',
        start:   /Ready/,
        stop:    /tunnel terminated/,
      )
    end

    def client_tunnel 
      @client_tunnel ||= SubProcess.new(
        name:    'client-tunnel',
        command: 'ruby spec/support/tunnel 127.0.0.1:17894 127.0.0.1:17892',
        start:   /Ready/,
        stop:    /tunnel terminated/,
      )
    end

    def all
      [server_tunnel, client_tunnel, watch, web, client]
    end
  end
end

