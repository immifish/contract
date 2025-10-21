# ----------------------- Base Sepolia (Testnet)

## Deploy CycleUpdater

```bash
forge script script/Deploy.sol:TestDeployCycleUpdater \
  --chain-id $BASE_SEPOLIA_CHAIN_ID \
  --rpc-url $ALCHEMY_BASE_SEPOLIA_RPC_URL \
  --broadcast \
  -vvvv
```

## Verify CycleUpdater

```bash
forge verify-contract \
  --chain $BASE_SEPOLIA_CHAIN_ID \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --watch \
  $TEST_CYCLE_FBTC10_IMPLEMENTATION_ADDRESS \
  src/CycleUpdater.sol:CycleUpdater
```

## Verify CycleUpdater Proxy (with constructor args)

```bash
forge verify-contract \
  --chain $BASE_SEPOLIA_CHAIN_ID \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --watch \
  $TEST_CYCLE_UPDATER_FBTC10_PROXY_ADDRESS \
  --constructor-args $(cast abi-encode "constructor(address,bytes)" \
    $TEST_CYCLE_FBTC10_IMPLEMENTATION_ADDRESS \
    $(cast abi-encode "function initialize()")) \
  node_modules/@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy
```

## Deploy MinerOracle

```bash
forge script script/Deploy.sol:TestDeployMinerOracle \
  --chain-id $BASE_SEPOLIA_CHAIN_ID \
  --rpc-url $ALCHEMY_BASE_SEPOLIA_RPC_URL \
  --broadcast \
  -vvvv
```

## Verify MinerOracle

```bash
forge verify-contract \
  --chain $BASE_SEPOLIA_CHAIN_ID \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --watch \
  $TEST_MINER_ORACLE_IMPLEMENTATION_ADDRESS \
  src/MinerOracle.sol:MinerOracle
```

## Verify MinerOracle Proxy (with constructor args)

```bash
forge verify-contract \
  --chain $BASE_SEPOLIA_CHAIN_ID \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --watch \
  $TEST_MINER_ORACLE_PROXY_ADDRESS \
  --constructor-args $(cast abi-encode "constructor(address,bytes)" \
    $TEST_MINER_ORACLE_IMPLEMENTATION_ADDRESS \
    $(cast abi-encode "function initialize(address)" \
    $TEST_ACCOUNT_ADDRESS
    )) \
  node_modules/@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy
```

## Deploy WBTC

```bash
forge script script/Deploy.sol:TestDeployWBTC \
  --chain-id $BASE_SEPOLIA_CHAIN_ID \
  --rpc-url $ALCHEMY_BASE_SEPOLIA_RPC_URL \
  --broadcast \
  -vvvv
```

## Verify WBTC

```bash
forge verify-contract \
  --chain $BASE_SEPOLIA_CHAIN_ID \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --watch \
  $TEST_WBTC_ADDRESS \
  src/mock/MockERC20.sol:MockERC20
```

## Deploy F(BTC,10)

```bash
forge script script/Deploy.sol:TestFBTC10 \
  --chain-id $BASE_SEPOLIA_CHAIN_ID \
  --rpc-url $ALCHEMY_BASE_SEPOLIA_RPC_URL \
  --broadcast \
  -vvvv
```

## Verify F(BTC,10) (implementation)

```bash
forge verify-contract \
  --chain $BASE_SEPOLIA_CHAIN_ID \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --watch \
  $TEST_FBTC10_IMPLEMENTATION_ADDRESS \
  src/MinerToken.sol:MinerToken
```

## Verify F(BTC,10) Proxy (with constructor args)

```bash
forge verify-contract \
  --chain base-sepolia \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --watch \
  $TEST_FBTC10_PROXY_ADDRESS \
  --constructor-args $(cast abi-encode "constructor(address,bytes)" \
    $TEST_FBTC10_IMPLEMENTATION_ADDRESS \
    $(cast abi-encode \
      "function initialize(string,string,uint8,address,address,address,uint256)" \
      "F(BTC,10)" \
      "F(BTC,10)" \
      18 \
      $TEST_WBTC_ADDRESS \
      $TEST_CYCLE_UPDATER_FBTC10_PROXY_ADDRESS \
      $TEST_FEE_RECEIVER_ADDRESS \
      100)) \
  node_modules/@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy
```

## Deploy Valuation

```bash
forge script script/Deploy.sol:TestDeployValuation \
  --chain-id $BASE_SEPOLIA_CHAIN_ID \
  --rpc-url $ALCHEMY_BASE_SEPOLIA_RPC_URL \
  --broadcast \
  -vvvv
```

## Verify Valuation (implementation)

```bash
forge verify-contract \
  --chain $BASE_SEPOLIA_CHAIN_ID \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --watch \
  $TEST_VALUATION_IMPLEMENTATION_ADDRESS \
  src/Valuation.sol:Valuation
```

## Verify Valuation Proxy (with constructor args)

```bash
forge verify-contract \
  --chain $BASE_SEPOLIA_CHAIN_ID \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --watch \
  $TEST_VALUATION_PROXY_ADDRESS \
  --constructor-args $(cast abi-encode "constructor(address,bytes)" \
    $TEST_VALUATION_IMPLEMENTATION_ADDRESS \
    $(cast abi-encode "function initialize(address)" \
    $TEST_MINER_ORACLE_PROXY_ADDRESS)) \
  node_modules/@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy
```

## Deploy DebtorManager

```bash
forge script script/Deploy.sol:TestDeployDebtorManagerForFBTC10 \
  --chain-id $BASE_SEPOLIA_CHAIN_ID \
  --rpc-url $ALCHEMY_BASE_SEPOLIA_RPC_URL \
  --broadcast \
  -vvvv
```

## Verify DebtorManager (implementation)

```bash
forge verify-contract \
  --chain $BASE_SEPOLIA_CHAIN_ID \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --watch \
  $TEST_DEBTOR_MANAGER_FBTC10_IMPLEMENTATION_ADDRESS \
  src/DebtorManager.sol:DebtorManager
```

## Verify DebtorManager Proxy (with constructor args)

```bash
forge verify-contract \
  --chain $BASE_SEPOLIA_CHAIN_ID \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --watch \
  $TEST_DEBTOR_MANAGER_FBTC10_PROXY_ADDRESS \
  --constructor-args $(cast abi-encode "constructor(address,bytes)" \
    $TEST_DEBTOR_MANAGER_FBTC10_IMPLEMENTATION_ADDRESS \
    $(cast abi-encode \
      "function initialize(address,address,address,int256,int256)" \
      $TEST_FBTC10_PROXY_ADDRESS \
      $TEST_CYCLE_UPDATER_FBTC10_PROXY_ADDRESS \
      $TEST_VALUATION_PROXY_ADDRESS \
      12000 \
      15000)) \
  node_modules/@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy
```

