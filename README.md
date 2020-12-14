## Kira Management Tool

### Minimum Requirements

```
RAM: 3072MB
```

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

```
KIRA_REGISTRY_SUBNET="100.0.0.0/8"
KIRA_KMS_SUBNET="10.1.0.0/16"
KIRA_VALIDATOR_SUBNET="10.2.0.0/16"
KIRA_SENTRY_SUBNET="10.3.0.0/16"
KIRA_SERVICE_SUBNET="10.4.0.0/16"
```

```
KIRA_REGISTRY_IP="100.0.1.1"
KIRA_KMS_IP="10.1.0.2"
KIRA_VALIDATOR_IP="10.2.0.2"
KIRA_SENTRY_IP="10.3.0.2"
KIRA_INTERX_IP="10.4.0.2"
KIRA_FRONTEND_IP="10.4.0.3"
```

```
VALIDATOR_NODE_ID="4fdfc055acc9b2b6683794069a08bb78aa7ab9ba"
SENTRY_NODE_ID="d81a142b8d0d06f967abd407de138630d8831fff"
```

### 2. Full Node Mode

### 3. Validator Mode
