# (rm -fv $KIRA_INFRA/docker/validator/Dockerfile) && nano $KIRA_INFRA/docker/validator/Dockerfile
FROM registry.regnet.local:5000/base-image:latest AS build-env

ARG BUILD_HASH
ARG BRANCH
ARG REPO

RUN echo "START: Build hash: ${BUILD_HASH}, Branch: ${BRANCH}, Repo: ${REPO}"
ADD ./container ${SELF_CONTAINER}
RUN "${SELF_CONTAINER}/setup.sh"

FROM nginx
ENV SELF_HOME=/self/home
ENV SELF_LOGS=/self/logs
ENV SELF_CONTAINER=${SELF_HOME}/container
ENV HEALTHCHECK_SCRIPT=${SELF_CONTAINER}/healthcheck.sh

RUN mkdir -p ${SELF_HOME} ${SELF_LOGS} ${SELF_CONTAINER}
ADD ./container ${SELF_CONTAINER}

RUN apt update
RUN apt install -y jq iputils-ping
RUN chmod 777 -R ${SELF_HOME}

HEALTHCHECK --interval=60s --timeout=600s --start-period=180s --retries=2 CMD ${HEALTHCHECK_SCRIPT} | tee -a ${COMMON_DIR}/healthcheck.log

COPY --from=build-env "/root/kira-frontend/src/build/web" /usr/share/nginx/html

CMD ["sh", "-c", "/bin/bash ${SELF_CONTAINER}/start.sh | tee -a ${COMMON_DIR}/start.log"]