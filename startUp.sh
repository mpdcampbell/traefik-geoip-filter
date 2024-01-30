#!/bin/bash

echo "${CRON_EXPRESSION}" /opt/scripts/geoip-filter.sh '>>' "${CRON_LOG_PATH}" > crontab
crontab crontab
echo "--------------------------------------"
echo "Running initial Maxmind database check"
./opt/scripts/geoip-filter.sh
if [ $? -ne 0 ]; then
    exit 1
fi
echo "Further Maxmind database checks will be done via cron with expression ${CRON_EXPRESSION}"
echo "The cron logs can be found at ${CRON_LOG_PATH}, further checks will not be shown here in the default Docker logs"
echo "--------------------------------------"
crond
exit 0;
