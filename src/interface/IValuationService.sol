// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IValuationService {
    
    function querySpotPrice(
        address _baseToken,
        address _quoteToken,
        uint256 _tokenAmount
    ) external view returns (uint256);
    
    function queryPriceLTV(
        address _collateralAsset,
        address _loanAsset,
        address _quoteToken,
        uint256 _tokenAmount
    ) external view returns (uint256);
    
    function queryCollateralValue(
        address _loanAsset,
        address _quoteToken,
        address _holder
    ) external view returns (uint256 sum);
    

    
}