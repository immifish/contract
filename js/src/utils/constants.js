// Contract addresses - these will be populated after deployment
export const CONTRACT_ADDRESSES = {
  // Main contracts (fallback from environment variables)
  MINER_TOKEN: process.env.MINER_TOKEN_ADDRESS || '',
  VALUATION_SERVICE: process.env.VALUATION_SERVICE_ADDRESS || '',
  DEBTOR_MANAGER: process.env.DEBTOR_MANAGER_ADDRESS || '',
  CYCLE_UPDATER: process.env.CYCLE_UPDATER_ADDRESS || '',
  PRICE_ORACLE: process.env.PRICE_ORACLE_ADDRESS || '',
  VALUATION_ORACLE: process.env.VALUATION_ORACLE_ADDRESS || '',
  
  // Network-specific addresses
  BASE_SEPOLIA: {
    MINER_TOKEN: '',
    VALUATION_SERVICE: '',
    DEBTOR_MANAGER: '',
    CYCLE_UPDATER: '0xB40C5De773828Aea6E22989730aaac872A8FD639',
    PRICE_ORACLE: '',
    VALUATION_ORACLE: ''
  },
  BASE_MAINNET: {
    MINER_TOKEN: '',
    VALUATION_SERVICE: '',
    DEBTOR_MANAGER: '',
    CYCLE_UPDATER: '',
    PRICE_ORACLE: '',
    VALUATION_ORACLE: ''
  }
};

export const NETWORKS = {
  BASE_MAINNET: 8453,
  BASE_SEPOLIA: 84532,
  LOCALHOST: 31337
};

export const DEFAULT_NETWORK = NETWORKS.BASE_SEPOLIA;
