# Tests

This directory contains comprehensive tests for the Immi Protocol JavaScript SDK.

## Test Structure

- `BaseContract.test.js` - Tests for the base contract class functionality
- `CycleUpdater.test.js` - Tests for the CycleUpdater contract interaction class

## Running Tests

### Run all tests
```bash
npm test
```

### Run tests with coverage
```bash
npm test -- --coverage
```

### Run specific test file
```bash
npx jest tests/CycleUpdater.test.js
```

### Run tests in watch mode
```bash
npm test -- --watch
```

## Test Coverage

The tests provide comprehensive coverage for:

### CycleUpdater Class
- ✅ Constructor and initialization
- ✅ `updateCycle()` method with various options
- ✅ `getCurrentCycle()` method
- ✅ `getCycle(cycleNumber)` method
- ✅ `isUpdateNeeded()` method
- ✅ Error handling for all methods
- ✅ Integration workflow tests

### BaseContract Class
- ✅ Constructor and initialization
- ✅ `getContract()` and `getAddress()` methods
- ✅ `estimateGas()` method
- ✅ `getTransactionReceipt()` method
- ✅ `waitForTransaction()` method
- ✅ Event handling (`on()` and `off()` methods)
- ✅ Error handling for all methods

## Test Features

- **Mocking**: Uses Jest mocks to simulate ethers.js contract interactions
- **Error Testing**: Comprehensive error scenario testing
- **Integration Tests**: End-to-end workflow testing
- **Edge Cases**: Tests for boundary conditions and edge cases
- **Type Safety**: Tests ensure proper data type handling (BigInt to string conversion)

## Dependencies

- Jest - Testing framework
- @jest/globals - Jest globals for ES modules
- @babel/core - JavaScript transpilation
- @babel/preset-env - Babel environment preset
- babel-jest - Jest Babel transformer

## Configuration

Tests are configured using:
- `jest.config.cjs` - Jest configuration
- `babel.config.cjs` - Babel configuration for ES modules

The configuration supports ES modules and provides proper mocking for ethers.js interactions.
