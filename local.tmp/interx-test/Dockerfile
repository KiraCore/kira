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

RUN apt-get update
RUN apt-get install -y --allow-unauthenticated libprotobuf-dev \
  protobuf-compiler \
  golang-goprotobuf-dev \
  golang-grpc-gateway \
  golang-github-grpc-ecosystem-grpc-gateway-dev

RUN wget https://dl.google.com/go/go1.14.2.linux-amd64.tar.gz
RUN tar -C /usr/local -xvf go1.14.2.linux-amd64.tar.gz

RUN cd /usr/local && ls

ENV GOROOT=/usr/local/go
ENV GOPATH=/home/go
ENV GOBIN=/usr/local/go/bin
ENV PATH=$PATH:$GOROOT:$GOPATH:$GOBIN

ENV SEKAI="${GOPATH}/src/github.com/kiracore/sekai"
ENV SEKAID_BIN="${GOBIN}/sekaid"
ENV COMMON_DIR="/common"

RUN go get -u github.com/golang/protobuf/proto
RUN go get google.golang.org/protobuf/cmd/protoc-gen-go

RUN mkdir ${SEKAI} -p
RUN cd ${GOPATH}/src/github.com/kiracore && git clone https://github.com/kiracore/sekai
RUN cd ${SEKAI} && git checkout KIP_31
# RUN cd ${SEKAI}/INTERX && make generate

ADD ./container /root
ADD ./configs /root

ARG DEBIAN_FRONTEND=noninteractive

RUN printenv

EXPOSE 11000

CMD ["sh", "-c", "/bin/bash /root/start.sh"]
