FROM base-node

COPY . /home/user/chipster-web-server/

RUN cd /home/user/chipster-web-server/js/cli-client \
    && chmod -R ug+rwx .
    
RUN cd /home/user/chipster-web-server/js/cli-client \
	&& npm install; tsc

WORKDIR /home/user/chipster-web-server/js/cli-client

CMD node lib/benchmark -h