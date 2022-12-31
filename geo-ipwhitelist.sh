#!/bin/bash

#DEFINE VARIABLES
################

countryCodes=($COUNTRY_CODES) #ISO alpha-2 codes
subCodes=($SUB_CODES) #ISO ISO 3166-2 codes (e.g. FR-45)
maxMindLicenceKey=${MAXMIND_KEY}
middlewareFilename=${IPWHITELIST_FILENAME:-"geo-ipwhitelist.yml"}
middlewareName=${IPWHITELIST_NAME:-"middlewares-geo-ipwhitelist"}
traefikProviderDir="/rules"
lastModifiedFilename=${LASTMODIFIED_FILENAME:-"last-modified.txt"}
middlewareFilePath="${traefikProviderDir}/${middlewareFilename}"
lastModifiedDir=${LASTMODIFIED_DIR:-$(dirname $0)}
lastModifiedFilePath="${lastModifiedDir}/${lastModifiedFilename}"

countryUrl="https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-Country-CSV&license_key=${maxMindLicenceKey}&suffix=zip"
subUrl="https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-City-CSV&license_key=${maxMindLicenceKey}&suffix=zip"
urls=(${countryURL} ${subURL})
yearsOldDate="Sun, 07 Jan 1990 01:00:00 GMT"

country_checkUrlLastModified() {
  urlResponse=$(curl -I "${countryUrl}")
  statusCode=$(echo "$urlResponse" | grep HTTP)
  urlLastModified=$(echo "$urlResponse" | grep last-modified: | sed 's/last-modified: //')
  if [[ -z $(echo "$statusCode" | grep 200) ]]; then
    echo "Error: The HEAD request on the GeoLite2 Country database failed with status code ${statusCode}"
    return 0
  elif ! [[ ${urlLastModified} > ${country_lastModified} ]]; then
    echo "GeoLite2 Country database hasn't been updated since middleware was last updated on ${country_lastModified}"
    echo "Not updating Country IPs"
    echo "If you wish to change the ipWhiteList countries, delete ${lastModifiedFilename} and run again."
    return 0
  fi
} 

sub_checkUrlLastModified() {
  urlResponse=$(curl -I "${subUrl}")
  statusCode=$(echo "$urlResponse" | grep HTTP)
  urlLastModified=$(echo "$urlResponse" | grep last-modified: | sed 's/last-modified: //')
  if [[ -z $(echo "$statusCode" | grep 200) ]]; then
    echo "Error: The HEAD request on the GeoLite2 City database failed with status code ${statusCode}"
    return 0
  elif ! [[ ${urlLastModified} > ${country_lastModified} ]]; then
    echo "GeoLite2 City database hasn't been updated since middleware was last updated on ${sub_lastModified}"
    echo "Not updating Subcode IPs"
    echo "If you wish to change the ipWhiteList subCodes, delete ${lastModifiedFilename} and run again."
    return 0
  fi
} 

country_getLastModified() {
  if [ -f "${lastModifiedDir}/country_${lastModifiedFilename}" ]; then
    country_lastModified="$(cat "${lastModifiedDir}/country_${lastModifiedFilename}")"
    country_checkUrlLastModified
  else
    country_lastModified=${yearsOldDate} #maybe not needed?
    echo "No country_${lastModifiedFilename} found"
  fi
} 

sub_getLastModified() {
  if [ -f "${lastModifiedDir}/country_${lastModifiedFilename}" ]; then
    sub_lastModified="$(cat "${lastModifiedDir}/country_${lastModifiedFilename}")"
    sub_checkUrlLastModified
  else
    sub_lastModified=${yearsOldDate} #maybe not needed?
    echo "No sub_${lastModifiedFilename} found"
  fi
} 

country_getZip() {
  echo "Downloading latest Geolite2 Country database."
  curl -LsS -z "${country_lastModified}" "${countryUrl}" --output "country.zip"
  if grep -q "Invalid license key" country.zip ; then #might remove shouldn't be possible
    echo "Error: MaxMind license key is invalid"
    rm country.zip
    return 0
  fi
}

sub_getZip() {
  echo "Downloading latest GeoLite2 City database."
  curl -LsS -z "${sub_lastModified}" "${subUrl}" --output "sub.zip"
  if grep -q "Invalid license key" sub.zip ; then #might remove shouldn't be possible
    echo "Error: MaxMind license key is invalid"
    rm sub.zip
    return 0
  fi
}

country_reformatGlobalList() {
  unzip -jd /country country.zip "*Blocks*.csv" "*Country-Locations-en.csv"
  cat /country/*Blocks*.csv | cut -d, -f 1-2 > /country/globalIPList.txt
  cat /country/*Country-Locations-en.csv | cut -d, -f 1,5,6 > /country/countryList.txt
  rm country.zip /country/*Blocks*.csv
}

sub_reformatGlobalList() {
  unzip -jd /sub sub.zip "*Blocks*.csv" "*City-Locations-en.csv"
  cat /sub/*Blocks*.csv | cut -d, -f 1-2 > /sub/globalIPList.txt
  cat /sub/*City-Locations-en.csv | \
  cut -d, -f 1,5,7,8,9,10 | \
  sed -r 's/(.*),(.*),(.*),(.*),(.*)(,.*)/\1,\2-\3,\4\,\2-\5\6/' | \
  sed -r 's/(^.*)(,[A-Z]+-,)(.*)/\1\3/' > /sub/subList.txt
  rm sub.zip /sub/*Blocks*.csv
}

country_addIPsToMiddleware() {
  geoNameID=$( grep -hwF "$1" /country/countryList.txt | cut -d, -f1 )
  if [ -z "${geoNameID}" ]; then
    echo "Country "$1" not found in GeoLite2 database, skipping it."
    return 0
  else
    echo "Adding IPs for country "$1" to middleware."
    echo "          #$1 IPs" >> ${middlewareFilePath}
    printf "%s\n" ${geoNameID[@]} > /country/geoNameID.txt
    grep -hwFf /country/geoNameID.txt /country/globalIPList.txt | cut -d, -f1 | sed 's/^/          - /' >> ${middlewareFilePath}
    rm /country/geoNameID.txt
  fi
}

sub_addIPsToMiddleware() {
  geoNameID=$( grep -hwF "$1" /sub/subList.txt | cut -d, -f1 )
  if [ -z "${geoNameID}" ]; then
    echo "Sublocation "$1" not found in GeoLite2 database, skipping it."
    return 0
  else
    echo "Adding IPs for sublocation "$1" to middleware."
    echo "          #$1 IPs" >> ${middlewareFilePath}
    printf "%s\n" ${geoNameID[@]} > /sub/geoNameID.txt
    grep -hwFf /sub/geoNameID.txt /sub/globalIPList.txt | cut -d, -f1 | sed 's/^/          - /' >> ${middlewareFilePath}
    rm /sub/geoNameID.txt
  fi
}

makeEmptyMiddlewareFile() {
  if [ -f "${middlewareFilePath}" ]; then
    mv ${middlewareFilePath} ${middlewareFilePath}.old
  fi
cat << EOF > ${middlewareFilePath}
http:
  middlewares:
    ${middlewareName}:
      ipWhiteList:
        sourcerange:
EOF
}

getLastModifiedArray=(country_getLastModified sub_getLastModified)
getZipArray=(country_getZip sub_getZip)
reformatGlobalListArray=(country_reformatGlobalList sub_reformatGlobalList)

country_loop () {
  for code in "$@"; do
    country_addIPsToMiddleware $code
  done
}

sub_loop () {
  for code in "$@"; do
    sub_addIPsToMiddleware $code
  done
}

mainFunctions () {
  index=$1
  
  ${getLastModifiedArray[index]}
  ${getZipArray[index]}
  ${reformatGlobalListArray[index]}
}

#SCRIPT
#################

#Check mandatory variables
if [ -z "$maxMindLicenceKey" ]; then
  echo "Error: The MAXMIND_KEY environment variable is empty, exiting script."
  exit 1
elif [ ! -d "$traefikProviderDir" ]; then
  echo "Error: The TRAFEIK_PROVIDER_DIR volume doesn't exist, exiting script."
  exit 1
fi

#country_getLastModified
#country_getZip
#country_reformatGlobalList
#sub_getLastModified
#sub_getZip
#sub_reformatGlobalList

# 0=country, 1=sub
mainFunctions 0
mainFunctions 1

makeEmptyMiddlewareFile

country_loop "${countryCodes[@]}"
sub_loop "${subCodes[@]}"

echo "middleware completed"
