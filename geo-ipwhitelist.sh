#!/bin/bash

#VARIABLES
################

countryCodes=($COUNTRY_CODES) #ISO alpha-2 codes (e.g FR)
subCodes=($SUB_CODES) #ISO 3166-2 codes (e.g. FR-45)
maxMindLicenceKey=${MAXMIND_KEY}
middlewareFilename=${IPWHITELIST_FILENAME:-"geo-ipwhitelist.yml"}
middlewareName=${IPWHITELIST_NAME:-"middlewares-geo-ipwhitelist"}
traefikProviderDir=${TRAEFIK_PROVIDER_DIR:-"/rules"}
lastModifiedFilename=${LASTMODIFIED_FILENAME:-"LastModified.txt"}
middlewareFilePath="${traefikProviderDir}/${middlewareFilename}"
lastModifiedDir=${LASTMODIFIED_DIR:-"/geoip"}
lastModifiedFilePath="${lastModifiedDir}/${lastModifiedFilename}"
countryDir=${COUNTRY_DIR:-"/geoip/country"}
subDir=${SUB_DIR:-"/geoip/sub"}
countryUrl="https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-Country-CSV&license_key=${maxMindLicenceKey}&suffix=zip"
subUrl="https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-City-CSV&license_key=${maxMindLicenceKey}&suffix=zip"
yearsOldDate="Sun, 07 Jan 1990 01:00:00 GMT"

#FUNCTIONS
############

country_getRemoteLastModified() {
  remoteResponse=$(curl -ISs "${countryUrl}")
  statusCode=$(echo "$remoteResponse" | grep HTTP)
  remoteLastModified=$(echo "$remoteResponse" | grep last-modified: | sed 's/last-modified: //')
  if [[ -z $(echo "$statusCode" | grep 200) ]]; then
    echo "ERROR: The HEAD request on the GeoLite2 Country database failed with status code ${statusCode}"
    exit 1
  fi
} 

sub_getRemoteLastModified() {
  remoteResponse=$(curl -ISs "${subUrl}")
  statusCode=$(echo "$remoteResponse" | grep HTTP)
  remoteLastModified=$(echo "$remoteResponse" | grep last-modified: | sed 's/last-modified: //')
  if [[ -z $(echo "$statusCode" | grep 200) ]]; then
    echo "ERROR: The HEAD request on the GeoLite2 City database failed with status code ${statusCode}"
    exit 1
  fi
} 

country_getLastModified() {
  if [ -f "${lastModifiedDir}/country${lastModifiedFilename}" ]; then
    countryLastModified="$(cat "${lastModifiedDir}/country${lastModifiedFilename}")"
  else
    countryLastModified=${yearsOldDate}
    echo "No country${lastModifiedFilename} record found."
  fi
  country_getRemoteLastModified
} 

sub_getLastModified() {
  if [ -f "${lastModifiedDir}/sub${lastModifiedFilename}" ]; then
    subLastModified="$(cat "${lastModifiedDir}/sub${lastModifiedFilename}")"
  else
    subLastModified=${yearsOldDate}
    echo "No sub${lastModifiedFilename} record found."
  fi
  sub_getRemoteLastModified
} 

country_getZip() {
  if ! [[ ${remoteLastModified} > ${countryLastModified} ]]; then
    echo "Not downloading GeoLite2 Country database as local copy is up to date."
    echo "  Remote GeoLite2 Country database was last updated on ${remoteLastModified}." 
    echo "  Local GeoLite2 Country database version is dated ${countryLastModified}."
    echo "  If you wish to force fresh download delete country${lastModifiedFilename} and run again."
    return 0
  else
    echo "Downloading latest Geolite2 Country database."
    mkdir -p ${countryDir}
    curl -LsS -z "${countryLastModified}" "${countryUrl}" --output "${countryDir}/country.zip"
    if grep -q "Invalid license key" ${countryDir}/country.zip ; then
      echo "ERROR: MaxMind license key is invalid."
      rm ${countryDir}/country.zip
      return 1
    else
      echo "${remoteLastModified}" > "${lastModifiedDir}/country${lastModifiedFilename}"
      country_unzipAndExtractIPs
    fi
  fi
}

sub_getZip() {
  if ! [[ ${remoteLastModified} > ${subLastModified} ]]; then
    echo "Not downloading GeoLite2 City database as local copy is up to date."
    echo "  Remote GeoLite2 City database was last updated on ${remoteLastModified}." 
    echo "  Local GeoLite2 City database version is dated ${subLastModified}."
    echo "  If you wish to force fresh download delete sub${lastModifiedFilename} and run again."
    return 0
  else
    echo "Downloading latest GeoLite2 City database."
    mkdir -p ${subDir}
    curl -LsS -z "${subLastModified}" "${subUrl}" --output "${subDir}/sub.zip"
    if grep -q "Invalid license key" ${subDir}/sub.zip ; then
      echo "ERROR: MaxMind license key is invalid."
      rm sub.zip
      exit 1
    else
      echo "${remoteLastModified}" > "${lastModifiedDir}/sub_${lastModifiedFilename}"
      sub_unzipAndExtractIPs
    fi
  fi
}

country_unzipAndExtractIPs() {
  unzip -jd ${countryDir} ${countryDir}/country.zip "*Blocks*.csv" "*Country-Locations-en.csv"
  cat ${countryDir}/*Blocks*.csv | cut -d, -f 1-2 > ${countryDir}/globalIPList.txt
  cat ${countryDir}/*Locations-en.csv | cut -d, -f 1,5,6 > ${countryDir}/countryList.txt
  rm ${countryDir}/country.zip ${countryDir}/*Blocks*.csv ${countryDir}/*Locations-en.csv
}

sub_unzipAndExtractIPs() {
  unzip -jd ${subDir} ${subDir}/sub.zip "*Blocks*.csv" "*City-Locations-en.csv"
  cat ${subDir}/*Blocks*.csv | cut -d, -f 1-2 > ${subDir}/globalIPList.txt
  cat ${subDir}/*Locations-en.csv | \
  cut -d, -f 1,5,7,8,9,10 | \
  sed -r 's/(.*),(.*),(.*),(.*),(.*)(,.*)/\1,\2-\3,\4\,\2-\5\6/' | \
  sed -r 's/(^.*)(,[A-Z]+-,)(.*)/\1\3/' > ${subDir}/subList.txt
  rm ${subDir}/sub.zip ${subDir}/*Blocks*.csv ${subDir}/*Locations-en.csv
}

country_addIPsToMiddleware() {
  geoNameID=$( grep -hwF "$1" ${countryDir}/countryList.txt | cut -d, -f1 )
  if [ -z "${geoNameID}" ]; then
    echo "  Country "$1" not found in GeoLite2 Country database, skipping it."
    return 0
  else
    echo "  Adding IPs for country "$1" to middleware."
    echo "          #$1 IPs" >> ${middlewareFilePath}
    printf "%s\n" ${geoNameID[@]} > ${countryDir}/geoNameID.txt
    grep -hwFf ${countryDir}/geoNameID.txt ${countryDir}/globalIPList.txt | cut -d, -f1 | sed 's/^/          - /' >> ${middlewareFilePath}
    rm ${countryDir}/geoNameID.txt
  fi
}

sub_addIPsToMiddleware() {
  geoNameID=$( grep -hwF "$1" ${subDir}/subList.txt | cut -d, -f1 )
  if [ -z "${geoNameID}" ]; then
    echo "  Location "$1" not found in GeoLite2 City database, skipping it."
    return 0
  else
    echo "  Adding IPs for Location "$1" to middleware."
    echo "          #$1 IPs" >> ${middlewareFilePath}
    printf "%s\n" ${geoNameID[@]} > ${subDir}/geoNameID.txt
    grep -hwFf ${subDir}/geoNameID.txt ${subDir}/globalIPList.txt | cut -d, -f1 | sed 's/^/          - /' >> ${middlewareFilePath}
    rm ${subDir}/geoNameID.txt
  fi
}

makeEmptyMiddlewareFile() {
  if [ -f "${middlewareFilePath}" ]; then
    mv ${middlewareFilePath} ${middlewareFilePath}.old
  fi
  echo "Writing new ${middlewareName} middleware."
cat << EOF > ${middlewareFilePath}
http:
  middlewares:
    ${middlewareName}:
      ipWhiteList:
        sourceRange:
EOF
}

getLastModifiedArray=(country_getLastModified sub_getLastModified)
getZipArray=(country_getZip sub_getZip)

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

updateGeoIPDatabase () {
  for index in "$@"; do 
    ${getLastModifiedArray[index]}
    ${getZipArray[index]}
  done
}

#MAIN
#################

#Check mandatory variables
if [ -z "$maxMindLicenceKey" ]; then
  echo "ERROR: The MAXMIND_KEY environment variable is empty, exiting script."
  exit 1
elif [ ! -d "$traefikProviderDir" ]; then
  echo "ERROR: The TRAFEIK_PROVIDER_DIR volume doesn't exist, exiting script."
  exit 1
fi

if ! [ -z "$countryCodes" ]; then
  codesArray[0]=0
else
  echo "COUNTRY_CODES environment variable is empty"
  echo "  Skipping Geolite2 Country database check."
fi
if ! [ -z "$subCodes" ]; then
  codesArray[1]=1
else
  echo "SUB_CODES environment variable is empty"
  echo "  Skipping Geolite2 City database check."
fi

if [ ${#codesArray[@]} -gt 0 ]; then
  updateGeoIPDatabase "${codesArray[@]}"
  makeEmptyMiddlewareFile
  country_loop "${countryCodes[@]}"
  sub_loop "${subCodes[@]}"
  echo "Middleware completed."
else
  echo "Both COUNTRY_CODES and SUB_CODES environment variables are empty."
  echo "  No GeoIP locations available to whitelist."
  echo "  Exiting script."
  exit 1
fi
