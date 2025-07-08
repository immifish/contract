// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./lib/AddressArray.sol";
import "./interface/IPriceOracle.sol";
import "./interface/IValuationService.sol";

contract ValuationService is Initializable, OwnableUpgradeable, UUPSUpgradeable, IValuationService {
    using AddressArray for address[];

    uint256 public constant SCALE_FACTOR = 10000;
    IPriceOracle public priceOracle;
    //collateral asset => loan asset => LTV, LTV should be scaled
    mapping(address => mapping(address => uint256)) public LTV;
    // List of accepted tokens that can be counted in value to filter(miner token)
    mapping(address => address[]) private whitelist;

    // Initializer function to replace constructor
    function initialize(address _oracleRegister) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        priceOracle = IPriceOracle(_oracleRegister);
    }

    // Override _authorizeUpgrade to restrict upgradeability to the owner
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function queryWhitelist(address _loanAsset) public view returns (address[] memory) {
        return whitelist[_loanAsset];
    }

    function setOracleRegister(address _oracleRegister) public onlyOwner {
        priceOracle = IPriceOracle(_oracleRegister);
    }

    // Set LTV for loan asset and collateral asset. Remember to add case for collateral asset == loan asset
    function setLTV(address _collateralAsset, address _loanAsset, uint256 _LTV, bool _isValid) public onlyOwner {
        require(_loanAsset != address(0) && _collateralAsset != address(0), "Invalid asset address");
        if (_isValid) {
            LTV[_collateralAsset][_loanAsset] = _LTV;
            // add to whitelist
            (bool hasAsset, ) = whitelist[_loanAsset].find(_collateralAsset);
            if (!hasAsset) {
                whitelist[_loanAsset].push(_collateralAsset);
            }
        } else {
            LTV[_collateralAsset][_loanAsset] = 0;
            // remove from whitelist
            whitelist[_loanAsset].remove(_collateralAsset);
        }
    }

    //if there is a direct trading pair, use the spot price
    function querySpotPrice(
        address _baseToken,
        address _quoteToken,
        uint256 _tokenAmount
    ) public view returns (uint256) {
        return priceOracle.getPrice(_baseToken, _quoteToken, _tokenAmount);
    }

    //use quote token to link pairs
    function queryRelativePriceViaQuote(
        address _tokenA,
        address _tokenB,
        address _quoteToken,
        uint256 _tokenAmount
    ) public view returns (uint256) {
        uint256 priceAQ = querySpotPrice(_tokenA, _quoteToken, _tokenAmount);
        uint256 priceAB = querySpotPrice(_quoteToken, _tokenB, priceAQ);
        return priceAB;
    }

    function queryPriceLTV(
        address _collateralAsset,
        address _loanAsset,
        address _quoteToken,
        uint256 _tokenAmount
    ) public view returns (uint256) {
        if (_collateralAsset == _loanAsset) {
            return _tokenAmount;
        }
        uint256 price = queryRelativePriceViaQuote(_collateralAsset, _loanAsset, _quoteToken, _tokenAmount);
        return (price * LTV[_collateralAsset][_loanAsset]) / SCALE_FACTOR;
    }  

    function queryCollateralValue(
        address _loanAsset,
        address _quoteToken,
        address _holder
    ) public view returns (uint256 sum) {
        address[] storage acceptedCollaterals = whitelist[_loanAsset];
        for (uint256 i = 0; i < acceptedCollaterals.length; ) {
            uint256 collateralAmount = IERC20(acceptedCollaterals[i]).balanceOf(_holder);
            if (collateralAmount > 0) {
                sum += queryPriceLTV(acceptedCollaterals[i], _loanAsset, _quoteToken, collateralAmount);
            }
            unchecked { i++; }
        }
    }
}
