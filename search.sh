#!/bin/bash

lastModifiedDir=${LASTMODIFIED_DIR:-"/geoip"}
countryDir=${COUNTRY_DIR:-"${lastModifiedDir}/country"}
subDir=${SUB_DIR:-"${lastModifiedDir}/sub"}

optstring=":c:s:nh"
numberOnly="false"

usage() {
    echo "Usage: $(basename $0) [-c -s -n]"
    echo "  -c  A space seperated array of country_code terms to search for in GeoLite2 database."
    echo "      e.g. -c \"US New-Zealand France\""
    echo "  -s  A space seperated array of sub_code terms to search for in GeoLite2 database."
    echo "      e.g. -n \"VN-43 West-Virginia:Dallas Berlin\""
    echo "  -n  Script will only display the number of matches for each value, default behaviour lists every matching location."
    echo "  -h  Show usage."
    exit 1
}

while getopts ${optstring} arg; do
    case "${arg}" in
	    c) countryCodes=(${OPTARG}) ;;
	    s) subCodes=(${OPTARG}) ;;
	    n) echo "Displaying counts only:" 
        numberOnly="true" ;;
      h) usage ;;
      :) echo "Error: Missing option argument for -${OPTARG}."
        usage ;;
      ?) echo "Error: Invalid option: - ${OPTARG}."
        usage ;;
    esac
done

if [[ -z "$countryCodes" && -z "$subCodes" ]]; then
  echo "Error: No country_code or sub_code terms provided."
  usage
  return 2> /dev/null; exit
fi

if ! [ -z "$countryCodes" ]; then
  for code in "${countryCodes[@]}"; do
    if [ $numberOnly == "false" ]; then
      echo "";
    fi
    placeName=$( grep -hwiF "$code" ${countryDir}/countryList.txt | cut -d, -f2-3 )
    if [ -z "${placeName}" ]; then
      echo "Country_code "$code" didn't match any entries in the GeoLite2 Country database"
    else 
	    placeNameCount=$( echo "${placeName[@]}" | wc -l )
      if [ $placeNameCount -eq 1 ]; then
	      echo "Country_code "$code" matched $placeNameCount country"
      else
        echo "Country_code "$code" matched $placeNameCount countries"
      fi
	    if [ $numberOnly == "false" ]; then
        echo "${placeName[@]}"
	    fi
    fi
  done
fi

if ! [ -z "$subCodes" ]; then
  for code in "${subCodes[@]}"; do
    if [ $numberOnly == "false" ]; then
      echo "";
    fi
    placeName=$( grep -hwiF "$code" ${subDir}/subList.txt | cut -d, -f2-5 | cut -d: -f1 )
    if [ -z "${placeName}" ]; then
      echo "Sub_code "$code" didn't match any entries in the GeoLite2 City database."
    else 
	    placeNameCount=$( echo "${placeName[@]}" | wc -l )
      if [ $placeNameCount -eq 1 ]; then
	      echo "Sub_code "$code" matched $placeNameCount location"
      else
        echo "Sub_code "$code" matched $placeNameCount locations"
	    fi
      if [ $numberOnly == "false" ]; then
        echo "${placeName[@]}"
	    fi
    fi
  done
fi