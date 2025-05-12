// SPDX-License-Identifier: MIT

pragma solidity =0.8.29;

interface IDebtorManager {

    struct DebtorParams {
        int256 minCollateralRate;   //scaled
        int256 minPaymentCycles;    //not scaled
        int256 healthyCollateralRate; //scaled
        int256 healthyPaymentCycles; //not scaled
    }

    event CreateDebtor(address owner, address debtor);

    function createDebtor() external returns (address);
    function getDebtor(address _owner) external view returns (address);
    function getDebtorParams(address _debtor) external view returns (DebtorParams memory);
    function healthCheck(
        address _debtor,
        uint256 _useOutstandingBalance
    ) external view returns (int256 collateralRate, int256 remainingPaymentCycles);
}