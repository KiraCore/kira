# (rm -fv $KIRA_INFRA/docker/validator/Dockerfile) && nano $KIRA_INFRA/docker/validator/Dockerfile
FROM registry.local:5000/base-image:latest AS build-env

ARG BUILD_HASH
ARG BRANCH
ARG REPO

RUN echo "Build hash: ${BUILD_HASH}"

RUN cd /root && git clone ${REPO}

WORKDIR /root/kira-frontend/src

RUN git checkout ${BRANCH}

ADD ./configs /root
ADD ./configs/config.json /root/kira-frontend/src/assets/config.json

RUN flutter pub get
RUN flutter build web --release

FROM nginx
ENV SELF_HOME=/self/home
ENV SELF_LOGS=/self/logs
ENV SELF_CONTAINER=${SELF_HOME}/container
ENV HEALTHCHECK_SCRIPT=${SELF_CONTAINER}/healthcheck.sh

RUN mkdir ${SELF_HOME} ${SELF_LOGS} ${SELF_CONTAINER} -p
ADD ./container ${SELF_CONTAINER}

RUN apt update
RUN apt install -y jq
RUN chmod 777 -R ${SELF_HOME}

HEALTHCHECK --interval=60s --timeout=600s --start-period=180s --retries=2 CMD ${HEALTHCHECK_SCRIPT} $>> ${SELF_LOGS}/healthcheck_script_output.txt

COPY --from=build-env /root/kira-frontend/src/build/web /usr/share/nginx/html