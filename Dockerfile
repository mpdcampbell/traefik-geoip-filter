FROM nginx:1.25.3-alpine3.18
RUN apk add --no-cache bash curl unzip tzdata 
COPY geoip-filter.sh ./opt/scripts/geoip-filter.sh 
COPY search.sh /search.sh
COPY startUp.sh /docker-entrypoint.d/50-startUp.sh
ARG CRON_EXPRESSION
ENV CRON_EXPRESSION=${CRON_EXPRESSION:-"0 6 * * wed,sat"}
ARG CRON_LOG_PATH
ENV CRON_LOG_PATH=${CRON_LOG_PATH:-"/var/log/cron.log"}
#Comment to trigger github action
