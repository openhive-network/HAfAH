# Base docker file having defined environment for build and run of HAF instance.
# docker build --target=ci-base-image -t registry.gitlab.syncad.com/hive/hafah/ci-base-image:ubuntu20.04-xxx -f Dockerfile .

ARG CI_REGISTRY_IMAGE=registry.gitlab.syncad.com/hive/hafah
ARG CI_IMAGE_TAG=:ubuntu20.04-6

# As described here, better to avoid Apline images usage together with Python...

FROM python:3.10-slim as ci-base-image

ENV LANG=en_US.UTF-8

RUN apt update && DEBIAN_FRONTEND=noniteractive apt install -y  \
  bash \
  joe \
  sudo \
  git \
  ca-certificates \
  postgresql-client \
  wget \
  procps \
  xz-utils \
  curl \
  && DEBIAN_FRONTEND=noniteractive apt-get clean && rm -rf /var/lib/apt/lists/* \
  && useradd -ms /bin/bash "haf_admin" && echo "haf_admin ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
  && useradd -ms /bin/bash "haf_app_admin" \
  && useradd -ms /bin/bash "hafah_user"

SHELL ["/bin/bash", "-c"]

FROM $CI_REGISTRY_IMAGE/ci-base-image$CI_IMAGE_TAG AS instance

ARG HTTP_PORT=6543
ENV HTTP_PORT=${HTTP_PORT}

# Lets use by default host address from default docker bridge network
ARG POSTGRES_URL="postgresql://haf_app_admin@172.17.0.1/haf_block_log"
ENV POSTGRES_URL=${POSTGRES_URL}

ARG USE_POSTGREST=0
ENV USE_POSTGREST=${USE_POSTGREST}

ENV PGRST_DB_SCHEMA="hafah_endpoints"
ENV PGRST_DB_ANON_ROLE="hafah_user"
ENV PGRST_DB_ROOT_SPEC="home"

ENV LANG=en_US.UTF-8

USER hafah_user
WORKDIR /home/hafah_user

SHELL ["/bin/bash", "-c"]

ADD --chown=hafah_user:hafah_user . ./app
ADD --chown=hafah_user:hafah_user ./docker/docker_entrypoint.sh .

USER haf_admin
RUN sudo -n /home/hafah_user/app/docker/docker_build.sh /home/hafah_user ${USE_POSTGREST} \
    && sudo rm -rf /home/hafah_user/app/.git

# JSON rpc service
EXPOSE ${HTTP_PORT}

STOPSIGNAL SIGINT

ENTRYPOINT [ "/home/hafah_user/docker_entrypoint.sh" ]
