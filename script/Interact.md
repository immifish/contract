# Valuation Contract Interaction Scripts

## Set Data Feed for WBTC

```bash
forge script script/Interact.sol:SetDataFeedForWBTC \
  --chain-id $BASE_SEPOLIA_CHAIN_ID \
  --rpc-url $ALCHEMY_BASE_SEPOLIA_RPC_URL \
  --broadcast \
  -vvvv
```

## Set LTV for WBTC/FBTC10

Sets the Loan-to-Value (LTV) ratio for WBTC as collateral against FBTC10 loans.

```bash
forge script script/Interact.sol:SetLtv_WBTC_FBTC10 \
  --chain-id $BASE_SEPOLIA_CHAIN_ID \
  --rpc-url $ALCHEMY_BASE_SEPOLIA_RPC_URL \
  --broadcast \
  -vvvv
```

## Set Token Price for FBTC10

```bash
forge script script/Interact.sol:SetTokenPrice_FBTC10 \
  --chain-id $BASE_SEPOLIA_CHAIN_ID \
  --rpc-url $ALCHEMY_BASE_SEPOLIA_RPC_URL \
  --broadcast \
  -vvvv
```

## Set Miner Oracle for Valuation

```bash
forge script script/Interact.sol:SetMinerOracle \
  --chain-id $BASE_SEPOLIA_CHAIN_ID \
  --rpc-url $ALCHEMY_BASE_SEPOLIA_RPC_URL \
  --broadcast \
  -vvvv
```