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
      const ltv = await this.contract.ltv(collateralAsset, loanAsset);
      return ltv.toString();
    } catch (error) {
      throw new Error(`Failed to get LTV: ${error.message}`);
    }
  }

  /**
   * Query asset price in USD (8 decimals)
   * @param {string} asset - Asset address
   * @param {string} amount - Token amount (raw units)
   * @returns {Promise<string>} Price in USD (8 decimals)
   */
  async queryPrice(asset, amount) {
    try {
      const value = await this.contract.queryPrice(asset, amount);
      return value.toString();
    } catch (error) {
      throw new Error(`Failed to query price: ${error.message}`);
    }
  }

  /**
   * Query miner token price using miner oracle
   * @param {string} minerToken - Miner token address
   * @param {string} amount - Token amount (raw units)
   * @returns {Promise<string>} Price in USD (8 decimals)
   */
  async queryMinerPrice(minerToken, amount) {
    try {
      const value = await this.contract.queryMinerPrice(minerToken, amount);
      return value.toString();
    } catch (error) {
      throw new Error(`Failed to query miner price: ${error.message}`);
    }
  }

  /**
   * Query LTV-adjusted price for a given input token into base token
   * @param {string} inputToken - Collateral asset address
   * @param {string} baseToken - Loan asset address
   * @param {string} amount - Amount of input token (raw units)
   * @returns {Promise<string>} LTV-adjusted value
   */
  async queryPriceLtv(inputToken, baseToken, amount) {
    try {
      const value = await this.contract.queryPriceLtv(inputToken, baseToken, amount);
      return value.toString();
    } catch (error) {
      throw new Error(`Failed to query price with LTV: ${error.message}`);
    }
  }

  /**
   * Get miner oracle address
   * @returns {Promise<string>} Miner oracle address
   */
  async getMinerOracle() {
    try {
      return await this.contract.minerOracle();
    } catch (error) {
      throw new Error(`Failed to get miner oracle: ${error.message}`);
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

  /**
   * Query total collateral value of holder for a loan asset
   * @param {string} loanAsset - Loan asset address
   * @param {string} holder - Holder address
   * @returns {Promise<string>} Collateral value
   */
  async queryCollateralValue(loanAsset, holder) {
    try {
      const value = await this.contract.queryCollateralValue(loanAsset, holder);
      return value.toString();
    } catch (error) {
      throw new Error(`Failed to query collateral value: ${error.message}`);
    }
  }
}
