# heroku-buildpack-static
**NOTE**: This buildpack is in an experimental OSS project.

This is a buildpack for handling static sites and single page web apps.

For a guide, read the [Getting Started with Single Page Apps on Heroku](https://gist.github.com/hone/24b06869b4c1eca701f9).

## Features
* serving static assets
* gzip on by default
* error/access logs support in `heroku logs`
* custom [configuration](#configuration)

## Deploying
The `static.json` file is required to use this buildpack. This file handles all the configuration described below.

1. Set the app to this buildpack: `$ heroku buildpacks:set https://github.com/heroku/heroku-buildpack-static.git`.
2. Deploy: `$ git push heroku master`

### Configuration
You can configure different options for your static application by writing a `static.json` in the root folder of your application.

#### Root
This allows you to specify a different asset root for the directory of your application. For instance, if you're using ember-cli, it naturally builds a `dist/` directory, so you might want to use that intsead.

```json
{
  "root": "dist/"
}

```

By default this is set to `public_html/`

#### Default Character Set
This allows you to specify a character set for your text assets (HTML, Javascript, CSS, and so on). For most apps, this should be the default value of "UTF-8", but you can override it by setting `encoding`:

```json
{
    "encoding": "US-ASCII"
}
```

#### Clean URLs
For SEO purposes, you can drop the `.html` extension from URLs for say a blog site. This means users could go to `/foo` instead of `/foo.html`.


```json
{
  "clean_urls": true
}
```

By default this is set to `false`.


#### Logging
You can disable the access log and change the severity level for the error log.

```json
{
  "logging": {
    "access": false,
    "error": "warn"
  }
}
```

By default `access` is set to `true` and `error` is set to `error`.

The environment variable `STATIC_DEBUG` can be set, to override the `error` log level to `error`.


#### Custom Routes
You can define custom routes that combine to a single file. This allows you to preserve routing for a single page web application. The following operators are supported:

* `*` supports a single path segment in the URL. In the configuration below, `/baz.html` would match but `/bar/baz.html` would not.
* `**` supports any length in the URL.  In the configuration below, both `/route/foo` would work and `/route/foo/bar/baz`.

```json
{
  "routes": {
    "/*.html": "index.html",
    "/route/**": "bar/baz.html"
  }
}
```

##### Browser history and asset files
When serving a single page app, it's useful to support wildcard URLs that serves the index.html file, while also continuing to serve JS and CSS files correctly. Route ordering allows you to do both:

```json
{
  "routes": {
    "/assets/*": "/assets/",
    "/**": "index.html"
  }
}
```

#### Custom Redirects
With custom redirects, you can move pages to new routes but still preserve the old routes for SEO purposes. By default, we return a `301` status code, but you can specify the status code you want.

```json
{
  "redirects": {
    "/old/gone/": {
      "url": "/",
      "status": 302
    }
  }
}
```

##### Interpolating Env Var Values
It's common to want to be able to test the frontend against various backends. The `url` key supports environment variable substitution using `${ENV_VAR_NAME}`. For instance, if there was a staging and production Heroku app for your API, you could setup the config above like the following:

```json
{
  "redirects": {
    "/old/gone/": {
      "url": "${NEW_SITE_DOMAIN}/new/here/"
    }
  }
}
```

Then using the [config vars](https://devcenter.heroku.com/articles/config-vars), you can point the frontend app to the appropriate backend. To match the original proxy setup:

```bash
$ heroku config:set NEW_SITE_DOMAIN="https://example.herokapp.com"
```

#### Custom Error Pages
You can replace the default nginx 404 and 500 error pages by defining the path to one in your config.

```json
{
  "error_page": "errors/error.html"
}
```

#### HTTPS Only

You can redirect all HTTP requests to HTTPS.

```
{
  "https_only": true
}
```

#### Basic Authentication

You can enable Basic Authentication so all requests require authentication.

```
{
  "basic_auth": true
}
```

This will generate `.htpasswd` using environment variables `BASIC_AUTH_USERNAME` and `BASIC_AUTH_PASSWORD` if they are present. Otherwise it will use a standard `.htpasswd` file present in the `app` directory.

Passwords set via `BASIC_AUTH_PASSWORD` can be generated using OpenSSL or Apache Utils. For instance: `openssl passwd -apr1`.

#### Proxy Backends
For single page web applications like Ember, it's common to back the application with another app that's hosted on Heroku. The down side of separating out these two applications is that now you have to deal with CORS. To get around this (but at the cost of some latency) you can have the static buildpack proxy apps to your backend at a mountpoint. For instance, we can have all the api requests live at `/api/` which actually are just requests to our API server.

```json
{
  "proxies": {
    "/api/": {
      "origin": "https://hone-ember-todo-rails.herokuapp.com/"
    }
  }
}
```

##### Interpolating Env Var Values
It's common to want to be able to test the frontend against various backends. The `origin` key supports environment variable substitution using `${ENV_VAR_NAME}`. For instance, if there was a staging and production Heroku app for your API, you could setup the config above like the following:

```json
{
  "proxies": {
    "/api/": {
      "origin": "https://${API_APP_NAME}.herokuapp.com/"
    }
  }
}
```

Then using the [config vars](https://devcenter.heroku.com/articles/config-vars), you can point the frontend app to the appropriate backend. To match the original proxy setup:

```bash
$ heroku config:set API_APP_NAME="hone-ember-todo-rails"
```

#### Custom Headers
Using the headers key, you can set custom response headers. It uses the same operators for pathing as [Custom Routes](#custom-routes).

```json
{
  "headers": {
    "/": {
      "Cache-Control": "no-store, no-cache"
    },
    "/assets/**": {
      "Cache-Control": "public, max-age=512000"
    },
    "/assets/webfonts/*": {
      "Access-Control-Allow-Origin": "*"
    }
  }
}
```

For example, to enable CORS for all resources, you just need to enable it for all routes like this:

```json
{
  "headers": {
    "/**": {
      "Access-Control-Allow-Origin": "*"
    }
  }
}
```

##### Precedence
When there are header conflicts, the last header definition always wins. The headers do not get appended. For example,

```json
{
  "headers": {
    "/**": {
      "X-Foo": "bar",
      "X-Bar": "baz"
    },
    "/foo": {
      "X-Foo": "foo"
    }
  }
}
```

when accessing `/foo`, `X-Foo` will have the value `"foo"` and `X-Bar` will not be present.

### Route Ordering

* HTTPS redirect
* Root Files
* Clean URLs
* Proxies
* Redirects
* Custom Routes
* 404

### Procfile / multiple buildpacks

In case you have multiple buildpacks for the application you can ensure static rendering in `Procfile` with `web: bin/boot`.

## Testing
For testing we use Docker to replicate Heroku locally. You'll need to have [it setup locally](https://docs.docker.com/installation/). We're also using rspec for testing with Ruby. You'll need to have those setup and install those deps:

```sh
$ bundle install
```

To run the test suite just execute:

```sh
$ bundle exec rspec
```

### Structure
To add a new test, add another example inside `spec/simple_spec.rb` or create a new file based off of `spec/simple_spec.rb`. All the example apps live in `spec/fixtures`.

When writing a test, `BuildpackBuilder` creates the docker container we need that represents the heroku cedar-14 stack. `AppRunner.new` takes the name of a fixture and mounts it in the container built by `BuildpackBuilder` to run tests against. The `AppRunner` instance provides convenience methods like `get` that just wrap `net/http` for analyzing the response.

### Boot2docker

If you are running docker with boot2docker, the buildpack will automatically send tests to the right ip address.
You need to forward the docker's port 3000 to the virtual machine's port though.

```
VBoxManage modifyvm "boot2docker-vm" --natpf1 "tcp-port3000,tcp,,3000,,3000";
```
