FROM matsumotory/ngx-mruby:latest

RUN echo $'\nUS\nTexas\nAustin\nHeroku\n\nexample.com\n\n' \
  | openssl req -x509 -nodes -days 365 -newkey rsa:1024 \
  -keyout /etc/ssl/private/myssl.key \
  -out /etc/ssl/certs/myssl.crt

RUN mkdir -p /root/conf/ && \
  touch /root/conf/extend.conf
