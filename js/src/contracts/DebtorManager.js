import { BaseContract } from './BaseContract.js';

/**
 * DebtorManager contract interaction class
 */
export class DebtorManager extends BaseContract {
  constructor(address, abi, provider) {
    super(address, abi, provider);
  }

  /**
   * Register a new debtor
   * @param {string} debtorAddress - Debtor address
   * @param {Object} options - Transaction options
   * @returns {Promise<Object>} Transaction result
   */
  async registerDebtor(debtorAddress, options = {}) {
    try {
      const tx = await this.contract.registerDebtor(debtorAddress, options);
      return {
        hash: tx.hash,
        wait: () => this.waitForTransaction(tx.hash)
      };
    } catch (error) {
      throw new Error(`Failed to register debtor: ${error.message}`);
    }
  }

  /**
   * Update debtor parameters
   * @param {string} debtorAddress - Debtor address
   * @param {Object} params - Debtor parameters
   * @param {Object} options - Transaction options
   * @returns {Promise<Object>} Transaction result
   */
  async updateDebtorParams(debtorAddress, params, options = {}) {
    try {
      const tx = await this.contract.updateDebtorParams(debtorAddress, params, options);
      return {
        hash: tx.hash,
        wait: () => this.waitForTransaction(tx.hash)
      };
    } catch (error) {
      throw new Error(`Failed to update debtor params: ${error.message}`);
    }
  }

  /**
   * Get debtor parameters
   * @param {string} debtorAddress - Debtor address
   * @returns {Promise<Object>} Debtor parameters
   */
  async getDebtorParams(debtorAddress) {
    try {
      const params = await this.contract.getDebtorParams(debtorAddress);
      return {
        minCollateralRatio: params.minCollateralRatio.toString(),
        marginBufferedCollateralRatio: params.marginBufferedCollateralRatio.toString()
      };
    } catch (error) {
      throw new Error(`Failed to get debtor params: ${error.message}`);
    }
  }

  /**
   * Get default debtor parameters
   * @returns {Promise<Object>} Default debtor parameters
   */
  async getDefaultDebtorParams() {
    try {
      const params = await this.contract.defaultDebtorParams();
      return {
        minCollateralRatio: params.minCollateralRatio.toString(),
        marginBufferedCollateralRatio: params.marginBufferedCollateralRatio.toString()
      };
    } catch (error) {
      throw new Error(`Failed to get default debtor params: ${error.message}`);
    }
  }

  /**
   * Calculate collateral ratio
   * @param {string} debtorAddress - Debtor address
   * @returns {Promise<string>} Collateral ratio
   */
  async calculateCollateralRatio(debtorAddress) {
    try {
      const ratio = await this.contract.calculateCollateralRatio(debtorAddress);
      return ratio.toString();
    } catch (error) {
      throw new Error(`Failed to calculate collateral ratio: ${error.message}`);
    }
  }

  /**
   * Get miner token address
   * @returns {Promise<string>} Miner token address
   */
  async getMinerToken() {
    try {
      return await this.contract.minerToken();
    } catch (error) {
      throw new Error(`Failed to get miner token: ${error.message}`);
    }
  }

  /**
   * Get valuation service address
   * @returns {Promise<string>} Valuation service address
   */
  async getValuationService() {
    try {
      return await this.contract.valuationService();
    } catch (error) {
      throw new Error(`Failed to get valuation service: ${error.message}`);
    }
  }

  /**
   * Get quote token address
   * @returns {Promise<string>} Quote token address
   */
  async getQuoteToken() {
    try {
      return await this.contract.quoteToken();
    } catch (error) {
      throw new Error(`Failed to get quote token: ${error.message}`);
    }
  }
}
