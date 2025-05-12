// SPDX-License-Identifier: MIT

pragma solidity =0.8.29;

interface IDebtor {
    function VERSION() external view returns (uint8);
    function getDebtorManager() external view returns (address);
}