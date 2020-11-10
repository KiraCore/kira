# (rm -fv $KIRA_INFRA/docker/validator/Dockerfile) && nano $KIRA_INFRA/docker/validator/Dockerfile
FROM registry.local:5000/base-image:latest

ARG BUILD_HASH
ARG BRANCH
ARG REPO

ENV SEKAI="${GOPATH}/src/github.com/kiracore/sekai"
ENV SEKAID_BIN="${GOBIN}/sekaid"
ENV COMMON_DIR="/common"
ENV GOBIN=/usr/local/go/bin

RUN echo "Build hash: ${BUILD_HASH}"

RUN ${SELF_SCRIPTS}/git-pull.sh "${REPO}" "${BRANCH}" "${SEKAI}"
RUN cd ${SEKAI} && go install ./cmd/sekaid
# RUN echo ${GOBIN} && cd ${GOBIN} && ls
RUN sekaid version --long
RUN mkdir -p "${COMMON_DIR}"

ADD ./configs ${SELF_CONFIGS}
ADD ./container ${SELF_CONTAINER}
ADD ./scripts ${SELF_SCRIPTS}

RUN chmod 777 -R ${SELF_HOME}

ARG DEBIAN_FRONTEND=noninteractive
RUN LC_ALL=C DEBIAN_FRONTEND=noninteractive ${BUILD_SCRIPT}

RUN printenv

HEALTHCHECK --interval=60s --timeout=600s --start-period=180s --retries=2 CMD ${HEALTHCHECK_SCRIPT} $>> ${SELF_LOGS}/healthcheck_script_output.txt

CMD ["sh", "-c", "/bin/bash ${START_SCRIPT}"]

