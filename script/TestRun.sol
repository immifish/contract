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

//Set run script
// forge script script/TestRun.sol:TestRun_CreateDebtor_MintWBTC_MintToken --chain-id $BASE_SEPOLIA_CHAIN_ID --rpc-url $ALCHEMY_BASE_SEPOLIA_RPC_URL --broadcast -vvvv
contract TestRun_CreateDebtor_MintWBTC_MintToken is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("TEST_ACCOUNT_PRIVATE_KEY");
        address wbtcAddress = vm.envAddress("TEST_WBTC_ADDRESS");
        address debtorManagerProxy = vm.envAddress("TEST_DEBTOR_MANAGER_FBTC10_PROXY_ADDRESS");

        uint256 operatorPrivateKey = 0x147f79f0d21249e9cb94935c3a986083f43c5a5d8218ae50ae9117c6552963c8;
        address operatorAddress = 0x981Fe33c382Aded927C1CAEaaA33474B7898C051;
    
        
        //send eth to operator
        // {
        //     vm.startBroadcast(deployerPrivateKey);
        //     (bool success, ) = payable(operatorAddress).call{value: 0.01 ether}("");
        //     require(success, "Failed to send ETH to operator");
        //     vm.stopBroadcast();
        //     console2.log("ETH sent to operator successfully:", operatorAddress);
        // }
        
        // Create debtor 
        DebtorManager debtorManager = DebtorManager(debtorManagerProxy);
        address debtorAddress; //0x9988E8480a4FF68c7D0872161A982338E0Cae84e

        // {
        //     vm.startBroadcast(operatorPrivateKey);
        //     DebtorManager debtorManager = DebtorManager(debtorManagerProxy);
        //     debtorManager.createDebtor();

        //     vm.stopBroadcast();
            
        // }
        
        debtorAddress = debtorManager.getDebtor(operatorAddress);
        console2.log("Debtor address is:", debtorAddress);

        // // Mint WBTC to operator
        // {
        //     vm.startBroadcast(deployerPrivateKey);
        
        //     MockERC20 wbtc = MockERC20(wbtcAddress);
        //     uint256 amount = 1 * 10**8; // 1 WBTC
        //     wbtc.mint(operatorAddress, amount);
            
        //     vm.stopBroadcast();

        //     console2.log("WBTC minted successfully for operator:", operatorAddress, "Amount:", amount);
        // }

        //Mint FBTC10 to operator
        {
            vm.startBroadcast(operatorPrivateKey);
            Debtor debtor = Debtor(debtorAddress);
            debtor.mint(1 * 10**18, operatorAddress);
            vm.stopBroadcast();
            console2.log("FBTC10 minted successfully for operator:", operatorAddress, "Amount:", 1 * 10**18);
        }

    }
}