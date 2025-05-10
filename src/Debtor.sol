// SPDX-License-Identifier: MIT

pragma solidity =0.8.29;

import "./interface/IDebtor.sol";
import "./interface/ICycleUpdater.sol";
import "./interface/IMinerToken.sol";

contract Debtor is IDebtor {
    uint8 public constant VERSION = 1;
    address public minerToken;
    address public manager;
    

    // those factors are for liquidation
    uint256 public constant SCALING_FACTOR = 10000;
    uint256 public minCollateralRate;
    uint256 public minPaymentCycle;
    uint256 public healthyCollateralRate;
    uint256 public healthyPaymentCycle;

    constructor(address minerToken_, 
                uint256 _minCollateralRate, 
                uint256 _minPaymentCycle, 
                uint256 _healthyCollateralRate, 
                uint256 _healthyPaymentCycle
                ) {
        minerToken = minerToken_;
        minCollateralRate = _minCollateralRate;
        minPaymentCycle = _minPaymentCycle;
        healthyCollateralRate = _healthyCollateralRate;
        healthyPaymentCycle = _healthyPaymentCycle;
        manager = msg.sender;
    }

    //should make delegateCall1 (by owner) and check on healthy
    //should make delegateCall2 (by other) and check on recovery

    // function delegateCall(
    //     address _target,
    //     bytes memory data
    // ) public onlyOwner returns (bytes memory) {
    //     // require(
    //     //     AccountRegister(accountRegister).isValidActor(minerToken, _target),
    //     //     "PositionStorage: invalid actor"
    //     // );
    //     return _target.functionDelegateCall(data);
    // }

    //calculate collateral value

    //t
    


}
