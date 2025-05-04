// SPDX-License-Identifier: MIT

pragma solidity =0.8.29;

interface IMinerToken {

    event RegisterDebtor(address debtor);
    event Mint(address byDebtor, address to, uint256 amount);
    event Burn(address from, address forDebtor, uint256 amount);
    event ClaimReward(address holder, address to, uint256 amount);
    event RemoveReserve(address debtor, uint256 amount);
    event AddReserve(address debtor, uint256 amount);

    error MinerTokenInsufficientInterest(address creditor, uint256 balance, uint256 needed);

    function registerDebtor(address debtor) external;

    function claim(address creditor, address to, uint256 amount) external;

    function mint(address to, uint256 amount) external;

    function removeReserve(uint256 amount) external;

    function addReserve(address debtor, uint256 amount) external;

    function interestToken() external view returns (address);

    function blockUpdater() external view returns (address);

    function valuationService() external view returns (address);

    function queryInterestReserve(address debtor) external view returns (uint256 reserve, bool isNegative);
}