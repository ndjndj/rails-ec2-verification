FROM --platform=linux/x86_64 nginx:latest 

# health check 
RUN apt-get update && apt-get install -y curl vim sudo lsof 

# remove include dir
RUN rm -f /etc/nginx/conf.d/* 

ADD nginx.conf /etc/nginx/myapp.conf 

CMD /usr/sbin/nginx -g 'daemon off;' -c /etc/nginx/myapp.conf 

EXPOSE 80 