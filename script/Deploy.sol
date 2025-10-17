// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {CycleUpdater} from "../src/CycleUpdater.sol";
import {MinerOracle} from "../src/MinerOracle.sol";
import {MinerToken} from "../src/MinerToken.sol";
import {MockERC20} from "../src/mock/MockERC20.sol";

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

contract TestDeployMinerOracle is Script {
    function run() external returns (address implementation, address proxy) {
        uint256 deployerPrivateKey = vm.envUint("TEST_ACCOUNT_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy implementation
        MinerOracle implementationContract = new MinerOracle();

        bytes memory initCalldata = abi.encodeWithSelector(MinerOracle.initialize.selector, msg.sender);

        ERC1967Proxy proxyContract = new ERC1967Proxy(address(implementationContract), initCalldata);

        vm.stopBroadcast();

        implementation = address(implementationContract);
        proxy = address(proxyContract);

        console2.log("MinerOracle implementation:", implementation);
        console2.log("MinerOracle proxy:", proxy);
    }
}

contract TestFBTC10 is Script {
    function run() external returns (address implementation, address proxy) {
        uint256 deployerPrivateKey = vm.envUint("TEST_ACCOUNT_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy implementation
        MinerToken implementationContract = new MinerToken();
        address receiver = vm.envAddress("TEST_FEE_RECEIVER_ADDRESS");
        address wbtc = vm.envAddress("TEST_WBTC_ADDRESS");
        address cycleUpdater = vm.envAddress("TEST_CYCLE_UPDATER_PROXY_ADDRESS");

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

        console2.log("MinerToken implementation:", implementation);
        console2.log("MinerToken proxy:", proxy);
    }
}

contract TestDeployWBTC is Script {
    function run() external returns (address token) {
        uint256 deployerPrivateKey = vm.envUint("TEST_ACCOUNT_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy MockERC20 as interest token
        // Parameters: name, symbol, decimals, initialOwner, initialSupply
        MockERC20 interestToken = new MockERC20(
            "Wrapped BTC",        // name
            "WBTC",                        // symbol
            8,                           // decimals (according to WBTC on base)
            msg.sender,                   // initialOwner (deployer)
            1000000 * 10**8             // initialSupply (1M tokens with 18 decimals)
        );

        vm.stopBroadcast();

        token = address(interestToken);

        console2.log("Interest Token deployed at:", token);
    }
}