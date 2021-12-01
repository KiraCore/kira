# (rm -fv $KIRA_INFRA/docker/validator/Dockerfile) && nano $KIRA_INFRA/docker/validator/Dockerfile
FROM registry.local:5000/base-image:latest

ARG BUILD_HASH
ARG BRANCH
ARG REPO

RUN echo "Build hash: ${BUILD_HASH}, branch: ${BRANCH}, repo: $REPO"

RUN git clone ${REPO} ${SEKAI} && cd ${SEKAI} && git checkout ${BRANCH}
RUN cd ${SEKAI} && make install
RUN sekaid version --long
RUN echo "source ${SEKAI}/env.sh" >> ${ETC_PROFILE}
RUN echo "source ${SELF_CONTAINER}/sekaid-helper.sh" >> ${ETC_PROFILE}

ADD ./container ${SELF_CONTAINER}

RUN chmod 777 -R ${SELF_HOME}

ARG DEBIAN_FRONTEND=noninteractive

RUN printenv

HEALTHCHECK --interval=60s --timeout=600s --start-period=600s --retries=4 CMD ${HEALTHCHECK_SCRIPT}

CMD ["sh", "-c", "/bin/bash ${START_SCRIPT} | tee -a ${COMMON_LOGS}/start.log ; test ${PIPESTATUS[0]} = 0"]

