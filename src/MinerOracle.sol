// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

interface IMinerOracle {
    function queryPrice(address _minerToken, int256 _tokenAmount) external view returns (int256);
}

contract MinerOracle is Initializable, OwnableUpgradeable, UUPSUpgradeable, IMinerOracle {

    // currently it is for both mint price and liquidate price
    mapping(address => int256) public price;

    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    // this price is the the same as chainlink price, with quote token usd decimal 8
    function setTokenPrice(address _minerToken, int256 _price) external onlyOwner {
        price[_minerToken] = _price;
    }

    function queryPrice(address _minerToken, int256 _tokenAmount) external view returns (int256) {
        return price[_minerToken] * _tokenAmount / int256(10 ** 18);
    }


    
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}