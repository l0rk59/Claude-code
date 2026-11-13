#!/usr/bin/env bash
# Runs a model on this computer for the phones of the network (Linux, macOS).
# The phones chat with it from PrivateLM; nothing leaves the network.
#
# Put this file in the folder of a llama.cpp release, next to llama-server,
# then run:
#
#     ./start-serveur.sh modele.gguf           # port 8080
#     ./start-serveur.sh modele.gguf 8081      # another port
#     ./start-serveur.sh modele.gguf 8080 --rpc 192.168.1.11:50052   # extra llama-server options
#
# With a single .gguf file in the folder, the model can be left out.
#
# The server asks for a key, made up on the first run and kept in
# .privatelm-cle next to this script: PrivateLM asks for it once. To choose
# it, set CLE (CLE=monsecret ./start-serveur.sh …); to run without one, set
# CLE=aucune. The key keeps out the other devices of the network; the
# traffic itself is not encrypted, so use a network you trust.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SERVER=""
for candidate in \
    "$DIR/llama-server" \
    "$DIR/bin/llama-server" \
    "$DIR/build/bin/llama-server" \
    "$(command -v llama-server 2>/dev/null || true)"; do
  if [ -n "$candidate" ] && [ -x "$candidate" ]; then
    SERVER="$candidate"
    break
  fi
done
if [ -z "$SERVER" ]; then
  echo "llama-server introuvable." >&2
  echo "Placez ce script dans le dossier de llama.cpp, à côté de llama-server," >&2
  echo "puis relancez-le." >&2
  exit 1
fi

MODEL="${1:-}"
if [ -z "$MODEL" ]; then
  # No model named: take the only one in the folder, if there is exactly one.
  shopt -s nullglob
  MODELS=("$DIR"/*.gguf)
  shopt -u nullglob
  if [ "${#MODELS[@]}" -eq 1 ]; then
    MODEL="${MODELS[0]}"
  else
    echo "Indiquez le fichier du modèle :  ./start-serveur.sh modele.gguf" >&2
    exit 1
  fi
else
  shift
fi
if [ ! -f "$MODEL" ]; then
  echo "Fichier de modèle introuvable : $MODEL" >&2
  exit 1
fi

PORT="8080"
if [ "$#" -gt 0 ] && [[ "$1" =~ ^[0-9]+$ ]]; then
  PORT="$1"
  shift
fi

# The addresses phones on the same network can use.
if command -v ip >/dev/null 2>&1; then
  ADDRESSES="$(ip -4 -o addr show scope global 2>/dev/null | awk '{print $4}' | cut -d/ -f1 || true)"
else
  ADDRESSES="$(ifconfig 2>/dev/null | awk '/inet /{print $2}' | grep -v '^127\.' || true)"
fi

KEY_FILE="$DIR/.privatelm-cle"
KEY="${CLE:-}"
if [ -z "$KEY" ]; then
  if [ ! -s "$KEY_FILE" ]; then
    # 16 random letters and digits, easy to type on a phone. (Reading a
    # fixed amount first: cutting /dev/urandom short would stop the script
    # under pipefail.)
    head -c 512 /dev/urandom | LC_ALL=C tr -dc 'a-z0-9' | cut -c1-16 > "$KEY_FILE"
    chmod 600 "$KEY_FILE"
  fi
  KEY="$(tr -d '[:space:]' < "$KEY_FILE")"
fi
KEY_ARGS=()
if [ "$KEY" != "aucune" ]; then
  KEY_ARGS=(--api-key "$KEY")
fi

echo "PrivateLM : cet ordinateur fait tourner $(basename "$MODEL")."
echo
echo "Dans l'application : Modèles > Cloud > Un ordinateur de votre réseau."
echo "La recherche le trouve seule. Sinon, saisissez son adresse :"
for address in $ADDRESSES; do
  echo "    $address:$PORT"
done
if [ "$KEY" != "aucune" ]; then
  echo
  echo "Clé à saisir dans l'application (une seule fois) :  $KEY"
fi
echo
echo "Laissez cette fenêtre ouverte. Ctrl+C pour arrêter."
echo

# (An empty array written this way also works with the bash of macOS.)
exec "$SERVER" -m "$MODEL" --host 0.0.0.0 --port "$PORT" ${KEY_ARGS[@]+"${KEY_ARGS[@]}"} "$@"
