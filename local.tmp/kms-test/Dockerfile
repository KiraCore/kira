FROM ubuntu:20.04

ARG DEBIAN_FRONTEND=noninteractive

RUN ln -fs /usr/share/zoneinfo/America/New_York /etc/localtime

RUN apt-get update && apt-get install -y --allow-unauthenticated --allow-downgrades --allow-remove-essential --allow-change-held-packages clang cmake gcc g++ pkg-config libusb-1.0-0-dev curl
RUN apt-get install -y git libudev-dev libusb-1.0-0-dev
RUN apt-get install -y iputils-ping

RUN apt-get update

RUN curl https://sh.rustup.rs -sSf | bash -s -- -y

ENV PATH="/root/.cargo/bin:${PATH}"

RUN cargo --help

ENV SELF_HOME=/self/home
ENV SELF_KMS=${SELF_HOME}/tmkms
ENV SELF_CONFIGS=${SELF_HOME}/configs
ENV SELF_KMS_RELEASE=${SELF_KMS}/target/release

RUN mkdir ${SELF_HOME} -p && cd ${SELF_HOME} && git clone https://github.com/iqlusioninc/tmkms.git && cd tmkms && ls 

RUN cd ${SELF_HOME}/tmkms && cargo build --release --features=softsign
RUN cd ${SELF_HOME}/tmkms && cargo test --all-features
RUN ln ${SELF_KMS_RELEASE}/tmkms /usr/bin/tmkms

ADD ./container /root
ADD ./configs/tmkms.toml ${SELF_KMS_RELEASE}
ADD ./configs/priv_validator_key.json ${SELF_KMS_RELEASE}

RUN mkdir /root/.tmkms/

ARG DEBIAN_FRONTEND=noninteractive

CMD ["sh", "-c", "/bin/bash /root/start.sh"]