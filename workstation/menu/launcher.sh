#!/usr/bin/env bash
ETC_PROFILE="/etc/profile" && set +e && source /etc/profile &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/menu/launcher.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

systemctl stop kirascan || echoWarn "WARNING: KIRA scan service could NOT be stopped"
systemctl stop kiraup || echoWarn "WARNING: KIRA update service could NOT be stopped"
systemctl stop kiraplan || echoWarn "WARNING: KIRA upgrade service could NOT be stopped"
systemctl stop kiraclean || echoWarn "WARNING: KIRA cleanup service could NOT be stopped"
sleep 1

timedatectl set-timezone "Etc/UTC" || ( echoErr "ERROR: Failed to set time zone to UTC, ensure to do that manually after setup is finalized!" && sleep 10 )

MNEMONICS="$KIRA_SECRETS/mnemonics.env" && touch $MNEMONICS

while :; do
    set -x
    
    NEW_NETWORK="$(globGet NEW_NETWORK)"
    if [ "$NEW_NETWORK" != "true" ] ; then
      $KIRA_MANAGER/menu/setup-refresh.sh
    fi

    IFACE=$(globGet IFACE)
    INFRA_MODE=$(globGet INFRA_MODE)
    CHAIN_ID="$(globGet TRUSTED_NODE_CHAIN_ID)"
    NEW_NETWORK_NAME="$(globGet NEW_NETWORK_NAME)"
    HEIGHT="$(globGet TRUSTED_NODE_HEIGHT)"
    NODE_ADDR="$(globGet TRUSTED_NODE_ADDR)"
    PRIVATE_MODE="$(globGet PRIVATE_MODE)"
    SEEDS_COUNT=$(wc -l < $PUBLIC_SEEDS || echo "0")
    [ -z "$CHAIN_ID" ] && CHAIN_ID="???"
    [ -z "$NEW_NETWORK_NAME" ] && NEW_NETWORK_NAME="???"
    (! $(isNaturalNumber "$HEIGHT")) && HEIGHT=0
    (! $(isNaturalNumber "$SEEDS_COUNT")) && SEEDS_COUNT=0

    TRUSTED_NODE_GENESIS_HASH="$(globGet TRUSTED_NODE_GENESIS_HASH)"
    TRUSTED_NODE_INTERX_PORT="$(globGet TRUSTED_NODE_INTERX_PORT)"
    TRUSTED_NODE_RPC_PORT="$(globGet TRUSTED_NODE_RPC_PORT)"
    TRUSTED_NODE_SNAP_SIZE="$(globGet TRUSTED_NODE_SNAP_SIZE)"
    (! $(isNaturalNumber "$TRUSTED_NODE_SNAP_SIZE")) && TRUSTED_NODE_SNAP_SIZE=0

    SNAPSHOT_FILE=$(globGet SNAPSHOT_FILE)
    SNAPSHOT_FILE_HASH=$(globGet SNAPSHOT_FILE_HASH)
    SNAPSHOT_CHAIN_ID=$(globGet SNAPSHOT_CHAIN_ID)
    SNAPSHOT_GENESIS_HASH=$(globGet SNAPSHOT_GENESIS_HASH)
    SNAPSHOT_HEIGHT=$(globGet SNAPSHOT_HEIGHT)
    SNAPSHOT_SYNC=$(globGet SNAPSHOT_SYNC)
    SNAPSHOT_CORRUPTED=$(globGet SNAPSHOT_CORRUPTED)
    (! $(isNaturalNumber "$SNAPSHOT_HEIGHT")) && SNAPSHOT_HEIGHT=0

    [ "$NODE_ADDR" == "0.0.0.0" ] && REINITALIZE_NODE="true" || REINITALIZE_NODE="false"
    if (! $(isDnsOrIp "$NODE_ADDR")) ; then
      NODE_ADDR="???.???.???.???"
      CHAIN_ID="???"
      HEIGHT="0"
    elif [ "$NODE_ADDR" != "0.0.0.0" ] ; then
      ($(isPort "$TRUSTED_NODE_INTERX_PORT")) && NODE_ADDR="${NODE_ADDR}:${TRUSTED_NODE_INTERX_PORT}" || \
       ( ($(isPort "$TRUSTED_NODE_RPC_PORT")) && NODE_ADDR="${NODE_ADDR}:${TRUSTED_NODE_RPC_PORT}" )
    fi

    echoInfo "INFO: Public & Local IP discovery..."
    PUBLIC_IP=$(timeout 10 bash -c ". /etc/profile && getPublicIp" 2> /dev/null || echo "")
    LOCAL_IP=$(timeout 10 bash -c ". /etc/profile && getLocalIp '$IFACE'" 2> /dev/null || echo "")
    (! $(isDnsOrIp "$PUBLIC_IP")) && PUBLIC_IP="???.???.???.???"
    (! $(isDnsOrIp "$LOCAL_IP")) && LOCAL_IP="???.???.???.???"
    
    set +x
    MASTER_MNEMONIC="$(tryGetVar MASTER_MNEMONIC "$MNEMONICS")"
    ($(isMnemonic "$MASTER_MNEMONIC")) && MNEMONIC_SAVED="true" || MNEMONIC_SAVED="false"
    MASTER_MNEMONIC=""
    set -x
    NODE_ID=$(tryGetVar "$(toUpper "$INFRA_MODE")_NODE_ID" "$MNEMONICS")
    (! $(isNodeId "$NODE_ID")) && NODE_ID="???...???"

    SSH_PORT=$(strFixC "$(globGet DEFAULT_SSH_PORT)" 11)
    P2P_PORT=$(strFixC "$(globGet CUSTOM_P2P_PORT)" 12)
    RPC_PORT=$(strFixC "$(globGet CUSTOM_RPC_PORT)" 12)
    GRPC_PORT=$(strFixC "$(globGet CUSTOM_GRPC_PORT)" 12)
    PRTH_PORT=$(strFixC "$(globGet CUSTOM_PROMETHEUS_PORT)" 12)
    INEX_PORT=$(strFixC "$(globGet CUSTOM_INTERX_PORT)" 14)
    EXPOSURE="local network exposure" 
    LMODE="join '$CHAIN_ID' network" 
    [ "$PRIVATE_MODE" == "false" ] && EXPOSURE="public network exposure"
    if [ "$NEW_NETWORK" == "true" ] ; then
      LMODE="create new test network"
      HEIGHT="0"
    fi

    if [ "$SNAPSHOT_CORRUPTED" == "true" ] ; then
      SNAPINFO_DISPLAY="unknown or corrupted snap. file"
    else
      if [ "$SNAPSHOT_SYNC" == "true" ] ; then
        SNAPINFO_DISPLAY="snapshot sync is ENABLED" 
      else
        SNAPINFO_DISPLAY="snapshot sync is DISABLED"
      fi
    fi

    SNAP_SIZE=$(globGet TRUSTED_NODE_SNAP_SIZE)
    DOCKER_SUBNET="$(globGet KIRA_DOCKER_SUBNET)"
    DOCKER_NETWORK="$(globGet KIRA_DOCKER_NETWORK)"
    FIREWALL_ENABLED="$(globGet FIREWALL_ENABLED)"

    set +x && printf "\033c" && clear
    opselM="m" && opselM="n" && opselT="t" && opselD="d" && opselS="s" && opselL="l"
    startCol="gre" && selACol="whi"
    echoC ";whi" " =============================================================================="
 echoC "sto;whi" "|$(echoC "res;gre" "$(strFixC "$(toUpper $INFRA_MODE) NODE LAUNCHER, KM $KIRA_SETUP_VER" 78)")|"
 echoC "sto;whi" "|$(echoC "res;bla" "$(strFixC " $(date '+%d/%m/%Y %H:%M:%S') " 78 "." "-")")|"
    echoC ";whi" "|  SSH PORT |  P2P PORT  |  RPC PORT  |  GRPC PORT | PROMETHEUS | INTERX (API) |"
    echoC ";whi" "|$SSH_PORT|$P2P_PORT|$RPC_PORT|$GRPC_PORT|$PRTH_PORT|$INEX_PORT|"
    if [ "$NEW_NETWORK" == "false" ] && [ "$REINITALIZE_NODE" != "true" ] && [ $HEIGHT -le 0 ] ; then
 echoC "sto;whi" "|$(echoC "res;red" "$(strFixC " NETWORK NOT FOUND, CHANGE TRUSTED SEED ADDRESS " 78 "." "-")")|"
 startCol="bla" && opselS="r" && selACol="red" 
    elif [ "$NEW_NETWORK" != "true" ] && (! $(isSHA256 "$TRUSTED_NODE_GENESIS_HASH")) ; then
 echoC "sto;whi" "|$(echoC "res;red" "$(strFixC " GENESIS FILE NOT FOUND, CHANGE TRUSTED SEED OR PROVIDE SOURCE " 78 "." "-")")|"
 startCol="bla" && opselS="r"
    elif [ "$MNEMONIC_SAVED" == "false" ] ; then
 echoC "sto;whi" "|$(echoC "res;red" "$(strFixC " MASTER MNEMONIC IS NOT DEFINED " 78 "." "-")")|"
 startCol="bla" && opselS="r"
    elif [ "$NEW_NETWORK" != "true" ] && [[ $SEEDS_COUNT -le 0 ]] && [ "$REINITALIZE_NODE" != "true" ] ; then
 echoC "sto;whi" "|$(echoC "res;red" "$(strFixC " P2P NODES NOT FOUND, CHANGE TRUSTED SEED ADDRESS " 78 "." "-")")|"
 startCol="bla" && opselS="r"
    elif [ "$SNAPSHOT_CORRUPTED" != "true" ] && [ "$SNAPSHOT_SYNC" == "true" ] && [[ $HEIGHT -lt $SNAPSHOT_HEIGHT ]] ; then
 echoC "sto;whi" "|$(echoC "res;red" "$(strFixC " TRUSTED NODE IS $((SNAPSHOT_HEIGHT - HEIGHT)) BLOCKS BEHIND SNAPSHOT " 78 "." "-")")|"
    else
      if [ "$NEW_NETWORK" == "false" ] ; then
 echoC "sto;whi" "|$(echoC "res;gre" "$(strFixC " PRESS [S]TART TO JOIN '$CHAIN_ID' NETWORK AT BLOCK $HEIGHT " 78 "." "-")")|"

        [[ $SEEDS_COUNT -le 8 ]] && [ "$REINITALIZE_NODE" != "true" ]
 echoC "sto;whi" "|$(echoC "res;yel" "$(strFixC " WARNING! ONLY $SEEDS_COUNT SEED P2P NODES WERE FOUND " 78 "." "-")")|"
      else
 echoC "sto;whi" "|$(echoC "res;gre" "$(strFixC " PRESS [S]TART TO CREATE NEW '$NEW_NETWORK_NAME' NETWORK " 78 "." "-")")|"
      fi
    fi

    [ "$FIREWALL_ENABLED" == "false" ] && \
      echoC "sto;whi" "|$(echoC "res;yel" "$(strFixC " WARNING! FIREWALL DISABLED " 78 "." "-")")|"
  
    (! $(isNodeId "$NODE_ID")) && col="red" || col="whi"
 echoC "sto;whi" "|$(echoC "res;$col" " $(strFixR "${INFRA_MODE^} Node ID" 19): $(strFixL "$NODE_ID" 55) ")|"
      echoC ";whi" "|   Secrets Direcotry: $(strFixL "$KIRA_SECRETS" 55) |"

    if [ "$NEW_NETWORK" != "true" ] ; then
      echoC ";whi" "| Snapshots Direcotry: $(strFixL "$KIRA_SNAP" 55) |"

      if [ "$SNAPSHOT_CORRUPTED" != "true" ] && [ "$SNAPSHOT_SYNC" == "true" ] ; then
        echoC ";whi" "|       Snapshot File: $(strFixL "$(basename $SNAPSHOT_FILE)" 40) $(strFixR "$(prettyBytes "$(fileSize "$SNAPSHOT_FILE")")" 14) |"
        echoC ";whi" "|  Snapshots Checksum: $(strFixL "$SNAPSHOT_FILE_HASH" 55) |"
      fi

      ($(isSHA256 "$TRUSTED_NODE_GENESIS_HASH")) && \
                                   echoC ";whi" "|        Genesis Hash: $(strFixL "$TRUSTED_NODE_GENESIS_HASH" 55) |"
    else
      echoC ";whi" "|   Base Image Source: $(strFixL "$(globGet NEW_BASE_IMAGE_SRC)" 55) |"
      echoC ";whi" "|  KIRA Manger Source: $(strFixL "$(globGet INFRA_SRC)" 55) |"
    fi

    echoC "sto;whi" "|$(echoC "res;bla" "----------- SELECT OPTION -----------:------------- CURRENT VALUE ------------")|"

    [ "$MNEMONIC_SAVED" == "true" ] && \
                       echoC ";whi" "| [M] | Modify Master Mnemonic        : $(strFixL "" 39)|" ||
    echoC ";whi" "| $(echoC "res;red" "[M] | Set or Gen. Master Mnemonic   : $(strFixL "" 39)")|"
    echoC ";whi" "| [N] | Modify Networking Config.     : $(strFixL "$IFACE, $DOCKER_NETWORK, $DOCKER_SUBNET" 39)|"
    [ "$NEW_NETWORK" != "true" ] && \
      echoC ";whi" "| [T] | Switch to Diffrent Node Type  : $(strFixL "$INFRA_MODE node" 39)|" || \
      opselT="r"

    [ "$PRIVATE_MODE" == "true" ] && \
    echoC ";whi" "| [E] | Expose Node to Public Netw.   : $(strFixL "expose as $LOCAL_IP to LOCAL" 39)|" || \
    echoC ";whi" "| [E] | Expose Node to Local Networks : $(strFixL "expose as $PUBLIC_IP to PUBLIC" 39)|"

    [ "$NEW_NETWORK" != "true" ] && \
      echoC ";whi" "| [D] | Download or Select Snapshot   : $(strFixL "$SNAPINFO_DISPLAY" 39)|" || \
      opselD="d"

    if [ "$INFRA_MODE" == "validator" ] ; then
      if [ "$NEW_NETWORK" == "true" ] ; then
        echoC ";whi" "| [J] | Join Existing Network         : $(strFixL "launch your own testnet" 39)|"
        opselL="j"
      else
        echoC ";whi" "| [L] | Launch New Local Testnet      : $(strFixL "join existing public network" 39)|"
        opselL="l"
      fi
    fi
    [ "$NEW_NETWORK" == "true" ] && \
                            echoC ";whi" "| [A] | Modify Network Name           : $(strFixL "$NEW_NETWORK_NAME" 39)|" || \
 echoC "sto;whi" "| $(echoC "res;$selACol" "[A] | Modify Trusted Node Address   : $(strFixL "$NODE_ADDR" 39)")|"
  echoC "sto;whi" "|$(echoC "res;bla" "------------------------------------------------------------------------------")|"

  echoC "sto;whi" "| $(echoC "res;$startCol" "$(strFixL "[S] | Start Setup" 36)")| [R] Refresh      | [X] Abort Setup     |"
    echoNC ";whi" " ------------------------------------------------------------------------------"
    setterm -cursor off && pressToContinue m n "$opselT" e "$opselD" "$opselL" a "$opselS" r x && setterm -cursor on
    KEY=$(globGet OPTION)
    KEY="$(toLower "$KEY")" && [ "${KEY}" == "j" ] && KEY="l"

  case ${KEY} in
  s*)
    $KIRA_MANAGER/menu/quick-select.sh
    break
    ;;
  m*)
    $KIRA_MANAGER/menu/mnemonic-select.sh
    ;;
  n*)
    $KIRA_MANAGER/menu/ports-select.sh
    ;;
  t*)
    $KIRA_MANAGER/menu/node-type-select.sh
    ;;
  e*)
    [ "$PRIVATE_MODE" == "true" ] && globSet PRIVATE_MODE "false" || globSet PRIVATE_MODE "true"
    ;;
  d*)
    $KIRA_MANAGER/menu/snap-select.sh
    ;;
  l*)
    [ "$INFRA_MODE" != "validator" ] && continue
    if [ "$NEW_NETWORK" == "true" ] ; then
      globSet NEW_NETWORK "false" 
    else
      globSet NEW_NETWORK "true"
      globSet NEW_NETWORK_NAME "localnet-$((RANDOM % 999 + 1))"
    fi
   ;;
   a*)
      if [ "$(globGet NEW_NETWORK)" == "true" ] ; then
        $KIRA_MANAGER/menu/chain-id-select.sh
      else
        $KIRA_MANAGER/menu/trusted-node-select.sh
      fi
   ;;
  x*)
    exit 0
    ;;
  r*)
    echoInfo "INFO: Refreshing status..."
    sleep 1
    continue
    ;;
  *)
    echoInfo "INFO: Refreshing status..."
    sleep 1
    continue
    ;;
  esac
done
set -x

exit 0
