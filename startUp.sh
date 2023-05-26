#!/bin/bash

echo  "${CRON_EXPRESSION}" /opt/scripts/geoip-filter.sh >> crontab
crontab crontab
./opt/scripts/geoip-filter.sh 2
crond -f -l 2

exit 0;