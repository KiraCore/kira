# (rm -fv $KIRA_INFRA/docker/validator/Dockerfile) && nano $KIRA_INFRA/docker/validator/Dockerfile
FROM registry.local:5000/base-image:latest

ARG BUILD_HASH
ARG BRANCH
ARG REPO

RUN echo "Build hash: ${BUILD_HASH}"

ENV FLUTTERROOT="/usr/lib/flutter"

RUN ${SELF_SCRIPTS}/git-pull.sh "${REPO}" "${BRANCH}" "/root"

RUN ${SELF_SCRIPTS}/git-pull.sh "https://github.com/flutter/flutter" "v1.16.3" "$FLUTTERROOT"

ENV PATH=${FLUTTERROOT}/bin:${PATH}

RUN flutter channel stable || echo "Failed to checkout flutter stable"
RUN flutter upgrade || echo "Failed to upgrade flutter"
RUN flutter --version
RUN flutter config --no-analytics
RUN flutter config --enable-web
RUN flutter doctor

ADD ./container ${SELF_CONTAINER}

RUN chmod 777 -R ${SELF_HOME}

ARG DEBIAN_FRONTEND=noninteractive

RUN printenv

CMD ["sh", "-c", "/bin/bash ${START_SCRIPT}"]

