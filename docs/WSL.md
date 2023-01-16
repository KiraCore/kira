
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

# Ensure that `Ubuntu-20.04` and `Ubuntu-22.04` is present

mkdir -p /c/linux && cd /c/linux

# Export Base Image
wsl --export Ubuntu-20.04 ubuntu-base-20.04.tar
wsl --export Ubuntu-22.04 ubuntu-base-22.04.tar

# Import Base Image & Create New Env
wsl --import kira /c/linux/kira /c/linux/ubuntu-base-20.04.tar

# Ensure WSL2 is used
wsl --set-version kira 2

# Open Env
wsl -d kira --user asmodat --cd ~

# Within WSL set default user and enable systemd service
tee -a /etc/wsl.conf <<EOF
[user]
default=asmodat
[boot]
systemd=true
EOF

wsl --terminate kira
wsl --shutdown

# Reboot WSL
net stop LxssManager
net start LxssManager

wsl --export default default.tar
```

# Quick Setup Clean VM
```
mkdir -p /c/linux && cd /c/linux && \
 wsl --terminate kira || echo "WARNING: Could NOT terminate kira VM" && \
 wsl --unregister kira || echo "WARNING: Could NOT unregister kira VM" && \
 rm -rfv /c/linux/kira && \
 wsl --import kira /c/linux/kira /c/linux/ubuntu-base-20.04.tar && echo "SUCCESS" || echo "FAILED"
```

# Docker Containers & Images Cleanup
```
docker rm -vf $(docker ps -aq)
docker rmi -f $(docker images -aq)
```

# Setup Example

Setup with IPFS hash
```
# Enter virtual machine
wsl --terminate kira3 && \
 wsl -d kira3 --user asmodat --cd ~

wsl --terminate kira2 && \
 wsl -d kira2 --user asmodat --cd ~

# v0.11.3: bafybeihgiyrw4jfvbtuuchvlybzs3e2keqb7krgom4liskwbei7qyo3vfm

read -p "INPUT HASH OF THE KM RELEASE: " HASH && rm -fv ./i.sh && \
 wget https://ipfs.kira.network/ipfs/$HASH/init.sh -O ./i.sh && \
 chmod 555 -v ./i.sh && ./i.sh --infra-src="$HASH" --init-mode="interactive"
```

Setup with version ID
```
# v0.10.1
read -p "INPUT VERSION OF THE KM RELEASE: " VER && rm -fv ./i.sh && \
 wget https://github.com/KiraCore/kira/releases/download/$VER/init.sh -O ./i.sh && \
 chmod 555 -v ./i.sh && ./i.sh --infra-src="$VER" --init-mode="interactive"
```

# Multi-node Local Testnet
```

# terminate all machines
wsl --terminate kira2 && \
 wsl --terminate kira3

wsl -d kira2 --user asmodat

# To pause failed updates run: systemctl stop kiraup

```