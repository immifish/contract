// SPDX-License-Identifier: MIT

pragma solidity =0.8.29;

import "./interface/IDebtor.sol";
import "./interface/ICycleUpdater.sol";
import "./interface/IMinerToken.sol";
import "./interface/IDebtorManager.sol";

contract Debtor is IDebtor {
    uint8 public constant VERSION = 1;

    IDebtorManager immutable debtorManager;

    constructor() {
        debtorManager = IDebtorManager(msg.sender);
    }

    function _isOwner() internal view returns (bool) {
        return address(this) == debtorManager.getDebtor(msg.sender);
    }

    function getDebtorManager() public view returns (address) {
        return address(debtorManager);
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
