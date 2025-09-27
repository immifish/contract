import { Contract } from 'ethers';
import { CONTRACT_ADDRESSES, NETWORKS, getMinerTokenAddress } from './constants.js';

/**
 * Factory class for creating contract instances
 */
export class ContractFactory {
  constructor(provider, network = NETWORKS.BASE_SEPOLIA) {
    this.provider = provider;
    this.network = network;
  }

  /**
   * Create a contract instance
   * @param {string} contractName - Name of the contract
   * @param {Array} abi - Contract ABI
   * @param {string} address - Contract address (optional, will use default if not provided)
   * @returns {Contract} Contract instance
   */
  createContract(contractName, abi, address = null) {
    const contractAddress = address || this.getContractAddress(contractName);
    
    if (!contractAddress) {
      throw new Error(`Contract address not found for ${contractName} on network ${this.network}`);
    }

    return new Contract(contractAddress, abi, this.provider);
  }

  /**
   * Create a miner token contract instance
   * @param {string} tokenName - Name of miner token (e.g., 'F(BTC,20)', 'F(ETH,15)', 'DEFAULT')
   * @param {Array} abi - Contract ABI
   * @param {string} address - Contract address (optional, will use default if not provided)
   * @returns {Contract} Contract instance
   */
  createMinerToken(tokenName = 'DEFAULT', abi, address = null) {
    const contractAddress = address || getMinerTokenAddress(tokenName, this.network);
    
    if (!contractAddress) {
      throw new Error(`Miner token address not found for ${tokenName} on network ${this.network}`);
    }

    return new Contract(contractAddress, abi, this.provider);
  }

  /**
   * Get contract address for the current network
   * @param {string} contractName - Name of the contract
   * @returns {string} Contract address
   */
  getContractAddress(contractName) {
    const networkAddresses = CONTRACT_ADDRESSES[this.getNetworkName()];
    return networkAddresses ? networkAddresses[contractName] : CONTRACT_ADDRESSES[contractName];
  }

  /**
   * Get miner token address for the current network
   * @param {string} tokenName - Name of miner token
   * @returns {string} Contract address
   */
  getMinerTokenAddress(tokenName = 'DEFAULT') {
    return getMinerTokenAddress(tokenName, this.network);
  }

  /**
   * Get network name from network ID
   * @returns {string} Network name
   */
  getNetworkName() {
    const networkMap = {
      [NETWORKS.BASE_MAINNET]: 'BASE_MAINNET',
      [NETWORKS.BASE_SEPOLIA]: 'BASE_SEPOLIA',
      [NETWORKS.LOCALHOST]: 'LOCALHOST'
    };
    return networkMap[this.network] || 'BASE_SEPOLIA';
  }

  /**
   * Set the network
   * @param {number} network - Network ID
   */
  setNetwork(network) {
    this.network = network;
  }
}