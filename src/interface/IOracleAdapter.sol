// SPDX-License-Identifier: MIT

pragma solidity =0.8.29;

interface IOracleAdapter {
  function priceIn(
    address inputToken,
    address baseToken,
    uint256 amount
  ) external view returns (uint256);
}
