FROM ruby:2.3.3-alpine

ARG ARG_BUNDLE_PATH=/bundle
ENV BUNDLE_PATH=$ARG_BUNDLE_PATH

# App home directory and app user can be injected through build params.
ARG ARG_PORT=3000
ARG ARG_HOME=/app
ARG ARG_USER=app

RUN gem install bundler \
    && apk add --update build-base \
    && rm -rf /var/cache/apk/* \
    && addgroup -S -g 1000 $ARG_USER \
    && adduser -S -D -u 1000 -h /home/$ARG_USER -G $ARG_USER $ARG_USER \
    && mkdir $BUNDLE_PATH \
    && chown $ARG_USER:$ARG_USER $BUNDLE_PATH

WORKDIR $ARG_HOME
ADD Gemfile* $ARG_HOME/
RUN bundle install --jobs 8 --retry 5

ADD . $ARG_HOME
RUN chown -R $ARG_USER:$ARG_USER $ARG_HOME
USER $ARG_USER

ENV PORT=$ARG_PORT

EXPOSE $PORT
CMD ["bundle", "exec", "puma", "-I.", "-C", "config/puma.rb"]
