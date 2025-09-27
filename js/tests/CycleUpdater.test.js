import { describe, it, expect, beforeEach, jest } from '@jest/globals';
import { CycleUpdater } from '../src/contracts/CycleUpdater.js';

// Mock ethers Contract
const mockContract = {
  updateCycle: jest.fn(),
  getCurrentCycle: jest.fn(),
  getCycle: jest.fn(),
  isUpdateNeeded: jest.fn()
};

// Mock provider
const mockProvider = {
  getTransactionReceipt: jest.fn(),
  waitForTransaction: jest.fn()
};

describe('CycleUpdater', () => {
  let cycleUpdater;
  const mockAddress = '0x1234567890123456789012345678901234567890';
  const mockAbi = [{ name: 'updateCycle', type: 'function' }];

  beforeEach(() => {
    // Reset all mocks before each test
    jest.clearAllMocks();
    
    // Create new instance for each test
    cycleUpdater = new CycleUpdater(mockAddress, mockAbi, mockProvider);
    
    // Replace the contract instance with our mock
    cycleUpdater.contract = mockContract;
  });

  describe('Constructor', () => {
    it('should create instance with correct properties', () => {
      expect(cycleUpdater.address).toBe(mockAddress);
      expect(cycleUpdater.abi).toBe(mockAbi);
      expect(cycleUpdater.provider).toBe(mockProvider);
    });
  });

  describe('updateCycle', () => {
    it('should successfully update cycle', async () => {
      const mockTx = { hash: '0xtx123' };
      const mockOptions = { gasLimit: 100000 };
      
      mockContract.updateCycle.mockResolvedValue(mockTx);
      mockProvider.waitForTransaction.mockResolvedValue({ status: 1 });

      const result = await cycleUpdater.updateCycle(mockOptions);

      expect(mockContract.updateCycle).toHaveBeenCalledWith(mockOptions);
      expect(result).toEqual({
        hash: '0xtx123',
        wait: expect.any(Function)
      });
    });

    it('should handle updateCycle with default options', async () => {
      const mockTx = { hash: '0xtx123' };
      
      mockContract.updateCycle.mockResolvedValue(mockTx);

      const result = await cycleUpdater.updateCycle();

      expect(mockContract.updateCycle).toHaveBeenCalledWith({});
      expect(result.hash).toBe('0xtx123');
    });

    it('should throw error when updateCycle fails', async () => {
      const error = new Error('Transaction failed');
      mockContract.updateCycle.mockRejectedValue(error);

      await expect(cycleUpdater.updateCycle()).rejects.toThrow('Failed to update cycle: Transaction failed');
    });

    it('should allow waiting for transaction confirmation', async () => {
      const mockTx = { hash: '0xtx123' };
      const mockReceipt = { status: 1, blockNumber: 12345 };
      
      mockContract.updateCycle.mockResolvedValue(mockTx);
      mockProvider.waitForTransaction.mockResolvedValue(mockReceipt);

      const result = await cycleUpdater.updateCycle();
      const receipt = await result.wait();

      expect(mockProvider.waitForTransaction).toHaveBeenCalledWith('0xtx123', 1);
      expect(receipt).toBe(mockReceipt);
    });
  });

  describe('getCurrentCycle', () => {
    it('should successfully get current cycle', async () => {
      const mockCycle = {
        cycleNumber: 5n,
        startTime: 1640995200n,
        endTime: 1641081600n,
        isActive: true
      };
      
      mockContract.getCurrentCycle.mockResolvedValue(mockCycle);

      const result = await cycleUpdater.getCurrentCycle();

      expect(mockContract.getCurrentCycle).toHaveBeenCalled();
      expect(result).toEqual({
        cycleNumber: '5',
        startTime: '1640995200',
        endTime: '1641081600',
        isActive: true
      });
    });

    it('should handle cycle with false isActive', async () => {
      const mockCycle = {
        cycleNumber: 3n,
        startTime: 1640908800n,
        endTime: 1640995199n,
        isActive: false
      };
      
      mockContract.getCurrentCycle.mockResolvedValue(mockCycle);

      const result = await cycleUpdater.getCurrentCycle();

      expect(result.isActive).toBe(false);
      expect(result.cycleNumber).toBe('3');
    });

    it('should throw error when getCurrentCycle fails', async () => {
      const error = new Error('Contract call failed');
      mockContract.getCurrentCycle.mockRejectedValue(error);

      await expect(cycleUpdater.getCurrentCycle()).rejects.toThrow('Failed to get current cycle: Contract call failed');
    });
  });

  describe('getCycle', () => {
    it('should successfully get cycle by number', async () => {
      const cycleNumber = 2;
      const mockCycle = {
        cycleNumber: 2n,
        startTime: 1640822400n,
        endTime: 1640908799n,
        isActive: false
      };
      
      mockContract.getCycle.mockResolvedValue(mockCycle);

      const result = await cycleUpdater.getCycle(cycleNumber);

      expect(mockContract.getCycle).toHaveBeenCalledWith(cycleNumber);
      expect(result).toEqual({
        cycleNumber: '2',
        startTime: '1640822400',
        endTime: '1640908799',
        isActive: false
      });
    });

    it('should handle cycle number 0', async () => {
      const cycleNumber = 0;
      const mockCycle = {
        cycleNumber: 0n,
        startTime: 1640736000n,
        endTime: 1640822399n,
        isActive: false
      };
      
      mockContract.getCycle.mockResolvedValue(mockCycle);

      const result = await cycleUpdater.getCycle(cycleNumber);

      expect(mockContract.getCycle).toHaveBeenCalledWith(0);
      expect(result.cycleNumber).toBe('0');
    });

    it('should throw error when getCycle fails', async () => {
      const error = new Error('Cycle not found');
      mockContract.getCycle.mockRejectedValue(error);

      await expect(cycleUpdater.getCycle(999)).rejects.toThrow('Failed to get cycle: Cycle not found');
    });
  });

  describe('isUpdateNeeded', () => {
    it('should return true when update is needed', async () => {
      mockContract.isUpdateNeeded.mockResolvedValue(true);

      const result = await cycleUpdater.isUpdateNeeded();

      expect(mockContract.isUpdateNeeded).toHaveBeenCalled();
      expect(result).toBe(true);
    });

    it('should return false when update is not needed', async () => {
      mockContract.isUpdateNeeded.mockResolvedValue(false);

      const result = await cycleUpdater.isUpdateNeeded();

      expect(mockContract.isUpdateNeeded).toHaveBeenCalled();
      expect(result).toBe(false);
    });

    it('should throw error when isUpdateNeeded fails', async () => {
      const error = new Error('Contract call failed');
      mockContract.isUpdateNeeded.mockRejectedValue(error);

      await expect(cycleUpdater.isUpdateNeeded()).rejects.toThrow('Failed to check if update is needed: Contract call failed');
    });
  });

  describe('Integration tests', () => {
    it('should handle complete cycle update workflow', async () => {
      // Mock the complete workflow
      mockContract.isUpdateNeeded.mockResolvedValue(true);
      mockContract.getCurrentCycle.mockResolvedValue({
        cycleNumber: 5n,
        startTime: 1640995200n,
        endTime: 1641081600n,
        isActive: true
      });
      
      const mockTx = { hash: '0xtx123' };
      mockContract.updateCycle.mockResolvedValue(mockTx);
      mockProvider.waitForTransaction.mockResolvedValue({ status: 1 });

      // Check if update is needed
      const needsUpdate = await cycleUpdater.isUpdateNeeded();
      expect(needsUpdate).toBe(true);

      // Get current cycle info
      const currentCycle = await cycleUpdater.getCurrentCycle();
      expect(currentCycle.cycleNumber).toBe('5');

      // Update cycle
      const updateResult = await cycleUpdater.updateCycle();
      expect(updateResult.hash).toBe('0xtx123');

      // Wait for confirmation
      const receipt = await updateResult.wait();
      expect(receipt.status).toBe(1);
    });

    it('should handle error scenarios gracefully', async () => {
      const error = new Error('Network error');
      mockContract.getCurrentCycle.mockRejectedValue(error);

      try {
        await cycleUpdater.getCurrentCycle();
      } catch (err) {
        expect(err.message).toBe('Failed to get current cycle: Network error');
      }
    });
  });
});
