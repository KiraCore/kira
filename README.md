## Kira Management Tool

### 1. Install & Update Ubuntu 20.04

```
apt update
```

### 2. Open terminal or SSH console & logs in as sudo

```
sudo -s
```

### 3. Executes following command that will setup the environment by downloading setup file from github or other source, check integrity of the file, start it and install all essential dependencies

```
cd /home/$SUDO_USER && \
 rm -fv ./setup.sh && \
 wget <URL_TO_THE_SCRIPT> -O ./setup.sh && \
 chmod 555 -v ./setup.sh && \
 echo "<SHA_256_CHECKSUM> setup.sh" | sha256sum --check && \
 ./setup.sh
```

Demo Mode Example:

```
cd /home/$SUDO_USER && \
 rm -fv ./setup.sh && \
 wget https://raw.githubusercontent.com/KiraCore/kira/KIP_51/workstation/init.sh -O ./setup.sh && \
 chmod 555 -v ./setup.sh && \
 ./setup.sh
```

### 4. Setup script will further download and install kira management tool

### 5. By typing kira in the terminal user will have ability to deploy, scale and manage his infrastructure

---

### 1. Demo Mode

1. base image

- update base image

2. sentry

- remove existing `sentrynet` subnet
- create new `sentrynet` subnet (103.0.0.0/8)
- build `sentry` image
- run `sentry` container on `sentrynet` subnet with ip `103.0.1.1`. (9090 port redirect)
- get `sentry`'s node id ($SENTRY_ID), seed ($SENTRY_SEED) & peer ($SENTRY_PEER)

3. validator

- update validator's config file (config.toml)

  - pex = false
  - persistent_peers = $SENTRY_SEED
  - addr_book_strict = false
  - priv_validator_laddr = "tcp://101.0.1.1:26658" (for KMS)

- remove existing `kiranet` subnet

- create new `kiranet` subnet (10.2.0.0/8)

- mnemonic keys generation (signer & faucet)

  - install hd-wallet-derive
  - generate mnemonic key and remove quotes

- run `validator` container on `kiranet` subnet with ip `10.2.0.1`. (send signer & faucet mnemonics as parameters)

- copy genesis.json & priv_validator_key.json file from `validator` container

- get `validator`'s node id ($NODE_ID), seed ($SEEDS), peer ($PEERS)

- update sentry config.toml file and copy into `sentry` container.

### 2. Full Node Mode

### 3. Validator Mode
