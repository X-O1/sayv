# SAYV v1

SAYV is a savings account that earns yield on digital dollars (stablecoins) via Aave and offers users optional cash advances against their future yield. It plugs directly into YieldWield for debt logic and TokenRegistry for token permissions.

---

## What It Does

SAYV handles the vault logic for:

* Accepting stablecoin deposits from users
* Supplying those funds to Aave v3 to earn yield
* Tracking user balances using Aave’s liquidity index and share math
* Allowing users to take advances against future yield via YieldWield
* Managing an allowlist of tokens via TokenRegistry
* Claiming protocol revenue automatically from YieldWield fees

---

## Installation (Forge)

To install SAYV into your Foundry project:

```bash
forge install smartcontractengineer/sayv
```

Then add your remappings to `foundry.toml`:

```toml
[profile.default]
src = 'src'
out = 'out'
libs = ['lib']

remappings = [
  '@sayv/=lib/sayv/src/',
  '@yieldwield/=lib/yieldwield/src/',
  '@token-registry/=lib/token-registry/src/'
]
```

---

## Deploying SAYV

```solidity
new Sayv(
  addressProviderAddress,      // Aave PoolAddressesProvider
  yieldWieldAddress,           // YieldWield contract
  tokenRegistryAddress         // TokenRegistry contract
);
```

Make sure Aave and token registry contracts are deployed before initializing SAYV.

---

## How It Works

### 1. Deposit

```solidity
sayv.depositToVault(token, amount);
```

User deposits stablecoins → SAYV supplies to Aave → mints yield shares for the user.

### 2. Withdraw

```solidity
sayv.withdrawFromVault(token, amount);
```

User burns yield shares → SAYV withdraws from Aave → sends stablecoins to user.

### 3. Take Advance

```solidity
sayv.getYieldAdvance(token, collateralAmount, requestedAdvance);
```

User redeems part of their shares → YieldWield calculates advance + fee → SAYV withdraws and sends advance.

### 4. Repay Advance

```solidity
sayv.repayYieldAdvanceWithDeposit(token, amount);
```

User sends stablecoins to repay their debt → SAYV re-supplies to Aave.

### 5. Unlock Collateral

```solidity
sayv.withdrawYieldAdvanceCollateral(token);
```

Once debt is repaid → user gets collateral back → shares are re-minted.

---

## Share Model

SAYV uses share-based accounting to represent user balances:

* `s_yieldShares` — user’s share balance
* `s_totalYieldShares` — total protocol shares
* Shares convert to real token value via Aave’s `liquidityIndex`
* Revenue shares are claimed from YieldWield and added to `s_totalRevenueShares`

---

## Token Management (Owner Only)

```solidity
sayv.managePermittedTokens(token, true);  // Add
sayv.managePermittedTokens(token, false); // Remove
```

* Automatically approves token for Aave supply
* TokenRegistry is used for permissioning

---

## Run Tests

```bash
forge test
```

---

## License

MIT
