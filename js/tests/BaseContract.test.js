import { describe, it, expect, beforeEach, jest } from '@jest/globals';
import { BaseContract } from '../src/contracts/BaseContract.js';

// Mock ethers Contract
const mockContract = {
  estimateGas: jest.fn(),
  on: jest.fn(),
  off: jest.fn()
};

// Mock provider
const mockProvider = {
  getTransactionReceipt: jest.fn(),
  waitForTransaction: jest.fn()
};

describe('BaseContract', () => {
  let baseContract;
  const mockAddress = '0x1234567890123456789012345678901234567890';
  const mockAbi = [{ name: 'testMethod', type: 'function' }];

  beforeEach(() => {
    jest.clearAllMocks();
    
    // Create new instance for each test
    baseContract = new BaseContract(mockAddress, mockAbi, mockProvider);
    
    // Replace the contract instance with our mock
    baseContract.contract = mockContract;
  });

  describe('Constructor', () => {
    it('should create instance with correct properties', () => {
      expect(baseContract.address).toBe(mockAddress);
      expect(baseContract.abi).toBe(mockAbi);
      expect(baseContract.provider).toBe(mockProvider);
    });
  });

  describe('getContract', () => {
    it('should return contract instance', () => {
      const contract = baseContract.getContract();
      expect(contract).toBe(mockContract);
    });
  });

  describe('getAddress', () => {
    it('should return contract address', () => {
      const address = baseContract.getAddress();
      expect(address).toBe(mockAddress);
    });
  });

  describe('estimateGas', () => {
    it('should estimate gas for method', async () => {
      const mockGasEstimate = 100000n;
      // Mock the method on the contract
      baseContract.contract.testMethod = {
        estimateGas: jest.fn().mockResolvedValue(mockGasEstimate)
      };

      const result = await baseContract.estimateGas('testMethod', 'param1', 'param2');

      expect(baseContract.contract.testMethod.estimateGas).toHaveBeenCalledWith('param1', 'param2');
      expect(result).toBe(mockGasEstimate);
    });

    it('should throw error when gas estimation fails', async () => {
      const error = new Error('Gas estimation failed');
      // Mock the method on the contract
      baseContract.contract.testMethod = {
        estimateGas: jest.fn().mockRejectedValue(error)
      };

      await expect(baseContract.estimateGas('testMethod')).rejects.toThrow('Gas estimation failed for testMethod: Gas estimation failed');
    });
  });

  describe('getTransactionReceipt', () => {
    it('should get transaction receipt', async () => {
      const mockReceipt = { status: 1, blockNumber: 12345 };
      mockProvider.getTransactionReceipt.mockResolvedValue(mockReceipt);

      const result = await baseContract.getTransactionReceipt('0xtx123');

      expect(mockProvider.getTransactionReceipt).toHaveBeenCalledWith('0xtx123');
      expect(result).toBe(mockReceipt);
    });

    it('should throw error when getting receipt fails', async () => {
      const error = new Error('Receipt not found');
      mockProvider.getTransactionReceipt.mockRejectedValue(error);

      await expect(baseContract.getTransactionReceipt('0xtx123')).rejects.toThrow('Failed to get transaction receipt: Receipt not found');
    });
  });

  describe('waitForTransaction', () => {
    it('should wait for transaction with default confirmations', async () => {
      const mockReceipt = { status: 1, blockNumber: 12345 };
      mockProvider.waitForTransaction.mockResolvedValue(mockReceipt);

      const result = await baseContract.waitForTransaction('0xtx123');

      expect(mockProvider.waitForTransaction).toHaveBeenCalledWith('0xtx123', 1);
      expect(result).toBe(mockReceipt);
    });

    it('should wait for transaction with custom confirmations', async () => {
      const mockReceipt = { status: 1, blockNumber: 12345 };
      mockProvider.waitForTransaction.mockResolvedValue(mockReceipt);

      const result = await baseContract.waitForTransaction('0xtx123', 3);

      expect(mockProvider.waitForTransaction).toHaveBeenCalledWith('0xtx123', 3);
      expect(result).toBe(mockReceipt);
    });

    it('should throw error when transaction fails', async () => {
      const error = new Error('Transaction failed');
      mockProvider.waitForTransaction.mockRejectedValue(error);

      await expect(baseContract.waitForTransaction('0xtx123')).rejects.toThrow('Transaction failed: Transaction failed');
    });
  });

  describe('Event handling', () => {
    it('should add event listener', () => {
      const mockCallback = jest.fn();
      const mockUnsubscribe = jest.fn();
      mockContract.on.mockReturnValue(mockUnsubscribe);

      const unsubscribe = baseContract.on('Transfer', mockCallback);

      expect(mockContract.on).toHaveBeenCalledWith('Transfer', mockCallback);
      expect(unsubscribe).toBe(mockUnsubscribe);
    });

    it('should remove event listener', () => {
      const mockCallback = jest.fn();
      mockContract.off.mockReturnValue(undefined);

      baseContract.off('Transfer', mockCallback);

      expect(mockContract.off).toHaveBeenCalledWith('Transfer', mockCallback);
    });
  });
});
