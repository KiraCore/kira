
# WSL Initial Setup

It is recommended to run the commands in git-bash

```
# Install WSL
wsl --install

# Uninstall Ubuntu (if needed)
wsl --terminate Ubuntu-20.04 && \
 wsl --unregister Ubuntu-20.04

# Re/Install Ubuntu
wsl --install -d Ubuntu-20.04 && \
 wsl --setdefault Ubuntu-20.04 && \
 wsl --set-version Ubuntu-20.04 2
```

# Multi WSL Instance Setup

```
# Listing Installed Distros
wsl --list --verbose

# Ensure that `Ubuntu-20.04` is present

mkdir -p /c/linux && cd /c/linux

# Export Base Image
wsl --export Ubuntu-20.04 ubuntu-base-20.04.tar

# Import Base Image & Create New Env
wsl --import kira /c/linux/kira /c/linux/ubuntu-base-20.04.tar

# Ensure WSL2 is used
wsl --set-version kira 2

# Open Env
wsl -d kira --user asmodat --cd ~

# Within WSL set default user
tee -a /etc/wsl.conf <<EOF
[user]
default=asmodat
EOF
```

# Setup Example

```
BRANCH="feature/ci-cd-v1" && rm -fv ./i.sh && \
 wget https://raw.githubusercontent.com/KiraCore/kira/$BRANCH/workstation/init.sh -O ./i.sh && \
 chmod 555 -v ./i.sh && ./i.sh "$BRANCH"
```