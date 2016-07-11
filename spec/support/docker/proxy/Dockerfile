FROM ruby:2.3.1-alpine

RUN mkdir -p /app
WORKDIR /app

ADD Gemfile* /app/
RUN bundle install --path /app/vendor/bundle
ADD config.ru /app/config/

EXPOSE 80
CMD bundle exec rackup /app/config/config.ru --host 0.0.0.0 -p 80
