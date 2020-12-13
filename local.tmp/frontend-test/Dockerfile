FROM cirrusci/flutter:stable

RUN apt-get update && apt-get install -y --allow-unauthenticated --allow-downgrades --allow-remove-essential --allow-change-held-packages \
  nginx

RUN flutter channel beta
RUN flutter config --enable-web
RUN flutter doctor

RUN cd /root && git clone https://github.com/KiraCore/kira-frontend

RUN cd /root/kira-frontend/src && git checkout dev

RUN wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
RUN sudo apt install -y ./google-chrome-stable_current_amd64.deb

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
