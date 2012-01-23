require 'sinatra/base'
require 'mongo'
require './build'

class App < Sinatra::Base
  set :db, Mongo::Connection.new.db("selenium").collection("builds")
  set :views, File.expand_path("../views", __FILE__)

  configure do
    db.ensure_index 'revision'
  end

  get "/" do
    builds = revs.map { |r| db.find(:revision => r).to_a }.flatten
    @builds = builds.group_by { |e| e['revision'] }.sort_by { |rev, _| rev }.reverse

    erb :builds
  end

  helpers do
    def revs
      revs = db.distinct('revision')
      revs.delete(nil)
      revs.delete('unknown')

      revs.map { |e| e.to_s }.sort.last(10)
    end

    def db
      settings.db
    end
  end
end

