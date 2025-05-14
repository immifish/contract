// SPDX-License-Identifier: MIT

pragma solidity =0.8.29;

contract Debtor {
    uint8 public constant VERSION = 1;

    address public immutable debtorManager;

    constructor() {
        debtorManager = msg.sender;
    }
}
