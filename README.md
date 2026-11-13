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
| `config.flrc-example.json` | Reference configuration template for multi-node Semtech LR2021 FLRC radio subnets |

---

## 1. Installation (Linux `x86_64`)

```bash
git clone https://github.com/superlexicon/lexicon-bin.git
cd lexicon-bin

# Verify binary integrity
(cd bin && sha256sum -c SHA256SUMS)

# Install to ~/.local/bin/lexicon-node (or run ./bin/lexicon-node directly)
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

## 3. Running on a Live Radio Subnet (Validator / Roamer / Repeater)

When operating with Semtech LR2021 FLRC hardware (`Lierda AM36-Pico` USB dongle or LR2021 bridge):

```bash
# 1. Generate an Ed25519/secp256k1 node keypair
lexicon-node generate-key node.key

# 2. Copy the template config and populate `p2p.private_key`, `p2p.initial_validators`, and `lr2021.serial_port`
cp config.flrc-example.json config.json

# 3a. Start as a configured genesis validator
lexicon-node --config config.json

# 3b. Start as a mobile frequency-scanning Roamer (GPS Haversine + store-and-forward relay)
lexicon-node --config config.json --roaming

# 3c. Start as a stationary long-range Repeater
lexicon-node --config config.json --repeater

# 3d. Dynamically join an active subnet as a Probation Validator
lexicon-node --config config.json --join-validator --subnet 00000001 --freq-hz 915000000
```

---

## 4. JSON-RPC & WebSocket Endpoints

By default, `lexicon-node` serves:
- **HTTP JSON-RPC:** `http://127.0.0.1:8545`
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
