// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {CycleUpdater} from "../src/CycleUpdater.sol";

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
