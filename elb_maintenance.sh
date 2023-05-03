#!/usr/bin/env bash

############
# FUNCTIONS
############
function usage(){
	echo -e "USAGE:\n$0 REGION ENV ROLE NODE MODE\n\nValid Options: $0 anz|us|uk stg|prd web node O|N\n\nEg: $0 anz stg web web3 O\n"
	exit 1
}

############
# MAIN
############
if [ "$#" -ne 5 ] ;then
	usage
fi

REGION="$1"
ENV="$2"
ROLE="$3"
NODE="$4"
MODE="$5"

case "$MODE" in
        O)
                AWSELBCMD="deregister-targets"
                ;;
	N)
                AWSELBCMD="register-targets"
                ;;
        *)
                echo "ERR: Unsupported mode ${MODE}"
                exit 51
                ;;
esac

case "$ROLE" in
	web)
		tgs="tg-web1 tg-web2"
		;;
	*)
		echo "ERR: Unsupported role ${ROLE}"
		exit 31
		;;
esac

if [ "$REGION" == "anz" ];then
	case "$ENV" in 
		stg|staging)
			AWSPROF="anzstg"
			;;
		prd|prod|production)
			AWSPROF="anzprod"
		        tgs="tg-web1 tg-web2"
			;;
		*)
			echo "ERR: Unsupported env ${REGION}:${ENV}"
			exit 21
			;;
	esac
elif [ "$REGION" == "us" ];then
	case "$ENV" in
                prd|prod|production)
			AWSPROF="usprod"
                        ;;
		*)
                        echo "ERR: Unsupported env ${REGION}:${ENV}"
                        exit 21
                        ;;
        esac
elif [ "$REGION" == "uk" ];then
	case "$ENV" in
                prd|prod|production)
			AWSPROF="ukprod"
                        ;;
		*)
                        echo "ERR: Unsupported env ${REGION}:${ENV}"
                        exit 21
                        ;;
        esac
else
	echo "ERR: Invalid region ${REGION}"
	exit 11
fi


for tg in ${tgs}
do
	#identify instance-id based on the given name
	ec2instanceid=$(aws ec2 describe-instances --query 'Reservations[].Instances[].[InstanceId]' --filters Name=tag:Name,Values=${NODE} --output=text --profile=${AWSPROF})
	if [ -z ${ec2instanceid} ];then
		echo "ERR: Cannot determine instance-id. Please check if the name is correct - it should be same as the 'Name' tag of the instance"
		exit 12
	fi
	echo "Instance-id: ${ec2instanceid}"

	#identify target-group arn
	tgarn=$(aws elbv2 describe-target-groups --names ${tg} --profile=${AWSPROF} --output=json|grep TargetGroupArn|awk -F": " '{print $2}'|sed 's/"//g;s/,//g')
	echo "target group of ${tg} is: ${tgarn}"

	#update target group based on the given mode
	echo -e "AWS Command:\naws elbv2 ${AWSELBCMD} --target-group-arn ${tgarn} --targets Id=${ec2instanceid} --profile=${AWSPROF}"
	aws elbv2 ${AWSELBCMD} --target-group-arn ${tgarn} --targets Id=${ec2instanceid} --profile=${AWSPROF}
done

