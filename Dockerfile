FROM ruby:2.3.3-alpine

# App home directory and app user can be injected through build params.
ARG ARG_HOME=/app
ARG ARG_USER=app

RUN gem install bundler \
    && apk add --update build-base \
    && rm -rf /var/cache/apk/* \
    && addgroup -S -g 1000 $ARG_USER \
    && adduser -S -D -u 1000 -h /home/$ARG_USER -G $ARG_USER $ARG_USER

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
RUN bundle check


ARG ARG_PORT=3000
ARG ARG_PROCESS=web

ENV PORT=$ARG_PORT
ENV PROCESS=$ARG_PROCESS

EXPOSE $PORT

CMD ["sh", "-c", "foreman start ${PROCESS}"]
