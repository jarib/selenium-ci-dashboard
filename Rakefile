
desc 'Release the app'
task :release do
  host = ENV['host'] or raise "please specify host"
  sh "git push origin master"
  sh "ssh", host, "cd /sites/selenium-ci.jaribakken.com/selenium-ci-dashboard && git pull origin master && touch tmp/restart.txt"
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
