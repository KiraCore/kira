FROM ubuntu:20.04

# Local Update
# (rm -fv $KIRA_INFRA/docker/base-image/Dockerfile) && nano $KIRA_INFRA/docker/base-image/Dockerfile

ENV ETC_PROFILE="/etc/profile"
ENV BASHRC="/root/.bashrc"
ENV JOURNAL_LOGS="/var/log/journal"
ENV COMMON_DIR="/common"
ENV SNAP_DIR="/snap"

# Env necessary for the individual child container setup
ENV SELF_HOME=/self/home
ENV SELF_LOGS=/self/logs
ENV SELF_SCRIPTS=${SELF_HOME}/scripts
ENV SELF_CONFIGS=${SELF_HOME}/configs
ENV SELF_UPDATE=${SELF_HOME}/update
ENV SELF_UPDATE_TMP=${SELF_HOME}/tmp/update
ENV SELF_CONTAINER=${SELF_HOME}/container
ENV START_SCRIPT=${SELF_CONTAINER}/start.sh
ENV BUILD_SCRIPT=${SELF_CONTAINER}/deployment.sh
ENV HEALTHCHECK_SCRIPT=${SELF_CONTAINER}/healthcheck.sh
ENV ON_FAILURE_SCRIPT=${SELF_CONTAINER}/on_failure.sh
ENV ON_INIT_SCRIPT=${SELF_CONTAINER}/on_init.sh
ENV ON_SUCCESS_SCRIPT=${SELF_CONTAINER}/on_success.sh
ENV INIT_START_FILE=${SELF_HOME}/init_start
ENV INIT_END_FILE=${SELF_HOME}/init_end
ENV FAILURE_START_FILE=${SELF_HOME}/failure_start
ENV FAILURE_END_FILE=${SELF_HOME}/failure_end
ENV SUCCESS_START_FILE=${SELF_HOME}/success_start
ENV SUCCESS_END_FILE=${SELF_HOME}/success_end
ENV MAINTENANCE_FILE=${SELF_HOME}/maintenence
ENV SEKAID_HOME=/root/.simapp
ENV FLUTTERROOT="/usr/lib/flutter"
ENV GOROOT=/usr/local/go
ENV GOPATH=/home/go
ENV GOBIN=/usr/local/go/bin
ENV SEKAI="${GOPATH}/src/github.com/kiracore/sekai"
ENV SEKAID_BIN="${GOBIN}/sekaid"
ENV RUSTFLAGS="-Ctarget-feature=+aes,+ssse3"
ENV PATH="${PATH}:${FLUTTERROOT}/bin:${FLUTTERROOT}/bin/cache/dart-sdk/bin:${GOROOT}:${GOPATH}:${GOBIN}:/root/.cargo/bin:/root/go/bin"
ENV COMMON_LOGS="${COMMON_DIR}/logs"

RUN mkdir -p ${SNAP_DIR} ${SELF_HOME} ${SELF_SCRIPTS} ${SELF_CONFIGS} ${SELF_UPDATE} ${SELF_UPDATE_TMP} ${SELF_LOGS} ${SELF_CONTAINER} ${GOPATH}/src ${GOPATH}/bin ${SEKAID_HOME} ${COMMON_DIR}

ADD ./container ${SELF_CONTAINER}

RUN chmod -R 777 ${SELF_HOME} && chmod 555 ${ETC_PROFILE} && chmod 555 ${BASHRC}

ARG DEBIAN_FRONTEND=noninteractive
RUN LC_ALL=C ${BUILD_SCRIPT} && rm -rf /var/lib/apt/lists/*

RUN go version
RUN go get -u github.com/golang/protobuf/proto
RUN go get google.golang.org/protobuf/cmd/protoc-gen-go

RUN curl https://sh.rustup.rs -sSf | bash -s -- -y
RUN cargo --version