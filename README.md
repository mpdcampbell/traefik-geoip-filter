# [<img alt="alt_text" width="50px" src="https://www.codeslikeaduck.com/img/codeDuck.svg" />](https://www.codeslikeaduck.com/)  traefik-geoip-filter <br> [![License](https://img.shields.io/badge/license-BSD%202--Clause-blue)](https://github.com/mpdcampbell/traefik-geoip-filter/blob/main/LICENSE) [![Docker Pulls](https://img.shields.io/docker/pulls/mpdcampbell/traefik-geoip-filter?color=red)](https://hub.docker.com/r/mpdcampbell/traefik-geoip-filter)

A Docker container that works as a GeoIP allow/blocklist middleware for Traefik.</br>
Uses the Maxmind GeoLite2 database and so requires a free [MaxMind account](https://www.maxmind.com/en/geolite2/signup) to work.</br>
Access can be controlled at a country, state, county, city or town level (with decreasing accuracy).</br>
Accepts [ISO 3166-1](https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2#Officially_assigned_code_elements) country codes, [ISO 3166-2](https://en.wikipedia.org/wiki/ISO_3166-2#Current_codes) subdivision codes, and [place names](#formatting-iso-3166-codes-and-place-names).</br>
</br>
_____
### TL;DR: How do I use this?
- Make a free MaxMind account to get an account ID and license key.  
- Download [docker-compose.example.yml](/docker-compose.example.yml) and add the lines to your traefik config as instructed.  
- Replace the dummy ID and key in the example.  
- Replace the location variables: countries go in COUNTRY_CODES, locations smaller than countries go in SUB_CODES.  
- Start up the container with ``docker-compose -f docker-compose.example.yml up -d``
- Check the logs with ``docker logs -tf geoipfilter`` to confirm it's working.
_____
<br>  

## Contents
- [How does it work?](#how-does-it-work)
- [Environment variables](#environment-variables)
- [Formatting ISO 3166 codes and place names](#formatting-iso-3166-codes-and-place-names)
- [Searching the GeoLite2 database](#searching-the-geolite2-database)
- [Default cron schedule](#default-cron-schedule)
- [Acknowledgements](#acknowledgements)
- [License](#license)

## How does it work?
The container acts as an authentication server for the [forwardAuth](https://doc.traefik.io/traefik/middlewares/http/forwardauth/) middleware functionality in Traefik. 
A bash script downloads the GeoLite2 Country and City databases, reformats them and saves a local copy. Then it searches through the database for country/sublocations passed in as environment variables and extracts the matching IPs. These are added to a configuration file in an nginx webserver along with the defined allow or block status. With the forwardAuth middleware added to a service router, the nginx webserver checks IPs of incoming requests and returns the appropriate status code. 

When downloading the databases the last-modified datetime is queried and saved. A cron job then reruns the script at regular intervals (configurable) and each time the last-modified HTTP header for the remote database is queried. The remote database is only downloaded and the middleware updated if the database has been modified since the last download.

## Environment Variables

### Mandatory Variables

| Variable           | What it is                            | Example Value          |
| ------------------ | ------------------------------------- |------------------------|
| MAXMIND_ID         | Your MaxMind account ID              | ``stringOfNumbers``           |
| MAXMIND_KEY        | Your MaxMind license key              | ``stringOfGibberish``           |
| FILTER_TYPE        | Set the filter as an allow or blocklist| ``allow``               |
| COUNTRY_CODES      | List of countries you want to allow/block IPs from. <br> See [formatting](#country_codes) for more details.| ``FR New-Zealand`` |
| SUB_CODES | List of locations smaller than a country that you want to allow/block IPs from. <br> See [formatting](#sub_codes) for more details.|``VN-43 West-Virginia:Dallas`` |

### Optional Variables

| Variable             | What it is                                                                                | Example Value           |
| ---------------------| ----------------------------------------------------------------------------------------- |-------------------------|
| SEARCH_MODE          | Don't set up IP filter, instead list all matches for the country_codes and sub_codes values in the local database. </br> Default value ```false```| ``true``                     |
| ALLOW_STATUS_CODE    | The status code returned when IP address is allowed to access container. </br> Default value ```200```| ``201``                     |
| BLOCK_STATUS_CODE    | The status code returned when IP address is blocked. </br> Default value ```404```                    | ``403``                     |
| COMPARED_IP_VARIABLE | The [variable](https://nginx.org/en/docs/http/ngx_http_core_module.html#variables) that the Nginx webserver compares to the filter list. </br> Default value ``http_x_forwarded_for``| ``http_forwarded`` |
| LISTEN_PORT          | The port the Nginx webserver listens on. </br>Default value ```8080```                                        | ``1234``                    |
| CRON_EXPRESSION      | Overwrites the default cron schedule of ```0 6 * * wed,sat```                             | ```5 1 * * MON-FRI```         |
| TZ                   | Sets the timezone inside the container, used by cron.</br>Default value ``UTC``                  | `EDT`                     |
| CRON_LOG_PATH        | The filepath that the container that the cron log is written to.</br> Default value ``/var/log/cron.log`` | `/path/filename` |
| TRAEFIK_PROVIDER_DIR | The directory inside the container that the middleware file is written to.</br>Default value ``/rules``| `/path/foldername`      |
| LASTMODIFIED_DIR     | The directory inside the container that the GeoLite2 databases and date last updated timestamps are saved to by default. </br>Default value `/geoip`| `/path/foldername` |
| COUNTRY_DIR | The directory inside the container that the country database file is saved to.</br>Default value `LASTMODIFIED_DIR/country`| `/path/foldername`      |
| SUB_DIR | The directory inside the container that the subdivision database file is saved to.</br>Default value `LASTMODIFIED_DIR/sub`| `/path/foldername`      |
| IPLIST_FILENAME | The filename of the configuration file containing the filter list. </br> Default value `IPList.conf` | `filename.conf` |
<br>

## Formatting ISO 3166 codes and place names
### COUNTRY_CODES
- Enter the countries you want to allow as either [ISO-3166-1 Alpha 2 codes](https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2#Officially_assigned_code_elements) or the place name. Using ISO codes is recommended as they are unambiguous. Place names and their spellings can vary regionally and is more likely to lead to match errors.<br>
- Separate elements in the list with a space.<br>
- If a place name contains spaces (i.e. New Zealand) replace the spaces with a dash (i.e. New-Zealand)<br>
- Don't use quotation marks.<br>
- The list is case insensitive.<br>

### SUB_CODES
**Note: There is no guarantee the sublocation you wish to limit access to is listed in the GeoLite2 database. You can check using the [search script](#searching-the-geolite2-database).**<br>
<br>
Accepts [ISO-3166-2 codes](https://en.wikipedia.org/wiki/ISO_3166-2#Current_codes) but the GeoLite database also lists IP address by smaller areas. For example in the United States the ISO-3166-2 codes represent states, when you might want to limit access to a given city or town. For this reason the variable also accepts place names, however they should always be qualified with the larger region. <br></br>Take Berlin as an example: </br>29 locations in the GeoLite2 database have Berlin in their name including towns in Russia, Uruguay, Colombia, and the United States. To narrow this down, the SUB_CODES variable accepts place names in the form ```Larger-Region:Location```.<br>
<br>
For example:<br>
```United-States:Berlin``` - This will match all the listed towns in the United States named Berlin.<br>
```Wisconsin:Berlin``` - This will match the listed towns in Wisconsin named Berlin.<br>
```Wisconsin:New-Berlin``` - This will match the town New Berlin in Wisconsin, which wasn't in the previous example.<br> 
Please note that obviously all towns and regions in the world are not in the database. Also regional spelling can vary. In general using place names is much more hit-or-miss than using ISO codes. You can check what locations a place name will match by using the [search functionality](#searching-the-geolite2-database) <br>
<br>
Also, the same format rules as for COUNTRY_CODES apply:
- Seperate elements in the list with a space.<br>
- If a place name contains spaces (i.e. New Berlin) replace the spaces with a dash (i.e. New-Berlin)<br>
- Don't use quotation marks.<br>
- The list is case insensitive.<br>

## Searching the GeoLite2 database
As shown above with "Berlin" matching locations across the world, a place name might have more matches than you expected. There are two ways you can check what locations the COUNTRY_CODES and SUB_CODES values will match:
### SEARCH_MODE
Set the value of the environment variable SEARCH_MODE to "true". Now when the container starts up, instead of creating the GeoIP filter, it will list all location matches in the docker logs and then stop. You can view the logs of the stopped container using the below command:
```
docker logs geoipfilter
```

### Run search.sh directly
The script used by SEARCH_MODE is inside the container at its root path, /search.sh. If the container is up and running, you can exec in and manually call the script. Use this command to open a terminal inside the geoipfilter container:
```
docker exec -it geoipfilter /bin/bash
```
The script takes three flags, -n, -c and -s, explained below.
```
Usage: search.sh [-c -s -n]
  -c  A space separated array of country_code terms to search for in GeoLite2 database.
      e.g. -c "US New-Zealand France"
  -s  A space separated array of sub_code terms to search for in GeoLite2 database.
      e.g. -n "VN-43 West-Virginia:Dallas Berlin"
  -n  Script will only display the number of matches for each value, default behaviour lists every matching location.
  -h  Show usage.
```
So for example run the script with:
```
./search.sh -c "france US" -s "VN-43 Germany:Berlin"
```

## Default cron schedule
By default the container adds a cron job to run the script at 6 AM UTC on Wednesdays and Saturdays. This is because the MaxMind Geolite 2 country and city databases update every [Tuesday and Friday.](https://support.maxmind.com/hc/en-us/articles/4408216129947) If you want to change the schedule you can define your own [cron expression](https://crontab.cronhub.io/) in the CRON_EXPRESSION environment variable, which will overwrite the default schedule. The cron job will run with the default timezone, UTC, but you can change this with the TZ environment variable.<br>
<br>
The free MaxMind account has a daily limit of 2,000 database downloads but the script first runs a HEAD request, to check if the last-modified header has changed, which doesn't count towards this limit. The script should only download the database if the last-modified is more recent than the last-modified time for the local database copies.

## Acknowledgements
The idea to use Nginx as an authentication server came from [this blog post](https://scaleup.us/2020/06/21/how-to-block-ips-in-your-traefik-proxy-server/), by Okzz.
<br>This repository is effectively that idea plus a bash script, to parse and update the Maxmind database, wrapped up in a Docker image.

## License

[BSD 2-Clause License](/LICENSE)
