// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IValuationOracle {

    struct Price {
        uint256 mintPrice;
        uint256 liquidationPrice;
    }
    
    function getMintPrice(address _token) external view returns (uint256);
    function getLiquidationPrice(address _token) external view returns (uint256);

    event PriceUpdated(address indexed token, uint256 mintPrice, uint256 liquidationPrice);

    
}