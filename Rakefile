
desc 'Release the app'
task :release do
  host = ENV['host'] or raise "please specify host"
  sh "git push origin master"
  sh "ssh", host, "cd /apps/selenium-ci-dashboard && git pull origin master && bundle install --path .bundle --binstubs && touch tmp/restart.txt"
end

namespace :db do
  desc 'Load production db'
  task :load do
    host = ENV['host'] or raise "please specify host"
    %w[builds queue].each do |collection|
      sh %[ssh #{host} "mongoexport -d selenium -c #{collection}" | mongoimport -d selenium -c #{collection} --drop]
    end
  end
end
