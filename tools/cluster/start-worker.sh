#!/usr/bin/env bash
# Lends this computer's memory to a PrivateLM cluster (Linux, macOS).
#
# Put this file in the folder of the llama.cpp release named in the app
# (Phone cluster > Add a computer), next to ggml-rpc-server, then run:
#
#     ./start-worker.sh          # port 50052
#     ./start-worker.sh 50060    # another port
#
# The connection has no password: only run it on a network you trust.
set -euo pipefail

PORT="${1:-50052}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SERVER=""
for candidate in \
    "$DIR/ggml-rpc-server" \
    "$DIR/bin/ggml-rpc-server" \
    "$DIR/build/bin/ggml-rpc-server" \
    "$(command -v ggml-rpc-server 2>/dev/null || true)"; do
  if [ -n "$candidate" ] && [ -x "$candidate" ]; then
    SERVER="$candidate"
    break
  fi
done
if [ -z "$SERVER" ]; then
  echo "ggml-rpc-server introuvable." >&2
  echo "Placez ce script dans le dossier de llama.cpp (la version indiquée par" >&2
  echo "l'application), à côté de ggml-rpc-server, puis relancez-le." >&2
  exit 1
fi

# The addresses phones on the same network can use.
if command -v ip >/dev/null 2>&1; then
  ADDRESSES="$(ip -4 -o addr show scope global 2>/dev/null | awk '{print $4}' | cut -d/ -f1 || true)"
else
  ADDRESSES="$(ifconfig 2>/dev/null | awk '/inet /{print $2}' | grep -v '^127\.' || true)"
fi

echo "PrivateLM : cet ordinateur rejoint le cluster."
echo
if [ -n "$ADDRESSES" ]; then
  echo "Dans l'application : Cluster de téléphones > Principal > Ajouter un ordinateur, puis saisissez :"
  for address in $ADDRESSES; do
    echo "    $address:$PORT"
  done
else
  echo "Aucune adresse réseau trouvée : vérifiez que l'ordinateur est connecté au Wi-Fi."
fi
echo
echo "Laissez cette fenêtre ouverte. Ctrl+C pour arrêter."
echo

# -c keeps the model's layers on disk, so they cross the Wi-Fi only once.
exec "$SERVER" -H 0.0.0.0 -p "$PORT" -c
