#Stage 1 - Install dependencies and build the app
FROM debian:latest AS build-env

# Install flutter dependencies
RUN apt-get update 
RUN apt-get install -y curl git wget unzip libgconf-2-4 gdb libstdc++6 libglu1-mesa fonts-droid-fallback lib32stdc++6 python3
RUN apt-get install -y wget
RUN apt-get clean

# Clone the flutter repo
RUN git clone https://github.com/flutter/flutter.git /usr/local/flutter

# Set flutter path
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"

RUN flutter doctor -v
# Enable flutter web
RUN flutter channel master
RUN flutter upgrade
RUN flutter config --enable-web

RUN cd /root && git clone https://github.com/KiraCore/kira-frontend
RUN cd /root/kira-frontend/src && git checkout dev

ADD ./configs /root
ADD ./configs/config.json /root/kira-frontend/src/assets/config.json

WORKDIR /root/kira-frontend/src
RUN flutter pub get
RUN flutter build web

# Stage 2 - Create the run-time image
FROM nginx

RUN wget https://raw.githubusercontent.com/gdraheim/docker-systemctl-replacement/master/files/docker/systemctl.py -O /usr/local/bin/systemctl2
RUN chmod -v 777 /usr/local/bin/systemctl2

COPY --from=build-env /root/kira-frontend/src/build/web /usr/share/nginx/html