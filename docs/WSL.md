
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

# Open Env
wsl -d Ubuntu-20.04 --user asmodat --cd ~

# Within WSL set default user and enable systemd service
sudo -s
tee -a /etc/wsl.conf <<EOF
[user]
default=asmodat
[boot]
systemd=true
EOF

# Update WSL instance for faster boot
apt-get update -y --fix-missing
exit
exit

mkdir -p /c/linux && cd /c/linux

# Export Base Image
cd /c/linux && wsl --export Ubuntu-20.04 ubuntu-base-20.04.tar
cd /c/linux && wsl --export Ubuntu-22.04 ubuntu-base-22.04.tar

# Import Base Image & Create New Env
wsl --import kira /c/linux/kira /c/linux/ubuntu-base-20.04.tar

# Ensure WSL2 is used
wsl --set-version kira 2



wsl --terminate kira
wsl --shutdown

# Reboot WSL
net stop LxssManager
net start LxssManager

wsl --export default default.tar
```

# Quick Setup or Hard Reset 3 VM insatnces
```
# this command should be run in bin bash
mkdir -p /c/linux && cd /c/linux && \
 wsl --terminate kira || echo "WARNING: Could NOT terminate kira VM 1" && \
 wsl --terminate kira2 || echo "WARNING: Could NOT terminate kira VM 2" && \
 wsl --terminate kira3 || echo "WARNING: Could NOT terminate kira VM 3" && \
 wsl --unregister kira || echo "WARNING: Could NOT unregister kira VM 1" && \
 wsl --unregister kira2 || echo "WARNING: Could NOT unregister kira VM 2" && \
 wsl --unregister kira3 || echo "WARNING: Could NOT unregister kira VM 3" && \
 rm -rfv /c/linux/kira /c/linux/kira2 /c/linux/kira3 && \
 wsl --import kira /c/linux/kira /c/linux/ubuntu-base-20.04.tar && \
 wsl --import kira2 /c/linux/kira2 /c/linux/ubuntu-base-20.04.tar && \
 wsl --import kira3 /c/linux/kira3 /c/linux/ubuntu-base-20.04.tar && echo "success" || echo "failure"
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
 chmod +x -v ./i.sh && ./i.sh --infra-src="$HASH" --init-mode="interactive"
```

Setup with version ID
```
# v0.10.1
read -p "INPUT VERSION OF THE KM RELEASE: " VER && rm -fv ./i.sh && \
 wget https://github.com/KiraCore/kira/releases/download/$VER/init.sh -O ./i.sh && \
 chmod +x -v ./i.sh && ./i.sh --infra-src="$VER" --init-mode="interactive"
```

# Setting Fixed IP
```
# execute within the instance
ROOT_PROFILE=/root/.profile

if [[ $(getLastLineByPSubStr "ip addr add" $ROOT_PROFILE) -lt 0 ]] ; then
    cat >> $ROOT_PROFILE <<EOL

ip addr flush dev eth0
ip addr add 192.168.123.100/24 brd + dev eth0
ip route add default via 192.168.123.1
EOL
fi

. $ROOT_PROFILE
```

# Multi-node Local Testnet
```
wsl -d kira --user asmodat --cd /tmp
wsl -d kira2 --user asmodat --cd /tmp
wsl -d kira3 --user asmodat --cd /tmp

# To pause failed updates run: systemctl stop kiraup

```