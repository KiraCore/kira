# (rm -fv $KIRA_INFRA/docker/validator/Dockerfile) && nano $KIRA_INFRA/docker/validator/Dockerfile
FROM registry.regnet.local:5000/base-image:latest AS build-env

ARG BUILD_HASH
ARG BRANCH
ARG REPO

RUN echo "START: Build hash: ${BUILD_HASH}, Branch: ${BRANCH}, Repo: ${REPO}"
ENV WORKDIR="/root/kira-frontend/src"
WORKDIR "${WORKDIR}"
ADD ./container ${SELF_CONTAINER}
RUN "${SELF_CONTAINER}/setup.sh"

FROM nginx
ENV SELF_HOME=/self/home
ENV SELF_LOGS=/self/logs
ENV SELF_CONTAINER=${SELF_HOME}/container
ENV HEALTHCHECK_SCRIPT=${SELF_CONTAINER}/healthcheck.sh

RUN mkdir ${SELF_HOME} ${SELF_LOGS} ${SELF_CONTAINER} -p
ADD ./container ${SELF_CONTAINER}

RUN apt update
RUN apt install -y jq iputils-ping
RUN chmod 777 -R ${SELF_HOME}

HEALTHCHECK --interval=60s --timeout=600s --start-period=180s --retries=2 CMD ${HEALTHCHECK_SCRIPT} $>> ${SELF_LOGS}/healthcheck_script_output.txt

COPY --from=build-env "${WORKDIR}/build/web" /usr/share/nginx/html

CMD ["sh", "-c", "/bin/bash ${SELF_CONTAINER}/start.sh"]