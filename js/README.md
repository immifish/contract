# Immi Protocol JavaScript SDK

JavaScript SDK for interacting with Immi Protocol smart contracts.

## Installation

```bash
npm install @immi/contract-sdk
```

## Getting Contract ABIs

The SDK requires contract ABIs to interact with deployed contracts. ABIs are generated when you compile your Solidity contracts with Foundry.

### Option 1: Use Foundry's output directly

Point your imports directly to Foundry's `out/` directory:

```javascript
import ValuationABI from '../out/Valuation.sol/Valuation.json' assert { type: 'json' };
```

### Option 2: Copy artifacts to an artifacts folder (Recommended)

1. Run the copy script after compiling contracts:
   ```bash
   ./js/scripts/copy-artifacts.sh
   ```

2. Import from the artifacts folder:
   ```javascript
   import ValuationABI from './artifacts/out/Valuation.sol/Valuation.json' assert { type: 'json' };
   ```

**Note**: The JSON files contain the contract ABI, bytecode, and metadata. You'll extract the `abi` field when creating contract instances.

## Usage

### Basic Setup

```javascript
import { MinerToken, Valuation, Debtor, DebtorManager, CONTRACT_ADDRESSES } from '@immi/contract-sdk';
import { ethers } from 'ethers';

// Load contract ABIs from Foundry compilation artifacts
import MinerTokenABI from './artifacts/out/MinerToken.sol/MinerToken.json' assert { type: 'json' };
import ValuationABI from './artifacts/out/Valuation.sol/Valuation.json' assert { type: 'json' };
import DebtorABI from './artifacts/out/Debtor.sol/Debtor.json' assert { type: 'json' };
import DebtorManagerABI from './artifacts/out/DebtorManager.sol/DebtorManager.json' assert { type: 'json' };

// Connect to provider
const provider = new ethers.JsonRpcProvider('YOUR_RPC_URL');
const signer = new ethers.Wallet('YOUR_PRIVATE_KEY', provider);

// Create contract instances
const minerToken = new MinerToken(CONTRACT_ADDRESSES.MINER_TOKEN, MinerTokenABI.abi, signer);
const valuation = new Valuation(CONTRACT_ADDRESSES.VALUATION, ValuationABI.abi, signer);
const debtorManager = new DebtorManager(CONTRACT_ADDRESSES.DEBTOR_MANAGER, DebtorManagerABI.abi, signer);

// Get debtor address for the caller
const debtorAddress = await debtorManager.getDebtor(signer.address);
const debtor = new Debtor(debtorAddress, DebtorABI.abi, signer);
```

### Alternative: Using ContractFactory

```javascript
import { ContractFactory, CONTRACT_ADDRESSES, NETWORKS } from '@immi/contract-sdk';
import { ethers } from 'ethers';
import MinerTokenABI from './artifacts/out/MinerToken.sol/MinerToken.json' assert { type: 'json' };

const provider = new ethers.JsonRpcProvider('YOUR_RPC_URL');
const factory = new ContractFactory(provider, NETWORKS.BASE_SEPOLIA);

// Create contract instance using factory
const minerTokenContract = factory.createContract('MINER_TOKEN', MinerTokenABI.abi);
```

### MinerToken Operations

```javascript
// Check if address is a debtor
const isDebtor = await minerToken.isDebtor(debtorAddress);

// Get debtor information
const debtorInfo = await minerToken.getDebtor(debtorAddress);

// Mint tokens (caller must be a debtor)
const tx = await minerToken.mint(recipientAddress, '1000');
await tx.wait();

// Claim interest for a creditor
const claimTx = await minerToken.claim(creditorAddress, beneficiaryAddress, '100');
await claimTx.wait();

// Set designated beneficiary for a creditor
const setBeneficiaryTx = await minerToken.setDesignatedBeneficiary(creditorAddress, beneficiaryAddress);
await setBeneficiaryTx.wait();

// Get balance
const balance = await minerToken.balanceOf(userAddress);
console.log('Balance:', balance);
```

### Valuation Operations

```javascript
// Query whitelist for accepted collateral tokens
const whitelist = await valuation.queryWhitelist(loanAsset);

// Get LTV ratio
const ltv = await valuation.getLTV(collateralAsset, loanAsset);

// Query asset price in USD
const price = await valuation.queryPrice(assetAddress, amount);

// Query miner token price
const minerPrice = await valuation.queryMinerPrice(minerTokenAddress, amount);

// Query LTV-adjusted price
const priceLtv = await valuation.queryPriceLtv(inputToken, baseToken, amount);

// Query total collateral value for a holder
const collateralValue = await valuation.queryCollateralValue(loanAsset, holderAddress);
```

### DebtorManager Operations

```javascript
// Create debtor contract for caller
const createTx = await debtorManager.createDebtor();
await createTx.wait();

// Get debtor address for an owner
const debtorAddress = await debtorManager.getDebtor(ownerAddress);

// Get debtor parameters
const params = await debtorManager.getDebtorParams(debtorAddress);

// Run health check for debtor
const healthCheck = await debtorManager.healthCheck(debtorAddress);
console.log('Collateral ratio:', healthCheck.collateralRatio);
console.log('Passes min ratio:', healthCheck.passMinCollateralRatioCheck);
console.log('Passes buffered ratio:', healthCheck.passMarginBufferedCollateralRatioCheck);
console.log('Interest reserve adjusted:', healthCheck.interestReserveAdjusted);
```

### Debtor Operations

```javascript
// Add reserve to debtor
const addReserveTx = await debtor.addReserve('1000');
await addReserveTx.wait();

// Remove reserve (must maintain healthy status)
const removeReserveTx = await debtor.removeReserve(recipientAddress, '500');
await removeReserveTx.wait();

// Mint tokens (must maintain healthy status)
const mintTx = await debtor.mint('1000');
await mintTx.wait();

// Remove collateral (must maintain healthy status)
const removeCollateralTx = await debtor.removeCollateral(tokenAddress, recipientAddress, '500');
await removeCollateralTx.wait();

// Execute delegate call (must maintain healthy status)
const delegateCallTx = await debtor.delegateCall(actionContractAddress, callData);
await delegateCallTx.wait();

// Liquidate unhealthy debtor
const liquidateTx = await debtor.liquidate(liquidatorActionAddress, callData);
await liquidateTx.wait();

// Get debtor information
const debtorManagerAddress = await debtor.getDebtorManager();
const version = await debtor.getVersion();

// Get token balance
const balance = await debtor.getTokenBalance(tokenAddress);
console.log('Token balance:', balance);
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
