FROM ruby:2.5-alpine3.7

LABEL maintainer="terehovk@ya.ru"

RUN mkdir -p /usr/src/app

RUN mkdir -p /usr/src/config

ADD startup.sh /

ENV MAIN_APP_FILE main.rb

RUN apk add --no-cache \
  build-base \
  libxml2-dev \
  libxslt-dev \
  libgit2-dev>=0.27 \
  ruby-dev \
  cmake \
  clang \
  clang-dev \
  make \
  gcc \
  g++ \
  libc-dev \
  linux-headers \
  bash \
  libssh2-dev

#preinstall gems
RUN gem install	mail rugged nokogiri mongo

ENV TZ=Europe/Minsk
RUN apk add tzdata && cp /usr/share/zoneinfo/Europe/Minsk /etc/localtime && echo "Europe/Minsk" >  /etc/timezone && apk del tzdata

WORKDIR /usr/src/app

EXPOSE 80

CMD ["/bin/bash", "/startup.sh"]