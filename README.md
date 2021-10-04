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
cd /tmp && wget https://raw.githubusercontent.com/KiraCore/kira/master/workstation/init.sh -O ./i.sh && \
 chmod 555 -v ./i.sh && H=$(sha256sum ./i.sh | awk '{ print $1 }') && read -p "Is '$H' a [V]alid SHA256 ?: "$'\n' -n 1 V && \
 [ "${V,,}" == "v" ] && ./i.sh master || echo "Hash was NOT accepted by the user"
```

Demo Mode Example:

```
cd /tmp && read -p "Input branch name: " BRANCH && \
 wget https://raw.githubusercontent.com/KiraCore/kira/$BRANCH/workstation/init.sh -O ./i.sh && \
 chmod 555 -v ./i.sh && H=$(sha256sum ./i.sh | awk '{ print $1 }') && read -p "Is '$H' a [V]alid SHA256 ?: "$'\n' -n 1 V && \
 [ "${V,,}" == "v" ] && ./i.sh "$BRANCH" || echo "Hash was NOT accepted by the user"
```

### 4. Setup script will further download and install kira management tool 

### 5. By typing kira in the terminal user will have ability to deploy, scale and manage his infrastructure

---

### 1. Demo Mode

```
KIRA_REGISTRY_SUBNET="10.1.0.0/16"
KIRA_SENTRY_SUBNET="10.2.0.0/16"
KIRA_SERVICE_SUBNET="10.3.0.0/16"
```

```
KIRA_REGISTRY_DNS="registry.local"
KIRA_VALIDATOR_DNS="validator.local"
KIRA_SENTRY_DNS="sentry.local"
KIRA_INTERX_DNS="interx.local"
KIRA_FRONTEND_DNS="fontend.local"
```

### 2. Validator Mode

### 3. Sentry Mode
```
KIRA_REGISTRY_SUBNET="10.1.0.0/16"
KIRA_SENTRY_SUBNET="10.2.0.0/16"
KIRA_SERVICE_SUBNET="10.4.0.0/16"
```

```
KIRA_REGISTRY_DNS="registry.local"
KIRA_SEED_DNS="seed.local"
KIRA_SENTRY_DNS="sentry.local"
KIRA_INTERX_DNS="interx.local"
KIRA_FRONTEND_DNS="fontend.local"
```