#!/bin/bash

echo  "${CRON_EXPRESSION}" /opt/scripts/geo-ipwhitelist.sh >> crontab
crontab crontab
./opt/scripts/geo-ipwhitelist.sh 2
crond -f -l 2
