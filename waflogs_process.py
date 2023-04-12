#!/usr/bin/env python3

#process json input
import json

#timestamp processing
from datetime import datetime

Headers=[]
#Pre-requisite for this script is WAF logs in 1 single file, separated by new-line
LOG="out_debug_20201019-20_anz-block.out"

#print headers
print("Time#WebaclId#ALB#blockedby#blockedaction#terminatingRule#clientIp#country#uri#args#httpVersion#httpMethod#Headers#RequestSleuth")

count = 0

#process the input file
with open(LOG) as f:
    while True:
      count += 1
      line = f.readline()

      if not line:
            break

    #line=f.readline()
    #while line:
      jsondata = json.loads(line)

      #extract json elements
      Time=jsondata['timestamp']
      #AWS log time is in milliseconds
      userTime = datetime.fromtimestamp(Time/1000)
      WebaclId=jsondata['webaclId']
      httpSourceId=jsondata['httpSourceId']
      ruleGroupList=jsondata['ruleGroupList']
      clientIp=jsondata['httpRequest']['clientIp']
      country=jsondata['httpRequest']['country']
      uri=jsondata['httpRequest']['uri']
      args=jsondata['httpRequest']['args']
      httpVersion=jsondata['httpRequest']['httpVersion']
      httpMethod=jsondata['httpRequest']['httpMethod']
      headers=jsondata['httpRequest']['headers']
     
      blockedby="NA"
      blockedaction="NA"
      terminatingRule="NA"

      #request blocked
      if jsondata['action'] == "BLOCK":
          blockedby=jsondata['terminatingRuleId']
          blockedaction="BLOCK"
          terminatingRuleType=jsondata['terminatingRuleType']

          if terminatingRuleType == "RATE_BASED":
              terminatingRule=jsondata['rateBasedRuleList'][0]['rateBasedRuleId']

      #request not blocked - allowed/count
      else:
        if jsondata['nonTerminatingMatchingRules']:
          blockedby=jsondata['nonTerminatingMatchingRules'][0]['ruleId']
          blockedaction=jsondata['nonTerminatingMatchingRules'][0]['action']

      #terminatingRule="NA"
      for rulegrouppos in range(len(ruleGroupList)):
          thisterrule=ruleGroupList[rulegrouppos]['terminatingRule']
          #print(thisterrule)
          if thisterrule is not None:
              terminatingRule=thisterrule

          #terminatingRule = not bool(thisterrule)

      #default set to manual validation
      requestsleuth="Validate"

      #check request uri
      if "robots" in uri:
          requestsleuth="suspicious"
      #requests not blocked/counted are okay
      elif terminatingRule == "NA":
          requestsleuth="NA"
      else:
        #extract headers from input
        for position in range(len(headers)):
          name=headers[position]['name']
          value=headers[position]['value']
          if name == "Host":
              #check if host header begins with "alb" or "IP address" - both are suspicious
              chvalue=value[0:3]
              if chvalue == "alb" or chvalue == "ec2":
                  requestsleuth="suspicious"
                  continue
              if value[0].isdigit():
                  requestsleuth="suspicious"
                  continue

              #check if host header is "localhost"
              lhvalue=value[0:9]
              if lhvalue == "localhost":
                  requestsleuth="suspicious"
                  continue
          elif name == "user-agent":
              if "robot" in value:
                  requestsleuth="suspicious"
                  continue

          #Headers.append(value)
          #print(name,":", value)
          #for key, value in header.items():
              #print(key, "is", value)

      httpSource = httpSourceId.split('/')
      albname = httpSource[1]
      print(userTime,"#",WebaclId,"#",albname,"#",blockedby,"#",blockedaction,"#",terminatingRule,"#",clientIp,"#",country,"#",uri,"#",args,"#",httpVersion,"#",httpMethod,"#",headers,"#",requestsleuth)
