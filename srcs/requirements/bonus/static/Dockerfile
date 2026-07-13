FROM debian:bookworm

RUN apt-get update && apt-get install -y \
	nginx \
	&& rm -rf /var/lib/apt/lists/*

COPY conf/nginx.conf /etc/nginx/nginx.conf
COPY html/ /var/www/html/static/

EXPOSE 8082

CMD ["nginx", "-g", "daemon off;"]
