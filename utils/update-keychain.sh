#!/usr/bin/env bash
set -euo pipefail

# auto-update-keychain.sh
# Fetch TLS chains for a set of hosts, extract corporate CA/intermediate certs,
# and install any missing certs into the macOS System keychain.
#
# Designed to be idempotent and safe: it only installs certificates that appear
# to be CA certs (Basic Constraints CA:TRUE or self-signed) and deduplicates by
# SHA256 fingerprint. It uses a single macOS GUI auth prompt (osascript) to
# perform the installs so you won't be prompted repeatedly.

DEFAULT_HOSTS=(github.com raw.githubusercontent.com ghcr.io registry.npmjs.org registry.yarnpkg.com nodejs.org npmjs.com models.dev)
OUTDIR_DEFAULT="$HOME/theoven/.devcontainer/cacerts"
CORP_PATTERN="${CORP_PATTERN:-Costco}"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This script runs only on macOS." >&2
  exit 2
fi

HOSTS=("${DEFAULT_HOSTS[@]}")

echo "[auto-update-keychain] checking hosts: ${HOSTS[*]}"

# fetch system keychain fingerprints
SYS_PEM="$TMPDIR/system.pem"
security find-certificate -a -p /Library/Keychains/System.keychain /System/Library/Keychains/SystemRootCertificates.keychain > "$SYS_PEM" 2>/dev/null || true
REPO_SYS_DIR="$TMPDIR/system-certs"
mkdir -p "$REPO_SYS_DIR"
awk -v outdir="$REPO_SYS_DIR" '/-----BEGIN CERTIFICATE-----/{flag=1; out=sprintf("%s/sys-%03d.crt", outdir, ++n)} flag{print > out} /-----END CERTIFICATE-----/{flag=0}' "$SYS_PEM"
SYS_FP_FILE="$TMPDIR/system-fps.txt"
: > "$SYS_FP_FILE"
for s in "$REPO_SYS_DIR"/*.crt; do
  [[ -f "$s" ]] || continue
  openssl x509 -in "$s" -noout -fingerprint -sha256 2>/dev/null | sed 's/SHA256 Fingerprint=//; s/://g' >> "$SYS_FP_FILE"
done

# collect candidate certs from remote chains
FETCHED_DIR="$TMPDIR/fetched"
mkdir -p "$FETCHED_DIR"
SEEN_FPS="$TMPDIR/seen-fps.txt"
: > "$SEEN_FPS"

for h in "${HOSTS[@]}"; do
  echo "[auto-update-keychain] fetching chain from $h:443"
  CHAIN_FILE="$TMPDIR/chain-${h}.txt"
  openssl s_client -showcerts -servername "$h" -connect "$h:443" </dev/null 2>/dev/null > "$CHAIN_FILE" || true
  if ! grep -q "BEGIN CERTIFICATE" "$CHAIN_FILE" 2>/dev/null; then
    echo "  -> no certs for $h (skipping)"
    continue
  fi
  HOST_DIR="$FETCHED_DIR/$h"
  mkdir -p "$HOST_DIR"
  awk -v outdir="$HOST_DIR" '/-----BEGIN CERTIFICATE-----/{flag=1; out=sprintf("%s/cert-%03d.pem", outdir, ++n)} flag{print > out} /-----END CERTIFICATE-----/{flag=0}' "$CHAIN_FILE"
  for p in "$HOST_DIR"/*.pem; do
    [[ -f "$p" ]] || continue
    # determine if cert is CA (basicConstraints CA:TRUE or self-signed)
    is_ca=0
    if openssl x509 -in "$p" -noout -text 2>/dev/null | grep -q "CA:TRUE"; then
      is_ca=1
    fi
    subj=$(openssl x509 -in "$p" -noout -subject 2>/dev/null || true)
    issuer=$(openssl x509 -in "$p" -noout -issuer 2>/dev/null || true)
    if [[ "$subj" == "$issuer" ]]; then
      is_ca=1
    fi
    if [[ $is_ca -ne 1 ]]; then
      # skip leaf certs
      continue
    fi
    fp=$(openssl x509 -in "$p" -noout -fingerprint -sha256 2>/dev/null | sed 's/SHA256 Fingerprint=//; s/://g')
    if [[ -z "$fp" ]]; then
      continue
    fi
    if grep -q "^$fp\b" "$SEEN_FPS" 2>/dev/null; then
      continue
    fi
    echo -e "$fp\t$p" >> "$SEEN_FPS"
  done
done

# decide which fetched certs are missing from system keychain
MISSING_DIR="$TMPDIR/missing"
mkdir -p "$MISSING_DIR"
MISSING_LIST=()
while IFS=$'\t' read -r fp path; do
  if ! grep -q "$fp" "$SYS_FP_FILE" 2>/dev/null; then
    # only consider certs matching corp pattern (subject contains pattern)
    subj=$(openssl x509 -in "$path" -noout -subject 2>/dev/null || true)
    if echo "$subj" | grep -qi "$CORP_PATTERN"; then
      base=$(basename "$path")
      dest="$MISSING_DIR/${base}"
      cp "$path" "$dest"
      MISSING_LIST+=("$dest")
    fi
  fi
done < "$SEEN_FPS"

if [[ ${#MISSING_LIST[@]} -eq 0 ]]; then
  echo "[auto-update-keychain] no missing corporate CA certs to install"
  exit 0
fi

echo "[auto-update-keychain] found ${#MISSING_LIST[@]} missing corp CA cert(s)"
for c in "${MISSING_LIST[@]}"; do
  openssl x509 -in "$c" -noout -subject -issuer -fingerprint -sha256 | sed -n '1,2p'
done

# create installer script that runs all security commands so we get one auth prompt
INSTALL_SCRIPT="$TMPDIR/install-certs.sh"
printf '#!/bin/bash\nset -euo pipefail\n' > "$INSTALL_SCRIPT"
for c in "${MISSING_LIST[@]}"; do
  printf 'security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain %q\n' "$c" >> "$INSTALL_SCRIPT"
done
chmod +x "$INSTALL_SCRIPT"

echo "[auto-update-keychain] requesting authorization to install certs into System keychain"
if osascript -e "do shell script \"$INSTALL_SCRIPT\" with administrator privileges"; then
  echo "[auto-update-keychain] installed missing certs"
  # optionally copy installed certs into repo cacerts for traceability
  if [[ -d "$OUTDIR_DEFAULT" ]]; then
    ts=$(date +%Y%m%d%H%M%S)
    dstdir="$OUTDIR_DEFAULT/fetched-$ts"
    mkdir -p "$dstdir"
    for c in "${MISSING_LIST[@]}"; do cp "$c" "$dstdir/"; done
    echo "[auto-update-keychain] copied installed certs to $dstdir"
  fi
else
  echo "[auto-update-keychain] authorization failed or cancelled; certs not installed" >&2
  echo "You can manually install the certs with: sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain <cert-file>" >&2
  exit 1
fi

exit 0
