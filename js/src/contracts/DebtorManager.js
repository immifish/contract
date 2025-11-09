import { BaseContract } from './BaseContract.js';

/**
 * DebtorManager contract interaction class
 */
export class DebtorManager extends BaseContract {
  constructor(address, abi, provider) {
    super(address, abi, provider);
  }

  /**
   * Create a new debtor contract for caller
   * @param {Object} options - Transaction options
   * @returns {Promise<Object>} Transaction result
   */
  async createDebtor(options = {}) {
    try {
      const tx = await this.contract.createDebtor(options);
      return {
        hash: tx.hash,
        wait: () => this.waitForTransaction(tx.hash)
      };
    } catch (error) {
      throw new Error(`Failed to create debtor: ${error.message}`);
    }
  }

  /**
   * Set valuation address (owner only)
   * @param {string} valuationService - Address of valuation contract
   * @param {Object} options - Transaction options
   * @returns {Promise<Object>} Transaction result
   */
  async setValuationService(valuationService, options = {}) {
    try {
      const tx = await this.contract.setValuationService(valuationService, options);
      return {
        hash: tx.hash,
        wait: () => this.waitForTransaction(tx.hash)
      };
    } catch (error) {
      throw new Error(`Failed to set valuation service: ${error.message}`);
    }
  }

  /**
   * Set default debtor params (owner only)
   * @param {{minCollateralRatio: string, marginBufferedCollateralRatio: string}} params - Default params
   * @param {Object} options - Transaction options
   * @returns {Promise<Object>} Transaction result
   */
  async setDefaultDebtorParams(params, options = {}) {
    try {
      const tx = await this.contract.setDefaultDebtorParams({
        minCollateralRatio: params.minCollateralRatio,
        marginBufferedCollateralRatio: params.marginBufferedCollateralRatio
      }, options);
      return {
        hash: tx.hash,
        wait: () => this.waitForTransaction(tx.hash)
      };
    } catch (error) {
      throw new Error(`Failed to set default debtor params: ${error.message}`);
    }
  }

  /**
   * Set custom debtor params for a debtor (owner only)
   * @param {string} debtor - Debtor address
   * @param {string} minCollateralRatio - Min collateral ratio
   * @param {string} marginBufferedCollateralRatio - Buffered collateral ratio
   * @param {Object} options - Transaction options
   * @returns {Promise<Object>} Transaction result
   */
  async setCustomDebtorParams(debtor, minCollateralRatio, marginBufferedCollateralRatio, options = {}) {
    try {
      const tx = await this.contract.setCustomDebtorParams(
        debtor,
        minCollateralRatio,
        marginBufferedCollateralRatio,
        options
      );
      return {
        hash: tx.hash,
        wait: () => this.waitForTransaction(tx.hash)
      };
    } catch (error) {
      throw new Error(`Failed to set custom debtor params: ${error.message}`);
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
   * Get debtor contract address for an owner
   * @param {string} owner - owner address
   * @returns {Promise<string>} Debtor contract address
   */
  async getDebtor(owner) {
    try {
      return await this.contract.getDebtor(owner);
    } catch (error) {
      throw new Error(`Failed to get debtor: ${error.message}`);
    }
  }

  /**
   * Run health check for debtor
   * @param {string} debtor - Debtor address
   * @returns {Promise<{collateralRatio: string, passMinCollateralRatioCheck: boolean, passMarginBufferedCollateralRatioCheck: boolean, interestReserveAdjusted: string}>}
   */
  async healthCheck(debtor) {
    try {
      const result = await this.contract.healthCheck(debtor);
      return {
        collateralRatio: result[0].toString(),
        passMinCollateralRatioCheck: result[1],
        passMarginBufferedCollateralRatioCheck: result[2],
        interestReserveAdjusted: result[3].toString()
      };
    } catch (error) {
      throw new Error(`Failed to run health check: ${error.message}`);
    }
  }

  /**
   * Run health check simulation with custom parameters
   * @param {Object} minerDebtor - MinerToken.Debtor struct with timeStamp, outStandingBalance, debtFactor, interestReserve
   * @param {string|number|bigint} collateralValueInDebtorContract - Collateral value in debtor contract
   * @param {string|number|bigint} minCollateralRatio - Minimum collateral ratio
   * @param {string|number|bigint} marginBufferedCollateralRatio - Margin buffered collateral ratio
   * @returns {Promise<{collateralRatio: string, passMinCollateralRatioCheck: boolean, passMarginBufferedCollateralRatioCheck: boolean, interestReserveAdjusted: string}>}
   */
  async healthCheckSimulation(minerDebtor, collateralValueInDebtorContract, minCollateralRatio, marginBufferedCollateralRatio) {
    try {
      const result = await this.contract.healthCheckSimulation(
        {
          timeStamp: {
            lastModifiedCycle: minerDebtor.timeStamp.lastModifiedCycle,
            lastModifiedTime: minerDebtor.timeStamp.lastModifiedTime
          },
          outStandingBalance: minerDebtor.outStandingBalance,
          debtFactor: minerDebtor.debtFactor,
          interestReserve: minerDebtor.interestReserve
        },
        collateralValueInDebtorContract,
        minCollateralRatio,
        marginBufferedCollateralRatio
      );
      return {
        collateralRatio: result[0].toString(),
        passMinCollateralRatioCheck: result[1],
        passMarginBufferedCollateralRatioCheck: result[2],
        interestReserveAdjusted: result[3].toString()
      };
    } catch (error) {
      throw new Error(`Failed to run health check simulation: ${error.message}`);
    }
  }

  /**
   * Set cycle updater address (owner only)
   * @param {string} newCycleUpdater - Address of new cycle updater contract
   * @param {Object} options - Transaction options
   * @returns {Promise<Object>} Transaction result
   */
  async setCycleUpdater(newCycleUpdater, options = {}) {
    try {
      const tx = await this.contract.setCycleUpdater(newCycleUpdater, options);
      return {
        hash: tx.hash,
        wait: () => this.waitForTransaction(tx.hash)
      };
    } catch (error) {
      throw new Error(`Failed to set cycle updater: ${error.message}`);
    }
  }

  /**
   * Get miner token address
   * @returns {Promise<string>} Miner token address
   */
  async minerToken() {
    try {
      return await this.contract.minerToken();
    } catch (error) {
      throw new Error(`Failed to get miner token address: ${error.message}`);
    }
  }
}
