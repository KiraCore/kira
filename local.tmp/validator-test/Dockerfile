FROM ubuntu:20.04

ARG DEBIAN_FRONTEND=noninteractive

RUN ln -fs /usr/share/zoneinfo/America/New_York /etc/localtime

RUN apt-get update && apt-get install -y --allow-unauthenticated --allow-downgrades --allow-remove-essential --allow-change-held-packages \
  software-properties-common \
  curl \
  wget \
  git \
  file \
  build-essential \
  hashdeep \
  make \
  nodejs \
  node-gyp \
  tar \
  unzip \
  xz-utils \
  yarn \
  zip
RUN apt-get install -y iputils-ping net-tools
RUN apt-get install -y jq

RUN wget https://dl.google.com/go/go1.14.2.linux-amd64.tar.gz
RUN tar -C /usr/local -xvf go1.14.2.linux-amd64.tar.gz

ENV PATH=$PATH:/usr/local/go/bin 

RUN cd /usr/local && ls

ENV SELF_HOME=/self/home
ENV SELF_LOGS=/self/logs
ENV SELF_SCRIPTS=${SELF_HOME}/scripts
ENV SELF_CONFIGS=${SELF_HOME}/configs
ENV SELF_CONTAINER=${SELF_HOME}/container
ENV GOPATH=/home/go
ENV GOBIN=/usr/local/go/bin

ENV SEKAI="${GOPATH}/src/github.com/kiracore/sekai"
ENV SEKAID_BIN="${GOBIN}/sekaid"
ENV COMMON_DIR="/common"

RUN mkdir ${SEKAI} ${SELF_HOME} ${SELF_SCRIPTS} ${SELF_CONFIGS} ${SELF_UPDATE} ${SELF_UPDATE_TMP} ${SELF_LOGS} ${SELF_CONTAINER} -p
RUN cd ${GOPATH}/src/github.com/kiracore && git clone https://github.com/kiracore/sekai
RUN cd ${SEKAI} && git checkout v0.1.7.4
RUN cd ${SEKAI} && go install ./cmd/sekaid
RUN sekaid version --long

RUN mkdir -p "${COMMON_DIR}"

ADD ./container /root
ADD ./configs /root

ARG DEBIAN_FRONTEND=noninteractive

RUN printenv

HEALTHCHECK --interval=60s --timeout=600s --start-period=180s --retries=2 CMD /root/healthcheck.sh $>> ${SELF_LOGS}/healthcheck_script_output.txt

CMD ["sh", "-c", "/bin/bash /root/start.sh"]
