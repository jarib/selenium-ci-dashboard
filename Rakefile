
task :release do
  host = ENV['host'] or raise "please specify host"
  sh "git push origin master"
  sh "ssh", host, "cd /sites/selenium-ci.jaribakken.com/selenium-ci-dashboard && git pull origin master && touch tmp/restart.txt"
end