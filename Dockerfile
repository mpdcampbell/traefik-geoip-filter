FROM alpine:latest
RUN apk add --no-cache bash curl unzip  
COPY startUp.sh .
COPY geo-ipwhitelist.sh /opt/scripts/geo-ipwhitelist.sh
ARG CRON_EXPRESSION
ENV CRON_EXPRESSION=${CRON_EXPRESSION:-"0 6 * * wed,sat"}
CMD ./startUp.sh
