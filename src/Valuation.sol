// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {AddressArray} from "./lib/AddressArray.sol";
import {AggregatorV3Interface} from "./interface/AggregatorV3Interface.sol";
import {IMinerOracle} from "./MinerOracle.sol";

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

/*
In this contact, we are using int256 for prices for two reasons:
1. The chainlink answer is int256;
2. The interest reserve can be negative, also using int256

[IMPORTANT] All the prices are against USD, and the decimal is 8.
 */

contract Valuation is Initializable, OwnableUpgradeable, UUPSUpgradeable, IValuation {
    using AddressArray for address[];

    int256 public constant SCALE_FACTOR = 10000;
    // align with chainlink token/USD decimal 8, but int256 version. This should not be used explicitly.
    int256 public constant DECIMAL = 8;
    // asset => DataFeed
    mapping(address => DataFeed) public feed;

    //collateral asset => loan asset => LTV, LTV should be scaled
    mapping(address => mapping(address => int256)) public ltv;
    // List of accepted tokens that can be counted in value to filter(miner token)
    mapping(address => address[]) private whitelist;

    // miner oracle
    IMinerOracle public minerOracle;

    // Initializer function to replace constructor
    function initialize(address _minerOracle) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        minerOracle = IMinerOracle(_minerOracle);
    }

    function setMinerOracle(address _minerOracle) public onlyOwner {
        minerOracle = IMinerOracle(_minerOracle);
    }

    // Override _authorizeUpgrade to restrict upgradeability to the owner
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function queryWhitelist(address _loanAsset) public view returns (address[] memory) {
        return whitelist[_loanAsset];
    }

    // this setting is for chainlink specific
    function setDataFeed(address _asset, address _aggregator, uint256 _tokenDecimal) public onlyOwner {
        uint8 _aggregatorDecimal = AggregatorV3Interface(_aggregator).decimals();
        // a check against quote token usd with 8 decimal
        require(_aggregatorDecimal == 8, "Aggregator decimal must be 8");
        feed[_asset] = DataFeed(_aggregator, _aggregatorDecimal, _tokenDecimal);
    }

    // Set LTV for loan asset and collateral asset. Remember to add case for collateral asset == loan asset
    function setLtv(address _collateralAsset, address _loanAsset, int256 _ltv, bool _isValid) public onlyOwner {
        require(_collateralAsset != address(0) && _loanAsset != address(0), "Invalid asset address");
        require(_ltv >= 0, "LTV must be positive");
        if (_isValid) {
            if (_collateralAsset == _loanAsset) require(_ltv == SCALE_FACTOR, "Same-asset LTV must be 1x");
            require(_ltv <= SCALE_FACTOR, "LTV too high");
            ltv[_collateralAsset][_loanAsset] = _ltv;
            // add to whitelist
            (bool hasAsset, ) = whitelist[_loanAsset].find(_collateralAsset);
            if (!hasAsset) {
                whitelist[_loanAsset].push(_collateralAsset);
            }
        } else {
            ltv[_collateralAsset][_loanAsset] = 0;
            // remove from whitelist
            whitelist[_loanAsset].remove(_collateralAsset);
        }
    }

    // query asset price in quote usd by chainlink feed
    function queryPrice(address _asset, int256 _tokenAmount) public view returns (int256) {
        DataFeed memory dataFeed = feed[_asset];
        int256 answer;
        if (dataFeed.aggregator == address(0)) {
            answer = -100;
        } else {
            // prettier-ignore
            (
                /* uint80 roundId */,
                answer,
                /*uint256 startedAt*/,
                /*uint256 updatedAt*/,
                /*uint80 answeredInRound*/
            ) = AggregatorV3Interface(dataFeed.aggregator).latestRoundData();
        }
        require(answer > 0, "Invalid price");
        return answer * _tokenAmount / int256(10 ** dataFeed.tokenDecimal);
    }

    // this price is from self maintained miner oracle
    function queryMinerPrice(address _minerToken, int256 _tokenAmount) public view returns (int256) {
        return minerOracle.queryPrice(_minerToken, _tokenAmount);
    }
    
    function queryPriceLtv(
        address _collateralAsset,
        address _loanAsset,
        int256 _tokenAmount
    ) public view returns (int256) {
        if (_collateralAsset == _loanAsset) {
            return _tokenAmount;
        } else {
            int256 price = queryPrice(_collateralAsset, _tokenAmount);
            price =
                (price * ltv[_collateralAsset][_loanAsset]) /
                SCALE_FACTOR;
            return price;
        }
    }


    function queryCollateralValue(
        address _loanAsset,
        address _holder
    ) public view returns (int256 sum) {
        address[] storage inputTokens = whitelist[_loanAsset];
        for (uint256 i = 0; i < inputTokens.length; ) {
            sum += queryPriceLtv(inputTokens[i], _loanAsset, SafeCast.toInt256(IERC20(inputTokens[i]).balanceOf(_holder)));
            unchecked { i++; }
        }
        sum += SafeCast.toInt256(IERC20(_loanAsset).balanceOf(_holder));
    }
}
