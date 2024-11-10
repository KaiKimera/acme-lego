#!/usr/bin/env -S bash -eu
# -------------------------------------------------------------------------------------------------------------------- #
# ACME: CERTIFICATE
#
# @package    Bash
# @author     Yuri Dunaev
# @license    MIT
# @version    0.1.0
# @link       https://fdn.im
# -------------------------------------------------------------------------------------------------------------------- #

# (( EUID != 0 )) && { echo >&2 'This script should be run as root!'; exit 1; }

# Sources.
SRC_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd -P )"; readonly SRC_DIR # Script directory.
SRC_NAME="$(basename "$(readlink -f "${BASH_SOURCE[0]}")")"; readonly SRC_NAME # Script name.
SRC_DOMAIN="${1:?}"; readonly SRC_DOMAIN # Domain name.
. "${SRC_DIR}/${SRC_NAME%.*}.conf" # Loading main configuration file.
. "${SRC_DIR}/${SRC_NAME%.*}.${SRC_DOMAIN}.conf" # Loading domain configuration file.

# Environment variables.
export LEGO_SERVER="${ACME_SERVER:?}"
export LEGO_PFX_PASSWORD="${ACME_PFX_PASSWORD:?}"
export LEGO_PFX_FORMAT="${ACME_PFX_FORMAT:?}"

# Parameters.
ACME_ACTION="${2:?}"; readonly ACME_ACTION
ACME_EMAIL="${ACME_EMAIL:?}"; readonly ACME_EMAIL
ACME_KEY_TYPE="${ACME_KEY_TYPE:?}"; readonly ACME_KEY_TYPE
ACME_WEB_ROOT="${ACME_WEB_ROOT:?}"; readonly ACME_WEB_ROOT
ACME_TYPE="${ACME_TYPE:?}"; readonly ACME_TYPE
ACME_DNS="${ACME_DNS:?}"; readonly ACME_DNS
ACME_DOMAINS=("${ACME_DOMAINS[@]:?}"); readonly ACME_DOMAINS

# -------------------------------------------------------------------------------------------------------------------- #
# INITIALIZATION
# -------------------------------------------------------------------------------------------------------------------- #

run() { lego "${ACME_ACTION}"; }

# -------------------------------------------------------------------------------------------------------------------- #
# ACME
# -------------------------------------------------------------------------------------------------------------------- #

lego() {
  local params; params=("--key-type ${ACME_KEY_TYPE}" "--email ${ACME_EMAIL}" '--pem' '--pfx')
  local action; action="${1}"

  if [[ "${ACME_TYPE}" == "http" ]]; then
    params+=('--http')
    [[ -n "${ACME_WEB_ROOT}" ]] && params+=("--http.webroot ${ACME_WEB_ROOT}")
  else
    params+=("--dns ${ACME_DNS}")
  fi

  for i in "${ACME_DOMAINS[@]}"; do params+=("--domains ${i}"); done

  local cert_path
  cert_path=("${LEGO_CERT_PATH}" "${LEGO_CERT_KEY_PATH}" "${LEGO_CERT_PEM_PATH}" "${LEGO_CERT_PFX_PATH}")

  if "${SRC_DIR}/lego" ${params[*]} "${action}"; then
    if mv "${cert_path[@]}" "${ACME_PATH}"; then
      for i in "${ACME_SERVICES[@]}"; do
        _service "${i}" && systemctl reload "${i}"
      done
    fi
  fi
}

# -------------------------------------------------------------------------------------------------------------------- #
# ------------------------------------------------< COMMON FUNCTIONS >------------------------------------------------ #
# -------------------------------------------------------------------------------------------------------------------- #

_service() {
  local s; s="${1}"
  { systemctl list-units --full -all | grep -Fq "${s}"; } && return 0
  return 1
}

# -------------------------------------------------------------------------------------------------------------------- #
# -------------------------------------------------< RUNNING SCRIPT >------------------------------------------------- #
# -------------------------------------------------------------------------------------------------------------------- #

run && exit 0 || exit 1
