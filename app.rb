require 'sinatra/base'
require 'mongo'
require './build'
require 'pp'
require 'json'
require 'uri'

class App < Sinatra::Base
  set :db, Mongo::Connection.new.db("selenium")
  set :views, File.expand_path("../views", __FILE__)
  set :styles, [
    "/css/bootstrap.min.css",
    "/css/bootstrap-responsive.min.css",
    "/css/master.css"
  ]

  configure do
    settings.db.collection('builds').ensure_index 'revision'
  end

  get "/" do
    erb :app
  end

  post "/build" do
    url = nil
    begin
      url = URI.parse(request.body.read)
    rescue
      halt 400, 'invalid url'
    end

    db('queue').insert(:timestamp => Time.now, :url => url.to_s)

    'ok'
  end

  get "/revs.json" do
    content_type :json
    { :revisions => fetch_revision_list }.to_json
  end

  get "/builds/:revision.json" do |revision|
    content_type :json

    builds = db("builds").find(:revision => revision).
                map { |e| BuildView.new e }.
                sort_by { |b| b.name }

    matrix = matrix_from(builds)

    {
      :builds         => builds,
      :revision       => revision,
      :row_headers    => matrix.row_headers,
      :column_headers => matrix.column_headers,
      :rows           => matrix.rows,
      :broken         => what_you_broke(builds),
      :message        => message_from(builds)
    }.to_json
  end

  helpers do
    def latest_rev
      revs(1).shift
    end

    def revs(last = 10)
      revs = db("builds").distinct('revision')
      revs.delete(nil)
      revs.delete('unknown')

      revs.map { |e| e.to_s }.sort.last(last)
    end

    def db(collection)
      settings.db.collection(collection)
    end

    def fetch_revision_list
      revisions = revs(50)
      builds = revisions.map { |r| db("builds").find(:revision => r).to_a }.flatten

      users = {}
      building = {}
      build_counts = Hash.new { |hash, rev| hash[rev] = Hash.new(0) }

      builds.each do |b|
        rev = b['revision']
        state = b['state'].to_sym

        building[rev] ||= (b['state'].to_sym == :building)
        users[rev] ||= b['user']

        counts = build_counts[rev]
        counts[state] += 1
      end

      revisions.sort.reverse.map.with_index do |r, idx|
        {
          :revision => r,
          :user     => users[r],
          :building => building[r],
          :counts   => build_counts[r].map { |k,v| {:key => k, :value => v, :class => class_for_build_state(k) }  },
          :class    => idx <= 6 ? '' : 'hidden-phone'
        }
      end
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

    def class_for_build_state(k)
      [:success, :total, :unstable, :failure, :building]

      case k
      when :success
        'success'
      when :unstable
        'warning'
      when :failure
        'important'
      when :building
        'info'
      else
        'inverse'
      end
    end

    def message_from(builds)
      b = builds.find { |e| e.message }
      b && b.message
    end

    def matrix_from(builds)
      MatrixView.new(builds)
    end
  end

  class MatrixView
    def initialize(builds)
      @builds = builds

      @row_headers    = []
      @column_headers = []

      builds.each do |build|
        rn = build.row_name
        cn = build.column_name
        @row_headers << rn unless rn == BuildView::NA
        @column_headers << cn unless cn == BuildView::NA
      end

      @row_headers    = @row_headers.sort.uniq
      @column_headers = @column_headers.sort.uniq

      # make sure N/A comes first
      @row_headers.unshift BuildView::NA
      @column_headers.unshift BuildView::NA

      @grouped = builds.group_by { |b|
        [b.row_name, b.column_name]
      }
    end

    def row_headers
      @row_headers.map { |e| {:name => e }}
    end

    def column_headers
      @column_headers.map { |e| {:name => e }}
    end

    def rows
      @row_headers.map { |name| row_for name }
    end

    private

    def row_for(rname)
      {
        :name => rname,
        :cells => @column_headers.map do |cname|
          {:build => @grouped[[rname, cname]]}
        end
      }
    end

  end

  class BuildView
    NA = "N/A"

    def initialize(data)
      @data = data
    end

    def as_json(opts = {})
      {
       :revision => revision,
       :state    => state,
       :params   => params.map { |k,v| {:key => k, :val => v} },
       :failed   => failed?,
       :building => building?,
       :url      => url,
       :name     => name,
       :type     => type,
       :message  => message
      }
    end

    def to_json(*args)
      as_json.to_json(*args)
    end

    def failed?
      [:unstable, :failed].include? state.to_sym
    end

    def building?
      state.to_sym == :building
    end

    def revision
      @data['revision']
    end

    def message
      msg = @data['message']
      if msg
        msg.size > 120 ? msg[0, 120] << "..." : msg
      end
    end

    def state
      @data['state']
    end

    def type
      stringify(params['test_type'])
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

