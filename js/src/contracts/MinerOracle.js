import { BaseContract } from './BaseContract.js';

/**
 * MinerOracle contract interaction class
 */
export class MinerOracle extends BaseContract {
  constructor(address, abi, provider) {
    super(address, abi, provider);
  }

  /**
   * Set token price in USD with 8 decimals (owner only)
   * @param {string} minerToken - Miner token address
   * @param {string|number|bigint} price - Price with 8 decimals
   * @param {Object} options - Transaction options
   * @returns {Promise<{hash: string, wait: Function}>}
   */
  async setTokenPrice(minerToken, price, options = {}) {
    try {
      const tx = await this.contract.setTokenPrice(minerToken, price, options);
      return {
        hash: tx.hash,
        wait: () => this.waitForTransaction(tx.hash)
      };
    } catch (error) {
      throw new Error(`Failed to set token price: ${error.message}`);
    }
  }

  /**
   * Query price for an amount of miner token
   * @param {string} minerToken - Miner token address
   * @param {string|number|bigint} amount - Token amount (raw units)
   * @returns {Promise<string>} Price in USD (8 decimals) as string
   */
  async queryPrice(minerToken, amount) {
    try {
      const value = await this.contract.queryPrice(minerToken, amount);
      return value.toString();
    } catch (error) {
      throw new Error(`Failed to query price: ${error.message}`);
    }
  }

  /**
   * Get stored unit price (USD with 8 decimals) for a miner token
   * @param {string} minerToken - Miner token address
   * @returns {Promise<string>} Stored price per 1e18 token
   */
  async getStoredPrice(minerToken) {
    try {
      const p = await this.contract.price(minerToken);
      return p.toString();
    } catch (error) {
      throw new Error(`Failed to get stored price: ${error.message}`);
    }
  }
}


