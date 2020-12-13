FROM ubuntu:20.04

ARG DEBIAN_FRONTEND=noninteractive

RUN ln -fs /usr/share/zoneinfo/America/New_York /etc/localtime

RUN apt-get update && apt-get install -y --allow-unauthenticated --allow-downgrades --allow-remove-essential --allow-change-held-packages \
  clang \
  cmake \
  gcc \
  g++ \
  software-properties-common \
  curl \
  wget \
  git \
  build-essential \
  make \
  tar \
  unzip \
  zip \
  nginx

RUN apt-get update

ENV FLUTTERROOT="/usr/lib/flutter"

RUN cd /usr/lib && git clone https://github.com/flutter/flutter

RUN cd $FLUTTERROOT && git checkout v1.16.3

ENV PATH=${FLUTTERROOT}/bin:${PATH}

RUN flutter channel beta || echo "Failed to checkout flutter beta"
RUN flutter upgrade || echo "Failed to upgrade flutter"
RUN flutter --version
RUN flutter config --no-analytics
RUN flutter config --enable-web
RUN flutter doctor

RUN cd /root && git clone https://github.com/KiraCore/kira-frontend

RUN cd /root/kira-frontend/src && git checkout dev

# ADD ./container /root
ADD ./configs /root
ADD ./configs/config.json /root/kira-frontend/src/assets/config.json

RUN cd /root/kira-frontend/src && flutter pub get && flutter build web

RUN rm -rf /var/www/html/web
RUN mv /root/kira-frontend/src/build/web /var/www/html

RUN mv /root/default /etc/nginx/sites-available/

RUN service nginx restart

EXPOSE 80

ENTRYPOINT [ "nginx", "-g", "daemon off;" ]
