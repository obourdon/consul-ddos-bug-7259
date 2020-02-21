ARG CONSUL_VERSION=1.6.3

# Retrieve consul-template
FROM alpine:3.9 AS consul-template
RUN apk add --no-cache wget=1.20.3-r0 unzip=6.0-r4
WORKDIR /
ARG CONSUL_TEMPLATE_VERSION=0.24.1
RUN wget -nv https://releases.hashicorp.com/consul-template/${CONSUL_TEMPLATE_VERSION}/consul-template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip
RUN unzip consul-template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip

# Build from original consul image
FROM consul:${CONSUL_VERSION}
LABEL maintainer "SquareScale Engineering <engineering@squarescale.com>"
LABEL name "SquareScale Consul DDoS test"

# Dependencies
RUN apk add --no-cache \
	tcpdump \
	tshark \
	libc6-compat=1.1.20-r5 \
	bash=4.4.19-r1 \
	openssl
COPY --from=consul-template /consul-template /bin/consul-template

WORKDIR /srv/jobs
COPY . .

#ENTRYPOINT [ ]
#CMD ["/srv/jobs/ddos.sh"]
