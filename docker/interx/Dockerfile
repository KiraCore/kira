# (rm -fv $KIRA_INFRA/docker/validator/Dockerfile) && nano $KIRA_INFRA/docker/validator/Dockerfile
FROM registry.local:5000/base-image:latest

ARG BUILD_HASH
ARG BRANCH
ARG REPO

ENV SEKAI="${GOPATH}/src/github.com/kiracore/sekai"
ENV SEKAID_BIN="${GOBIN}/sekaid"
ENV COMMON_DIR="/common"

RUN go get -u github.com/golang/protobuf/proto
RUN go get google.golang.org/protobuf/cmd/protoc-gen-go

RUN mkdir ${SEKAI} -p
RUN cd ${GOPATH}/src/github.com/kiracore && git clone ${REPO}
RUN cd ${SEKAI} && git checkout ${BRANCH}

ADD ./container /root
ADD ./configs /root

ARG DEBIAN_FRONTEND=noninteractive

RUN printenv

EXPOSE 11000

HEALTHCHECK --interval=60s --timeout=600s --start-period=180s --retries=2 CMD ${HEALTHCHECK_SCRIPT} $>> ${SELF_LOGS}/healthcheck_script_output.txt

CMD ["sh", "-c", "/bin/bash /root/start.sh"]
