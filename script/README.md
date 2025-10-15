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