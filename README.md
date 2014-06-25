# Setup

Four things need to be set up for the dashboard to work:

1. Each Jenkins build must report its build URL to the dashboard, e.g.

    $ curl -XPOST -d http://jenkins.example.com/job/Build%20All%20Java/5194/ http://dashboard.example.com/build

2. The dashboard uses MongoDB for storage. The app expects it to run on the default post, at localhost:27017.

3. The actual dashboard is a [Sinatra](http://www.sinatrarb.com/) web app, and can be run like any Rack application (e.g. using Passenger, Unicorn). To run it standalone, do:

    $ bundle install
    $ bundle exec rackup config.ru

4. The separate poller process needs to run in order to collect data from Jenkins and save it in the db:

    $ bundle exec ruby poller.rb
