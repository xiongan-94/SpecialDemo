#!/bin/bash
es_home=/opt/module/elasticsearch
kibana_home=/opt/module/kibana
case $1  in
 "start") {
  for i in hadoop102 hadoop103 hadoop104
  do
    echo "==============$i=============="
ssh $i  "source /etc/profile;${es_home}/bin/elasticsearch >/dev/null 2>&1 &"
sleep 4s;
  done
  sleep 2s;
  nohup ${kibana_home}/bin/kibana > kibana.log 2>&1 &
};;
"stop") {
  ps -ef | grep ${kibana_home} | grep -v grep | awk '{print $2}'| xargs kill
  for i in hadoop102 hadoop103 hadoop104
  do
    echo "==============$i=============="
    ssh $i "ps -ef|grep $es_home |grep -v grep|awk '{print \$2}'|xargs kill" >/dev/null 2>&1
  done
};;
esac

