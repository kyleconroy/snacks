Snacks is a stupidly simple and hackable question-and-answer site. 
By simple I mean the Gemfile requires about half a dozen gems, no javascript libraries are used
other than Bootstrap + jQuery, the total application code is < 300 LoC, and there are no runtime dependencies other than Postgres. 

It is meant to be deployed on Heroku and used with Google Apps openid authentication, such as within a company.

Configuring Snacks

Wish list
---
view count
activity streams
Java .war deployment

Todo
---
Database indexes

Keeping the design snack-like

Referential integrity is good, please use foreign key constraints.
There are no plans to run Snacks on anything other than Postgres.

Contributing

All pull requests will be looked at but priority will be given to those that are stupidly simple
