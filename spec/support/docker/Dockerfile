FROM heroku/cedar:14

RUN apt-get update && apt-get install -y phantomjs
RUN cd /tmp && \
  curl -L https://github.com/n1k0/casperjs/archive/1.1-beta3.tar.gz -s -o - | tar xzvf - && \
  mv casperjs-1.1-beta3 /opt/casperjs && \
  ln -s /opt/casperjs/bin/casperjs /usr/local/bin

RUN useradd -d /app -m app
USER app

WORKDIR /buildpack
COPY bin/ /buildpack/bin/
COPY scripts/ /buildpack/scripts/
RUN /buildpack/bin/compile /app

ENV HOME /app
ENV PORT 3000
EXPOSE 3000

WORKDIR /app

COPY ./spec/support/docker/init.sh /usr/bin/init.sh
ENTRYPOINT ["/usr/bin/init.sh"]
