# ----------------------- Base Sepolia (Testnet)

## Deploy CycleUpdater
forge script script/Deploy.sol:TestDeployCycleUpdater \
  --chain-id $BASE_SEPOLIA_CHAIN_ID \
  --rpc-url $ALCHEMY_BASE_SEPOLIA_RPC_URL \
  --broadcast \
  -vvvv

## Verify CycleUpdater
forge verify-contract \
  --chain $BASE_SEPOLIA_CHAIN_ID \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --watch \
  $TEST_CYCLE_IMPLEMENTATION_ADDRESS \
  src/CycleUpdater.sol:CycleUpdater

## Verify CycleUpdater Proxy (with constructor args)
forge verify-contract \
  --chain $BASE_SEPOLIA_CHAIN_ID \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --watch \
  $TEST_CYCLE_UPDATER_PROXY_ADDRESS \
  --constructor-args $(cast abi-encode "constructor(address,bytes)" \
    $TEST_CYCLE_IMPLEMENTATION_ADDRESS \
    $(cast abi-encode "function initialize()")) \
  node_modules/@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy


## Deploy MinerOracle
forge script script/Deploy.sol:TestDeployMinerOracle \
  --chain-id $BASE_SEPOLIA_CHAIN_ID \
  --rpc-url $ALCHEMY_BASE_SEPOLIA_RPC_URL \
  --broadcast \
  -vvvv

## Verify MinerOracle
forge verify-contract \
  --chain $BASE_SEPOLIA_CHAIN_ID \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --watch \
  $TEST_MINER_ORACLE_IMPLEMENTATION_ADDRESS \
  src/MinerOracle.sol:MinerOracle
  
## Verify MinerOracle Proxy (with constructor args)
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

## Deploy WBTC
forge script script/Deploy.sol:TestDeployWBTC \
  --chain-id $BASE_SEPOLIA_CHAIN_ID \
  --rpc-url $ALCHEMY_BASE_SEPOLIA_RPC_URL \
  --broadcast \
  -vvvv

## Verify WBTC
forge verify-contract \
  --chain $BASE_SEPOLIA_CHAIN_ID \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --watch \
  $TEST_WBTC_ADDRESS \
  src/mock/MockERC20.sol:MockERC20

## Deploy F(BTC,10)
forge script script/Deploy.sol:TestFBTC10 \
  --chain-id $BASE_SEPOLIA_CHAIN_ID \
  --rpc-url $ALCHEMY_BASE_SEPOLIA_RPC_URL \
  --broadcast \
  -vvvv

## Verify F(BTC,10) (implementation)
forge verify-contract \
  --chain $BASE_SEPOLIA_CHAIN_ID \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --watch \
  $TEST_FBTC10_IMPLEMENTATION_ADDRESS \
  src/MinerToken.sol:MinerToken

## Verify F(BTC,10) Proxy (with constructor args)
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
      $TEST_CYCLE_UPDATER_PROXY_ADDRESS \
      $TEST_FEE_RECEIVER_ADDRESS \
      100)) \
  node_modules/@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy
