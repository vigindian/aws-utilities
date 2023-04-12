#!/usr/bin/env bash
#############################################################
# S3 Glacier to standard for objects older than given days
#
# VN
# v1.0 202009
#
#############################################################

##############
# FUNCTIONS
##############
function s3restore_glacier() {

	bucketName=$1

	objectName=$2

	#initiate restore request: As of Sep-2020, Bulk tier is cheapest but slowest restore i.e. about 5-12 hours ref https://aws.amazon.com/glacier/faqs/
	aws s3api restore-object --bucket ${bucketName} --key ${objectName} --restore-request '{"Days":5,"GlacierJobParameters":{"Tier":"Bulk"}}'

	#check the status of restoration
	aws s3api head-object --bucket ${bucketName} --key ${objectName} --output json
}

function s3restore_check() {
        RC=0

        bucketName=$1

        objectName=$2

        #check the status of restoration
        aws s3api head-object --bucket ${bucketName} --key ${objectName} --output json | grep -w Restore > /dev/null 2>&1
        if [ $? == 0 ] ; then
                return $RC
        else
                RC=1
                return $RC
        fi

}

function s3restore_status() {

	RC=0

        bucketName=$1

        objectName=$2

        #check the status of restoration
        aws s3api head-object --bucket ${bucketName} --key ${objectName} --output json | grep -w ongoing-request | grep -w false > /dev/null 2>&1
	if [ $? == 0 ] ; then
		return $RC
	else
		RC=1
		return $RC
	fi

}

function s3glacier_to_standard() {

        RC=0

        bucketName=$1

        objectName=$2

        #change storage class to standard
	aws s3 cp s3://${bucketName}/${objectName} s3://${bucketName}/${objectName} --storage-class STANDARD
        if [ $? == 0 ] ; then
                return $RC
        else
                RC=1
                return $RC
        fi

}

function s3download_archive() {

        bucketName=$1

        objectName=$2

	#copy the file to local
	aws s3 cp s3://${bucketName}/${objectName} .
}

#########
# MAIN
#########
date

S3ARCHIVEBUCKET="YOURBUCKETNAME"
DAYS=401
TMPFILE="/tmp/s3glacier.restore"

today=$(date +%Y-%m-%d)

#aws s3 ls s3://${S3ARCHIVEBUCKET}/ --recursive > ${TMPFILE}
#find all the objects in glacier storage class
#aws s3api list-objects-v2 --bucket $S3ARCHIVEBUCKET --query "Contents[?StorageClass=='GLACIER'].Key" --output text | sed 's/\t/\n/g' > ${TMPFILE}
aws s3api list-objects-v2 --bucket ${S3ARCHIVEBUCKET} --query "Contents[?StorageClass=='GLACIER'].{key: Key, date: LastModified}" --output text > ${TMPFILE}

cat ${TMPFILE} | while read i
do
   objdate=$(echo $i | awk '{print $1}' | awk -F"T" '{print $1}')
   archiveObject=$(echo $i | awk '{print $NF}')

   age_in_days=$(echo $(( ($(date --date="$today" +%s) - $(date --date="$objdate" +%s) )/(60*60*24) )))
   if [ $age_in_days -gt ${DAYS} ] ; then
	#echo "WARN: ${archiveObject}:OLDER:${age_in_days}"
	continue
   fi

   #echo "INFO: $archiveObject:${age_in_days} days older"
   #continue

   #RC 0 is restoration initiated/completed
   s3restore_check $S3ARCHIVEBUCKET $archiveObject
   if [ $? != 0 ] ;then
	echo "INFO: $archiveObject: Let us restore from s3 glacier"
   	s3restore_glacier $S3ARCHIVEBUCKET $archiveObject
   else
	echo "INFO: $archiveObject: glacier restoration already initiated from s3 glacier"
   fi

   #RC 0 is restoration complete
   s3restore_status $S3ARCHIVEBUCKET $archiveObject
   if [ $? == 0 ] ;then
	echo "INFO: $archiveObject: AWS s3 glacier restore successful"
   else
	echo "INFO: $archiveObject: AWS s3 glacier restore in progress"
	continue
   fi

   #RC 0 is storage class change successful
   s3glacier_to_standard $S3ARCHIVEBUCKET $archiveObject
   if [ $? == 0 ] ;then
        echo "INFO: $archiveObject: AWS s3 glacier to standard storage class completed successfully"
   else
        echo "ERR: $archiveObject: AWS s3 glacier to standard storage class failed"
   fi
   echo "-----------------"

done

#cleanup
rm -f ${TMPFILE}
date
