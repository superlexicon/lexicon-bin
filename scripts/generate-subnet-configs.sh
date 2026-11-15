#!/usr/bin/env bash
# =============================================================================
# generate-subnet-configs.sh
#
# Turnkey multi-validator subnet configuration generator for `lexicon-node`.
# Generates Ed25519/secp256k1 node keypairs for N validators (and 1 Roamer),
# populates identical `p2p.initial_validators` and `p2p.validator_peer_mappings`
# across all nodes, and emits ready-to-deploy `config.json` and `systemd` unit
# files for each node in the subnet.
#
# Usage:
#   bash scripts/generate-subnet-configs.sh [NUM_VALIDATORS=4] [OUT_DIR=./subnet-bundle] [TRANSPORT=Flrc|Libp2p]
# =============================================================================
set -euo pipefail

NUM_VALIDATORS="${1:-4}"
OUT_DIR="${2:-./subnet-bundle}"
TRANSPORT="${3:-Flrc}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ -x "$REPO_ROOT/bin/lexicon-node" ]]; then
  LEXICON_BIN="$REPO_ROOT/bin/lexicon-node"
elif command -v lexicon-node >/dev/null 2>&1; then
  LEXICON_BIN="$(command -v lexicon-node)"
else
  echo "Error: lexicon-node binary not found in $REPO_ROOT/bin/lexicon-node or PATH" >&2
  exit 1
fi

if [[ "$TRANSPORT" != "Flrc" && "$TRANSPORT" != "Libp2p" ]]; then
  echo "Error: TRANSPORT must be 'Flrc' or 'Libp2p' (got '$TRANSPORT')" >&2
  exit 1
fi

LR2021_ENABLED="true"
if [[ "$TRANSPORT" == "Libp2p" ]]; then
  LR2021_ENABLED="false"
fi

mkdir -p "$OUT_DIR"

declare -a PUB_KEYS=()
declare -a PRIV_KEYS=()
declare -a PEER_IDS=()

echo "==> Generating $NUM_VALIDATORS validator identities using $LEXICON_BIN..."

for ((i = 1; i <= NUM_VALIDATORS; i++)); do
  NODE_DIR="$OUT_DIR/validator-$i"
  mkdir -p "$NODE_DIR"
  KEY_FILE="$NODE_DIR/node.key"

  OUT="$("$LEXICON_BIN" generate-key "$KEY_FILE")"
  PEER_ID="$(echo "$OUT" | awk '/Peer ID:/ {print $3}')"
  PUB_HEX="$(echo "$OUT" | awk '/Public key \(hex\):/ {print $4}')"
  PRIV_HEX="$(echo "$OUT" | awk '/Private key \(hex\):/ {print $4}')"

  PEER_IDS+=("$PEER_ID")
  PUB_KEYS+=("$PUB_HEX")
  PRIV_KEYS+=("$PRIV_HEX")
  echo "  [validator-$i] PeerID=$PEER_ID  PubKey=${PUB_HEX:0:16}..."
done

# Build JSON array for `initial_validators` and JSON object for `validator_peer_mappings`
INITIAL_VALIDATORS_JSON="["
PEER_MAPPINGS_JSON="{"
for ((i = 0; i < NUM_VALIDATORS; i++)); do
  COMMA=","
  if ((i == NUM_VALIDATORS - 1)); then
    COMMA=""
  fi
  INITIAL_VALIDATORS_JSON="${INITIAL_VALIDATORS_JSON}
      \"${PUB_KEYS[$i]}\"${COMMA}"
  PEER_MAPPINGS_JSON="${PEER_MAPPINGS_JSON}
      \"${PUB_KEYS[$i]}\": \"${PEER_IDS[$i]}\"${COMMA}"
done
INITIAL_VALIDATORS_JSON="${INITIAL_VALIDATORS_JSON}
    ]"
PEER_MAPPINGS_JSON="${PEER_MAPPINGS_JSON}
    }"

# Emit per-validator `config.json` and `lexicon-node.service`
for ((i = 1; i <= NUM_VALIDATORS; i++)); do
  idx=$((i - 1))
  NODE_DIR="$OUT_DIR/validator-$i"

  cat > "$NODE_DIR/config.json" <<EOF
{
  "app_name": "SuperLexicon-Subnet-Validator-$i",
  "version": "1.0.0",
  "server": {
    "host": "0.0.0.0",
    "port": 8080,
    "max_connections": 100
  },
  "database": {
    "consensus_db_path": "consensus.db",
    "pruning": {
      "size_limit_mb": 4096,
      "keep_recent_blocks": 500
    }
  },
  "logging": {
    "level": "info",
    "file": "app.log"
  },
  "features": {
    "enable_metrics": true,
    "enable_cache": true,
    "cache_ttl_seconds": 3600
  },
  "p2p": {
    "listen_address": "0.0.0.0",
    "listen_port": 30303,
    "max_peers": 50,
    "min_peers": 1,
    "bootstrap_nodes": [],
    "network_id": 1337,
    "protocol_version": 66,
    "discovery_enabled": true,
    "mdns_enabled": false,
    "discv5_enabled": false,
    "connection_retry_delay_ms": 5000,
    "max_connection_attempts": 5,
    "bootstrap_interval_seconds": 30,
    "idle_connection_timeout_seconds": 10,
    "kademlia_enabled": false,
    "kademlia_protocol": "/superlexicon/kad/1.0.0",
    "initial_validators": $INITIAL_VALIDATORS_JSON,
    "validator_peer_mappings": $PEER_MAPPINGS_JSON,
    "private_key": "${PRIV_KEYS[$idx]}"
  },
  "api": {
    "jsonrpc": {
      "enabled": true,
      "host": "0.0.0.0",
      "port": 8545,
      "max_connections": 100,
      "cors_enabled": true,
      "allowed_origins": ["*"]
    },
    "graphql": {
      "enabled": true,
      "host": "127.0.0.1",
      "port": 8547,
      "playground": true,
      "max_complexity": 100,
      "max_depth": 15
    },
    "grpc": {
      "enabled": true,
      "host": "127.0.0.1",
      "port": 50051,
      "reflection": true,
      "tls_enabled": false,
      "cert_path": null,
      "key_path": null
    },
    "websocket": {
      "enabled": true,
      "host": "0.0.0.0",
      "port": 8546,
      "max_connections": 100
    }
  },
  "genesis": {
    "transport_selection": {
      "peer_exchange": "$TRANSPORT",
      "transaction": "$TRANSPORT",
      "block_proposal": "$TRANSPORT",
      "final_block": "$TRANSPORT",
      "receipt": "$TRANSPORT",
      "contract_state": "$TRANSPORT",
      "db_sync": "$TRANSPORT",
      "bytecode_sync": "$TRANSPORT",
      "role_proposal": "$TRANSPORT",
      "finalized_role": "$TRANSPORT"
    },
    "validator_promotion_threshold": 100,
    "block_gas_limit": 100000000,
    "max_transaction_gas_limit": 10000000,
    "max_bytecode_size": 100000,
    "max_constructor_args_size": 32768,
    "max_nonce_gap": 32,
    "max_txs_per_origin_node": 100,
    "reputation_account_threshold": -100,
    "reputation_node_threshold": -1000,
    "reputation_success_delta": 1,
    "reputation_failure_delta": 1,
    "reputation_blacklist_enabled": true,
    "block_interval_ms": 1000,
    "pre_phase1_ms": 100,
    "consensus_phase1_ms": 8000,
    "pre_phase2_ms": 200,
    "consensus_phase2_ms": 4000,
    "pre_phase3_ms": 200,
    "consensus_phase3_ms": 5000,
    "pre_phase4_ms": 200,
    "consensus_phase4_ms": 4000,
    "timestamp": 0,
    "chain_id": 1337,
    "contract_creation_gas_per_byte": 1,
    "max_parallel_execution_groups": 8,
    "mempool_exchange_timeout_ms": 10000,
    "block_proposal_timeout_ms": 15000,
    "insufficient_participation_timeout_ms": 30000,
    "post_byzantine_mempool_timeout_ms": 3000,
    "post_byzantine_proposal_timeout_ms": 2000,
    "network_thread_pool_size": 4,
    "network_thread_replicas_size": 3,
    "threadpool_consensus_threshold_percentage": 0.67
  },
  "lr2021": {
    "enabled": $LR2021_ENABLED,
    "serial_port": "/dev/ttyACM0",
    "baud_rate": 115200,
    "frequency_hz": 867100000,
    "bandwidth_hz": 1200000,
    "coding_rate": 1,
    "tx_power_dbm": 22,
    "sync_word": "0x12345690",
    "tx_ingress_mode": "rpc",
    "client_radio": null
  }
}
EOF

  cat > "$NODE_DIR/lexicon-node.service" <<EOF
[Unit]
Description=Lexicon Subnet Validator Node ($i)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$USER
WorkingDirectory=/opt/lexicon
ExecStart=/usr/local/bin/lexicon-node --config /opt/lexicon/config.json
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
done

# Also generate a Roamer / Observer node config (`roamer-1`)
ROAMER_DIR="$OUT_DIR/roamer-1"
mkdir -p "$ROAMER_DIR"
ROAMER_OUT="$("$LEXICON_BIN" generate-key "$ROAMER_DIR/node.key")"
ROAMER_PRIV="$(echo "$ROAMER_OUT" | awk '/Private key \(hex\):/ {print $4}')"
ROAMER_PEER="$(echo "$ROAMER_OUT" | awk '/Peer ID:/ {print $3}')"
cp "$OUT_DIR/validator-1/config.json" "$ROAMER_DIR/config.json"
sed -i "s/\"SuperLexicon-Subnet-Validator-1\"/\"SuperLexicon-Roamer-1\"/" "$ROAMER_DIR/config.json"
sed -i "s/\"private_key\": \"${PRIV_KEYS[0]}\"/\"private_key\": \"${ROAMER_PRIV}\"/" "$ROAMER_DIR/config.json"
echo "  [roamer-1]    PeerID=$ROAMER_PEER"

echo ""
echo "==> Subnet configuration bundle generated in: $OUT_DIR"
echo "    - Validators : $OUT_DIR/validator-1 .. $OUT_DIR/validator-$NUM_VALIDATORS"
echo "    - Roamer     : $OUT_DIR/roamer-1"
echo "    - Transport  : $TRANSPORT"
