FROM ubuntu:16.04

WORKDIR /home/user

ENV HOME=/home/user

RUN apt-get update -y \
	&& apt-get upgrade -y \
	&& apt-get install -y nano dstat pv curl liblz4-tool parallel jq wget rsync less \
	&& apt-get clean \
	&& chmod ug+rwx $HOME

# OpenShift gives a random uid for the user and some programs (e.g. dstat) try to find a username from the /etc/passwd.
# Let user to fix it, but obviously this shouldn't be run outside OpenShift
RUN chmod ug+rw /etc/passwd \
	&& echo 'echo "chipster:x:$(id -u):$(id -g)::/tmp:/bin/bash" >> /etc/passwd' > fix-username.bash

CMD sleep inf