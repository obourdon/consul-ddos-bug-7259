# README.md for GitHub repository consul-ddos-bug-7259

This repository contains code and instruction for reproducing Consul issue [#7259](https://github.com/hashicorp/consul/issues/7259)

The case which works:

```
export CONSUL_VERSION=1.6.2
docker kill consul-server consul-client
NO_DOCKER_BUILD=n ./run_ddos_scenario.sh
docker exec -t consul-client consul members ; docker exec -t consul-client /srv/jobs/ddos_entrypoint.sh >/dev/null &
sleep 2 ; docker exec -t consul-client consul members
```

The output should look like:

```
... [deleted stuff]
Consul server docker container: 6ea6207978a3bf0a8c1f6a33c3501e043e89b458526357f64e59075f732d0584

=====> Imported: 151 keys

Consul client docker container: 173fc39fe97cd57f6954e4e6b36db3ada52ae7def7d74536cd1700a3717f3383

MacBook-Pro-Olivier-3:consul-ddos-bug-7259 olivierbourdon$ docker exec -t consul-client consul members ; docker exec -t consul-client /srv/jobs/ddos_entrypoint.sh >/dev/null &
Node           Address          Status  Type    Build  Protocol  DC   Segment
consul-server  172.17.0.2:8301  alive   server  1.6.2  2         dc1  <all>
consul-client  172.17.0.3:8301  alive   client  1.6.2  2         dc1  <default>
[1] 75150
MacBook-Pro-Olivier-3:consul-ddos-bug-7259 olivierbourdon$ sleep 2 ; docker exec -t consul-client consul members
Node           Address          Status  Type    Build  Protocol  DC   Segment
consul-server  172.17.0.2:8301  alive   server  1.6.2  2         dc1  <all>
consul-client  172.17.0.3:8301  alive   client  1.6.2  2         dc1  <default>
```

The case which does not work:

```
# Can be anything >1.6.2
export CONSUL_VERSION=1.6.3
docker kill consul-server consul-client
NO_DOCKER_BUILD=n ./run_ddos_scenario.sh
docker exec -t consul-client consul members ; docker exec -t consul-client /srv/jobs/ddos_entrypoint.sh >/dev/null &
sleep 2 ; docker exec -t consul-client consul members
```

The output should look like:

```
... [deleted stuff]
Consul server docker container: 9486675159ef9dc660a15af942a4f9c2272b068ee607c476aba823bd70fe61d6

=====> Imported: 151 keys

Consul client docker container: e46edc20957c37708b5d7cad43987afaef8f4172acd1df3072ddbdef284d0279

MacBook-Pro-Olivier-3:consul-ddos-bug-7259 olivierbourdon$ docker exec -t consul-client consul members ; docker exec -t consul-client /srv/jobs/ddos_entrypoint.sh >/dev/null &
Node           Address          Status  Type    Build  Protocol  DC   Segment
consul-server  172.17.0.2:8301  alive   server  1.6.3  2         dc1  <all>
consul-client  172.17.0.3:8301  alive   client  1.6.3  2         dc1  <default>
[1] 76858
MacBook-Pro-Olivier-3:consul-ddos-bug-7259 olivierbourdon$ sleep 2 ; docker exec -t consul-client consul members
Error retrieving members: Get http://127.0.0.1:8500/v1/agent/members?segment=_all: EOF
```

See script details for more/extra parametrization

Once containers are build for 1st run, you can then use

```NO_DOCKER_BUILD=y```

You can also try to add some more configuration information to either or both Consul client/server:

```
CONSUL_AGENT_EXTRA_CFG=',"limits": {"rpc_rate": 50,"rpc_max_burst": 100}'
```

You can also log into running docker containers:

```docker exec -ti docker-server sh```

```docker exec -ti docker-client bash```
