#!/bin/bash
set -euo pipefail

RS_NAME=${RS_NAME:-rs0}
MONGO_PORT=${MONGO_PORT:-27017}
AUTH=${AUTH:-true}
ROOT_USER=${MONGO_INITDB_ROOT_USERNAME:-root}
ROOT_PWD=${MONGO_INITDB_ROOT_PASSWORD:-change_me_strong}

if [ "${AUTH}" = "true" ]; then
  mongod --bind_ip_all --port "${MONGO_PORT}" --replSet "${RS_NAME}" --dbpath /data/db --auth &
else
  mongod --bind_ip_all --port "${MONGO_PORT}" --replSet "${RS_NAME}" --dbpath /data/db &
fi

echo "[init] waiting for mongod..."
for i in {1..60}; do
  if mongosh --quiet --eval 'db.runCommand({ ping: 1 }).ok' >/dev/null 2>&1; then
    break
  fi
  sleep 1
  if [ $i -eq 60 ]; then
    echo "[init] mongod not ready in time" >&2
    exit 1
  fi
done

RS_STATUS=$(mongosh --quiet --eval 'db.isMaster().ismaster' || echo "false")
if [ "${RS_STATUS}" != "true" ]; then
  echo "[init] initiating replica set ${RS_NAME}..."
  mongosh --quiet --eval "rs.initiate({_id:'${RS_NAME}', members:[{_id:0, host:'localhost:${MONGO_PORT}'}]})" || true
  sleep 3
fi

if [ "${AUTH}" = "true" ]; then
  if ! mongosh --quiet -u "${ROOT_USER}" -p "${ROOT_PWD}" --authenticationDatabase admin --eval 'db.runCommand({ ping: 1 }).ok' >/dev/null 2>&1; then
    echo "[init] creating admin user..."
    mongosh --quiet --eval "db.getSiblingDB('admin').createUser({user:'${ROOT_USER}', pwd:'${ROOT_PWD}', roles:[{role:'root', db:'admin'}]})"
  fi
fi

echo "[init] replica set ready."
wait
