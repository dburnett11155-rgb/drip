# Drip 💧

> Recurring payments for Web3. The simplest way to add subscriptions to any EVM protocol.

```typescript
import Drip, { INTERVALS, DEPLOYMENTS } from "drip-web3-sdk";

const drip = new Drip({ contractAddress: DEPLOYMENTS["base"], signer });
const { planId } = await drip.createPlan(USDC_ADDRESS, 10_000000n, INTERVALS.MONTHLY);
const { subscriptionId } = await drip.subscribe(planId);
```

That's it. Your protocol now has recurring payments.

---

## What is Drip?

Drip is an on-chain recurring payment protocol deployed on Base. It lets any Web3 protocol charge users on a recurring schedule — daily, weekly, monthly, or any custom interval.

Think Stripe for Web3. One smart contract integration. Payments execute automatically. You never touch it again.

---

## How it works

1. **Protocol creates a plan** — token, amount, interval
2. **User subscribes** — first payment charged immediately
3. **Drip executes payments** — automatically on schedule, forever
4. **Protocol earns revenue** — 99% of each payment, on-chain

Drip takes a 1% fee on each payment execution to fund the keeper bot infrastructure.

---

## Installation

```bash
npm install drip-web3-sdk
```

---

## Quick start

### Create a subscription plan

```typescript
import Drip, { INTERVALS, DEPLOYMENTS } from "drip-web3-sdk";
import { ethers } from "ethers";

const provider = new ethers.BrowserProvider(window.ethereum);
const signer = await provider.getSigner();

const drip = new Drip({
  contractAddress: DEPLOYMENTS["base"],
  signer,
});

// Create a $10/month USDC plan
const { planId } = await drip.createPlan(
  USDC_ADDRESS,        // token
  10_000000n,          // amount (10 USDC, 6 decimals)
  INTERVALS.MONTHLY    // interval (30 days)
);
```

### Subscribe a user

```typescript
// Auto-approves token allowance and charges first payment
const { subscriptionId } = await drip.subscribe(planId);
```

### Check subscription status

```typescript
const sub = await drip.getSubscription(subscriptionId);
console.log(sub.active);        // true
console.log(sub.nextPayment);   // unix timestamp of next charge
```

### Cancel a subscription

```typescript
// User cancels their own subscription
await drip.cancelSubscription(subscriptionId);

// Merchant cancels a specific user's subscription
await drip.cancelSubscriptionAsMerchant(subscriptionId);
```

---

## API Reference

### `new Drip(config)`

| Parameter | Type | Description |
|---|---|---|
| `contractAddress` | `string` | Drip contract address |
| `signer` | `ethers.Signer` | Ethers.js signer |

### `createPlan(token, amount, interval)`

Creates a new subscription plan.

| Parameter | Type | Description |
|---|---|---|
| `token` | `string` | ERC-20 token address |
| `amount` | `bigint` | Amount per cycle in token decimals |
| `interval` | `bigint` | Seconds between payments |

Returns `{ planId, tx }`

### `subscribe(planId, options?)`

Subscribes to a plan. Charges first payment immediately.

| Option | Type | Default | Description |
|---|---|---|---|
| `autoApprove` | `boolean` | `true` | Auto-approve token allowance |
| `approvalAmount` | `bigint` | `MaxUint256` | Custom approval amount |

Returns `{ subscriptionId, tx }`

### `cancelSubscription(subscriptionId)`

Cancels a subscription as the subscriber.

### `cancelPlan(planId)`

Deactivates a plan as the merchant.

### `getStats()`

Returns protocol-wide stats: `planCount`, `subscriptionCount`, `feeBps`, `feeRecipient`.

---

## Intervals

```typescript
import { INTERVALS } from "drip-web3-sdk";

INTERVALS.DAILY    // 86400 seconds
INTERVALS.WEEKLY   // 604800 seconds
INTERVALS.MONTHLY  // 2592000 seconds
INTERVALS.YEARLY   // 31536000 seconds
```

---

## Deployments

| Network | Address |
|---|---|
| Base Mainnet | `0xba23e6f93982de89106E9E69065573b0405825A6` |
| Base Sepolia (testnet) | `0x1ad2FC3469dB1625730B4401E5717B741526B6af` |

---

## Contract

Drip is a non-upgradeable, audited Solidity contract. No proxies. No admin keys for payment execution. What you integrate is what runs forever.

- **Language:** Solidity 0.8.20
- **Framework:** Foundry
- **Dependencies:** OpenZeppelin 5.0
- **Ownership:** Gnosis Safe `0x05f16F1B126cff3c7BC9079Cf7278E2C6BD35B46`
- **Audit:** In progress

---

## Security

- Non-upgradeable contract — no rug vectors
- Pull-based payments — Drip never holds user funds
- Users can cancel anytime on-chain
- Merchants can cancel individual subscriptions
- Fee capped at 5% by contract — currently set to 1%
- Owned by Gnosis Safe multisig

---

## License

MIT
