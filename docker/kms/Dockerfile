FROM registry.local:5000/base-image:latest

ENV SELF_HOME=/self/home
ENV SELF_KMS=${SELF_HOME}/tmkms
ENV SELF_CONFIGS=${SELF_HOME}/configs
ENV SELF_KMS_RELEASE=${SELF_KMS}/target/release

RUN cd ${SELF_HOME} && git clone https://github.com/tendermint/tmkms.git && cd tmkms && ls

RUN cd ${SELF_HOME}/tmkms && cargo build --release --features=softsign
RUN cd ${SELF_HOME}/tmkms && cargo test --all-features
RUN ln ${SELF_KMS_RELEASE}/tmkms /usr/bin/tmkms

ADD ./container ${SELF_CONTAINER}
ADD ./configs/tmkms.toml ${SELF_KMS_RELEASE}
ADD ./configs/priv_validator_key.json ${SELF_KMS_RELEASE}

RUN mkdir /root/.tmkms/

ARG DEBIAN_FRONTEND=noninteractive
RUN LC_ALL=C ${BUILD_SCRIPT} && rm -rf /var/lib/apt/lists/*