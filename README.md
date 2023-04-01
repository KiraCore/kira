## Kira Management Tool (KM)

#### Setup & Minimum Requirements

* Hardware
  * Minimum `2 CPU` cores (ARM64 or x64)
  * Minimum `4 GB` of RAM
  * Storage space required to persist blockchain state and snapshots (`2 TB+` recommended)
  * Minimum `32 GB+` of the **free** storage space available at all times
* Networking
  * Stable internet connection with minimum `128 Mbps` Up/Dn speed
  * Static IP address or dynamic DNS 
  * Access to router or otherwise your local network configuration
* Software
  * Ubuntu 20.04 LTS installed on the host instance, VM or WSL2
  * Secure SSH configuration with RSA key or strong password

##### 1. Install & Update Ubuntu 20.04

```bash
apt update
```

##### 2. Open terminal or SSH console and login as sudo

```bash
sudo -s
```

##### 3. Execute KM Setup Command

```bash
# substitute <hash> with IPFS CID of desired KM release
HASH="<hash>" && \
 cd /tmp && wget https://ipfs.kira.network/ipfs/$HASH/init.sh -O ./i.sh && \
 chmod +x -v ./i.sh && ./i.sh --infra-src="$HASH" --init-mode="interactive"
```

##### 4. Proceed with setup and await process to finish
```
# type following command to enter KM or preview setup process
kira
```

#### Init Script & Supported Flags

The init script of the KM can be found in the [./workstation/init.sh](./workstation/init.sh) location. It is a standalone bash script and can be either copied from the relevant repository or downloaded from a trusted source.

Main purpose of the init stript is to setup all dependencies needed to install KM, you can think about it as an "installation program" for your KIRA node. By supplying flags to the executable file users can customize the setup process:

```bash
# init.sh script supported flags

--infra-src="<string>"        // source of the KM package: <url>, <CID>, <version>
--image-src="<url>"           // source of the base image <url>, <version>
--init-mode="<string>"        // initialization mode: noninteractive, interactive, upgrade
--infra-mode="<string>"       // infrastructure deployment mode: validator, sentry, seed
--master-mnemonic="<string>"  // 24 whitespace separated bip39 words
--trusted-node="<ip>"         // IP address of a trusted node to start syncing from
```
