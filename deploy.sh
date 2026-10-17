#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

VERSION=${1:?укажите версию: bash deploy.sh 5.0}
PREFIX=klyauzin-01
PORT=8003
REGISTRY=localhost:6001
IMAGE=$REGISTRY/$PREFIX/probe:$VERSION

# 1. Включить Swarm, если он выключен.
if [ "$(docker info --format '{{.Swarm.LocalNodeState}}')" != "active" ]; then
  if [ "$(uname -s)" = "Darwin" ]; then
    docker swarm init
  else
    docker swarm init --advertise-addr eth0
  fi
fi

# 2. Создать свой registry, если его ещё нет.
if ! docker ps -a --format '{{.Names}}' | grep -qx "$PREFIX-registry"; then
  docker volume create "$PREFIX-registry" > /dev/null
  docker run -d \
    --restart unless-stopped \
    --name "$PREFIX-registry" \
    -p 6001:5000 \
    -v "$PREFIX-registry:/var/lib/registry" \
    registry:2
elif [ "$(docker inspect -f '{{.State.Running}}' "$PREFIX-registry")" != "true" ]; then
  docker start "$PREFIX-registry" > /dev/null
fi

until curl -sf "$REGISTRY/v2/" > /dev/null; do
  sleep 1
done

# 3. Собрать образ заданной версии и отправить его в registry.
docker build \
  --build-arg VERSION="$VERSION" \
  -t "$IMAGE" .

docker push "$IMAGE"

# 4. Развернуть стек, передав VERSION в stack.yaml.
VERSION="$VERSION" docker stack deploy \
  --detach=false \
  -c stack.yaml \
  "$PREFIX"

# 5. Дождаться ответа приложения, не дольше 90 секунд.
SECONDS=0
until curl -sf -m 2 "127.0.0.1:$PORT/notes" > /dev/null; do
  if [ $SECONDS -ge 90 ]; then
    echo "приложение не ответило за 90 секунд" >&2
    exit 1
  fi
  sleep 2
done

curl -s "127.0.0.1:$PORT/notes"
echo
