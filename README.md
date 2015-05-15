# heroku-buildpack-static
This is a discovery project for using a buildpack for handling static sites and single page web apps (I'm lookingat you Sam Phippen).

## Features
* serving static assets
* gzip on by default
* support for proxying backends
* error/access logs support in `heroku logs`

## Deploying
The directory structure expected is that you have a `public_html/` directory containing all your static assets.

1. Set the app to this buildpack: `$ heroku buildpacks:set git://github.com/hone/heroku-buildpack-static.git`.
2. Deploy: `$ git push heroku master`

### Proxy Backends
For single page web applications like Ember, it's common to back the application with another app that's hosted on Heroku. The down side of separating out these two applications is that now you have to deal with CORS. To get around this (but at the cost of some latency) you can have the static buildpack proxy apps to your backend at a mountpoint. For instance, we can have all the api requests live at `/api/` which actually are just requests to our API server.

In order to do this we need to setup a `backends.yml` file to be parsed by the static buildpack. It has the structure of the following:

```yaml
---
- mount: "/api"
  url: https://hone-ember-todo-rails.herokuapp.com/
- mount: "/kpi"
  url: https://kpi.heroku.com/
```
