# (rm -fv $KIRA_INFRA/docker/validator/Dockerfile) && nano $KIRA_INFRA/docker/validator/Dockerfile
FROM registry.regnet.local:5000/base-image:latest

ARG BUILD_HASH
ARG BRANCH
ARG REPO

RUN echo "Build hash: ${BUILD_HASH}"

RUN git clone ${REPO} ${SEKAI} && cd ${SEKAI} && git checkout ${BRANCH}
RUN cd ${SEKAI} && go install ./cmd/sekaid
RUN sekaid version --long

ADD ./container ${SELF_CONTAINER}

RUN chmod 777 -R ${SELF_HOME}

ARG DEBIAN_FRONTEND=noninteractive

RUN printenv

HEALTHCHECK --interval=30s --timeout=600s --start-period=600s --retries=2 CMD ${HEALTHCHECK_SCRIPT}

CMD ["sh", "-c", "/bin/bash ${START_SCRIPT} | tee -a ${COMMON_LOGS}/start.log ; test ${PIPESTATUS[0]} = 0"]

