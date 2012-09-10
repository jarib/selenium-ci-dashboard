require 'em-http'
require 'em-mongo'
require 'logger'
require 'uri'
require 'json'
require "./build"

class Poller
  CONNECT_OPTIONS = {
    :connect_timeout    => 3,
    :inactivity_timeout => 10,
  }

  REQUEST_OPTIONS = {
    :redirects => 10
  }

  INTERVAL = 60

  def initialize(log)
    @log = log
    @pending = 0
  end

  def start
    EM.run {
      trap('INT') { EM.stop }
      trap('TERM') { EM.stop }
      trap('HUP') { @log.info "pending: #{@pending}"}

      poll
      EM.add_periodic_timer(INTERVAL) { poll }
    }
  end

  private

  def poll
    fetch_all do |data, error|
      if error
        @log.error error
      else
        data.each do |job|
          EM.schedule { process_job job }
        end
      end
    end
  end

  def process_job(job)
    @log.info "checking queued build #{job}"

    url = job['url']
    api = URI.join(url, "api/json?tree=fullDisplayName,actions[parameters[name,value]],url,result,building,changeSet[items[user,revision,msg],revisions[revision]]").to_s
    fetch api do |data, error|
      if error && error =~ /404/
        remove_from_queue url
      elsif error
        @log.error error
      else
        build = Build.new(data)
        save_build build
        remove_from_queue url unless build.building?
      end
    end
  end

  def remove_from_queue(url)
      @log.info "removing from queue: #{url}"
      coll('queue').remove('url' => url)
  end

  def fetch_all(&blk)
    cursor = coll('queue').find.defer_as_a

    cursor.errback do |klass, msg|
      yield nil, "#{klass} - #{msg}"
    end

    cursor.callback do |docs|
      yield docs, nil
    end
  end

  def save_build(build)
    @log.info "saving build #{build.url.inspect}"
    coll('builds').update({'url' => build.url}, build.as_json, :upsert => true)
  end

  def increment
    @pending += 1
    @log.info "pending: #{@pending}"
  end

  def decrement
    @pending -= 1
    @log.info "pending: #{@pending}"
  end

  def fetch(url, &blk)
    increment
    http = EventMachine::HttpRequest.new(url, CONNECT_OPTIONS).get REQUEST_OPTIONS

    http.errback do
      decrement
      @log.error "#{url}: errback called - #{http.last_effective_url} - #{http.response_header.status}"
      yield(nil, "#{http.last_effective_url} returned #{http.response_header.status}")
    end

    http.callback {
      decrement

      case http.response_header.status
      when 200
        @log.info "#{url}: #{http.response_header.status}"

        begin
          result = JSON.parse(http.response)
        rescue IndexError, JSON::ParserError => ex
          yield nil, "#{ex.message} for #{url}"
          next
        end

        yield result, nil
      when 404
        @log.warn "404 for #{url}, removing from queue"
        yield nil, "404 for #{url}"
      else
        @log.error "#{url}: #{http.response_header.status}"
        yield nil, "#{http.last_effective_url} returned #{http.response_header.status}"
      end
    }
  end

  def mongo
    @mongo ||= EM::Mongo::Connection.new('localhost').db("selenium")
  end

  def coll(name)
    mongo.collection(name)
  end
end

log = Logger.new(STDOUT)
Poller.new(log).start