# (rm -fv $KIRA_INFRA/docker/validator/Dockerfile) && nano $KIRA_INFRA/docker/validator/Dockerfile
FROM registry.local:5000/base-image:latest

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

# Stage 2 - Create the run-time image
FROM nginx

HEALTHCHECK --interval=60s --timeout=600s --start-period=180s --retries=2 CMD ${HEALTHCHECK_SCRIPT} $>> ${SELF_LOGS}/healthcheck_script_output.txt

COPY /root/kira-frontend/src/build/web /usr/share/nginx/html