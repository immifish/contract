import { BaseContract } from './BaseContract.js';

/**
 * CycleUpdater contract interaction class
 */
export class CycleUpdater extends BaseContract {
  constructor(address, abi, provider) {
    super(address, abi, provider);
  }

  /**
   * Start a new cycle (owner only)
   * @param {string|number|bigint} currentCycle - Current cycle index (for validation)
   * @param {string|number|bigint} currentCycleInterest - Interest generated in current cycle (scaled by SCALING_FACTOR)
   * @param {Object} options - Transaction options
   * @returns {Promise<Object>} Transaction result
   */
  async startNewCycle(currentCycle, currentCycleInterest, options = {}) {
    try {
      const tx = await this.contract.startNewCycle(currentCycle, currentCycleInterest, options);
      return {
        hash: tx.hash,
        wait: () => this.waitForTransaction(tx.hash)
      };
    } catch (error) {
      throw new Error(`Failed to start new cycle: ${error.message}`);
    }
  }

  /**
   * Get current cycle index
   * @returns {Promise<string>} Current cycle index
   */
  async getCurrentCycleIndex() {
    try {
      const index = await this.contract.getCurrentCycleIndex();
      return index.toString();
    } catch (error) {
      throw new Error(`Failed to get current cycle index: ${error.message}`);
    }
  }

  /**
   * Get cycle by index
   * @param {string|number|bigint} index - Cycle index
   * @returns {Promise<Object>} Cycle information
   */
  async getCycle(index) {
    try {
      const cycle = await this.contract.getCycle(index);
      return {
        startTime: cycle.startTime.toString(),
        rateFactor: cycle.rateFactor.toString(),
        interestSnapShot: cycle.interestSnapShot.toString()
      };
    } catch (error) {
      throw new Error(`Failed to get cycle: ${error.message}`);
    }
  }

  /**
   * Get accumulated interest up to the last completed cycle
   * @returns {Promise<string>} Accumulated interest
   */
  async getAccumulatedInterest() {
    try {
      const interest = await this.contract.getAccumulatedInterest();
      return interest.toString();
    } catch (error) {
      throw new Error(`Failed to get accumulated interest: ${error.message}`);
    }
  }

  /**
   * Preview interest calculation
   * @param {string|number|bigint} balance - Token balance
   * @param {string|number|bigint} lastModifiedCycle - Last modified cycle index
   * @param {string|number|bigint} lastModifiedTime - Last modified timestamp
   * @param {string|number|bigint} factor - Interest factor before update
   * @returns {Promise<Object>} Object with finalizedInterest and updatedFactor
   */
  async interestPreview(balance, lastModifiedCycle, lastModifiedTime, factor) {
    try {
      const result = await this.contract.interestPreview(
        balance,
        lastModifiedCycle,
        lastModifiedTime,
        factor
      );
      return {
        finalizedInterest: result[0].toString(),
        updatedFactor: result[1].toString()
      };
    } catch (error) {
      throw new Error(`Failed to preview interest: ${error.message}`);
    }
  }

  /**
   * Estimate debt using the last completed cycle's rateFactor
   * @param {string|number|bigint} debtFactor - Debt factor
   * @returns {Promise<string>} Estimated debt (normalized by SCALING_FACTOR)
   */
  async estimateDebtByFactor(debtFactor) {
    try {
      const debt = await this.contract.estimateDebtByFactor(debtFactor);
      return debt.toString();
    } catch (error) {
      throw new Error(`Failed to estimate debt by factor: ${error.message}`);
    }
  }

  /**
   * Get scaling factor constant
   * @returns {Promise<string>} Scaling factor (10^30)
   */
  async getScalingFactor() {
    try {
      const factor = await this.contract.SCALING_FACTOR();
      return factor.toString();
    } catch (error) {
      throw new Error(`Failed to get scaling factor: ${error.message}`);
    }
  }
}
