// SPDX-License-Identifier: MIT

pragma solidity =0.8.29;

interface IDebtorManager {

    event CreateDebtor(address owner, address debtor);
    event ChangeCollateralParams(uint256 minCollateralRate, uint256 minPaymentCycle, uint256 healthyCollateralRate, uint256 healthyPaymentCycle);
    function createDebtor() external returns (address);
}