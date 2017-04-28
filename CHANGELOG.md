## v3 (3/30/2017)
* [#32](https://github.com/heroku/heroku-buildpack-static/pull/32) proxies set ssl server name extension for SNI
* [#37](https://github.com/heroku/heroku-buildpack-static/pull/47) fallback proxies set ssl server name extension for SNI
* [#61](https://github.com/heroku/heroku-buildpack-static/pull/61) proxy redirects work even when the scheme does not match
* [#62](https://github.com/heroku/heroku-buildpack-static/pull/62) clean urls work even on a directory
* [#63](https://github.com/heroku/heroku-buildpack-static/pull/63) proxies respect DNS TTL
* [#65](https://github.com/heroku/heroku-buildpack-static/pull/65) https redirects happen over proxies

## v2 (7/13/2016)

* [#36](https://github.com/heroku/heroku-buildpack-static/pull/36) env interpolation available when doing `redirects`
* [#40](https://github.com/heroku/heroku-buildpack-static/pull/40) mitigate CRLF HTTP Header Injection when using `https_only`

## v1 (3/27/2016)

* Initial Release!
