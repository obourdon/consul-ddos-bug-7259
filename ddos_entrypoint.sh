#!/bin/bash
set -xe

if [[ -n "$CONSUL_TEMPLATE_LOG_LEVEL" ]]; then
  CONSUL_TEMPLATE_LOG_LEVEL="-log-level $CONSUL_TEMPLATE_LOG_LEVEL"
fi

consul-template \
  $CONSUL_TEMPLATE_LOG_LEVEL \
  -config consul-template.conf
