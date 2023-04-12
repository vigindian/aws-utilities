#!/usr/bin/env bash

##############################################
# Purpose: Query/Search AWS DynamoDB table 
#
# v1.0 VN 202011
##############################################

#if [ -z $1 ];then
#  profile="IN"
#else
#  profile=$1
#fi

DEFAULT_FORMAT="json"
DEFAULT_TABLE="YOURDYNAMODBTABLE"

function usage() {
	echo -e "\nUsage: $0 [-h] [-a] [-p aws_profile] [-t table_name] [-s search_attributes.json] [-f output_format]\n-h: help\n-f output_format: output format e.g. json\n-a: get all rows of the table\n-s search_attributes.json: search as per search attributes in search_attributes.json\n-p aws_profile: aws profile name\n-t table_name: dynamodb table name\n\nExamples\n $0 -a\n $0 -s search_attributes.json -f json -t YOURDYNAMODBTABLE"
	exit 0
}

function queryAllrows() {
  #get all rows of the table
  aws dynamodb scan --table-name ${table} --profile=$profile --output=${format}
}

function querySearch() {
  #search row with specific search attribute in json. Eg: get row with pkgname "telegraf"
  aws dynamodb query --table-name ${table} --key-condition-expression "pkgname=:name" --expression-attribute-values file://$file --profile=$profile --output=${format}
}

#process input
while getopts ":hap:t:s:f:" opt; do
  case ${opt} in
    h)
            usage
      ;;
    a)
	    search="ALL" 
      ;;
    s)
	    search="specific"
	    file=$OPTARG
            echo "given file is $file"
      ;;
    p)
            profile=$OPTARG
            echo "given profile is $profile"
      ;;
    t)
            table=$OPTARG
            echo "given table is $table"
      ;;
    f)
            format=$OPTARG
            echo "given format is $format"
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

if [ -z $table ];then
        table=${DEFAULT_TABLE}
fi

if [ -z $format ];then
        format=${DEFAULT_FORMAT}
fi


if [ "$search" == "ALL" ];then
	queryAllrows
elif [ "$search" == "specific" ];then
	if [ -f ${file} ];then
		querySearch
	else
		echo "ERROR: The input file ${file} is not present"
		exit 2
	fi
else
	usage
fi
