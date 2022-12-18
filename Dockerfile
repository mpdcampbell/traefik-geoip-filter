FROM alpine:latest
COPY geo-ipwhitelist.sh /opt/scripts/geo-ipwhitelist.sh
COPY crontab .
RUN apk add --no-cache bash curl unzip && crontab crontab
CMD ./opt/scripts/geo-ipwhitelist.sh 2 && crond -f -l 2
