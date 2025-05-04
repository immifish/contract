// SPDX-License-Identifier: MIT

pragma solidity =0.8.29;

interface IDebtor {
    function VERSION() external view returns (uint8);
    function minCollateralRate() external view returns (uint256);
    function healthyCollateralRate() external view returns (uint256);
    function minPaymentCycle() external view returns (uint256);
    function healthyPaymentCycle() external view returns (uint256);
}