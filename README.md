# Tyto App

Web application for Tyto, a course-attendance system that combines time-windowed events with geolocation-verified check-ins.

This is the **server-rendered web frontend**. It is a thin presentation layer over the Tyto API (`tyto2026-api`); the API holds the database and enforces all authorization. The app is responsible for sessions, login flow, form validation, and rendering Slim templates.

> **Note:** This is a teaching project, not for live grading. The progression of branches in this repo is designed to introduce one security concept at a time.

## Install

Install this application by cloning the relevant branch and using bundler to install specified gems:

```shell
bundle install
```

You will also need to copy `config/secrets.example.yml` to `config/secrets.yml` and fill in a real `SESSION_SECRET`:

```shell
cp config/secrets.example.yml config/secrets.yml
bundle exec rake generate:session_secret
# paste the printed value into config/secrets.yml under development: SESSION_SECRET
```

## Test

This web app does not contain automated tests yet -- behavior is verified manually against a running API. See the branch plan for the manual flow checklist.

## Execute

The web app expects the Tyto API to be running on `http://localhost:3000`. From `tyto2026-api/`, start the API first:

```shell
bundle exec rake run:dev
```

Then, from this repo, launch the web app on port 9292:

```shell
bundle exec rake run:dev
```

Visit `http://localhost:9292/` in your browser.
