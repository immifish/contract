// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IMinerOracle {
    function queryPrice(address _minerToken, int256 _tokenAmount) external view returns (int256);
}