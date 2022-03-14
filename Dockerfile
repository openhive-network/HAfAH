# Base docker file having defined environment for build and run of HAF instance.
# docker build --target=ci-base-image -t registry.gitlab.syncad.com/hive/hafah/ci-base-image:ubuntu20.04-xxx -f Dockerfile .
# To be started from cloned haf source directory.

ARG CI_REGISTRY_IMAGE=registry.gitlab.syncad.com/hive/hafah
ARG CI_IMAGE_TAG=:ubuntu20.04-1

FROM python:3.8-alpine as ci-base-image

ENV LANG=en_US.UTF-8

RUN apk update && DEBIAN_FRONTEND=noniteractive apk add  \
  bash \
  joe \
  sudo \
  ca-certificates \
  && \
  addgroup -S hive && adduser --shell=/bin/bash -S hive -G hive \
  && echo "hive ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers


SHELL ["/bin/bash", "-c"] 

FROM $CI_REGISTRY_IMAGE/ci-base-image$CI_IMAGE_TAG AS instance

ARG HTTP_PORT=6543
ENV HTTP_PORT=${HTTP_PORT}

ARG POSTGRES_URL="postgresql://hive@localhost/haf_block_log"
ENV POSTGRES_URL=${POSTGRES_URL}

USER hive
WORKDIR /home/hive

ENV LANG=en_US.UTF-8

SHELL ["/bin/bash", "-c"] 

ADD --chown=hive:hive . ./app
ADD --chown=hive:hive ./docker/docker_entrypoint.sh .

RUN chmod +x ./docker_entrypoint.sh && \
  cd ./app && \
  pip3 install --no-cache-dir -r requirements.txt

# JSON rpc service
EXPOSE ${HTTP_PORT}

STOPSIGNAL SIGINT

ENTRYPOINT [ "/home/hive/docker_entrypoint.sh" ]

