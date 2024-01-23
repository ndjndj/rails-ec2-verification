#!/bin/bash 
set -e 

echo "Start entrypoint.verification.sh" 

echo "rm -f /usr/src/app/tmp/pids/server.pid"
rm -f /usr/src/app/tmp/pids/server.pid 

echo "bundle exec rails db:create RAILS_ENV=development"
bundle exec rails db:create RAILS_ENV=development 

echo "bundle exec rails db:migrate RAILS_ENV=development"
bundle exec rails db:migrate RAILS_ENV=development 

#echo "bundle exec rails db:seed RAILS_ENV=development"
#bundle exec rails db:seed RAILS_ENV=development 

echo "exec pumactl start"
bundle exec pumactl start 