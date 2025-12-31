# uniswap_v2 (Cairo / StarkNet)

🔧 **A Uniswap v2 style AMM implementation in Cairo for StarkNet**

This repository is an educational/experimental implementation of the Uniswap v2 design in Cairo. It contains the core contracts and utilities necessary to create and manage liquidity pools, perform swaps, and calculate amounts and paths — adapted to StarkNet / Cairo primitives.

---

## 🚀 Overview

- This repo implements the classical Uniswap v2 architecture:
  - `Factory` — deploys and tracks `Pair` contracts (liquidity pools) and stores fee/owner info.
  - `Pair` — manages reserves, LP token mint/burn, and `swap` logic. Embedded ERC20 component is used for LP shares.
  - `Router` — convenience layer to add/remove liquidity and perform multi-hop swaps.
  - `Library` — pure helpers: token sorting, pair address computation, amount math (`get_amount_out`, `get_amount_in`), reserves fetching and path helpers.
  - `LPToken` — simple ERC20 used as the pair's liquidity token.

Contracts and interfaces live in `src/`:

- `src/factory/` — `factory.cairo`, `ifactory.cairo` (IFactory interface)
- `src/pair/` — `pair.cairo`, `ipair.cairo` (IPair interface)
- `src/router/` — `router.cairo`, `irouter.cairo` (IRouter interface)
- `src/library/` — `library.cairo` (utility functions)
- `src/lp_token/` — `lp_token.cairo`, `ilp_token.cairo` (ILPToken interface)
- `src/lib.cairo` — module re-exports

Compiled artifacts are placed under `target/dev/` after building.

---

## 🔍 Contract Responsibilities

### Factory
- Creates pair contracts deterministically (using salt derived from token addresses).
- Tracks all pairs in `all_pairs` and a map `pair[(token0, token1)] -> pair_address`.
- Stores `fee_to` (recipient of protocol fees) and `owner` (admin who can set fee recipient).
- Holds `pair_class_hash` and `lp_token_class_hash` (used for on-chain deterministic deploys).
- Key functions: `create_pair`, `get_pair`, `set_fee_to`, `set_new_owner`, `all_pairs_length`.

Notes: `pair_class_hash` / `lp_token_class_hash` are stored but there are currently no explicit setters in the contract — these must be initialized in deployment or via a migration/upgrade.

### Pair
- Implements pool logic: `mint` (add liquidity), `burn` (remove liquidity), `swap`, `sync`, `skim`.
- Keeps reserves (`reserve0`, `reserve1`), `price*_cumulative_last`, `k_last` (for fees), and an embedded ERC20 component for LP shares.
- Emits events: `Mint`, `Burn`, `Swap`, `Sync`.
- Reentrancy protection is implemented via `ReentrancyGuardComponent`.
- Fee-on mechanism: partially implemented via `_mint_fee` reading `fee_to` from Factory.

### Router
- User-facing convenience for multi-hop swaps and for adding/removing liquidity.
- Uses `Library` to compute amounts and resolve pair addresses.
- Key functions: `add_liquidity`, `remove_liquidity`, `swap_exact_tokens_for_tokens`, `swap_tokens_for_exact_tokens`.

### Library
- Deterministic `pair_for` computation (compute a pair address without on-chain calls).
- `sort_tokens`, `get_reserves` (fetch reserves from pair), `quote`, `get_amount_out`, `get_amount_in`, `get_amounts_out`, `get_amounts_in`.
- Useful for router computations and client-side calculations.

### LPToken -> (Not used)
- Basic ERC20 implementation used as liquidity tokens for pools.
- Not used, instead turned pair contracts to erc20

---

## 🛠 Building & Testing

Prerequisites: Rust toolchain (for Scarb), Scarb, and StarkNet development toolchain (snforge / foundry).

Suggested commands:

- Build contracts: `scarb build`
- Run tests: `scarb run test` or `snforge test`

Note: Tests directory `tests/` exists but has no tests yet — add unit tests under `tests/` to exercise functionality.

---

## 🧩 Deployment & Usage Notes

- Typical flow:
  1. Compile the pair and LP token contract classes (via `scarb build`).
  2. Deploy the `Factory` with an owner.
  3. Ensure `pair_class_hash` and `lp_token_class_hash` are set (no setter currently exists — initialize them in deployment or via a migration step).
  4. Deploy a `Router` pointing at the `Factory` and ensure it knows the `pair_class_hash` (router has a storage field for this).
  5. Create pairs via `Factory.create_pair(tokenA, tokenB)` or use `Router.add_liquidity` (which calls `create_pair` if necessary).

- Examples (pseudocode):

  - Create pair: `factory.create_pair(tokenA, tokenB)`
  - Add liquidity: `router.add_liquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin, to, deadline)`
  - Swap: `router.swap_exact_tokens_for_tokens(amountIn, amountOutMin, path, to, deadline)`

Important: The factory/router requires correct class hashes for deterministic pair address computation; ensure these are configured before calling `create_pair` and other functions that rely on deterministic address computation.

---

## ⚠️ Known Limitations & TODOs

- Tests are empty — add comprehensive unit/integration tests (e.g., mint/burn, swaps, router path routing, fee-on behavior).
- No explicit setters for `pair_class_hash` and `lp_token_class_hash` — consider adding initialization/setter methods or accept them in constructor.
- Flash swap functionality is noted as `TODO` in `Pair` code (not implemented yet).
- Some commented TODOs remain; review the codebase for edge cases (overflow/regression checking, extended Oracle support, gas optimizations).

---

## 🤝 Contributing

Contributions are welcome. Add tests for existing behaviors, improve deployment/initialization ergonomics (setters, constructors), and add example scripts for deploy & interaction.

Please add a `LICENSE` file if you want to make the license explicit.

---

## 📄 Files of interest

- `src/factory/factory.cairo` — Factory implementation
- `src/pair/pair.cairo` — Pair implementation (core AMM logic)
- `src/router/router.cairo` — Router (user-facing helpers)
- `src/library/library.cairo` — Utilities and math helpers
- `src/lp_token/lp_token.cairo` & `src/lp_token/ilp_token.cairo` — LP token
- `Scarb.toml` — project config and build/test script

---
