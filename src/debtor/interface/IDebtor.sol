// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IDebtor {

    function VERSION() external view returns (uint8);

    function debtorManager() external view returns (address);
    
}