// Contract addresses - these will be populated after deployment
export const CONTRACT_ADDRESSES = {
  // Main contracts (fallback from environment variables)
  MINER_TOKEN: process.env.MINER_TOKEN_ADDRESS || '', // Kept for backward compatibility
  VALUATION_SERVICE: process.env.VALUATION_SERVICE_ADDRESS || '',
  DEBTOR_MANAGER: process.env.DEBTOR_MANAGER_ADDRESS || '',
  CYCLE_UPDATER: process.env.CYCLE_UPDATER_ADDRESS || '',
  PRICE_ORACLE: process.env.PRICE_ORACLE_ADDRESS || '',
  VALUATION_ORACLE: process.env.VALUATION_ORACLE_ADDRESS || '',
  
  // Multiple miner tokens support - flexible mapping
  MINER_TOKENS: {
    // Default miner token (for backward compatibility)
    DEFAULT: process.env.MINER_TOKEN_ADDRESS || '',
    
    // Miner token mappings - add new tokens here as needed
    'F(BTC,20)': process.env.MINER_TOKEN_F_BTC_20_ADDRESS || '',
    // Add more miner tokens as they are deployed:
    // 'F(ETH,15)': process.env.MINER_TOKEN_F_ETH_15_ADDRESS || '',
    // 'F(USDC,25)': process.env.MINER_TOKEN_F_USDC_25_ADDRESS || '',
    // 'F(USDT,30)': process.env.MINER_TOKEN_F_USDT_30_ADDRESS || '',
  },
  
  // Network-specific addresses
  BASE_SEPOLIA: {
    MINER_TOKEN: '', // Kept for backward compatibility
    VALUATION_SERVICE: '',
    DEBTOR_MANAGER: '',
    CYCLE_UPDATER: '0xB40C5De773828Aea6E22989730aaac872A8FD639',
    PRICE_ORACLE: '',
    VALUATION_ORACLE: '',
    
    // Network-specific miner tokens
    MINER_TOKENS: {
      DEFAULT: '',
      'F(BTC,20)': '',
      // Add more miner tokens as they are deployed:
      // 'F(ETH,15)': '',
      // 'F(USDC,25)': '',
      // 'F(USDT,30)': '',
    }
  },
  BASE_MAINNET: {
    MINER_TOKEN: '', // Kept for backward compatibility
    VALUATION_SERVICE: '',
    DEBTOR_MANAGER: '',
    CYCLE_UPDATER: '',
    PRICE_ORACLE: '',
    VALUATION_ORACLE: '',
    
    // Network-specific miner tokens
    MINER_TOKENS: {
      DEFAULT: '',
      'F(BTC,20)': '',
      // Add more miner tokens as they are deployed:
      // 'F(ETH,15)': '',
      // 'F(USDC,25)': '',
      // 'F(USDT,30)': '',
    }
  }
};

export const NETWORKS = {
  BASE_MAINNET: 8453,
  BASE_SEPOLIA: 84532,
  LOCALHOST: 31337
};

export const DEFAULT_NETWORK = NETWORKS.BASE_SEPOLIA;

// Helper function to get miner token address
export function getMinerTokenAddress(tokenName = 'DEFAULT', network = null) {
  const networkName = network ? Object.keys(NETWORKS).find(key => NETWORKS[key] === network) : null;
  
  if (networkName && CONTRACT_ADDRESSES[networkName]?.MINER_TOKENS?.[tokenName]) {
    return CONTRACT_ADDRESSES[networkName].MINER_TOKENS[tokenName];
  }
  
  // Fallback to global miner tokens
  if (CONTRACT_ADDRESSES.MINER_TOKENS?.[tokenName]) {
    return CONTRACT_ADDRESSES.MINER_TOKENS[tokenName];
  }
  
  // Fallback to legacy MINER_TOKEN for backward compatibility
  if (tokenName === 'DEFAULT') {
    if (networkName && CONTRACT_ADDRESSES[networkName]?.MINER_TOKEN) {
      return CONTRACT_ADDRESSES[networkName].MINER_TOKEN;
    }
    return CONTRACT_ADDRESSES.MINER_TOKEN;
  }
  
  return '';
}

// Helper function to get all miner token addresses for a network
export function getAllMinerTokenAddresses(network = null) {
  const networkName = network ? Object.keys(NETWORKS).find(key => NETWORKS[key] === network) : null;
  
  if (networkName && CONTRACT_ADDRESSES[networkName]?.MINER_TOKENS) {
    return CONTRACT_ADDRESSES[networkName].MINER_TOKENS;
  }
  
  return CONTRACT_ADDRESSES.MINER_TOKENS || {};
}

// Helper function to get available miner token names
export function getAvailableMinerTokenNames(network = null) {
  const addresses = getAllMinerTokenAddresses(network);
  return Object.keys(addresses).filter(name => addresses[name] && addresses[name] !== '');
}

// Helper function to add a new miner token (for runtime configuration)
export function addMinerToken(tokenName, address, network = null) {
  const networkName = network ? Object.keys(NETWORKS).find(key => NETWORKS[key] === network) : null;
  
  if (networkName) {
    if (!CONTRACT_ADDRESSES[networkName].MINER_TOKENS) {
      CONTRACT_ADDRESSES[networkName].MINER_TOKENS = {};
    }
    CONTRACT_ADDRESSES[networkName].MINER_TOKENS[tokenName] = address;
  } else {
    CONTRACT_ADDRESSES.MINER_TOKENS[tokenName] = address;
  }
}
