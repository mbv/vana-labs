FROM ruby:2.5-alpine3.7

LABEL maintainer="terehovk@ya.ru"

RUN mkdir -p /usr/src/app

RUN mkdir -p /usr/src/config

ADD startup.sh /

ENV RACK_ENV production
ENV MAIN_APP_FILE app.rb

RUN apk add --no-cache \
  build-base \
  libxml2-dev \
  libxslt-dev \
  bash

#preinstall gems
RUN gem install	sinatra nokogiri mongo slim

ENV TZ=Europe/Minsk
RUN apk add tzdata && cp /usr/share/zoneinfo/Europe/Minsk /etc/localtime && echo "Europe/Minsk" > /etc/timezone

WORKDIR /usr/src/app

EXPOSE 80

CMD ["/bin/bash", "/startup.sh"]