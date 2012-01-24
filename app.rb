require 'sinatra/base'
require 'mongo'
require './build'
require 'pp'

class App < Sinatra::Base
  set :db, Mongo::Connection.new.db("selenium").collection("builds")
  set :views, File.expand_path("../views", __FILE__)

  configure do
    db.ensure_index 'revision'
  end

  get "/" do
    redirect "/revs"
  end

  get "/revs" do
    builds = revs.map { |r| db.find(:revision => r).to_a }.flatten

    @users = {}
    @builds = builds.group_by do |e|
      rev = e['revision']
      @users[rev] ||= e['user']

      rev
    end.sort_by { |rev, _| rev }.reverse

    erb :revs
  end

  get "/matrix/:rev" do |rev|
    builds = []

    @revision = rev
    builds = db.find(:revision => @revision).to_a

    views = builds.map { |e| BuildView.new(e) }

    @rows = []
    @columns = []

    views.each do |view|
      rn = view.row_name
      cn = view.column_name
      @rows << rn unless rn == BuildView::NA
      @columns << cn unless cn == BuildView::NA
    end

    @rows    = @rows.sort.uniq
    @columns = @columns.sort.uniq

    # make sure N/A comes first
    @rows.unshift BuildView::NA
    @columns.unshift BuildView::NA

    @builds = views.group_by do |view|
      [view.row_name, view.column_name]
    end

    @broken = what_you_broke(views)

    # @builds.each { |k,v| p k => v.map { |e| e.name }  }

    erb :matrix, :layout => false
  end

  helpers do
    def latest_rev
      revs(1).shift
    end

    def revs(last = 10)
      revs = db.distinct('revision')
      revs.delete(nil)
      revs.delete('unknown')

      revs.map { |e| e.to_s }.sort.last(last)
    end

    def db
      settings.db
    end

    def what_you_broke(builds)
      counts = Hash.new(0)

      failed_builds = builds.select { |e| e.failed? }

      failed_builds.each do |view|
        view.params.each do |key, value|
          next if key == "svnrevision"
          counts[[key.downcase, value.downcase]] += 1
        end
      end

      common = counts.select { |key, count| count == failed_builds.size }.keys
      if common.any?
        str = []
        common.each do |key, value|
          str << "#{key}=#{value}"
        end

        str.join(', ')
      end
    end
  end

  class BuildView
    NA = "N/A"

    def initialize(data)
      @data = data
    end

    def failed?
      [:unstable, :failed].include? state.to_sym
    end

    def state
      @data['state']
    end

    def type
      stringify(params['type'])
    end

    def name
      @data['display_name']
    end

    def url
      @data['url']
    end

    def column_name
      names = [
        stringify(params['os']),
        stringify(params['native_events'])
      ]

      names.all?(&:empty?) ? NA : names.join(":")
    end

    def row_name
      names = [
        stringify(params['browser_name']),
        stringify(params['browser_version'])
      ]

      names.all?(&:empty?) ? NA : names.join(":")
    end

    def params
      @data['params'] || {}
    end

    private

    def stringify(str)
      str.to_s.downcase
    end
  end
end

