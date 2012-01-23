require 'em-http'
require 'em-mongo'
require 'logger'
require 'uri'
require 'json'
require "./build"

class Poller
  CONNECT_OPTIONS = {
    :connect_timeout    => 5,
    :inactivity_timeout => 5,
  }

  REQUEST_OPTIONS = {
    :redirects => 10
  }

  INTERVAL = 60*3

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
    fetch_all_jobs do |jobs, error|
      if error
        @log.error error
      else
        jobs.each_with_index do |job, idx|
          delay = (INTERVAL / jobs.size.to_f)*idx
          @log.info "scheduling fetch of #{idx} in #{delay} seconds"
          EM.add_timer(delay) {
            fetch_builds_for(job) { |build| process_build(build) }
          }
        end
      end
    end
  end

  def process_build(build)
    url = build.fetch('url')
    @log.info "saving build #{url.inspect}"
    mongo.update({'url' => url}, Build.new(build).as_json, :upsert => true)
  end

  def fetch_all_jobs(&blk)
    @log.info "fetching all jobs"
    fetch(api_url_for(@host), 'jobs', &blk)
  end

  def fetch_builds_for(job, &blk)
    url = api_url_for job.fetch('url')
    @log.info "fetching builds for #{url}"
    fetch(url, 'builds') do |builds, error|
      if error
        @log.error error
      else
        if builds.first
          fetch_build_data(builds.first, &blk)
        end
      end
    end
  end

  def fetch_build_data(build, &blk)
    url = api_url_for(build.fetch('url'))

    @log.info "fetching build data for #{url}"
    fetch(url) do |data, e|
      if e
        @log.error e
      else
        yield data
      end
    end
  end

  def api_url_for(url)
    URI.join(url, 'api/json').to_s
  end

  def increment
    @pending += 1
    @log.info "pending: #{@pending}"
  end

  def decrement
    @pending -= 1
    @log.info "pending: #{@pending}"
  end

  def fetch(url, key = nil, &blk)
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
          result = result.fetch(key) if key
        rescue IndexError, JSON::ParserError => ex
          yield nil, "#{ex.message} for #{url}"
          next
        end

        yield(result, nil)
      else
        @log.error "#{url}: #{http.response_header.status}"
        yield(nil, "#{http.last_effective_url} returned #{http.response_header.status}")
      end
    }
  end

  def mongo
    @mongo ||= EM::Mongo::Connection.new('localhost').db("selenium").collection("builds")

  end
end

log = Logger.new(STDOUT)
Poller.new("http://sci.illicitonion.com:8080", log).start