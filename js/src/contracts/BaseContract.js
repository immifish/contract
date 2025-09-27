import { Contract } from 'ethers';

/**
 * Base contract class with common functionality
 */
export class BaseContract {
  constructor(address, abi, provider) {
    this.address = address;
    this.abi = abi;
    this.provider = provider;
    this.contract = new Contract(address, abi, provider);
  }

  /**
   * Get contract instance
   * @returns {Contract} Contract instance
   */
  getContract() {
    return this.contract;
  }

  /**
   * Get contract address
   * @returns {string} Contract address
   */
  getAddress() {
    return this.address;
  }

  /**
   * Estimate gas for a transaction
   * @param {string} method - Method name
   * @param {Array} params - Method parameters
   * @returns {Promise<BigNumber>} Gas estimate
   */
  async estimateGas(method, ...params) {
    try {
      return await this.contract[method].estimateGas(...params);
    } catch (error) {
      throw new Error(`Gas estimation failed for ${method}: ${error.message}`);
    }
  }

  /**
   * Get transaction receipt
   * @param {string} txHash - Transaction hash
   * @returns {Promise<TransactionReceipt>} Transaction receipt
   */
  async getTransactionReceipt(txHash) {
    try {
      return await this.provider.getTransactionReceipt(txHash);
    } catch (error) {
      throw new Error(`Failed to get transaction receipt: ${error.message}`);
    }
  }

  /**
   * Wait for transaction confirmation
   * @param {string} txHash - Transaction hash
   * @param {number} confirmations - Number of confirmations to wait for
   * @returns {Promise<TransactionReceipt>} Transaction receipt
   */
  async waitForTransaction(txHash, confirmations = 1) {
    try {
      return await this.provider.waitForTransaction(txHash, confirmations);
    } catch (error) {
      throw new Error(`Transaction failed: ${error.message}`);
    }
  }

  /**
   * Listen to contract events
   * @param {string} eventName - Event name
   * @param {Function} callback - Callback function
   * @returns {Function} Unsubscribe function
   */
  on(eventName, callback) {
    return this.contract.on(eventName, callback);
  }

  /**
   * Remove event listener
   * @param {string} eventName - Event name
   * @param {Function} callback - Callback function
   */
  off(eventName, callback) {
    this.contract.off(eventName, callback);
  }
}
