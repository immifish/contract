# Immi Protocol JavaScript SDK

JavaScript SDK for interacting with Immi Protocol smart contracts.

## Installation

```bash
npm install @immi/contract-sdk
```

## Usage

### Basic Setup

```javascript
import { MinerToken, ValuationService, CONTRACT_ADDRESSES } from '@immi/contract-sdk';
import { ethers } from 'ethers';

// Connect to provider
const provider = new ethers.JsonRpcProvider('YOUR_RPC_URL');
const signer = new ethers.Wallet('YOUR_PRIVATE_KEY', provider);

// Create contract instances
const minerToken = new MinerToken(CONTRACT_ADDRESSES.MINER_TOKEN, ABI, signer);
const valuationService = new ValuationService(CONTRACT_ADDRESSES.VALUATION_SERVICE, ABI, signer);
```

### MinerToken Operations

```javascript
// Check if address is a debtor
const isDebtor = await minerToken.isDebtor(debtorAddress);

// Get debtor information
const debtorInfo = await minerToken.getDebtor(debtorAddress);

// Mint tokens
const tx = await minerToken.mint(debtorAddress, '1000');
await tx.wait();

// Burn tokens
const burnTx = await minerToken.burn('500');
await burnTx.wait();

// Claim interest
const claimTx = await minerToken.claim('100');
await claimTx.wait();
```

### ValuationService Operations

```javascript
// Query whitelist
const whitelist = await valuationService.queryWhitelist(loanAsset);

// Get LTV ratio
const ltv = await valuationService.getLTV(collateralAsset, loanAsset);

// Calculate collateral value
const value = await valuationService.calculateCollateralValue(collateralAsset, amount, loanAsset);
```

### DebtorManager Operations

```javascript
// Register debtor
const registerTx = await debtorManager.registerDebtor(debtorAddress);
await registerTx.wait();

// Get debtor parameters
const params = await debtorManager.getDebtorParams(debtorAddress);

// Calculate collateral ratio
const ratio = await debtorManager.calculateCollateralRatio(debtorAddress);
```

## Contract Addresses

Contract addresses are available in `CONTRACT_ADDRESSES`:

```javascript
import { CONTRACT_ADDRESSES, NETWORKS } from '@immi/contract-sdk';

console.log(CONTRACT_ADDRESSES.MINER_TOKEN);
console.log(CONTRACT_ADDRESSES.SEPOLIA.MINER_TOKEN);
```

## Error Handling

All methods include proper error handling:

```javascript
try {
  const debtorInfo = await minerToken.getDebtor(debtorAddress);
} catch (error) {
  console.error('Failed to get debtor info:', error.message);
}
```

## Development

```bash
# Install dependencies
npm install

# Build the package
npm run build

# Run tests
npm test

# Development mode with watch
npm run dev
```
