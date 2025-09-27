import { BaseContract } from './BaseContract.js';

/**
 * ValuationService contract interaction class
 */
export class ValuationService extends BaseContract {
  constructor(address, abi, provider) {
    super(address, abi, provider);
  }

  /**
   * Query whitelist for accepted collateral tokens
   * @param {string} loanAsset - Loan asset address
   * @returns {Promise<Array>} Array of accepted collateral token addresses
   */
  async queryWhitelist(loanAsset) {
    try {
      return await this.contract.queryWhitelist(loanAsset);
    } catch (error) {
      throw new Error(`Failed to query whitelist: ${error.message}`);
    }
  }

  /**
   * Get LTV (Loan-to-Value) ratio
   * @param {string} collateralAsset - Collateral asset address
   * @param {string} loanAsset - Loan asset address
   * @returns {Promise<string>} LTV ratio
   */
  async getLTV(collateralAsset, loanAsset) {
    try {
      const ltv = await this.contract.LTV(collateralAsset, loanAsset);
      return ltv.toString();
    } catch (error) {
      throw new Error(`Failed to get LTV: ${error.message}`);
    }
  }

  /**
   * Calculate collateral value
   * @param {string} collateralAsset - Collateral asset address
   * @param {string} amount - Collateral amount
   * @param {string} loanAsset - Loan asset address
   * @returns {Promise<string>} Collateral value
   */
  async calculateCollateralValue(collateralAsset, amount, loanAsset) {
    try {
      const value = await this.contract.calculateCollateralValue(collateralAsset, amount, loanAsset);
      return value.toString();
    } catch (error) {
      throw new Error(`Failed to calculate collateral value: ${error.message}`);
    }
  }

  /**
   * Get price oracle address
   * @returns {Promise<string>} Price oracle address
   */
  async getPriceOracle() {
    try {
      return await this.contract.priceOracle();
    } catch (error) {
      throw new Error(`Failed to get price oracle: ${error.message}`);
    }
  }

  /**
   * Get scale factor
   * @returns {Promise<string>} Scale factor
   */
  async getScaleFactor() {
    try {
      const scaleFactor = await this.contract.SCALE_FACTOR();
      return scaleFactor.toString();
    } catch (error) {
      throw new Error(`Failed to get scale factor: ${error.message}`);
    }
  }
}
