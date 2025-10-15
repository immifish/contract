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
        debtFactor: debtor.debtFactor.toString(),
        interestReserve: debtor.interestReserve.toString()
      };
    } catch (error) {
      throw new Error(`Failed to get debtor info: ${error.message}`);
    }
  }

  /**
   * Mint tokens to a non-debtor recipient (caller must be a debtor)
   * @param {string} to - Recipient address
   * @param {string} amount - Amount to mint
   * @param {Object} options - Transaction options
   * @returns {Promise<Object>} Transaction result
   */
  async mint(to, amount, options = {}) {
    try {
      const parsedAmount = parseTokenAmount(amount);
      const tx = await this.contract.mint(to, parsedAmount, options);
      return {
        hash: tx.hash,
        wait: () => this.waitForTransaction(tx.hash)
      };
    } catch (error) {
      throw new Error(`Failed to mint tokens: ${error.message}`);
    }
  }

  /**
   * Claim interest for a creditor (caller must be creditor or designated beneficiary)
   * @param {string} creditor - Creditor address
   * @param {string} to - Recipient address for interest token
   * @param {string} amount - Amount to claim
   * @param {Object} options - Transaction options
   * @returns {Promise<Object>} Transaction result
   */
  async claim(creditor, to, amount, options = {}) {
    try {
      const parsedAmount = parseTokenAmount(amount);
      const tx = await this.contract.claim(creditor, to, parsedAmount, options);
      return {
        hash: tx.hash,
        wait: () => this.waitForTransaction(tx.hash)
      };
    } catch (error) {
      throw new Error(`Failed to claim interest: ${error.message}`);
    }
  }

  /**
   * Set designated beneficiary for a creditor
   * @param {string} creditor - Creditor address
   * @param {string} beneficiary - Beneficiary address
   * @param {Object} options - Transaction options
   * @returns {Promise<Object>} Transaction result
   */
  async setDesignatedBeneficiary(creditor, beneficiary, options = {}) {
    try {
      const tx = await this.contract.setDesignatedBeneficiary(creditor, beneficiary, options);
      return {
        hash: tx.hash,
        wait: () => this.waitForTransaction(tx.hash)
      };
    } catch (error) {
      throw new Error(`Failed to set designated beneficiary: ${error.message}`);
    }
  }

  /**
   * Get designated beneficiary for a creditor
   * @param {string} creditor - Creditor address
   * @returns {Promise<string>} Beneficiary address
   */
  async getDesignatedBeneficiary(creditor) {
    try {
      return await this.contract.getDesignatedBeneficiary(creditor);
    } catch (error) {
      throw new Error(`Failed to get designated beneficiary: ${error.message}`);
    }
  }

  /**
   * Preview claimable interest for creditor
   * @param {string} creditor - Creditor address
   * @returns {Promise<string>} Claimable interest amount
   */
  async settleCreditorPreview(creditor) {
    try {
      const amount = await this.contract.settleCreditorPreview(creditor);
      return formatTokenAmount(amount);
    } catch (error) {
      throw new Error(`Failed to preview creditor settlement: ${error.message}`);
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
