#!/bin/bash


if [ $# -eq 0 ]
  then
    echo "Usgae: deploy.bash PROJECT"
    exit 0
fi

# check if login is needed
oc get projects > /dev/null

if [ $? -eq 1 ]
then
  oc login
fi

PROJECT=$1

oc project "$PROJECT"

if [ $? -eq 1 ]
then
  oc new-project "$PROJECT"
fi

if [[ $(oc project -q) != "$PROJECT" ]]
then
  echo "failed to create the project"
  exit 1
fi 

if [[ $(oc get all) ]]
then
  echo "The project is not empty"
  exit 1
fi 

set -e
set -x

# deploy

oc run auth --image 172.30.1.144:5000/$PROJECT/server \
--env JAVA_CLASS=fi.csc.chipster.auth.AuthenticationService \
--env authentication_service_bind=http://0.0.0.0:8080/ \
--expose --port 8080

oc set volume dc/auth --add -t pvc --mount-path /mnt/artefacts --claim-name artefacts
oc set volume dc/auth --add -t emptyDir --mount-path /opt/chipster-web-server/logs
oc set volume dc/auth --add -t emptyDir --mount-path /opt/chipster-web-server/database

oc expose service auth

oc run service-locator --image 172.30.1.144:5000/$PROJECT/server \
--env JAVA_CLASS=fi.csc.chipster.servicelocator.ServiceLocator \
--env service_locator_bind=http://0.0.0.0:8080/ \
--env authentication_service=http://auth:8080/ \
--env session_db=http://session-db:8080/ \
--env session_db_events=ws://session-db:8081/ \
--env file_broker=http://file-broker:8080/ \
--env scheduler=ws://scheduler:8080/ \
--env toolbox_url=http://toolbox:8080/ \
--expose --port 8080

oc set volume dc/service-locator --add -t pvc --mount-path /mnt/artefacts --claim-name artefacts
oc set volume dc/service-locator --add -t emptyDir --mount-path /opt/chipster-web-server/logs

oc run session-db --image 172.30.1.144:5000/$PROJECT/server \
--env JAVA_CLASS=fi.csc.chipster.sessiondb.SessionDb \
--env session_db_bind=http://0.0.0.0:8080/ \
--env session_db_events_bind=ws://0.0.0.0:8081/ \
--env service_locator=http://service-locator:8080/ \
--expose --port 8080

oc patch service session-db -p '{
	"spec": {
        "ports": [
            {
                "name": "rest",
                "protocol": "TCP",
                "port": 8080,
                "targetPort": 8080
            },
            {
                "name": "websocket",
                "protocol": "TCP",
                "port": 8081,
                "targetPort": 8081
            }
        ]
	}
}'

oc expose service session-db --name session-db
oc expose service session-db --name session-db-events

oc patch route session-db-events -p '{
    "spec": {
        "port": {
            "targetPort": "websocket"
        }
    }
}'

oc set volume dc/session-db --add -t pvc --mount-path /mnt/artefacts --claim-name artefacts
oc set volume dc/session-db --add -t emptyDir --mount-path /opt/chipster-web-server/logs
oc set volume dc/session-db --add -t emptyDir --mount-path /opt/chipster-web-server/database


oc run file-broker --image 172.30.1.144:5000/$PROJECT/server \
--env JAVA_CLASS=fi.csc.chipster.filebroker.FileBroker \
--env file_broker_bind=http://0.0.0.0:8080/ \
--env service_locator=http://service-locator:8080/ \
--expose --port 8080

oc expose service file-broker

oc set volume dc/file-broker --add -t pvc --mount-path /mnt/artefacts --claim-name artefacts
oc set volume dc/file-broker --add -t emptyDir --mount-path /opt/chipster-web-server/logs
oc set volume dc/file-broker --add -t emptyDir --mount-path /opt/chipster-web-server/storage


oc run scheduler --image 172.30.1.144:5000/$PROJECT/server \
--env JAVA_CLASS=fi.csc.chipster.scheduler.Scheduler \
--env scheduler_bind=ws://0.0.0.0:8080/ \
--env service_locator=http://service-locator:8080/ \
--expose --port 8080

oc set volume dc/scheduler --add -t pvc --mount-path /mnt/artefacts --claim-name artefacts
oc set volume dc/scheduler --add -t emptyDir --mount-path /opt/chipster-web-server/logs


oc run toolbox --image 172.30.1.144:5000/$PROJECT/server \
--env JAVA_CLASS=fi.csc.chipster.toolbox.ToolboxService \
--env toolbox_bind_url=http://0.0.0.0:8080/ \
--env service_locator=http://service-locator:8080/ \
--expose --port 8080

oc expose service toolbox

oc set volume dc/toolbox --add -t pvc --mount-path /mnt/artefacts --claim-name artefacts
oc set volume dc/toolbox --add -t emptyDir --mount-path /opt/chipster-web-server/logs


oc run comp --image 172.30.1.144:5000/$PROJECT/comp \
--env JAVA_CLASS=fi.csc.chipster.comp.RestCompServer \
--env service_locator=http://service-locator:8080/

oc set volume dc/comp --add -t pvc --mount-path /mnt/artefacts --claim-name artefacts
oc set volume dc/comp --add -t emptyDir --mount-path /opt/chipster-web-server/logs
oc set volume dc/comp --add -t emptyDir --mount-path /opt/chipster-web-server/jobs-data

oc run web --image 172.30.1.144:5000/$PROJECT/server \
--env JAVA_CLASS=fi.csc.chipster.web.WebServer \
--env web_bind=http://0.0.0.0:8080/ \
--expose --port 8080

oc expose service web 

oc set volume dc/web --add -t pvc --mount-path /mnt/artefacts --claim-name artefacts
oc set volume dc/web --add -t emptyDir --mount-path /opt/chipster-web-server/logs

