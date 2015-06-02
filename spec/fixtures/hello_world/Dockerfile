FROM heroku/cedar:14

RUN useradd -d /app -m app
USER app
WORKDIR /app

ENV HOME /app
ENV PORT 3000

RUN mkdir -p /app
COPY . /app/

RUN /app/buildpack/bin/compile /app

EXPOSE 3000
CMD /app/bin/boot
