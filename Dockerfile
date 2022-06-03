# Base docker file having defined environment for build and run of HAF instance.
# docker build --target=ci-base-image -t registry.gitlab.syncad.com/hive/hafah/ci-base-image:ubuntu20.04-xxx -f Dockerfile .

ARG CI_REGISTRY_IMAGE=registry.gitlab.syncad.com/hive/hafah
ARG CI_IMAGE_TAG=:ubuntu20.04-3

FROM python:3.8-alpine as ci-base-image

ENV LANG=en_US.UTF-8

RUN apk update && DEBIAN_FRONTEND=noniteractive apk add  \
  bash \
  joe \
  sudo \
  ca-certificates \
  postgresql-client \
  wget \
  && addgroup -S haf_admin && adduser --shell=/bin/bash -S haf_admin -G haf_admin \
  && addgroup -S haf_app_admin && adduser --shell=/bin/bash -S haf_app_admin -G haf_app_admin \
  && addgroup -S hafah_user && adduser --shell=/bin/bash -S hafah_user -G hafah_user \
  && echo "haf_admin ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

SHELL ["/bin/bash", "-c"]

FROM $CI_REGISTRY_IMAGE/ci-base-image$CI_IMAGE_TAG AS instance

ARG HTTP_PORT=6543
ENV HTTP_PORT=${HTTP_PORT}

# Lets use by default host address from default docker bridge network
ARG POSTGRES_URL="postgresql://haf_app_admin@172.17.0.1/haf_block_log"
ENV POSTGRES_URL=${POSTGRES_URL}

ARG USE_POSTGREST=0
ENV USE_POSTGREST=${USE_POSTGREST}

ENV PGRST_DB_SCHEMA="hafah_endpoints, hafah_api_v1, hafah_api_v2"
ENV PGRST_DB_ANON_ROLE="hafah_user"
ENV PGRST_DB_ROOT_SPEC="home"

ENV LANG=en_US.UTF-8

USER hafah_user
WORKDIR /home/hafah_user

SHELL ["/bin/bash", "-c"]

ADD --chown=hafah_user:hafah_user . ./app
ADD --chown=hafah_user:hafah_user ./docker/docker_entrypoint.sh .

USER haf_admin

ARG GIT_HASH=''
ENV GIT_HASH=${GIT_HASH}

RUN sudo -n /home/hafah_user/app/docker/docker_build.sh /home/hafah_user ${USE_POSTGREST} ${GIT_HASH}

# JSON rpc service
EXPOSE ${HTTP_PORT}

STOPSIGNAL SIGINT

ENTRYPOINT [ "/home/hafah_user/docker_entrypoint.sh" ]
