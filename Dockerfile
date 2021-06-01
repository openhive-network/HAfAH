# The file is used to build docker container for gitlab ci
FROM phusion/baseimage:0.11

ENV LANG=en_US.UTF-8

RUN \
        apt-get update \
    && \
        apt-get install -y \
            iputils-ping \
            systemd \
            postgresql \
            postgresql-contrib \
            build-essential \
            cmake \
            libboost-all-dev \
            postgresql-server-dev-all \
            git \
    && \
        apt-get clean

USER postgres
RUN  /etc/init.d/postgresql start \
    && psql --command "CREATE USER root WITH SUPERUSER CREATEDB;"

USER root