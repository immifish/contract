import { BaseContract } from './BaseContract.js';
import { formatTokenAmount, parseTokenAmount } from '../utils/helpers.js';
import { Contract } from 'ethers';

/**
 * Debtor contract interaction class
 */
export class Debtor extends BaseContract {
  constructor(address, abi, provider) {
    super(address, abi, provider);
  }

  /**
   * Get debtor manager address
   * @returns {Promise<string>} Debtor manager address
   */
  async getDebtorManager() {
    try {
      return await this.contract.debtorManager();
    } catch (error) {
      throw new Error(`Failed to get debtor manager: ${error.message}`);
    }
  }

  /**
   * Get version
   * @returns {Promise<number>} Version number
   */
  async getVersion() {
    try {
      const version = await this.contract.VERSION();
      return version;
    } catch (error) {
      throw new Error(`Failed to get version: ${error.message}`);
    }
  }

  /**
   * Add reserve to the debtor
   * @param {string} amount - Amount to add (human readable format)
   * @param {Object} options - Transaction options
   * @returns {Promise<Object>} Transaction result
   */
  async addReserve(amount, options = {}) {
    try {
      const parsedAmount = parseTokenAmount(amount);
      const tx = await this.contract.addReserve(parsedAmount, options);
      return {
        hash: tx.hash,
        wait: () => this.waitForTransaction(tx.hash)
      };
    } catch (error) {
      throw new Error(`Failed to add reserve: ${error.message}`);
    }
  }

  /**
   * Remove reserve from the debtor (owner only, must maintain healthy status)
   * @param {string} to - Recipient address
   * @param {string} amount - Amount to remove (human readable format)
   * @param {Object} options - Transaction options
   * @returns {Promise<Object>} Transaction result
   */
  async removeReserve(to, amount, options = {}) {
    try {
      const parsedAmount = parseTokenAmount(amount);
      const tx = await this.contract.removeReserve(to, parsedAmount, options);
      return {
        hash: tx.hash,
        wait: () => this.waitForTransaction(tx.hash)
      };
    } catch (error) {
      throw new Error(`Failed to remove reserve: ${error.message}`);
    }
  }

  /**
   * Mint tokens (owner only, must maintain healthy status)
   * @param {string} amount - Amount to mint (human readable format)
   * @param {Object} options - Transaction options
   * @returns {Promise<Object>} Transaction result
   */
  async mint(amount, options = {}) {
    try {
      const parsedAmount = parseTokenAmount(amount);
      const tx = await this.contract.mint(parsedAmount, options);
      return {
        hash: tx.hash,
        wait: () => this.waitForTransaction(tx.hash)
      };
    } catch (error) {
      throw new Error(`Failed to mint: ${error.message}`);
    }
  }

  /**
   * Remove collateral (owner only, must maintain healthy status)
   * @param {string} token - Token contract address
   * @param {string} to - Recipient address
   * @param {string} amount - Amount to remove (human readable format)
   * @param {Object} options - Transaction options
   * @returns {Promise<Object>} Transaction result
   */
  async removeCollateral(token, to, amount, options = {}) {
    try {
      const parsedAmount = parseTokenAmount(amount);
      const tx = await this.contract.removeCollateral(token, to, parsedAmount, options);
      return {
        hash: tx.hash,
        wait: () => this.waitForTransaction(tx.hash)
      };
    } catch (error) {
      throw new Error(`Failed to remove collateral: ${error.message}`);
    }
  }

  /**
   * Execute delegate call (owner only, must maintain healthy status)
   * @param {string} action - Action contract address
   * @param {string} data - Call data (hex string)
   * @param {Object} options - Transaction options
   * @returns {Promise<Object>} Transaction result with return data
   */
  async delegateCall(action, data, options = {}) {
    try {
      const tx = await this.contract.delegateCall(action, data, options);
      return {
        hash: tx.hash,
        wait: () => this.waitForTransaction(tx.hash),
        result: tx.result // bytes memory return value
      };
    } catch (error) {
      throw new Error(`Failed to execute delegate call: ${error.message}`);
    }
  }

  /**
   * Liquidate unhealthy debtor
   * Must be unhealthy before and margined after
   * @param {string} liquidatorAction - Liquidator action contract address
   * @param {string} data - Call data (hex string)
   * @param {Object} options - Transaction options
   * @returns {Promise<Object>} Transaction result with return data
   */
  async liquidate(liquidatorAction, data, options = {}) {
    try {
      const tx = await this.contract.liquidate(liquidatorAction, data, options);
      return {
        hash: tx.hash,
        wait: () => this.waitForTransaction(tx.hash),
        result: tx.result // bytes memory return value
      };
    } catch (error) {
      throw new Error(`Failed to liquidate: ${error.message}`);
    }
  }

  /**
   * Get token balance of this debtor contract
   * @param {string} tokenAddress - Token contract address
   * @returns {Promise<string>} Token balance
   */
  async getTokenBalance(tokenAddress) {
    try {
      // Using a generic ERC20 balanceOf interface
      const abi = [
        "function balanceOf(address) view returns (uint256)"
      ];
      const tokenContract = new Contract(tokenAddress, abi, this.provider);
      const balance = await tokenContract.balanceOf(this.address);
      return formatTokenAmount(balance);
    } catch (error) {
      throw new Error(`Failed to get token balance: ${error.message}`);
    }
  }
}

