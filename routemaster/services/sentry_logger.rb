class Routemaster::Services::ExceptionLoggers::Sentry
  include Singleton

  def process(e, env = ENV['RACK_ENV'])
    if ENV['EXCEPTION_SERVICE_URL']
      evt = Raven::Event.capture_rack_exception(e, env)
      Raven.send(evt) if evt
    end
  end

end
