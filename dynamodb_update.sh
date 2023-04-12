#!/usr/bin/env bash

#####################################################################
# Purpose: Update AWS DynamoDB in batch mode as per input file
#
# v1.0 VN 202011
#####################################################################

function usage() {
	echo -e "\nUsage: $0 [-h] [-p aws_profile] [-i inputfile.json] \n-h: help\n-i inputfile.json: batch update dynamodb table as per inputfile.json\n-p aws_profile: aws profile name\n\nExamples\n $0 -i dynamodb-batch-input.json"
	exit 0
}

#process input
while getopts ":hi:p:" opt; do
  case ${opt} in
    h)
            usage
      ;;
    i)
	    file=$OPTARG
            echo "given input-file is $file"
      ;;
    p)
            profile=$OPTARG
            echo "given profile is $profile"
      ;;
    *)
            echo "Incorrect syntax"
            usage
      ;;
  esac
done
shift $((OPTIND -1))

if [ -z $profile ];then
	profile="IN"
fi

if [ -z $1 ];then
  profile="IN"
else
  profile=$1
fi

#single-item
#aws dynamodb put-item --table-name yourdynamodbtable --item file://dynamodb-single-input.json --profile=$profile

if [ -f "${file}" ] && [ ! -z "${profile}" ];then
  #multiple items: prepare input file in json format and run this script
  aws dynamodb batch-write-item --request-items file://${file} --profile=$profile
else
  usage
fi
