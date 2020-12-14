# (rm -fv $KIRA_INFRA/docker/validator/Dockerfile) && nano $KIRA_INFRA/docker/validator/Dockerfile
FROM registry.local:5000/base-image:latest

ARG BUILD_HASH
ARG BRANCH
ARG REPO

RUN echo "Build hash: ${BUILD_HASH}"

ENV FLUTTERROOT="/usr/lib/flutter"

RUN cd /usr/lib && git clone https://github.com/flutter/flutter

RUN cd $FLUTTERROOT && git checkout v1.16.3

ENV PATH=${FLUTTERROOT}/bin:${PATH}

RUN flutter channel beta || echo "Failed to checkout flutter beta"
RUN flutter upgrade || echo "Failed to upgrade flutter"
RUN flutter config --enable-web
RUN flutter doctor

RUN cd /root && git clone ${REPO}

WORKDIR /root/kira-frontend/src

RUN git checkout ${BRANCH}

ADD ./configs /root
ADD ./configs/config.json /root/kira-frontend/src/assets/config.json

RUN flutter pub get
RUN flutter build web --release

RUN rm -rf /var/www/html/web
RUN mv /root/kira-frontend/src/build/web /var/www/html

RUN mv /root/default /etc/nginx/sites-available/

RUN service nginx restart

EXPOSE 80

ENTRYPOINT [ "nginx", "-g", "daemon off;" ]
