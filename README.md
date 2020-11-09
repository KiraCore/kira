## Kira Management Tool

### 1. User installs Ubuntu 20.04

### 2. User opens terminal and logs in as sudo

```
sudo -s
```

### 3. User executes a command that will setup the environment by downloading setup file from github or other source, check integrity of the file, start it and install all essential dependencies

```
cd /home/$SUDO_USER && \
 rm -f ./setup.sh && \
 wget <URL_TO_THE_SCRIPT> -O ./setup.sh && \
 chmod 555 ./setup.sh && \
 echo "<SHA_256_CHECKSUM> setup.sh" | sha256sum --check && \
 ./setup.sh
```

### 4. Setup script will further download and install kira management tool

### 5. By typing kira in the terminal user will have ability to deploy, scale and manage his infrastructure

---

### 1. Demo Mode

- dependencies
- images
  - base image
  - validator
  - sentry
  - kms
- subnets
- containers
  - registry
  - validator
  - the rest

### 2. Full Node Mode

### 3. Validator Mode
