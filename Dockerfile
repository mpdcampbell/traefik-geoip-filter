FROM nginx:1.23.3-alpine
RUN apk add --no-cache bash curl unzip tzdata 
COPY geoip-filter.sh /docker-entrypoint.d/50-geoip-filter.sh
ARG CRON_EXPRESSION
ENV CRON_EXPRESSION=${CRON_EXPRESSION:-"0 6 * * wed,sat"}
#CMD ./startUp.sh