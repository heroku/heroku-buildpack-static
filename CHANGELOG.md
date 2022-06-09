# Static Buildpack Changelog

## Unreleased

## v9 (2022-06-09)

* [#243](https://github.com/heroku/heroku-buildpack-static/pull/243) Buildpack is officially deprecated

## v8 (2022-05-19)

* [#240](https://github.com/heroku/heroku-buildpack-static/pull/240) Update ngx_mruby from 2.2.3 to 2.2.4.
* [#240](https://github.com/heroku/heroku-buildpack-static/pull/240) Update nginx from 1.19.0 to 1.21.3.
* [#238](https://github.com/heroku/heroku-buildpack-static/pull/238) Drop support for Cedar-14 and Heroku-16.

## v7 (2021-03-09)

* [#202](https://github.com/heroku/heroku-buildpack-static/pull/202) Output a helpful error message when no `static.json` is found

## v6 (2020-12-09)

* [#190](https://github.com/heroku/heroku-buildpack-static/pull/190) Update nginx for Heroku-16 and Heroku-18 to 1.19.0
* [#186](https://github.com/heroku/heroku-buildpack-static/pull/186) Ensure the SSL module is enabled

## v5 (2020-11-11)

* [#182](https://github.com/heroku/heroku-buildpack-static/pull/182) Add support for Heroku-20
* [#181](https://github.com/heroku/heroku-buildpack-static/pull/181) Fix compatibility with ngx_mruby 1.18.4+
* [#178](https://github.com/heroku/heroku-buildpack-static/pull/178) Exclude unnecessary files when publishing the buildpack
* [#177](https://github.com/heroku/heroku-buildpack-static/pull/177) Make curl retry in case of a failed download
* [#177](https://github.com/heroku/heroku-buildpack-static/pull/177) Fix the printing of the installed nginx version
* [#177](https://github.com/heroku/heroku-buildpack-static/pull/177) Switch to the recommended S3 URL format
* [#177](https://github.com/heroku/heroku-buildpack-static/pull/177) Remove unused archive caching
* [#177](https://github.com/heroku/heroku-buildpack-static/pull/177) Fail the build early on unsupported stacks

## v4 (2019-09-18)

* [#136](https://github.com/heroku/heroku-buildpack-static/pull/136) Add support for canonical host
* [#45](https://github.com/heroku/heroku-buildpack-static/pull/45) Add Basic Auth Configuration
* [#78](https://github.com/heroku/heroku-buildpack-static/pull/78) Add json mime type
* [#70](https://github.com/heroku/heroku-buildpack-static/pull/70) Make config copying idempotent
* [#68](https://github.com/heroku/heroku-buildpack-static/pull/68) Disable access logs

## v3 (2017-03-30)

* [#32](https://github.com/heroku/heroku-buildpack-static/pull/32) proxies set ssl server name extension for SNI
* [#37](https://github.com/heroku/heroku-buildpack-static/pull/47) fallback proxies set ssl server name extension for SNI
* [#61](https://github.com/heroku/heroku-buildpack-static/pull/61) proxy redirects work even when the scheme does not match
* [#62](https://github.com/heroku/heroku-buildpack-static/pull/62) clean urls work even on a directory
* [#63](https://github.com/heroku/heroku-buildpack-static/pull/63) proxies respect DNS TTL
* [#65](https://github.com/heroku/heroku-buildpack-static/pull/65) https redirects happen over proxies

## v2 (2016-07-13)

* [#36](https://github.com/heroku/heroku-buildpack-static/pull/36) env interpolation available when doing `redirects`
* [#40](https://github.com/heroku/heroku-buildpack-static/pull/40) mitigate CRLF HTTP Header Injection when using `https_only`

## v1 (2016-03-27)

* Initial Release!
