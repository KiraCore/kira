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
RUN apt-get install -y jq

RUN wget https://dl.google.com/go/go1.14.2.linux-amd64.tar.gz
RUN tar -C /usr/local -xvf go1.14.2.linux-amd64.tar.gz

ENV PATH=$PATH:/usr/local/go/bin 

RUN cd /usr/local && ls

ENV GOPATH=/home/go
ENV GOBIN=/usr/local/go/bin

ENV SEKAI="${GOPATH}/src/github.com/kiracore/sekai"
ENV SEKAID_BIN="${GOBIN}/sekaid"
ENV COMMON_DIR="/common"

RUN mkdir ${SEKAI} -p
RUN cd ${GOPATH}/src/github.com/kiracore && git clone https://github.com/kiracore/sekai
RUN cd ${SEKAI} && git checkout v0.1.7.4
RUN cd ${SEKAI} && go install ./cmd/sekaid
RUN sekaid version --long

RUN mkdir -p "${COMMON_DIR}"

ADD ./container /root
ADD ./configs /root

ARG DEBIAN_FRONTEND=noninteractive

RUN printenv

EXPOSE 26657

CMD ["sh", "-c", "/bin/bash /root/start.sh"]
