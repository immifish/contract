import { BaseContract } from './BaseContract.js';
import { formatUnits, parseUnits } from 'ethers';

/**
 * BatchTransfer contract interaction class
 */
export class BatchTransfer extends BaseContract {
  constructor(address, abi, provider) {
    super(address, abi, provider);
  }

  /**
   * Transfer multiple ERC20 tokens to a single address
   * @param {string[]} tokens - Array of token addresses to transfer
   * @param {string[]} amounts - Array of amounts to transfer (must be same length as tokens)
   * @param {string} to - The recipient address
   * @param {Object} options - Transaction options
   * @returns {Promise<Object>} Transaction result
   */
  async batchTransfer(tokens, amounts, to, options = {}) {
    try {
      // Parse amounts to BigNumber if they're strings with decimals
      const parsedAmounts = amounts.map(amount => {
        // Try to parse as ether amounts if it's a string
        if (typeof amount === 'string' && amount.includes('.')) {
          return parseUnits(amount, 18);
        }
        return amount;
      });

      const tx = await this.contract.batchTransfer(tokens, parsedAmounts, to, options);
      return {
        hash: tx.hash,
        wait: () => this.waitForTransaction(tx.hash)
      };
    } catch (error) {
      throw new Error(`Failed to batch transfer tokens: ${error.message}`);
    }
  }

  /**
   * Estimate gas for batch transfer
   * @param {string[]} tokens - Array of token addresses to transfer
   * @param {string[]} amounts - Array of amounts to transfer
   * @param {string} to - The recipient address
   * @returns {Promise<bigint>} Gas estimate
   */
  async estimateBatchTransferGas(tokens, amounts, to) {
    try {
      const parsedAmounts = amounts.map(amount => {
        if (typeof amount === 'string' && amount.includes('.')) {
          return parseUnits(amount, 18);
        }
        return amount;
      });

      return await this.contract.batchTransfer.estimateGas(tokens, parsedAmounts, to);
    } catch (error) {
      throw new Error(`Gas estimation failed for batch transfer: ${error.message}`);
    }
  }
}

