
# Setting Up Permissions

> Propose & Vote on Upgrade Proposals

```
whitelistPermission validator $PermCreateSoftwareUpgradeProposal $(showAddress validator)
whitelistPermission validator $PermVoteSoftwareUpgradeProposal $(showAddress validator) 
```

> Creating Soft Fork Update Plan

```
INFRA_RES_TMP="{\"id\":\"kira\",\"git\":\"https://github.com/KiraCore/kira\",\"checkout\":\"testnet\",\"checksum\":\"\"}" && \
SEKAI_RES_TMP="{\"id\":\"sekai\",\"git\":\"https://github.com/KiraCore/sekai\",\"checkout\":\"master\",\"checksum\":\"\"}" && \
INTRX_RES_TMP="{\"id\":\"interx\",\"git\":\"https://github.com/KiraCore/sekai\",\"checkout\":\"master\",\"checksum\":\"\"}" && \
FRONT_RES_TMP="{\"id\":\"frontend\",\"git\":\"https://github.com/KiraCore/kira-frontend\",\"checkout\":\"master\",\"checksum\":\"\"}" && \
UPGRADE_NAME_TMP="upgrade-50" && \
sekaid tx upgrade proposal-set-plan \
 --name="$UPGRADE_NAME_TMP" \
 --instate-upgrade=true \
 --skip-handler=true \
 --resources="[${INFRA_RES_TMP},${SEKAI_RES_TMP},${INTRX_RES_TMP},${FRONT_RES_TMP}]" \
 --min-upgrade-time=$(($(date -d "$(date)" +"%s") + 900)) \
 --old-chain-id="$NETWORK_NAME" \
 --new-chain-id="$NETWORK_NAME" \
 --rollback-memo="${UPGRADE_NAME_TMP}-roll" \
 --max-enrollment-duration=60 \
 --upgrade-memo="This is a soft fork test upgrade" \
 --from=validator --keyring-backend=test --home=$SEKAID_HOME --chain-id=$NETWORK_NAME --fees=100ukex --log_format=json --yes | txAwait 180

voteYes $(lastProposal) validator

showCurrentPlan | jq
showNextPlan | jq
```

> Creating Hard Fork Update Plan

```
INFRA_RES_TMP="{\"id\":\"kira\",\"git\":\"https://github.com/KiraCore/kira\",\"checkout\":\"testnet\",\"checksum\":\"\"}" && \
SEKAI_RES_TMP="{\"id\":\"sekai\",\"git\":\"https://github.com/KiraCore/sekai\",\"checkout\":\"master\",\"checksum\":\"\"}" && \
INTRX_RES_TMP="{\"id\":\"interx\",\"git\":\"https://github.com/KiraCore/sekai\",\"checkout\":\"master\",\"checksum\":\"\"}" && \
FRONT_RES_TMP="{\"id\":\"frontend\",\"git\":\"https://github.com/KiraCore/kira-frontend\",\"checkout\":\"master\",\"checksum\":\"\"}" && \
UPGRADE_NAME_TMP="upgrade-50" && \
sekaid tx upgrade proposal-set-plan \
 --name="$UPGRADE_NAME_TMP" \
 --instate-upgrade=false \
 --skip-handler=true \
 --resources="[${INFRA_RES_TMP},${SEKAI_RES_TMP},${INTRX_RES_TMP},${FRONT_RES_TMP}]" \
 --min-upgrade-time=$(($(date -d "$(date)" +"%s") + 900)) \
 --old-chain-id="$NETWORK_NAME" \
 --new-chain-id="newnet-1" \
 --rollback-memo="${UPGRADE_NAME_TMP}-roll" \
 --max-enrollment-duration=60 \
 --upgrade-memo="This is a hard fork test upgrade" \
 --from=validator --keyring-backend=test --home=$SEKAID_HOME --chain-id=$NETWORK_NAME --fees=100ukex --log_format=json --yes | txAwait 180

voteYes $(lastProposal) validator

showCurrentPlan | jq
showNextPlan | jq
```

Usage:
  sekaid tx upgrade proposal-set-plan [flags]

Flags:
  -a, --account-number uint           The account number of the signing account (offline mode only)
  -b, --broadcast-mode string         Transaction broadcasting mode (sync|async|block) (default "sync")
      --description string            description
      --dry-run                       ignore the --gas flag and perform a simulation of a transaction, but don't broadcast it      --fees string                   Fees to pay along with transaction; eg: 10uatom
      --from string                   Name or address of private key with which to sign
      --gas string                    gas limit to set per-transaction; set to "auto" to calculate sufficient gas automatically (default 200000)
      --gas-adjustment float          adjustment factor to be multiplied against the estimate returned by the tx simulation; if the gas limit is set manually this flag is ignored  (default 1)
      --gas-prices string             Gas prices in decimal format to determine the transaction fee (e.g. 0.1uatom)
      --generate-only                 Build an unsigned transaction and write it to STDOUT (when enabled, the local Keybase is not accessible)
      --height int                    upgrade height
  -h, --help                          help for proposal-set-plan
      --instate-upgrade               instate upgrade flag (default true)
      --keyring-backend string        Select keyring's backend (os|file|kwallet|pass|test|memory) (default "os")
      --keyring-dir string            The client Keyring directory; if omitted, the default 'home' directory will be used
      --ledger                        Use a connected Ledger device
      --max-enrollment-duration int   max enrollment duration
      --memo string                   Memo to send along with transaction
      --min-upgrade-time int          min halt time
      --name string                   upgrade name (default "upgrade1")
      --new-chain-id string           new chain id
      --node string                   <host>:<port> to tendermint rpc interface for this chain (default "tcp://localhost:26657")
      --offline                       Offline mode (does not allow any online functionality
      --old-chain-id strin           old chain id
      --resources string              resource info (default "[]")
      --rollback-memo string          rollback memo
  -s, --sequence uint                 The sequence number of the signing account (offline mode only)
      --sign-mode string              Choose sign mode (direct|amino-json), this is an advanced feature
      --timeout-height uint           Set a block timeout height to prevent the tx from being committed past a certain height      --title string                  title
      --upgrade-memo string           upgrade memo
  -y, --yes                           Skip tx broadcasting prompt confirmation

Global Flags:
      --chain-id string     The network chain ID
      --home string         directory for config and data (default "/root/.sekaid")
      --log_format string   The logging format (json|plain) (default "plain")
      --log_level string    The logging level (trace|debug|info|warn|error|fatal|panic) (default "info")
      --trace               print out full stack trace on errors