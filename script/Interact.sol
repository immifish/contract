// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {Valuation} from "../src/Valuation.sol";

contract SetDataFeedForWBTC is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("TEST_ACCOUNT_PRIVATE_KEY");
        address valuationProxy = vm.envAddress("TEST_VALUATION_PROXY_ADDRESS");
        
        // Parameters - modify these directly in the script
        address asset = 0x2906C5C8Ac0Aff8FAe91599b85c30Ee301e8d485; //
        address aggregator = 0x0FB99723Aee6f420beAD13e6bBB79b7E6F034298; // Replace with actual Chainlink aggregator address
        uint256 tokenDecimal = 8; // Token decimals (e.g., 8 for WBTC, 18 for most ERC20s)
        
        vm.startBroadcast(deployerPrivateKey);
        
        Valuation valuation = Valuation(valuationProxy);
        valuation.setDataFeed(asset, aggregator, tokenDecimal);
        
        vm.stopBroadcast();
        
        console2.log("Data feed set successfully!");
        console2.log("Asset:", asset);
        console2.log("Aggregator:", aggregator);
        console2.log("Token Decimal:", tokenDecimal);
    }
}
