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
cd /home/$SUDO_USER && INFRA_BRANCH="master" && rm -fv ./init.sh && \
 wget https://raw.githubusercontent.com/KiraCore/kira/$INFRA_BRANCH/workstation/init.sh -O ./init.sh && \
 chmod 555 -v ./init.sh && echo "d80b88ddd830175f26e09ab7b21320fe1ebc5f32ecdd644c843d43f6539a1916 init.sh" | sha256sum --check && \
```

Demo Mode Example:

```
cd /home/$SUDO_USER && INFRA_BRANCH="dev" && rm -fv ./init.sh && \
 wget https://raw.githubusercontent.com/KiraCore/kira/$INFRA_BRANCH/workstation/init.sh -O ./init.sh && \
 chmod 555 -v ./init.sh && \
 ./init.sh "$INFRA_BRANCH"
```

### 4. Setup script will further download and install kira management tool 

### 5. By typing kira in the terminal user will have ability to deploy, scale and manage his infrastructure

---

### 1. Demo Mode

```
KIRA_REGISTRY_SUBNET="10.1.0.0/16"
KIRA_VALIDATOR_SUBNET="10.2.0.0/16"
KIRA_SENTRY_SUBNET="10.3.0.0/16"
KIRA_SERVICE_SUBNET="10.4.0.0/16"
```

```
KIRA_REGISTRY_IP="10.1.1.1"
KIRA_VALIDATOR_IP="10.2.0.2"
KIRA_SENTRY_IP="10.3.0.2"
KIRA_INTERX_IP="10.4.0.2"
KIRA_FRONTEND_IP="10.4.0.3"
```

### 2. Full Node Mode

### 3. Validator Mode
