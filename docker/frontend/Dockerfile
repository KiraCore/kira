# (rm -fv $KIRA_INFRA/docker/validator/Dockerfile) && nano $KIRA_INFRA/docker/validator/Dockerfile
FROM registry.regnet.local:5000/base-image:latest

ARG BUILD_HASH
ARG BRANCH
ARG REPO

RUN echo "START: Build hash: ${BUILD_HASH}, Branch: ${BRANCH}, Repo: ${REPO}"

ADD ./container ${SELF_CONTAINER}
RUN chmod 777 -R ${SELF_HOME}

HEALTHCHECK --interval=60s --timeout=600s --start-period=180s --retries=2 CMD ${HEALTHCHECK_SCRIPT} | tee -a ${COMMON_DIR}/healthcheck.log

CMD ["sh", "-c", "/bin/bash ${SELF_CONTAINER}/start.sh | tee -a ${COMMON_DIR}/start.log"]