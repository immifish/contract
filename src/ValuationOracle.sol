// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IValuationOracle} from "./interface/IValuationOracle.sol";

contract ValuationOracle is Initializable, OwnableUpgradeable, IValuationOracle {
    mapping(address => Price) public prices;

    function initialize() public initializer {
        __Ownable_init(msg.sender);
    }

    function getMintPrice(address _token) external view returns (uint256) {
        return prices[_token].mintPrice;
    }

    function getLiquidationPrice(address _token) external view returns (uint256) {
        return prices[_token].liquidationPrice;
    }

    function updatePrice(address _token, uint256 _mintPrice, uint256 _liquidationPrice) external onlyOwner {
        storage price = prices[_token];
        if (price.mintPrice != _mintPrice) {
            price.mintPrice = _mintPrice;
        }
        if (price.liquidationPrice != _liquidationPrice) {
            price.liquidationPrice = _liquidationPrice;
        }
        emit PriceUpdated(_token, _mintPrice, _liquidationPrice);
    }


}   