FROM registry.local:5000/base-image:latest

ENV PROFILE_PATH="/etc/profile"
ENV BASHRC_PATH="/root/.bashrc"

ENV GOROOT="/usr/local/go"
ENV GOPATH="/home/go"
ENV GOBIN="${GOROOT}/bin"
ENV GO_VERSION="1.14.2"
ENV DOTNET_ROOT="/usr/bin/dotnet"
ENV PATH="/root/.cargo/bin:${PATH}:${GOBIN}:${GOROOT}:${GOPATH}:/usr/local/bin/CDHelper:/usr/local/bin/AWSHelper"
ENV RUSTFLAGS="-Ctarget-feature=+aes,+ssse3"
ENV GO111MODULE=on
ENV NGINX_CONFIG="/etc/nginx/nginx.conf"
ENV NGINX_SERVICED_PATH="/etc/systemd/system/nginx.service.d"

ADD ./scripts ${SELF_SCRIPTS}
#ADD ./configs ${SELF_CONFIGS}
ADD ./container ${SELF_CONTAINER}

RUN chmod -R 777 ${SELF_HOME} && chmod 777 ${PROFILE_PATH} && chmod 777 ${BASHRC_PATH}

ARG DEBIAN_FRONTEND=noninteractive
RUN LC_ALL=C ${BUILD_SCRIPT} && rm -rf /var/lib/apt/lists/*

ENV AWSHelperVersion="$(AWSHelper version --silent=true)"
ENV CDHelperVersion="$(CDHelper version --silent=true)"

RUN git config --global url.https://github.com/.insteadOf git://github.com/

RUN npm install -g @angular/cli
RUN npm install -g web3 --unsafe-perm=true --allow-root

RUN curl https://sh.rustup.rs -sSf | bash -s -- -y
RUN cargo --version