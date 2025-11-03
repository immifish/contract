// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {Valuation} from "../src/Valuation.sol";
import {MinerOracle} from "../src/MinerOracle.sol";
import {MockERC20} from "../src/mock/MockERC20.sol";
import {MinerToken} from "../src/MinerToken.sol";
import {Debtor} from "../src/debtor/Debtor.sol";

contract SetDataFeedForWBTC is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("TEST_ACCOUNT_PRIVATE_KEY");
        address valuationProxy = vm.envAddress("TEST_VALUATION_PROXY_ADDRESS");
        
        // Parameters - modify these directly in the script
        address asset = vm.envAddress("TEST_WBTC_ADDRESS"); //
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

contract SetLtv_WBTC_FBTC10 is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("TEST_ACCOUNT_PRIVATE_KEY");
        address valuationProxy = vm.envAddress("TEST_VALUATION_PROXY_ADDRESS");
        
        // Parameters - modify these directly in the script
        address collateralAsset = vm.envAddress("TEST_WBTC_ADDRESS"); // WBTC address
        address loanAsset = vm.envAddress("TEST_FBTC10_PROXY_ADDRESS"); // FBTC10 address
        int256 ltv = 8000; // 80% LTV (scaled by 10000)
        bool isValid = true; // Set to true to enable, false to disable
        
        vm.startBroadcast(deployerPrivateKey);
        
        Valuation valuation = Valuation(valuationProxy);
        valuation.setLtv(collateralAsset, loanAsset, ltv, isValid);
        
        vm.stopBroadcast();
        
        console2.log("LTV set successfully!");
        console2.log("Collateral Asset:", collateralAsset);
        console2.log("Loan Asset:", loanAsset);
        console2.log("LTV:", ltv);
        console2.log("Is Valid:", isValid);
    }
}

contract SetTokenPrice_FBTC10 is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("TEST_ACCOUNT_PRIVATE_KEY");
        address minerOracleAddress = vm.envAddress("TEST_MINER_ORACLE_PROXY_ADDRESS");
        
        // Parameters - modify these directly in the script
        address minerToken = vm.envAddress("TEST_FBTC10_PROXY_ADDRESS"); // FBTC10 address
        int256 price = 2000000000; // $20 USD (scaled by 10^8 for USD decimal)
        
        vm.startBroadcast(deployerPrivateKey);
        
        MinerOracle minerOracle = MinerOracle(minerOracleAddress);
        minerOracle.setTokenPrice(minerToken, price);
        
        vm.stopBroadcast();
        
        console2.log("Token price set successfully!");
        console2.log("Miner Token:", minerToken);
        console2.log("Price:", price);
        console2.log("Price in USD:", uint256(price) / 10**8);
    }
}

contract SetMinerOracle is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("TEST_ACCOUNT_PRIVATE_KEY");
        address valuationProxy = vm.envAddress("TEST_VALUATION_PROXY_ADDRESS");
        
        // Parameters - modify these directly in the script
        address minerOracleAddress = vm.envAddress("TEST_MINER_ORACLE_PROXY_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);
        
        Valuation valuation = Valuation(valuationProxy);
        valuation.setMinerOracle(minerOracleAddress);
        
        vm.stopBroadcast();
        
        console2.log("Miner Oracle set successfully!");
        console2.log("Valuation Proxy:", valuationProxy);
        console2.log("Miner Oracle Address:", minerOracleAddress);
    }
}

contract SetDebtorManagerForFBTC10 is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("TEST_ACCOUNT_PRIVATE_KEY");
        address minerTokenProxy = vm.envAddress("TEST_FBTC10_PROXY_ADDRESS");

        // Parameters - modify these directly in the script
        address debtorManagerAddress = vm.envAddress("TEST_DEBTOR_MANAGER_FBTC10_PROXY_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        MinerToken minerToken = MinerToken(minerTokenProxy);
        minerToken.setDebtorManager(debtorManagerAddress);

        vm.stopBroadcast();

        console2.log("Debtor Manager set successfully!");
        console2.log("MinerToken Proxy:", minerTokenProxy);
        console2.log("DebtorManager Address:", debtorManagerAddress);
    }
}

contract MintWBTC is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("TEST_ACCOUNT_PRIVATE_KEY");
        address mockTokenAddress = vm.envAddress("TEST_WBTC_ADDRESS");
        
        // Parameters - modify these directly in the script
        address recipient = 0x1bF5c8C327ECf83Adf7CdCeeb2173fd085968fBe; // Replace with recipient address
        uint256 amount = 1000 * 10**8; // 1000 tokens with 18 decimals (adjust based on token decimals)
        
        vm.startBroadcast(deployerPrivateKey);
        
        MockERC20 mockToken = MockERC20(mockTokenAddress);
        mockToken.mint(recipient, amount);
        
        vm.stopBroadcast();
        
        console2.log("MockERC20 minted successfully!");
        console2.log("Token Address:", mockTokenAddress);
        console2.log("Recipient:", recipient);
        console2.log("Amount:", amount);
    }
}

contract DebtorMint is Script {
    function run() external {
        uint256 ownerPrivateKey = vm.envUint("TEST_ACCOUNT_PRIVATE_KEY");
        address debtorAddress = 0xedd2635a1B1800c6668dDA30C5B11338d40Fb004;
        address to = 0x1bF5c8C327ECf83Adf7CdCeeb2173fd085968fBe;

        // Parameters - modify via env
        uint256 amount = 1 * 10**18;

        vm.startBroadcast(ownerPrivateKey);

        Debtor debtor = Debtor(debtorAddress);
        debtor.mint(amount, to);

        vm.stopBroadcast();

        console2.log("Debtor minted successfully!");
        console2.log("Debtor:", debtorAddress);
        console2.log("Amount:", amount);
    }
}

