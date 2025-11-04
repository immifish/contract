// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IValuation {

    struct DataFeed {
        address aggregator;
        uint8 aggregatorDecimal; // for chainlink feed with quote token usd, it is 8
        uint256 tokenDecimal;
    }

    function queryPrice(address _asset, int256 _tokenAmount) external view returns (int256);

    function queryMinerPrice(address _minerToken, int256 _tokenAmount) external view returns (int256);

    function queryPriceLtv(address _collateralAsset, address _loanAsset, int256 _tokenAmount) external view returns (int256);

    function queryCollateralValue(address _loanAsset, address _holder) external view returns (int256);
}
