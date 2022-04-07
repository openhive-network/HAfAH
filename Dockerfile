# Base docker file having defined environment for build and run of HAF instance.
# docker build --target=ci-base-image -t registry.gitlab.syncad.com/hive/hafah/ci-base-image:ubuntu20.04-xxx -f Dockerfile .

ARG CI_REGISTRY_IMAGE=registry.gitlab.syncad.com/hive/hafah
ARG CI_IMAGE_TAG=:ubuntu20.04-3

FROM python:3.8-alpine as ci-base-image

ENV LANG=en_US.UTF-8
ENV WORKUSER=hafah_user
ENV WORKUSER_HOME=/home/${WORKUSER}

RUN apk update && DEBIAN_FRONTEND=noniteractive apk add  \
  bash \
  joe \
  sudo \
  ca-certificates \
  postgresql-client \
  wget \
  openjdk11-jre \
  openjdk11-jdk \
  git \
  zip \
  maven \
  && addgroup -S haf_admin && adduser --shell=/bin/bash -S haf_admin -G haf_admin \
  && addgroup -S hive && adduser --shell=/bin/bash -S hive -G hive \
  && addgroup -S hafah_user && adduser --shell=/bin/bash -S hafah_user -G hafah_user \
  && echo "haf_admin ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

WORKDIR ${WORKUSER_HOME}
SHELL ["/bin/bash", "-c"]

ADD --chown=${WORKUSER}:${WORKUSER} ./scripts/setup_jmeter.bash ${WORKUSER_HOME}
ADD --chown=${WORKUSER}:${WORKUSER} ./scripts/setup_m2u.bash ${WORKUSER_HOME}

USER ${WORKUSER}

RUN chmod +x ./setup_jmeter.bash ./setup_m2u.bash
RUN ${WORKUSER_HOME}/setup_jmeter.bash
RUN ${WORKUSER_HOME}/setup_m2u.bash

FROM $CI_REGISTRY_IMAGE/ci-base-image$CI_IMAGE_TAG AS instance

ARG HTTP_PORT=6543
ENV HTTP_PORT=${HTTP_PORT}

ARG POSTGRES_URL="postgresql://${WORKUSER}@localhost/haf_block_log"
ENV POSTGRES_URL=${POSTGRES_URL}

ARG USE_POSTGREST=0
ENV USE_POSTGREST=${USE_POSTGREST}

ENV PGRST_DB_SCHEMA="hafah_endpoints, hafah_api_v1, hafah_api_v2"
ENV PGRST_DB_ANON_ROLE=${WORKUSER}
ENV PGRST_DB_ROOT_SPEC="home"

ENV PERFORMANCE_DIR=${WORKUSER_HOME}/wdir
ENV LANG=en_US.UTF-8

USER ${WORKUSER}
WORKDIR ${WORKUSER_HOME}
SHELL ["/bin/bash", "-c"]

ADD --chown=${WORKUSER}:${WORKUSER} . ./app
ADD --chown=${WORKUSER}:${WORKUSER} ./docker/docker_entrypoint.sh .
ADD --chown=${WORKUSER}:${WORKUSER} ./docker/performance_tests.bash .

RUN pip3 install --no-cache-dir -r ${WORKUSER_HOME}/app/requirements.txt -r ${WORKUSER_HOME}/app/tests/requirements.txt
RUN chmod +x ./docker_entrypoint.sh ./performance_tests.bash

# JSON rpc service
EXPOSE ${HTTP_PORT}

STOPSIGNAL SIGINT

# ENTRYPOINT [ ${WORKUSER_HOME}/performance_tests.bash ]
ENTRYPOINT [ ${WORKUSER_HOME}/docker_entrypoint.sh ]
