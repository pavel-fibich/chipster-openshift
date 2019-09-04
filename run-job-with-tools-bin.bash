#!/bin/bash

set -e

source scripts/utils.bash

job="$1"
tools_bin_version="$2"
temp_pvc="$3"

if [ -z $tools_bin_version ]; then
  echo "Usage: bash run-job-with-tools-bin.bash BASH_JOB TOOLS_BIN_VERSION"
  exit 1
fi

PROJECT=$(oc project -q)
DOMAIN=$(get_domain)
      
private_config_path="../chipster-private/confs"
image_project=$(get_image_project $private_config_path $PROJECT $DOMAIN)

name=$(basename $job .bash)-bash-job

if oc get job $name > /dev/null 2>&1; then
  oc delete job $name  
  #TODO wait until the job isn't Running anymore
fi

max_cpu=$(oc get limits -o json | jq .items[].spec.limits[0].max.cpu -r)
cpu="4"
if [ "$cpu" -gt "$max_cpu" ]; then
  cpu="$max_cpu"  
fi

oc process -f templates/jobs/bash-job-template-with-tools-bin.yaml --local \
	-p IMAGE_PROJECT=$image_project \
	-p TOOLS_BIN_VERSION=$tools_bin_version \
	-p NAME=$name \
	-p CPU=$cpu \
	-p TEMP_PVC=$temp_pvc \
	| yq r -j - | jq .items[0].spec.template.spec.containers[0].command[2]="$(cat $job | jq -s -R .)" \
	| oc create -f - --validate 
	
#TODO show logs even if the job completed already
follow_job download-tools-bin