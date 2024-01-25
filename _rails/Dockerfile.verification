FROM --platform=linux/x86_64 ruby:3.3.0 

ENV LANG C.UTF-8 
ENV TZ Asia/Tokyo 
ENV RAILS_ENV=development 

RUN mkdir /usr/src/app 
WORKDIR /usr/src/app 
COPY Gemfile /usr/src/app/Gemfile 
COPY Gemfile.lock /usr/src/app/Gemfile.lock 

RUN gem update --system 
RUN bundle update --bundler 

RUN bundle install 

COPY . /usr/src/app 
RUN mkdir -p tmp/sockets 
RUN mkdir -p tmp/pids 

VOLUME /usr/src/app/public 
VOLUME /usr/src/app/tmp 

COPY entrypoint.verification.sh /usr/bin/ 
RUN chmod +x /usr/bin/entrypoint.verification.sh 
ENTRYPOINT ["entrypoint.verification.sh"]