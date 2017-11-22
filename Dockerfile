FROM deliveroo/decrypt_env:0.5.5 as decrypt_env

FROM ruby:2.3.3-alpine

COPY --from=decrypt_env /decrypt_env /usr/bin/decrypt_env

# App home directory and app user can be injected through build params.
ARG ARG_HOME=/app
ARG ARG_USER=app

RUN gem install bundler \
    && apk add --no-cache build-base git \
    && addgroup -S $ARG_USER \
    && adduser -S -D -h /home/$ARG_USER -G $ARG_USER $ARG_USER

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

ENTRYPOINT ["decrypt_env"]
