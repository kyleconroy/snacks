[![Build Status](https://secure.travis-ci.org/bdon/snacks.png)](http://travis-ci.org/bdon/snacks)

Snacks is a stupidly simple question and answer application. 
It is meant to be deployed on Heroku and used with Google Apps authentication. Perfect as an internal site for your comapny.

Snacks is on [Pivotal Tracker.](https://www.pivotaltracker.com/projects/709989#)

Requirements
---
* PostgreSQL
* Ruby (MRI 1.9+)
* Firefox (for running Selenium tests)
* Your favorite snack

Configuration
---
* ALLOW_ANONYMOUS_READERS - true if you can read questions/answers without logging in
* GOOGLE_APPS_DOMAIN - the authentication domain
* XSS_TOKEN - something unguessable
* EMAILER_FREQUENCY - 'daily', 'weekly', etc
* EMAILER_ADDRESS - the email address to send email as e.g. qa-mailer@example.com
* EMAILER_PASSWORD - the password for that email address
