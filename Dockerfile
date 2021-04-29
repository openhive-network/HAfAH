# docker build -t psql-tools .
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



ADD . /usr/local/src
WORKDIR /usr/local/src

RUN mkdir build \
     && cd build \
     && cmake .. \
     && make \
     && make install

USER postgres
RUN  /etc/init.d/postgresql start \
    && psql --command "CREATE USER root WITH SUPERUSER CREATEDB;" \
    && cd build \
    && make CTEST_OUTPUT_ON_FAILURE=1 test