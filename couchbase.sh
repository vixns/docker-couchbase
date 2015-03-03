#!/bin/bash

# based on https://github.com/aminjam/docker-containers/blob/master/couchbase/community/run.sh

check() {
  if [ -z "$COUCHBASE_USER" ] || [ -z "$COUCHBASE_PASS" ]; then
    echo >&2 "error: Couchbase not initialized. Please make sure COUCHBASE_USER and COUCHBASE_PASS are set."
    exit 1
  fi
}

start() {
  local counter=1
  "$@"
  while [ $? -ne 0 ]; do
    if [[ "$CLI" == "true" && "$counter" -ge 10 ]]; then
      echo "server didn't start in 50 seconds, exiting now..."
      exit
    fi
    counter=$[$counter +1]
    echo "waiting for couchbase to start..."
    sleep 5
    "$@"
  done
}

get_ip() {
  local eth0=$(ip addr show dev eth0 | sed -e's/^.*inet \([^ ]*\)\/.*$/\1/;t;d')
  echo $eth0
}

get_server_ip() {
	if [[ -z "$COUCHBASE_SERVER" ]]; then
	  echo $(dig +short a ${COUCHBASE_FQDN-init.couchbase.service.consul})
    else
      echo $COUCHBASE_SERVER
    fi
}

wait_for_shutdown() {
  local pid_file=/opt/couchbase/var/lib/couchbase/couchbase-server.pid

  # can't use 'wait $(<"$pid_file")' as process not child of shell
  while [ -e /proc/$(<"$pid_file") ]; do sleep 5; done
}

check_data_persistence() {
  if [[ -n "$COUCHBASE_DATA" ]]; then
    echo "change data path owner to couchbase"
    chown -R couchbase $COUCHBASE_DATA
    echo "initializing node..."
    start /opt/couchbase/bin/couchbase-cli node-init -c $ip:8091 -u "$COUCHBASE_USER" -p "$COUCHBASE_PASS" --node-init-data-path=$COUCHBASE_DATA
  fi
}

cluster_init() {
  check
  local ip=$(get_ip)
  if [ -z "$CLUSTER_RAM_SIZE" ]; then
    CLUSTER_RAM_SIZE=256
  fi
  check_data_persistence
  echo "initializing cluster..."
  start /opt/couchbase/bin/couchbase-cli cluster-init -c $ip:8091 -u "$COUCHBASE_USER" -p "$COUCHBASE_PASS" --cluster-init-ramsize=$CLUSTER_RAM_SIZE --cluster-username="$COUCHBASE_USER" --cluster-password="$COUCHBASE_PASS"
  
  if [ -n "$BUCKET_NAME" ];then
    echo "adding bucket..."
    if [ -z "$BUCKET_RAM_SIZE" ]; then
      BUCKET_RAM_SIZE=$CLUSTER_RAM_SIZE
    fi
    start /opt/couchbase/bin/couchbase-cli bucket-create -c $ip:8091 -u "$COUCHBASE_USER" -p "$COUCHBASE_PASS" --bucket="$BUCKET_NAME" --bucket-ramsize=$BUCKET_RAM_SIZE --wait --bucket-type=couchbase --bucket-replica=1 --bucket-priority=high
  fi
}

rebalance() {
  check
  local ip=$(get_ip)
  local server_ip=$(get_server_ip)
  check_data_persistence
  echo "adding server with rebalance..."
  start /opt/couchbase/bin/couchbase-cli rebalance -c $server_ip:8091 -u "$COUCHBASE_USER" -p "$COUCHBASE_PASS" --server-add=$ip:8091 --server-add-username="$COUCHBASE_USER" --server-add-password="$COUCHBASE_PASS"
}

cli() {
  CLI="true"
  start $@
}

start_couchbase() {
  echo "starting couchbase"
  cd /opt/couchbase/var/lib/couchbase
  chpst -u couchbase:couchbase /opt/couchbase/bin/couchbase-server -- -noinput -detached

  trap "/opt/couchbase/bin/couchbase-server -k" exit INT TERM
}

main() {
  set +e
  set -o pipefail

  case "$1" in
    cluster-init)    start_couchbase && cluster_init && wait_for_shutdown;;
    rebalance)       start_couchbase && rebalance    && wait_for_shutdown;;
    *)               cli $@;;
  esac
}

main "$@"
