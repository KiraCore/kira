FROM registry.local:5000/base-image:latest

ENV SELF_HOME=/self/home
ENV SELF_KMS=${SELF_HOME}/kms
ENV SELF_CONFIGS=${SELF_HOME}/configs
ENV SELF_KMS_RELEASE=${SELF_KMS}/target/release

RUN apt update && apt install -y clang gcc g++ pkg-config libusb-1.0-0-dev

ENV PATH=$PATH:$HOME/.cargo/bin
RUN curl https://sh.rustup.rs -sSf | bash -s -- -y
ENV RUSTFLAGS="-Ctarget-feature=+aes,+ssse3"

RUN cd ${SELF_HOME} && git clone https://github.com/tendermint/kms.git && cd kms

RUN cargo build --release --features=softsign
RUN cargo test --all-features
RUN ln ${SELF_KMS_RELEASE}/tmkms /usr/bin/tmkms

RUN tmkms softsign keygen ~/.tmkms/secret_connection.key

ADD ./config/tmkms.toml ${SELF_KMS_RELEASE}

RUN tmkms start