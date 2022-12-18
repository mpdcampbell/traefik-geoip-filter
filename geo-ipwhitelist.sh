#!/bin/bash

#This script downloads country-wide IP lists and formats into a forwardauth middleware to make a local geolocation ipWhiteList for Traefik
#The country IP data is obtained from the GeoLite2 csv database created by maxmind
#Accessing the GeoLite 2 database is free but requires an account and licence key, see maxmind.com 

#DEFINE VARIABLES
################

countryCodes=($COUNTRY_CODES) #ISO alpha-2 codes
maxMindLicenceKey=${MAXMIND_KEY}
middlewareFilename=${IPWHITELIST_FILENAME:-"geo-ipwhitelist.yml"}
middlewareName=${IPWHITELIST_NAME:-"middlewares-geo-ipwhitelist"}
traefikProviderDir="/rules"
lastModifiedFilename="last-modified.txt"
middlewareFilePath="${traefikProviderDir}/${middlewareFilename}"

isLastModifiedLocal=${IS_LASTMODIFIED_LOCAL:-false}
if [ ${isLastModifiedLocal} = true ]; then
  lastModifiedDir=${LASTMODIFIED_DIR:-$traefikProviderDir}
else
  lastModifiedDir=$(dirname $0)
fi
lastModifiedFilePath="${lastModifiedDir}/${lastModifiedFilename}"

#SCRIPT
#################

#Check mandatory variables
if [ -z "$countryCodes" ]; then
  echo "Error: The countryCodes variable is empty, exiting script."
  exit 1
elif [ -z "$maxMindLicenceKey" ]; then
  echo "Error: The maxMindLicenceKey variable is empty, exiting script."
  exit 1
elif [ -z "$traefikProviderDir" ]; then
  echo "Error: The traefikProviderDir variable is empty, exiting script."
  exit 1
fi

#Load in datetime geoIP list last modified
if [ -f ${lastModifiedFilePath} ]; then
  lastModified=$(cat ${lastModifiedFilePath} )
else
  lastModified=0
fi

#Download if hosted file has updated since last download
curl -LsS -z "${lastModified}" "https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-Country-CSV&license_key=${maxMindLicenceKey}&suffix=zip" --output "countryIPList.zip"

if [ -f "countryIPList.zip" ]; then
  #Check if licence key was valid
  if grep -q "Invalid license key" countryIPList.zip ; then
    echo "Error: The license key is invalid"
    rm countryIPList.zip
    exit 1
  fi

  #Overwrite new datetime for last modified
  date -r "countryIPList.zip" > ${lastModifiedFilePath}

  #Backup existing middleware yml
  if [ -f "${middlewareFilePath}" ]; then
    mv ${middlewareFilePath} ${middlewareFilePath}.old
  fi

#Make new middleware yml
cat << EOF > ${middlewareFilePath}
http:
  middlewares:
    ${middlewareName}:
      ipWhiteList:
        sourcerange:
EOF

  #Extract ipv4 and ipv6 lists, reformat to just ip and geonameID, and append in new file
  unzip -jd countryIPList countryIPList.zip "*Blocks*.csv" "*Country-Locations-en.csv"
  cat countryIPList/*Blocks*.csv | cut -d, -f 1-2 > countryIPList/globalIPList.txt

  #Add comment to middleware file with which countries included in whitelist 
  echo "         # ipWhiteList countries: ${countryCodes[@]}" >> ${middlewareFilePath}
    
  for country in ${countryCodes[@]}; do
    #Extract geonameID for each country  
    geoNameId=$( grep "${country}" countryIPList/*-en.csv | cut -d, -f1 )
    echo "         # ${country} IPs" >> ${middlewareFilePath}
    #Grab every IP listed in that country, reformat, append to middleware file
    grep ${geoNameId} countryIPList/globalIPList.txt | cut -d, -f1 | sed 's/^/          - /' >> ${middlewareFilePath}
  done    
  
  # Delete zip and extracted files
  rm -r countryIPList*
  echo "${lastModifiedFilename} has been updated, ipWhiteList countries are ${countryCodes[@]}"

else
  echo "GeoLite2 Country List hasn't been modified since the ipWhiteList last was generated."
  echo "If you wish to change the ipWhiteList countries, delete ${lastModifiedFilename} and run again."

fi
