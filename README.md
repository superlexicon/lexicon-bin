# Lexicon Node (`lexicon-bin`)

Official prebuilt **`lexicon-node`** binary distribution for **Lexicon** — a deterministic, radio-defined, multi-proposer Byzantine Fault Tolerant (BFT) protocol executing **WebAssembly (`Wasmtime`) Haltproof Subroutines (HPS)** with zero token transaction fees across Semtech LR2021 FLRC broadcast radio subnets and standalone `--localtestnet` environments.

For authoring, unit-testing, compiling, optimizing, and deploying **Haltproof Subroutines (HPS)**, use the companion developer toolkit:
- **[`superlexicon/haltproof-subroutines`](https://github.com/superlexicon/haltproof-subroutines)** (`cargo hps`, `hps-sdk`, `hps-client`, and `ts-client/hps.mjs`)

---

## Contents

| Path | Description |
| :--- | :--- |
| `bin/lexicon-node` | Prebuilt Linux `x86_64` `lexicon-node` executable (statically linked RocksDB + `rustls` TLS + Wasmtime JIT) |
| `bin/SHA256SUMS` | SHA-256 checksum for verifying `bin/lexicon-node` |
| `install.sh` | Installs `lexicon-node` into `~/.local/bin` (or `$INSTALL_DIR`) |
| `scripts/generate-subnet-configs.sh` | Turnkey generator that creates an $N$-validator + Roamer subnet configuration bundle (`config.json`, `node.key`, and `lexicon-node.service` per node) |
| `config.flrc-example.json` | Reference configuration template for multi-node Semtech LR2021 FLRC radio subnets |

---

## 1. Installation (Linux `x86_64`)

```bash
git clone https://github.com/superlexicon/lexicon-bin.git
cd lexicon-bin

# Verify binary integrity
(cd bin && sha256sum -c SHA256SUMS)

# Install to ~/.local/bin/lexicon-node (or INSTALL_DIR=/usr/local/bin bash install.sh)
bash install.sh
```

---

## 2. Quickstart: Local Haltproof Subroutine Development (`--localtestnet`)

To develop and test Haltproof Subroutines (HPS) and dApps on a single machine **without radio hardware or a multi-node subnet**, start `lexicon-node` with `--localtestnet`:

```bash
# Starts a standalone 1-node chain (HTTP JSON-RPC on 127.0.0.1:8545, WebSocket on 127.0.0.1:8546)
lexicon-node --localtestnet
```

### What `--localtestnet` Does
- Opens **zero** radio serial ports and **zero** P2P sockets (completely offline/local).
- Runs the exact same JSON-RPC (`:8545`), WebSocket (`:8546`), `LayeredMempool`, **Wasmtime** execution engine (`1 fuel = 1 gas`), and persistent RocksDB state (`localtestnet.db` + `localtestnet.db-flatkv`) as a live multi-validator subnet.
- Confirms a block every **4 seconds** containing queued transactions and persists state across restarts.
- Requires **zero account token balance** to deploy or invoke Haltproof Subroutines.

### Customizing Database Path or Ports
```bash
# Use an isolated database directory (great for automated integration tests)
lexicon-node --localtestnet --db-path /tmp/my-dev-chain.db

# Override ports or limits via an optional config file (radio/validator fields are still disabled automatically)
lexicon-node --localtestnet --config my-local-config.json
```

### Deploying & Calling a Haltproof Subroutine
In a second terminal, use [`haltproof-subroutines`](https://github.com/superlexicon/haltproof-subroutines) (`cargo hps`):

```bash
cargo hps new my-first-hps
cd my-first-hps
cargo test
cargo hps build
cargo hps deploy dist/my_first_hps.wasm --save deployment.json

HPS=$(jq -r .hps_address deployment.json)
cargo hps send "$HPS" "increment(bytes32,uint64)" "alpha" 42
cargo hps call "$HPS" "getCount(bytes32)" "alpha"
```

---

## 3. Running a Full Multi-Node Subnet (FLRC Radio or TCP/IP)

A production Lexicon subnet consists of **$N$ Genesis Validators** (typically $N \ge 4$ for $3f+1$ BFT quorum resilience, where $\lceil 2N/3 \rceil$ validators finalize each block) plus optional **Roamers** and **Repeaters**.

All validators in a subnet must share:
1. The exact same ordered `p2p.initial_validators` list (32-byte hex Ed25519 public keys).
2. The exact same `p2p.validator_peer_mappings` dictionary (`"<public_key_hex>": "<12D3KooW..._peer_id>"`).
3. Identical consensus window timings (`genesis.pre_phase1_ms` .. `genesis.consensus_phase4_ms`) and radio parameters (`lr2021.frequency_hz`, `bandwidth_hz`, `coding_rate`, `sync_word`).
4. Synchronized system clocks within **$\pm 50\,\text{ms}$** (via NTP/`chrony` or a hardware GNSS NMEA receiver configured in `genesis.gnss_device`), since the 8-step TDMA/CSMA consensus window is anchored to UTC Unix millisecond boundaries.

---

### 3.1 Option A: One-Command Subnet Configuration Bundle Generator (Recommended)

Use [`scripts/generate-subnet-configs.sh`](scripts/generate-subnet-configs.sh) to automatically generate keys, `initial_validators`, `validator_peer_mappings`, `config.json`, and `systemd` service files for an entire $N$-validator subnet:

```bash
# Generate a 4-validator + 1-roamer FLRC radio subnet bundle in ./subnet-bundle
bash scripts/generate-subnet-configs.sh 4 ./subnet-bundle Flrc

# Or generate a 4-validator TCP/IP (Libp2p) subnet bundle (no radio hardware required)
bash scripts/generate-subnet-configs.sh 4 ./subnet-bundle-ip Libp2p
```

This creates:
```text
subnet-bundle/
├── validator-1/
│   ├── config.json            # Pre-populated with validator-1's private_key + full subnet validator set
│   ├── node.key               # Keypair summary (Peer ID, Public Key, Private Key)
│   └── lexicon-node.service   # Ready-to-install systemd unit
├── validator-2/
├── validator-3/
├── validator-4/
└── roamer-1/
    ├── config.json
    └── node.key
```

Copy each `validator-<i>/config.json` and `bin/lexicon-node` to the corresponding validator host:

```bash
# Example: Deploy validator-1 to host 192.168.50.91
ssh user@192.168.50.91 "mkdir -p ~/lexicon"
scp bin/lexicon-node subnet-bundle/validator-1/config.json user@192.168.50.91:~/lexicon/
```

---

### 3.2 Option B: Manual Step-by-Step Genesis Ceremony

If each validator operator generates their own keypair independently:

#### Step 1: Generate a Node Identity on Each Validator
On each validator (`1..N`), run:
```bash
lexicon-node generate-key node.key
```
Output:
```text
Generated node identity:
  Peer ID: 12D3KooWEAnEJfhCDtp3EAcNgDtkEcsYMBvkSSzi6vKciGq3qnz8
  Public key (hex): 40a991f83f1f4da925345e52dba316ab88847944cfd87e69e7efe4702db37b25
  Private key (hex): 58dff002a62d481ccd41602ed7a2a443a06d6dfa6faac7775829cee604597cd1
  Key file: node.key
```

#### Step 2: Assemble `initial_validators` and `validator_peer_mappings`
Collect the `Public key (hex)` and `Peer ID` from all $N$ validators (keep `Private key (hex)` secret on each respective node). In every node's `config.json` (starting from `cp config.flrc-example.json config.json`), set:

```json
  "p2p": {
    "listen_address": "0.0.0.0",
    "listen_port": 30303,
    "initial_validators": [
      "40a991f83f1f4da925345e52dba316ab88847944cfd87e69e7efe4702db37b25",
      "edfbd90a2b8d7388328d3ca02c5dd9a4e8d6c6a902bcbd6db330de62d27a49bb",
      "321636b666ba2f54395a131b7cfdbdf92b7115b7ae96c18e6d216f08888a731d",
      "df1fc01227ac7234845e58110b7403e2d66b73f44474a6c4343c187e1d8fb9ac"
    ],
    "validator_peer_mappings": {
      "40a991f83f1f4da925345e52dba316ab88847944cfd87e69e7efe4702db37b25": "12D3KooWEAnEJfhCDtp3EAcNgDtkEcsYMBvkSSzi6vKciGq3qnz8",
      "edfbd90a2b8d7388328d3ca02c5dd9a4e8d6c6a902bcbd6db330de62d27a49bb": "12D3KooWRqMXcfk8oPMBFY1n1s5WQvxSQojCyDtYASBXpTVdVu2J",
      "321636b666ba2f54395a131b7cfdbdf92b7115b7ae96c18e6d216f08888a731d": "12D3KooWDBtCXo1hK7MgMwDcDgwLjmZcnmbeVLG9fmqqGdCYJ8hS",
      "df1fc01227ac7234845e58110b7403e2d66b73f44474a6c4343c187e1d8fb9ac": "12D3KooWQqMAZ42E6SnGXdw14AFRGv52YkXaWDUJ7auYMAmiTz2F"
    },
    "private_key": "<THIS_NODES_PRIVATE_KEY_HEX>"
  }
```

---

### 3.3 Configuring Physical Semtech LR2021 FLRC Radio Hardware

When running over physical Semtech LR2021 FLRC USB bridges (`Lierda AM36-Pico` / `/dev/ttyACM*`):

1. **Grant Serial Port Access (`dialout`)**:
   ```bash
   sudo usermod -aG dialout "$USER"
   # Disable ModemManager so it does not probe /dev/ttyACM* with AT commands:
   sudo systemctl stop ModemManager && sudo systemctl disable ModemManager
   ```

2. **Single-Radio vs. Dual-Radio (`client_radio`) Configuration**:
   - **Single Radio (`tx_ingress_mode: "rpc"`)**: `/dev/ttyACM0` handles the 4-phase validator consensus air schedule, while clients submit transactions via HTTP JSON-RPC (`:8545`) or WebSocket (`:8546`).
   - **Dual Radio (`tx_ingress_mode: "radio"` or `"both"`)**: Attach a second LR2021 dongle (`/dev/ttyACM1`) dedicated to receiving client/Roamer transactions over the air on a separate frequency while `/dev/ttyACM0` runs consensus uninterrupted:
   ```json
   "lr2021": {
     "enabled": true,
     "serial_port": "/dev/ttyACM0",
     "baud_rate": 115200,
     "frequency_hz": 867100000,
     "bandwidth_hz": 1200000,
     "coding_rate": 1,
     "tx_power_dbm": 22,
     "sync_word": "0x12345690",
     "tx_ingress_mode": "both",
     "client_radio": {
       "serial_port": "/dev/ttyACM1",
       "baud_rate": 115200,
       "frequency_hz": 868300000
     }
   }
   ```

3. **Running a Multi-Node Subnet Over TCP/IP (`Libp2p` Transport, Without Radio Hardware)**:
   If you want to run a multi-validator BFT cluster across LAN/cloud VMs without LR2021 USB radios:
   - Set `"lr2021": { "enabled": false, ... }`.
   - Set all 10 channels in `"genesis.transport_selection"` from `"Flrc"` to `"Libp2p"`.
   - Populate `"p2p.bootstrap_nodes"` with multiaddrs of your peers, e.g.:
     ```json
     "bootstrap_nodes": [
       "/ip4/192.168.50.91/tcp/30303/p2p/12D3KooWEAnEJfhCDtp3EAcNgDtkEcsYMBvkSSzi6vKciGq3qnz8",
       "/ip4/192.168.50.92/tcp/30303/p2p/12D3KooWRqMXcfk8oPMBFY1n1s5WQvxSQojCyDtYASBXpTVdVu2J"
     ]
     ```

---

### 3.4 Launching & Managing Subnet Roles (`Validator`, `Roamer`, `Repeater`)

```bash
# 1. Start as a configured Genesis Validator
lexicon-node --config config.json

# 2. Start as a mobile frequency-scanning Roamer (GPS Haversine + cross-subnet store-and-forward relay)
lexicon-node --config config.json --roaming

# 3. Start as a stationary long-range Repeater
lexicon-node --config config.json --repeater

# 4. Dynamically join an active subnet as a Probation Validator
lexicon-node --config config.json --join-validator --subnet 00000001 --freq-hz 867100000
```

#### Installing as a Production `systemd` Service
```bash
sudo cp bin/lexicon-node /usr/local/bin/lexicon-node
sudo mkdir -p /opt/lexicon
sudo cp subnet-bundle/validator-1/config.json /opt/lexicon/config.json
sudo cp subnet-bundle/validator-1/lexicon-node.service /etc/systemd/system/lexicon-node.service

sudo systemctl daemon-reload
sudo systemctl enable --now lexicon-node
sudo journalctl -u lexicon-node -f
```

---

### 3.5 Verifying Subnet Quorum & Block Finality

Once at least $\lceil 2N/3 \rceil$ validators (e.g. 3 of 4 validators) are online, verify block progression and consensus state across the subnet:

```bash
# Check latest finalized block height across all 4 validators
for host in 192.168.50.91 192.168.50.92 192.168.50.93 192.168.50.94; do
  printf "%s: " "$host"
  curl -s --max-time 2 -X POST "http://$host:8545" \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
  echo ""
done

# Inspect local node consensus role & discovered radio subnets
curl -s -X POST http://127.0.0.1:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"slx_role","params":[],"id":1}'
```

---

## 4. JSON-RPC & WebSocket Endpoints

By default, `lexicon-node` serves:
- **HTTP JSON-RPC:** `http://127.0.0.1:8545` (or `0.0.0.0:8545` in subnet configs)
- **WebSocket Pub/Sub:** `ws://127.0.0.1:8546`

### Key JSON-RPC Methods

| Method | Description |
| :--- | :--- |
| `eth_chainId` | Returns chain ID (`0x539` / `1337` by default) |
| `eth_blockNumber` | Latest confirmed block height |
| `eth_getTransactionCount` / `eth_getAccountNonce` | Committed + pending sequential nonce for a 20-byte sender address |
| `eth_sendRawTransaction` | Submit a signed 10-field Lexicon EIP-155 RLP transaction |
| `eth_getTransactionReceipt` | Retrieve block confirmation status, fuel used, `contractAddress` (HPS address), and emitted logs |
| `eth_call` | Execute a read-only Haltproof Subroutine query against committed state (`0` blocks, `0` fees) |
| `eth_getLogs` | Query historical indexed HPS event logs by address, block range, and topics |
| `subnet_sendTransaction` | Queue a signed transaction for store-and-forward delivery to a foreign 4-byte subnet ID |
| `slx_role` / `slx_getSubnets` | Inspect local node consensus role and discovered radio subnets |

### WebSocket Subscriptions (`eth_subscribe`)
- `"newHeads"` — Stream newly finalized block headers in real time.
- `"logs"` — Stream real-time Haltproof Subroutine events (`{"address": "0x...", "topics": [...]}`).
