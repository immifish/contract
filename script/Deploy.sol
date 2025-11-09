// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {CycleUpdater} from "../src/CycleUpdater.sol";
import {MinerOracle} from "../src/MinerOracle.sol";
import {MinerToken} from "../src/MinerToken.sol";
import {Valuation} from "../src/Valuation.sol";
import {DebtorManager} from "../src/DebtorManager.sol";
import {MockERC20} from "../src/mock/MockERC20.sol";
import {BatchTransfer} from "../src/helper/BatchTransfer.sol";

// Deploy CycleUpdater
// forge script script/Deploy.sol:TestDeployCycleUpdater --chain-id $BASE_SEPOLIA_CHAIN_ID --rpc-url $ALCHEMY_BASE_SEPOLIA_RPC_URL --broadcast -vvvv
// Verify Implementation: forge verify-contract --chain $BASE_SEPOLIA_CHAIN_ID --etherscan-api-key $ETHERSCAN_API_KEY --watch $TEST_CYCLE_FBTC10_IMPLEMENTATION_ADDRESS src/CycleUpdater.sol:CycleUpdater
// Verify Proxy: forge verify-contract --chain $BASE_SEPOLIA_CHAIN_ID --etherscan-api-key $ETHERSCAN_API_KEY --watch $TEST_CYCLE_UPDATER_FBTC10_PROXY_ADDRESS --constructor-args $(cast abi-encode "constructor(address,bytes)" $TEST_CYCLE_FBTC10_IMPLEMENTATION_ADDRESS $(cast abi-encode "function initialize()")) node_modules/@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy
contract TestDeployCycleUpdater is Script {
    function run() external returns (address implementation, address proxy) {
        uint256 deployerPrivateKey = vm.envUint("TEST_ACCOUNT_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy implementation
        CycleUpdater implementationContract = new CycleUpdater();

        // Prepare initializer calldata for UUPS proxy
        bytes memory initCalldata = abi.encodeWithSelector(CycleUpdater.initialize.selector);

        // Deploy ERC1967Proxy pointing to implementation with initializer
        ERC1967Proxy proxyContract = new ERC1967Proxy(address(implementationContract), initCalldata);

        vm.stopBroadcast();

        implementation = address(implementationContract);
        proxy = address(proxyContract);

        console2.log("CycleUpdater implementation:", implementation);
        console2.log("CycleUpdater proxy:", proxy);
    }
}

// Deploy MinerOracle
// forge script script/Deploy.sol:TestDeployMinerOracle --chain-id $BASE_SEPOLIA_CHAIN_ID --rpc-url $ALCHEMY_BASE_SEPOLIA_RPC_URL --broadcast -vvvv
// Verify Implementation: forge verify-contract --chain $BASE_SEPOLIA_CHAIN_ID --etherscan-api-key $ETHERSCAN_API_KEY --watch $TEST_MINER_ORACLE_IMPLEMENTATION_ADDRESS src/MinerOracle.sol:MinerOracle
// Verify Proxy: forge verify-contract --chain $BASE_SEPOLIA_CHAIN_ID --etherscan-api-key $ETHERSCAN_API_KEY --watch $TEST_MINER_ORACLE_PROXY_ADDRESS --constructor-args $(cast abi-encode "constructor(address,bytes)" $TEST_MINER_ORACLE_IMPLEMENTATION_ADDRESS $(cast abi-encode "function initialize()" $TEST_ACCOUNT_ADDRESS)) node_modules/@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy
contract TestDeployMinerOracle is Script {
    function run() external returns (address implementation, address proxy) {
        uint256 deployerPrivateKey = vm.envUint("TEST_ACCOUNT_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy implementation
        MinerOracle implementationContract = new MinerOracle();

        bytes memory initCalldata = abi.encodeWithSelector(MinerOracle.initialize.selector);

        ERC1967Proxy proxyContract = new ERC1967Proxy(address(implementationContract), initCalldata);

        vm.stopBroadcast();

        implementation = address(implementationContract);
        proxy = address(proxyContract);

        console2.log("MinerOracle implementation:", implementation);
        console2.log("MinerOracle proxy:", proxy);
    }
}

// Deploy F(BTC,10)
// forge script script/Deploy.sol:TestFBTC10 --chain-id $BASE_SEPOLIA_CHAIN_ID --rpc-url $ALCHEMY_BASE_SEPOLIA_RPC_URL --broadcast -vvvv
// Verify Implementation: forge verify-contract --chain $BASE_SEPOLIA_CHAIN_ID --etherscan-api-key $ETHERSCAN_API_KEY --watch $TEST_FBTC10_IMPLEMENTATION_ADDRESS src/MinerToken.sol:MinerToken
// Verify Proxy: forge verify-contract --chain base-sepolia --etherscan-api-key $ETHERSCAN_API_KEY --watch $TEST_FBTC10_PROXY_ADDRESS --constructor-args $(cast abi-encode "constructor(address,bytes)" $TEST_FBTC10_IMPLEMENTATION_ADDRESS $(cast abi-encode "function initialize(string,string,uint8,address,address,address,uint256)" "F(BTC,10)" "F(BTC,10)" 18 $TEST_WBTC_ADDRESS $TEST_CYCLE_UPDATER_FBTC10_PROXY_ADDRESS $TEST_FEE_RECEIVER_ADDRESS 100)) node_modules/@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy
contract TestFBTC10 is Script {
    function run() external returns (address implementation, address proxy) {
        uint256 deployerPrivateKey = vm.envUint("TEST_ACCOUNT_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy implementation
        MinerToken implementationContract = new MinerToken();
        address receiver = vm.envAddress("TEST_FEE_RECEIVER_ADDRESS");
        address wbtc = vm.envAddress("TEST_WBTC_ADDRESS");
        address cycleUpdater = vm.envAddress("TEST_CYCLE_UPDATER_FBTC10_PROXY_ADDRESS");

        // Prepare initializer calldata for UUPS proxy
        // Parameters: name, symbol, decimals, interestToken, cycleUpdater, feeReceiver, feeRate
        bytes memory initCalldata = abi.encodeWithSelector(
            MinerToken.initialize.selector,
            "F(BTC,10)",           // name
            "F(BTC,10)",                        // symbol
            18,                           // decimals
            wbtc,                   // interestToken (placeholder - should be set to actual token address)
            cycleUpdater,                   // cycleUpdater (placeholder - should be set to actual cycle updater address)
            receiver,                   // feeReceiver (deployer)
            100                          // feeRate (1% = 100/10000)
        );

        // Deploy ERC1967Proxy pointing to implementation with initializer
        ERC1967Proxy proxyContract = new ERC1967Proxy(address(implementationContract), initCalldata);

        vm.stopBroadcast();

        implementation = address(implementationContract);
        proxy = address(proxyContract);

        console2.log("Test FBTC10 implementation:", implementation);
        console2.log("Test FBTC10 proxy:", proxy);
    }
}

// Deploy WBTC
// forge script script/Deploy.sol:TestDeployWBTC --chain-id $BASE_SEPOLIA_CHAIN_ID --rpc-url $ALCHEMY_BASE_SEPOLIA_RPC_URL --broadcast -vvvv
// Verify: forge verify-contract --chain $BASE_SEPOLIA_CHAIN_ID --etherscan-api-key $ETHERSCAN_API_KEY --watch $TEST_WBTC_ADDRESS src/mock/MockERC20.sol:MockERC20
contract TestDeployWBTC is Script {
    function run() external returns (address token) {
        uint256 deployerPrivateKey = vm.envUint("TEST_ACCOUNT_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy MockERC20 as interest token
        // Parameters: name, symbol, decimals, recipient, initialSupply
        // Note: deployer (msg.sender) automatically becomes owner
        MockERC20 interestToken = new MockERC20(
            "Wrapped BTC",        // name
            "WBTC",                        // symbol
            8,                           // decimals (according to WBTC on base)
            msg.sender,                   // recipient (deployer receives initial supply)
            1000000 * 10**8             // initialSupply (1M tokens with 8 decimals)
        );

        vm.stopBroadcast();

        token = address(interestToken);

        console2.log("Interest Token deployed at:", token);
    }
}

// Deploy Valuation
// forge script script/Deploy.sol:TestDeployValuation --chain-id $BASE_SEPOLIA_CHAIN_ID --rpc-url $ALCHEMY_BASE_SEPOLIA_RPC_URL --broadcast -vvvv
// Verify Implementation: forge verify-contract --chain $BASE_SEPOLIA_CHAIN_ID --etherscan-api-key $ETHERSCAN_API_KEY --watch $TEST_VALUATION_IMPLEMENTATION_ADDRESS src/Valuation.sol:Valuation
// Verify Proxy: forge verify-contract --chain $BASE_SEPOLIA_CHAIN_ID --etherscan-api-key $ETHERSCAN_API_KEY --watch $TEST_VALUATION_PROXY_ADDRESS --constructor-args $(cast abi-encode "constructor(address,bytes)" $TEST_VALUATION_IMPLEMENTATION_ADDRESS $(cast abi-encode "function initialize(address)" $TEST_MINER_ORACLE_PROXY_ADDRESS)) node_modules/@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy
contract TestDeployValuation is Script {
    function run() external returns (address implementation, address proxy) {
        uint256 deployerPrivateKey = vm.envUint("TEST_ACCOUNT_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy implementation
        Valuation implementationContract = new Valuation();
        address minerOracle = vm.envAddress("TEST_MINER_ORACLE_PROXY_ADDRESS");

        // Prepare initializer calldata for UUPS proxy
        bytes memory initCalldata = abi.encodeWithSelector(Valuation.initialize.selector, minerOracle);

        // Deploy ERC1967Proxy pointing to implementation with initializer
        ERC1967Proxy proxyContract = new ERC1967Proxy(address(implementationContract), initCalldata);

        vm.stopBroadcast();

        implementation = address(implementationContract);
        proxy = address(proxyContract);

        console2.log("Valuation implementation:", implementation);
        console2.log("Valuation proxy:", proxy);
    }
}

// Deploy DebtorManager
// forge script script/Deploy.sol:TestDeployDebtorManagerForFBTC10 --chain-id $BASE_SEPOLIA_CHAIN_ID --rpc-url $ALCHEMY_BASE_SEPOLIA_RPC_URL --broadcast -vvvv
// Verify Implementation: forge verify-contract --chain $BASE_SEPOLIA_CHAIN_ID --etherscan-api-key $ETHERSCAN_API_KEY --watch $TEST_DEBTOR_MANAGER_FBTC10_IMPLEMENTATION_ADDRESS src/DebtorManager.sol:DebtorManager
// Verify Proxy: forge verify-contract --chain $BASE_SEPOLIA_CHAIN_ID --etherscan-api-key $ETHERSCAN_API_KEY --watch $TEST_DEBTOR_MANAGER_FBTC10_PROXY_ADDRESS --constructor-args $(cast abi-encode "constructor(address,bytes)" $TEST_DEBTOR_MANAGER_FBTC10_IMPLEMENTATION_ADDRESS $(cast abi-encode "function initialize(address,address,address,int256,int256)" $TEST_FBTC10_PROXY_ADDRESS $TEST_CYCLE_UPDATER_FBTC10_PROXY_ADDRESS $TEST_VALUATION_PROXY_ADDRESS 12000 15000)) node_modules/@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy
contract TestDeployDebtorManagerForFBTC10 is Script {
    function run() external returns (address implementation, address proxy) {
        uint256 deployerPrivateKey = vm.envUint("TEST_ACCOUNT_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy implementation
        DebtorManager implementationContract = new DebtorManager();
        
        // Get environment variables for dependencies
        address minerToken = vm.envAddress("TEST_FBTC10_PROXY_ADDRESS");
        address cycleUpdater = vm.envAddress("TEST_CYCLE_UPDATER_FBTC10_PROXY_ADDRESS");
        address valuationService = vm.envAddress("TEST_VALUATION_PROXY_ADDRESS");
        
        // Set default collateral ratios (scaled by 10000)
        // minCollateralRatio: 120% = 12000/10000
        // marginBufferedCollateralRatio: 150% = 15000/10000
        int256 minCollateralRatio = 12000;
        int256 marginBufferedCollateralRatio = 15000;

        // Prepare initializer calldata for UUPS proxy
        bytes memory initCalldata = abi.encodeWithSelector(
            DebtorManager.initialize.selector,
            minerToken,
            cycleUpdater,
            valuationService,
            minCollateralRatio,
            marginBufferedCollateralRatio
        );

        // Deploy ERC1967Proxy pointing to implementation with initializer
        ERC1967Proxy proxyContract = new ERC1967Proxy(address(implementationContract), initCalldata);

        vm.stopBroadcast();

        implementation = address(implementationContract);
        proxy = address(proxyContract);

        console2.log("DebtorManager implementation:", implementation);
        console2.log("DebtorManager proxy:", proxy);
        console2.log("MinerToken address:", minerToken);
        console2.log("CycleUpdater address:", cycleUpdater);
        console2.log("ValuationService address:", valuationService);
        console2.log("Min collateral ratio:", minCollateralRatio);
        console2.log("Margin buffered collateral ratio:", marginBufferedCollateralRatio);
    }
}

// Deploy BatchTransfer
// forge script script/Deploy.sol:TestDeployBatchTransfer --chain-id $BASE_SEPOLIA_CHAIN_ID --rpc-url $ALCHEMY_BASE_SEPOLIA_RPC_URL --broadcast -vvvv
// Verify: forge verify-contract --chain $BASE_SEPOLIA_CHAIN_ID --etherscan-api-key $ETHERSCAN_API_KEY --watch $TEST_BATCH_TRANSFER src/helper/BatchTransfer.sol:BatchTransfer
contract TestDeployBatchTransfer is Script {
    function run() external returns (address batchTransfer) {
        uint256 deployerPrivateKey = vm.envUint("TEST_ACCOUNT_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy BatchTransfer contract (not upgradeable, so no proxy needed)
        BatchTransfer batchTransferContract = new BatchTransfer();

        vm.stopBroadcast();

        batchTransfer = address(batchTransferContract);

        console2.log("BatchTransfer deployed at:", batchTransfer);
    }
}

// Upgrade Valuation
// forge script script/Deploy.sol:UpgradeValuation --chain-id $BASE_SEPOLIA_CHAIN_ID --rpc-url $ALCHEMY_BASE_SEPOLIA_RPC_URL --broadcast -vvvv
contract UpgradeValuation is Script {
    function run() external returns (address newImplementation) {
        uint256 deployerPrivateKey = vm.envUint("TEST_ACCOUNT_PRIVATE_KEY");
        address valuationProxy = vm.envAddress("TEST_VALUATION_PROXY_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy new implementation
        Valuation newImplementationContract = new Valuation();

        // Upgrade the proxy to point to the new implementation
        Valuation valuation = Valuation(valuationProxy);
        valuation.upgradeToAndCall(address(newImplementationContract), "");

        vm.stopBroadcast();

        newImplementation = address(newImplementationContract);

        console2.log("Valuation upgrade completed!");
        console2.log("New implementation address:", newImplementation);
        console2.log("Proxy address (unchanged):", valuationProxy);
    }
}

// Upgrade Cycle Updater
// forge script script/Deploy.sol:UpgradeCycleUpdater --chain-id $BASE_SEPOLIA_CHAIN_ID --rpc-url $ALCHEMY_BASE_SEPOLIA_RPC_URL --broadcast -vvvv
contract UpgradeCycleUpdater is Script {
    function run() external returns (address newImplementation) {
        uint256 deployerPrivateKey = vm.envUint("TEST_ACCOUNT_PRIVATE_KEY");
        address cycleUpdaterProxy = vm.envAddress("TEST_CYCLE_UPDATER_FBTC10_PROXY_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy new implementation
        CycleUpdater newImplementationContract = new CycleUpdater();

        // Upgrade the proxy to point to the new implementation
        CycleUpdater cycleUpdater = CycleUpdater(cycleUpdaterProxy);
        cycleUpdater.upgradeToAndCall(address(newImplementationContract), "");

        vm.stopBroadcast();

        newImplementation = address(newImplementationContract);

        console2.log("CycleUpdater upgrade completed!");
        console2.log("New implementation address:", newImplementation);
        console2.log("Proxy address (unchanged):", cycleUpdaterProxy);
    }
}

// Upgrade DebtorManager
// forge script script/Deploy.sol:UpgradeDebtorManager --chain-id $BASE_SEPOLIA_CHAIN_ID --rpc-url $ALCHEMY_BASE_SEPOLIA_RPC_URL --broadcast -vvvv
contract UpgradeDebtorManager is Script {
    function run() external returns (address newImplementation) {
        uint256 deployerPrivateKey = vm.envUint("TEST_ACCOUNT_PRIVATE_KEY");
        address debtorManagerProxy = vm.envAddress("TEST_DEBTOR_MANAGER_FBTC10_PROXY_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy new implementation
        DebtorManager newImplementationContract = new DebtorManager();

        // Upgrade the proxy to point to the new implementation
        DebtorManager debtorManager = DebtorManager(debtorManagerProxy);
        debtorManager.upgradeToAndCall(address(newImplementationContract), "");

        vm.stopBroadcast();

        newImplementation = address(newImplementationContract);

        console2.log("DebtorManager upgrade completed!");
        console2.log("New implementation address:", newImplementation);
        console2.log("Proxy address (unchanged):", debtorManagerProxy);
    }
}
