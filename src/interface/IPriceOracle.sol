// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IPriceOracle {
    function getPrice(
        address _inputToken,
        address _baseToken,
        uint256 _tokenAmount
    ) external view returns (uint256);
}