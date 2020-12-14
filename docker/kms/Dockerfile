FROM registry.local:5000/base-image:latest

ARG BUILD_HASH
ARG BRANCH
ARG REPO

ENV SELF_HOME=/self/home
ENV SELF_KMS=${SELF_HOME}/tmkms
ENV SELF_CONFIGS=${SELF_HOME}/configs
ENV SELF_KMS_RELEASE=${SELF_KMS}/target/release

RUN cd ${SELF_HOME} && git clone ${REPO} && cd tmkms && git checkout ${BRANCH} && ls

RUN cd ${SELF_HOME}/tmkms && cargo build --release --features=softsign
RUN cd ${SELF_HOME}/tmkms && cargo test --all-features
RUN ln ${SELF_KMS_RELEASE}/tmkms /usr/bin/tmkms

ADD ./container /root
ADD ./configs/tmkms.toml /root
ADD ./configs/priv_validator_key.json /root

ARG DEBIAN_FRONTEND=noninteractive

CMD ["sh", "-c", "/bin/bash /root/start.sh"]