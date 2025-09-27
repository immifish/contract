import { BaseContract } from './BaseContract.js';

/**
 * CycleUpdater contract interaction class
 */
export class CycleUpdater extends BaseContract {
  constructor(address, abi, provider) {
    super(address, abi, provider);
  }

  /**
   * Update the interest cycle
   * @param {Object} options - Transaction options
   * @returns {Promise<Object>} Transaction result
   */
  async updateCycle(options = {}) {
    try {
      const tx = await this.contract.updateCycle(options);
      return {
        hash: tx.hash,
        wait: () => this.waitForTransaction(tx.hash)
      };
    } catch (error) {
      throw new Error(`Failed to update cycle: ${error.message}`);
    }
  }

  /**
   * Get current cycle information
   * @returns {Promise<Object>} Current cycle info
   */
  async getCurrentCycle() {
    try {
      const cycle = await this.contract.getCurrentCycle();
      return {
        cycleNumber: cycle.cycleNumber.toString(),
        startTime: cycle.startTime.toString(),
        endTime: cycle.endTime.toString(),
        isActive: cycle.isActive
      };
    } catch (error) {
      throw new Error(`Failed to get current cycle: ${error.message}`);
    }
  }

  /**
   * Get cycle by number
   * @param {number} cycleNumber - Cycle number
   * @returns {Promise<Object>} Cycle information
   */
  async getCycle(cycleNumber) {
    try {
      const cycle = await this.contract.getCycle(cycleNumber);
      return {
        cycleNumber: cycle.cycleNumber.toString(),
        startTime: cycle.startTime.toString(),
        endTime: cycle.endTime.toString(),
        isActive: cycle.isActive
      };
    } catch (error) {
      throw new Error(`Failed to get cycle: ${error.message}`);
    }
  }

  /**
   * Check if cycle update is needed
   * @returns {Promise<boolean>} True if update is needed
   */
  async isUpdateNeeded() {
    try {
      return await this.contract.isUpdateNeeded();
    } catch (error) {
      throw new Error(`Failed to check if update is needed: ${error.message}`);
    }
  }
}
