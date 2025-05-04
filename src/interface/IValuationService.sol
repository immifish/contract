// SPDX-License-Identifier: MIT

pragma solidity =0.8.29;

interface IValuationService {
    
    function queryPrice(
        address _baseToken,
        address _quoteToken,
        uint256 _tokenAmount
    ) external view returns (uint256);
    
    function queryPriceLTV(
        address _baseToken,
        address _quoteToken,
        uint256 _tokenAmount
    ) external view returns (uint256);
    
    function queryCollateralValue(
        address _quoteToken,
        address _holder
    ) external view returns (uint256 sum);
    

    
}