#!/usr/bin/env bash

set -e
set -o pipefail

# Safety when piling up with previous commands like docker kill ...
sleep 1

# Random key
consul_key=$(pwgen 15 1 | base64 -e -- -)

#
# Extra info: see it using:
# consul catalog nodes -detailed
#
function gen_extra_consul_cfg_json {
cat <<EOF
"node_meta": {
	"group": "${1:-consul}",
	"cluster": "${2:-consul}"
}
EOF
}

#
# Generic part of consul configuration
#
function gen_consul_cfg_json {
cat <<EOF
	"log_level": "${CONSUL_TRACE_LEVEL:-debug}",
	"client_addr": "0.0.0.0",
	"disable_update_check": true,
	"enable_script_checks": true,
	"ui": true,
	"ports": {
		"dns": 53
	},
	"dns_config" : {
		"enable_truncate" : true
	}
EOF
}

#
# Used for building consul-template.conf file
#
function gen_consul_template_section {
cat <<EOF
template {
  source               = "jobs/in_$1.ctmpl"
  destination          = "jobs/out_$1.rendered"
  error_on_missing_key = true
}
EOF
}

#
# Used for building consul-template test files
#
function gen_consul_template_key {
cat <<EOF
TEST-KEY-$1-$2 = "{{ key "env/test/key-$1-$2" }}"
EOF
}

#
# Used for building consul-template test files
#
function gen_consul_template_key_or_dflt {
cat <<EOF
TEST-KEY-DFLT-$1-$2 = "{{ keyOrDefault "env/test/key-$1-$2" "default-$1-$2" }}"
EOF
}

#
# Used for building consul content test file for import
#
function gen_consul_kv {
cat <<EOF
        {
                "key": "$1",
                "flags": 0,
                "value": "$2"
        }
EOF
}

#
# JSON string with Consul server configuration
#
consul_server_cfg_json=$(cat <<EOF
{
	$(gen_extra_consul_cfg_json),
	$(gen_consul_cfg_json ${CONSUL_TRACE_LEVEL:-debug}),
	"leave_on_terminate" : true,
  	"server": true${CONSUL_SERVER_EXTRA_CFG}
}
EOF
)

#
# JSON string with Consul client/agent configuration
#
consul_client_cfg_json=$(cat <<EOF
{
	$(gen_extra_consul_cfg_json worker app),
	$(gen_consul_cfg_json ${CONSUL_TRACE_LEVEL:-debug})${CONSUL_AGENT_EXTRA_CFG}
}
EOF
)

#
# Build docker container if asked to
#
mkdir -p jobs
if [ -z "$NO_DOCKER_BUILD" ] || [ "$NO_DOCKER_BUILD" != "y" ]; then
	rm -f consul-template.conf consul_kv_export.json
	echo '[' >>consul_kv_export.json
	for i in $(seq 1 ${NUM_TEMPLATES:-15}); do
		item=$(gen_consul_template_section $i)
		echo "$item" >>consul-template.conf
		rm -f jobs/in_${i}.ctmpl
		for j in $(seq 1 20); do
			if [ $((j % 3)) -eq 0 ]; then
				entry=$(gen_consul_template_key $i $j)
				kv=$(gen_consul_kv env/test/key-$i-$j $( echo "VAL-4-KEY-$i-$j" | base64 -e -- - | tr -d '\r'))
			else
				entry=$(gen_consul_template_key_or_dflt $i $j)
				if [ $((j % 4)) -eq 0 ]; then
					kv=$(gen_consul_kv env/test/key-$i-$j $( echo "VAL-4-KEY-DFLT-$i-$j" | base64 -e -- - | tr -d '\r'))
				else
					kv=""
				fi
			fi
			echo "$entry" >>jobs/in_${i}.ctmpl
			if [ -n "$kv" ]; then
				echo "$kv," >>consul_kv_export.json
			fi
		done
	done
	dummy=$(gen_consul_kv env/test/key-dummy $( echo "VAL-4-KEY-DUMMY" | base64 -e -- - | tr -d '\r'))
	echo -e "$dummy\n]" >>consul_kv_export.json
	docker build -t consul-ddos:${CONSUL_VERSION:-1.6.3} --build-arg CONSUL_VERSION=${CONSUL_VERSION:-1.6.3} .
fi

#
# Run Consul server
#
srv=$(docker run \
	$(echo ${CONSUL_SERVER_LAUNCH_MODE:-"--rm -d"}) \
	--name=consul-server \
	--hostname=consul-server \
	-e CONSUL_HTTP_ADDR=http://${CONSUL_SERVER_LOCAL_IP:-172.17.0.2}:8500 \
	-e 'CONSUL_ALLOW_PRIVILEGED_PORTS=' \
	-e CONSUL_BIND_INTERFACE=eth0 \
	-e CONSUL_CLIENT_INTERFACE=eth0 \
	-e "CONSUL_LOCAL_CONFIG=$(echo "${consul_server_cfg_json}" | jq -r .)" \
	-p 8300:8300 \
	-p 8301:8301 \
	-p 8302:8302 \
	-p 8500:8500 \
	consul:${CONSUL_VERSION:-1.6.3} agent \
	-dns-port=53 \
	-recursor=$(awk '/^nameserver/{print $NF;exit}' /etc/resolv.conf) \
	-bootstrap-expect=1
)

echo -e "\nConsul server docker container: $srv\n"

# Wait a little bit for container to be active
sleep 10

# Import test values into consul
echo -e "=====> Imported: $(consul kv import @${CONSUL_EXPORT_JSON:-consul_kv_export.json} | wc -l | awk '{print $NF}') keys\n"

#
# Run Consul client/agent
#
cli=$(docker run \
	--rm \
	$(echo ${CONSUL_AGENT_LAUNCH_MODE:-"--rm -d"}) \
	--name=consul-client \
	--hostname=consul-client \
	-e 'CONSUL_ALLOW_PRIVILEGED_PORTS=' \
	-e "CONSUL_LOCAL_CONFIG=$(echo "${consul_client_cfg_json}" | jq -r .)" \
	-e CONSUL_TEMPLATE_LOG_LEVEL=${CONSUL_TEMPLATE_LOG_LEVEL:-debug} \
	consul-ddos:${CONSUL_VERSION:-1.6.3} agent \
	-dns-port=53 \
	-recursor=$(awk '/^nameserver/{print $NF;exit}' /etc/resolv.conf) \
	-client 0.0.0.0 \
	-retry-join=${CONSUL_SERVER_LOCAL_IP:-172.17.0.2}
)

echo -e "Consul client docker container: $cli\n"

sleep 10

#docker exec -t $cli ./ddos.sh
#exec docker exec -ti $cli bash
