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

ONBUILD WORKDIR /app/
ONBUILD COPY . /app/
ONBUILD CMD /app/bin/boot
