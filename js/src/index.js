// Main export file - this is what other projects will import

// Contract classes
export { MinerToken } from './contracts/MinerToken.js';
export { ValuationService } from './contracts/ValuationService.js';
export { DebtorManager } from './contracts/DebtorManager.js';
export { MinerOracle } from './contracts/MinerOracle.js';
export { BatchTransfer } from './contracts/BatchTransfer.js';
export { BaseContract } from './contracts/BaseContract.js';

// Utility classes
export { ContractFactory } from './utils/contractFactory.js';

// Constants
export { 
  CONTRACT_ADDRESSES, 
  NETWORKS, 
  DEFAULT_NETWORK,
  getMinerTokenAddress,
  getAllMinerTokenAddresses,
  getAvailableMinerTokenNames,
  addMinerToken
} from './utils/constants.js';

// Helper functions
export { 
  formatTokenAmount, 
  parseTokenAmount, 
  formatPercentage, 
  sleep, 
  retry 
} from './utils/helpers.js';

// Re-export ethers utilities for convenience
export { formatUnits, parseUnits } from 'ethers';
