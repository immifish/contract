import { BaseContract } from './BaseContract.js';
import { formatTokenAmount, parseTokenAmount } from '../utils/helpers.js';

/**
 * MinerToken contract interaction class
 */
export class MinerToken extends BaseContract {
  constructor(address, abi, provider) {
    super(address, abi, provider);
  }

  /**
   * Check if an address is a debtor
   * @param {string} debtorAddress - Address to check
   * @returns {Promise<boolean>} True if address is a debtor
   */
  async isDebtor(debtorAddress) {
    try {
      return await this.contract.isDebtor(debtorAddress);
    } catch (error) {
      throw new Error(`Failed to check debtor status: ${error.message}`);
    }
  }

  /**
   * Get debtor information
   * @param {string} debtorAddress - Debtor address
   * @returns {Promise<Object>} Debtor information
   */
  async getDebtor(debtorAddress) {
    try {
      const debtor = await this.contract.getDebtor(debtorAddress);
      return {
        timeStamp: {
          lastModifiedCycle: debtor.timeStamp.lastModifiedCycle.toString(),
          lastModifiedTime: debtor.timeStamp.lastModifiedTime.toString()
        },
        outStandingBalance: formatTokenAmount(debtor.outStandingBalance),
        debtFactor: debtor.debtFactor.toString()
      };
    } catch (error) {
      throw new Error(`Failed to get debtor info: ${error.message}`);
    }
  }

  /**
   * Get creditor information
   * @param {string} creditorAddress - Creditor address
   * @returns {Promise<Object>} Creditor information
   */
  async getCreditor(creditorAddress) {
    try {
      const creditor = await this.contract.getCreditor(creditorAddress);
      return {
        timeStamp: {
          lastModifiedCycle: creditor.timeStamp.lastModifiedCycle.toString(),
          lastModifiedTime: creditor.timeStamp.lastModifiedTime.toString()
        },
        interestFactor: creditor.interestFactor.toString(),
        interest: formatTokenAmount(creditor.interest)
      };
    } catch (error) {
      throw new Error(`Failed to get creditor info: ${error.message}`);
    }
  }

  /**
   * Mint tokens for a debtor
   * @param {string} debtorAddress - Debtor address
   * @param {string} amount - Amount to mint
   * @param {Object} options - Transaction options
   * @returns {Promise<Object>} Transaction result
   */
  async mint(debtorAddress, amount, options = {}) {
    try {
      const parsedAmount = parseTokenAmount(amount);
      const tx = await this.contract.mint(debtorAddress, parsedAmount, options);
      return {
        hash: tx.hash,
        wait: () => this.waitForTransaction(tx.hash)
      };
    } catch (error) {
      throw new Error(`Failed to mint tokens: ${error.message}`);
    }
  }

  /**
   * Burn tokens
   * @param {string} amount - Amount to burn
   * @param {Object} options - Transaction options
   * @returns {Promise<Object>} Transaction result
   */
  async burn(amount, options = {}) {
    try {
      const parsedAmount = parseTokenAmount(amount);
      const tx = await this.contract.burn(parsedAmount, options);
      return {
        hash: tx.hash,
        wait: () => this.waitForTransaction(tx.hash)
      };
    } catch (error) {
      throw new Error(`Failed to burn tokens: ${error.message}`);
    }
  }

  /**
   * Claim interest
   * @param {string} amount - Amount to claim
   * @param {Object} options - Transaction options
   * @returns {Promise<Object>} Transaction result
   */
  async claim(amount, options = {}) {
    try {
      const parsedAmount = parseTokenAmount(amount);
      const tx = await this.contract.claim(parsedAmount, options);
      return {
        hash: tx.hash,
        wait: () => this.waitForTransaction(tx.hash)
      };
    } catch (error) {
      throw new Error(`Failed to claim interest: ${error.message}`);
    }
  }

  /**
   * Get token balance
   * @param {string} address - Address to check balance for
   * @returns {Promise<string>} Token balance
   */
  async balanceOf(address) {
    try {
      const balance = await this.contract.balanceOf(address);
      return formatTokenAmount(balance);
    } catch (error) {
      throw new Error(`Failed to get balance: ${error.message}`);
    }
  }

  /**
   * Get total supply
   * @returns {Promise<string>} Total supply
   */
  async totalSupply() {
    try {
      const supply = await this.contract.totalSupply();
      return formatTokenAmount(supply);
    } catch (error) {
      throw new Error(`Failed to get total supply: ${error.message}`);
    }
  }
}
