// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./interface/IDebtor.sol";

contract Debtor is IDebtor {
    uint8 public constant VERSION = 1;

    address public immutable debtorManager;

    constructor() {
        debtorManager = msg.sender;
    }
    

    //add health check
    //add delegateCall

    //---- add reserve there is no need to protect, add there is no need to write it


    // remove reserve need to be healthy and not in debt, and healthy after
    // mint need be healthy and not in debt
    // burn (transfer) is ok at anytime
    
    // if a debt owner can do something, it need to be both healthy and no debt
    // if this is healthy but in debt, a liquidator can not do anything
    // if it is not healthy (but collateralRatio is above 100%), a liquidtor can take a move.
    // if the liquidator take a move, there will be a total liquidation that will sell all the assets, remove
    // debt first then lift all the shortBalance



}
