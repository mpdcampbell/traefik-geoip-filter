FROM nginx:alpine
COPY geo-ipwhitelist.sh /opt/scripts/geo-ipwhitelist.sh
RUN apk add --no-cache bash unzip
CMD ./opt/scripts/geo-ipwhitelist.sh
