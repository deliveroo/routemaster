FROM deliveroo/hopper-runner:1.4.0 as hopper-runner
FROM ruby:2.3.3

COPY --from=hopper-runner /hopper-runner /usr/bin/hopper-runner

# App home directory and app user can be injected through build params.
ARG ARG_HOME=/app
ARG ARG_USER=app

RUN useradd -d /home/$ARG_USER -m --shell /bin/false --user-group $ARG_USER

RUN sed -i '/jessie-updates/d' /etc/apt/sources.list  # Now archived

RUN apt-get update \
    && apt-get install -q -y -V --no-install-recommends \
        build-essential \
        dnsutils \
        git \
        mtr-tiny \
        tcpdump

RUN gem install bundler

WORKDIR $ARG_HOME
ADD vendor $ARG_HOME/vendor
ADD Gemfile* $ARG_HOME/
RUN bundle install --jobs 8 --retry 5 --local --deployment \
    && mv $ARG_HOME/vendor /tmp/vendor

ADD . $ARG_HOME
RUN rm -rf $ARG_HOME/vendor \
    && mv /tmp/vendor $ARG_HOME/ \
    && rm -rf $ARG_HOME/vendor/cache \
    && chown -R $ARG_USER:$ARG_USER $ARG_HOME
USER $ARG_USER

ARG ARG_PORT=3000
ENV PORT=$ARG_PORT
EXPOSE $PORT

ARG ARG_PROCESS=web
ENV PROCESS=$ARG_PROCESS

ENTRYPOINT ["hopper-runner"]
CMD ["bundle", "exec", "foreman start $PROCESS"]
