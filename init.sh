#!/bin/bash
set -euo pipefail

RS_NAME=${RS_NAME:-rs0}
MONGO_PORT=${MONGO_PORT:-27017}
AUTH=${AUTH:-true}
ROOT_USER=${MONGO_INITDB_ROOT_USERNAME:-root}
ROOT_PWD=${MONGO_INITDB_ROOT_PASSWORD:-change_me_strong}
WAIT_MAX=${WAIT_MAX:-90}

echo "[init] prepare data dirs..."
mkdir -p /data/db /data/keyfile
# 生成并持久化 keyfile（仅首启生成）
if [ ! -f /data/keyfile/key ]; then
  echo "[init] generating keyfile..."
  # 生成 756 字节的随机密钥
  openssl rand -base64 756 > /data/keyfile/key
  chmod 400 /data/keyfile/key
  chown root:root /data/keyfile/key
fi

echo "[init] starting mongod ..."
# 重要：副本集 + 鉴权 => 必须带 --keyFile
if [ "${AUTH}" = "true" ]; then
  mongod --bind_ip_all --port "${MONGO_PORT}" \
        --replSet "${RS_NAME}" \
        --dbpath /data/db \
        --auth \
        --keyFile /data/keyfile/key \
        --logpath /proc/1/fd/1 --logappend &
else
  mongod --bind_ip_all --port "${MONGO_PORT}" \
        --replSet "${RS_NAME}" \
        --dbpath /data/db \
        --logpath /proc/1/fd/1 --logappend &
fi

echo "[init] waiting for mongod (${WAIT_MAX}s max)..."
for i in $(seq 1 "${WAIT_MAX}"); do
  if mongosh --quiet --eval 'db.runCommand({ ping: 1 }).ok' >/dev/null 2>&1; then
    break
  fi
  sleep 1
  [ "$i" -eq "${WAIT_MAX}" ] && echo "[init] ERROR: mongod not ready" >&2 && exit 1
done

# 若还未成为 primary，则初始化副本集
IS_PRIMARY=$(mongosh --quiet --eval 'db.hello().isWritablePrimary' || echo "false")
if [ "${IS_PRIMARY}" != "true" ]; then
  echo "[init] initiating replica set ${RS_NAME}..."
  mongosh --quiet --eval "rs.initiate({_id:'${RS_NAME}', members:[{_id:0, host:'localhost:${MONGO_PORT}'}]})" || true
  sleep 3
fi

# 创建 root 用户（仅在 AUTH=true 且还未可用时）
if [ "${AUTH}" = "true" ]; then
  if ! mongosh --quiet -u "${ROOT_USER}" -p "${ROOT_PWD}" --authenticationDatabase admin --eval 'db.runCommand({ ping: 1 }).ok' >/dev/null 2>&1; then
    echo "[init] creating admin user..."
    mongosh --quiet --eval "db.getSiblingDB('admin').createUser({user:'${ROOT_USER}', pwd:'${ROOT_PWD}', roles:[{role:'root', db:'admin'}]})" || true
  fi
fi

echo "[init] replica set ready."
wait

