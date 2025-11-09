// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {Valuation} from "../src/Valuation.sol";
import {MinerOracle} from "../src/MinerOracle.sol";
import {MockERC20} from "../src/mock/MockERC20.sol";
import {MinerToken} from "../src/MinerToken.sol";
import {Debtor} from "../src/debtor/Debtor.sol";
import {DebtorManager} from "../src/DebtorManager.sol";

contract TestRun_CreateDebtor_MintWBTC_MintToken is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("TEST_ACCOUNT_PRIVATE_KEY");
        address mockTokenAddress = vm.envAddress("TEST_WBTC_ADDRESS");
        address debtorManagerProxy = vm.envAddress("TEST_DEBTOR_MANAGER_FBTC10_PROXY_ADDRESS");

        uint256 operatorPrivateKey = 0x147f79f0d21249e9cb94935c3a986083f43c5a5d8218ae50ae9117c6552963c8;
        address operatorAddress = 0x981Fe33c382Aded927C1CAEaaA33474B7898C051;
        
        uint256 amount = 1000 * 10**8; // 1000 tokens with 18 decimals (adjust based on token decimals)
        
       
        
        // Create debtor 

        {
            vm.startBroadcast(operatorPrivateKey);

            DebtorManager debtorManager = DebtorManager(debtorManagerProxy);
            debtorManager.createDebtor();

            vm.stopBroadcast();
        }
        
        // // Mint WBTC to operator
        // {
        //     vm.startBroadcast(deployerPrivateKey);
        
        //     MockERC20 mockToken = MockERC20(mockTokenAddress);
        //     mockToken.mint(operatorAddress, amount);
            
        //     vm.stopBroadcast();

        //     console2.log("WBTC minted successfully for operator:", operatorAddress, "Amount:", amount);
        // }



    }
}