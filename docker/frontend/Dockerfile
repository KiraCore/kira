# (rm -fv $KIRA_INFRA/docker/validator/Dockerfile) && nano $KIRA_INFRA/docker/validator/Dockerfile
FROM registry.local:5000/base-image:latest

ARG BUILD_HASH
ARG BRANCH
ARG REPO

ENV REPO="${REPO}"
ENV BRANCH="${BRANCH}"
ENV BUILD_HASH="${BUILD_HASH}"
ENV FRONTEND_SRC="/root/kira-frontend/src"

RUN cd /root && git clone ${REPO}
RUN cd ${FRONTEND_SRC} && git checkout ${BRANCH}
RUN cd ${FRONTEND_SRC} && flutter pub get
RUN cd ${FRONTEND_SRC} && flutter build web --release

ADD ./container ${SELF_CONTAINER}
RUN chmod 777 -R ${SELF_HOME}

HEALTHCHECK --interval=30s --timeout=600s --start-period=180s --retries=2 CMD ${HEALTHCHECK_SCRIPT}

CMD ["sh", "-c", "/bin/bash ${SELF_CONTAINER}/start.sh | tee -a ${COMMON_LOGS}/start.log ; test ${PIPESTATUS[0]} = 0"]