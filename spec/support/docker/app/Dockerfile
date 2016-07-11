FROM heroku/cedar:14

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

COPY ./spec/support/docker/app/init.sh /usr/bin/init.sh
ENTRYPOINT ["/usr/bin/init.sh"]
CMD "/app/bin/boot"
