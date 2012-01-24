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

  def initialize(host, log)
    @host = host
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

  def fetch_all(&blk)
    url = URI.join(@host, 'api/json?tree=jobs[lastBuild[fullDisplayName,actions[parameters[name,value]],url,result,building,changeSet[items[user,revision],revisions[revision]]]]').to_s

    fetch url do |data, error|
      if error
        yield nil, error
      else
        yield data.fetch('jobs'), nil
      end
    end
  end

  def process_job(job)
    last_build = job.fetch('lastBuild') or return
    url = last_build.fetch('url')

    @log.info "saving build #{url.inspect}"
    mongo.update({'url' => url}, Build.new(last_build).as_json, :upsert => true)
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

      if http.response_header.status == 200
        @log.info "#{url}: #{http.response_header.status}"

        begin
          result = JSON.parse(http.response)
        rescue IndexError, JSON::ParserError => ex
          yield nil, "#{ex.message} for #{url}"
          next
        end

        yield result, nil
      else
        @log.error "#{url}: #{http.response_header.status}"
        yield nil, "#{http.last_effective_url} returned #{http.response_header.status}"
      end
    }
  end

  def mongo
    @mongo ||= EM::Mongo::Connection.new('localhost').db("selenium").collection("builds")
  end
end

log = Logger.new(STDOUT)
Poller.new("http://sci.illicitonion.com:8080", log).start