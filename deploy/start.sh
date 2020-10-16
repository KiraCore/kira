#!/usr/local/bin/bash

set -e

clear

while :; do
  case "$1" in
  -d | --demo)
    title="Demo Mode (local testnet)"
    shift
    ;;
  -f | --full)
    title="Full Node Mode"
    shift
    ;;
  -v | --validator)
    title="Validator Mode"
    shift
    ;;
  -h | --help)
    display_help # Call your function
    # no shifting needed here, we're done.
    exit 0
    ;;
  --) # End of all options
    shift
    break
    ;;
  -*)
    echo "Error: Unknown option: $1" >&2
    exit 1
    ;;
  *) # No more options
    break
    ;;
  esac
done

chmod +x $KIRA_WORKDIR/utils.sh
source $KIRA_WORKDIR/utils.sh

printWidth=47
echo -e "-------------------------------------------------"
displayAlign center $printWidth "$title"
displayAlign center $printWidth "$(date '+%d/%m/%Y %H:%M:%S')"
echo -e "|-----------------------------------------------|"
echo "| [1] | Quick Setup                             |"
echo "| [2] | Advanced Setup                          |"
echo "|-----------------------------------------------|"
echo "| [X] | Exit | [B] | Go Back                    |"
echo -e "-------------------------------------------------"
