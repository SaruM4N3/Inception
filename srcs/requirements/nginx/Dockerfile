FROM debian:bookworm

RUN apt-get update && apt-get install -y \
    nginx \
    openssl \
    && rm -rf /var/lib/apt/lists/*

# launch openssl req to create a cert
# -x509 generate and signe the cert instead of asking CA to sign it 
# -nodes "no DES" doesnt encrypt private key with a password. without this nginx ask for a password at start (impossible in automated container)
RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
	-keyout /etc/ssl/private/zsonie.key \
	-out /etc/ssl/certs/zsonie.crt \
	-subj "/C=FR/ST=Rhone/L=Lyon/O=42/CN=zsonie.42.fr"

COPY conf/nginx.conf /etc/nginx/nginx.conf

EXPOSE 443

CMD ["nginx", "-g", "daemon off;"]