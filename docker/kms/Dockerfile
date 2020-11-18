FROM registry.local:5000/base-image:latest

ENV SELF_HOME=/self/home
ENV SELF_KMS=${SELF_HOME}/kms
ENV SELF_CONFIGS=${SELF_HOME}/configs
ENV SELF_KMS_RELEASE=${SELF_KMS}/target/release

RUN apt-get update && apt-get install -y --allow-unauthenticated --allow-downgrades --allow-remove-essential --allow-change-held-packages clang cmake gcc g++ pkg-config libudev-dev libusb-1.0-0-dev curl

RUN apt-get update

RUN curl https://sh.rustup.rs -sSf | bash -s -- -y
ENV RUSTFLAGS="-Ctarget-feature=+aes,+ssse3"
ENV PATH="/root/.cargo/bin:${PATH}"
RUN cargo --version

RUN cd ${SELF_HOME} && git clone https://github.com/tendermint/kms.git && cd kms && ls

RUN cd ${SELF_HOME}/kms && cargo build --release --features=softsign
RUN cd ${SELF_HOME}/kms && cargo test --all-features
RUN ln ${SELF_KMS_RELEASE}/tmkms /usr/bin/tmkms

ADD ./container ${SELF_CONTAINER}
ADD ./config/tmkms.toml ${SELF_KMS_RELEASE}
ADD ./config/priv_validator_key.json ${SELF_KMS_RELEASE}

RUN mkdir ~/.tmkms/

ARG DEBIAN_FRONTEND=noninteractive
RUN LC_ALL=C ${BUILD_SCRIPT} && rm -rf /var/lib/apt/lists/*