// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IMinerToken {

    event RegisterDebtor(address debtor);
    event Mint(address byDebtor, address to, uint256 amount);
    event Burn(address from, address forDebtor, uint256 amount);
    event Claim(address holder, address to, uint256 amount);
    event RemoveReserve(address debtor, uint256 amount);
    event AddReserve(address debtor, uint256 amount);

    error MinerTokenInsufficientInterest(address creditor, uint256 balance, uint256 needed);

    struct TimeStamp {
        uint256 lastModifiedCycle;
        uint256 lastModifiedTime;
    }
    
    struct Creditor {
        TimeStamp timeStamp;
        uint256 interestFactor;
        uint256 interest;
    }

    struct Debtor {
        TimeStamp timeStamp;
        uint256 outStandingBalance;
        uint256 debtFactor;
        int256 interestReserve; //reserved interest for payment, it can be negative (in debt)
    }

    function registerDebtor(address debtor) external;

    function getDebtor(address debtor) external view returns (Debtor memory);

    function claim(address creditor, address to, uint256 amount) external;

    function mint(address to, uint256 amount) external;

    function removeReserve(address to, uint256 amount) external;

    function addReserve(address debtor, uint256 amount) external;

    function interestToken() external view returns (address);

    function cycleUpdater() external view returns (address);

}