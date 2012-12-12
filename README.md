[![Build Status](https://secure.travis-ci.org/bdon/snacks.png)](http://travis-ci.org/bdon/snacks)

Snacks is a stupidly simple question and answer application. 
It is meant to be deployed on Heroku and used with Google Apps authentication. Perfect as an internal site for your comapny.

Snacks is on [Pivotal Tracker.](https://www.pivotaltracker.com/projects/709989#)

Deployment
---
    heroku apps:create my-qa-site --stack cedar
    heroku addons:add sendgrid:starter
    heroku config:add EMAIL_DELIVERY_ADDRESS=qa-user@example.com
    heroku config:add AUTHORIZED_IP_ADDRESSES='{ :sf => [ IPAddr.new("10.0.0.1/24") ] }'
    git push heroku
    heroku run rake db:migrate:up

Configuration
---
* ALLOW_ANONYMOUS_READERS - true if you can read questions/answers without logging in
* GOOGLE_APPS_DOMAIN - the authentication domain
* XSS_TOKEN - something unguessable
* EMAIL_DELIVERY_FREQUENCY - 'daily', 'weekly', etc
* EMAIL_DELIVERY_ADDRESS - the email address to send email as e.g. qa-mailer@example.com
* AUTHORIZED_IP_ADDRESSES - which ip addresses to allow in
