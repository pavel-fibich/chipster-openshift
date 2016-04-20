#!/bin/bash

set -e

if [ $# -eq 0 ]
then
  echo "Usgae: run-job.bash BASH_SCRIPT [IMAGE [ENVS_FILE]]"
  exit 0
fi

if [ -z "$2" ]
then
  IMAGE="base"
else
  IMAGE="$2"
fi

if [ -z "$3" ]
then
  ENVS_FILE=/dev/null
else
  ENVS_FILE=$3
fi

BASH_SCRIPT="$1"
# generate valid job names from the script name by 
# - removing the path and file extension
# - changing uppercase letters to lowercase
# - replacing any special characters with dashes 
JOB_NAME=build3-$(basename $BASH_SCRIPT .bash | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z|0-9]/-/g' )
CMD="$(cat "$ENVS_FILE" "$BASH_SCRIPT" | python -c 'import json,sys;str=sys.stdin.read();print(json.dumps(str))')"

if oc get job $JOB_NAME > /dev/null 2>&1 ; then
  oc delete job $JOB_NAME
fi

echo '
{
    "kind": "Job",
    "apiVersion": "extensions/v1beta1",
    "metadata": {
        "name": "'$JOB_NAME'"
    },
    "spec": {
        "parallelism": 1,
        "completions": 1,
        "selector": {
            "matchLabels": {
                "app": "'$JOB_NAME'"
            }
        },
        "template": {
            "metadata": {
                "name": "'$JOB_NAME'",
                "labels": {
                    "app": "'$JOB_NAME'"
                }
            },
            "spec": {
                "volumes": [
                    {
                        "name": "volume-sjrx3",
                        "persistentVolumeClaim": {
                            "claimName": "artefacts"
                        }
                    },
                    {
                        "name": "volume-empty-dir1",
                        "emptyDir": { }
                    }
                ],
                "containers": [
                    {
                        "name": "'$JOB_NAME'",
                        "image": "172.30.1.144:5000/chipster/'$IMAGE'",
                        "command": [
                            "bash",
                            "-c",
                            ' > template-start
                            
echo "$CMD" > job-command

echo '
                        ],
                        "resources": {},
                        "volumeMounts": [
                            {
                                "name": "volume-sjrx3",
                                "mountPath": "/mnt/artefacts"
                            },
                            {
                                "name": "volume-empty-dir1",
                                "mountPath": "/opt"
                            }
                        ],
                        "imagePullPolicy": "Always"
                    }
                ],
                "restartPolicy": "Never",
                "terminationGracePeriodSeconds": 30
            }
        }
    }
}' > template-end

# delete the job in the end to prevent failed jobs to restart
function finish {
  oc delete job $JOB_NAME
  if [ $SUCCESS ]; then 
    echo "JOB SUCCESSFUL"
    exit 0
  else
    echo "JOB FAILED"
    exit 1
  fi  
}
trap finish EXIT

cat template-start job-command template-end | oc create -f -
#cat template-start job-command template-end
rm template-start job-command template-end

bash $(dirname "${BASH_SOURCE[0]}")/follow-logs.bash $JOB_NAME
SUCCESS=1
