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

RUN curl -L https://storage.googleapis.com/flutter_infra/releases/beta/linux/flutter_linux_1.22.0-12.1.pre-beta.tar.xz | tar -C /opt -xJ

ENV PATH "$PATH:/opt/flutter/bin"

# Enable web capabilities
RUN flutter config --enable-web
RUN flutter upgrade
RUN flutter pub global activate webdev
RUN flutter doctor

RUN cd /root && git clone https://github.com/KiraCore/kira-frontend

RUN cd /root/kira-frontend/src && git checkout dev

# ADD ./container /root
ADD ./configs /root
ADD ./configs/config.json /root/kira-frontend/src/assets/config.json

RUN cd /root/kira-frontend/src && flutter pub get
RUN cd /root/kira-frontend/src && flutter build web --release

RUN rm -rf /var/www/html/web
RUN mv /root/kira-frontend/src/build/web /var/www/html

RUN mv /root/default /etc/nginx/sites-available/

RUN service nginx restart

EXPOSE 80

ENTRYPOINT [ "nginx", "-g", "daemon off;" ]
