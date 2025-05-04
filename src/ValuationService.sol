// SPDX-License-Identifier: MIT

pragma solidity =0.8.29;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./lib/AddressArray.sol";
import "./interface/IPriceOracle.sol";
import "./interface/IValuationService.sol";

contract ValuationService is Initializable, OwnableUpgradeable, UUPSUpgradeable, IValuationService {
    using AddressArray for address[];

    IPriceOracle public priceOracle;
    //collateral asset => loan asset => LTV
    mapping(address => mapping(address => uint256)) public LTV;
    uint256 public constant EFFICIENCY_DENOMINATOR = 10000;
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

    // set LTV for loan asset and collateral asset
    function setLTV(address _collateralAsset, address _loanAsset, uint256 _LTV, bool _isValid) public onlyOwner {
        // do not allow 0 address and same address
        require(_loanAsset != address(0) && _collateralAsset != address(0), "Invalid asset address");
        require(_loanAsset != _collateralAsset, "Loan asset and collateral asset cannot be the same");
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

    function queryPrice(
        address _baseToken,
        address _quoteToken,
        uint256 _tokenAmount
    ) public view returns (uint256) {
        return priceOracle.getPrice(_baseToken, _quoteToken, _tokenAmount);
    }

    function queryPriceLTV(
        address _baseToken,   //_collateralAsset
        address _quoteToken,  //_loanAsset
        uint256 _tokenAmount
    ) public view returns (uint256) {
        if (_baseToken == _quoteToken) {
            return _tokenAmount;
        } else {
            uint256 price = priceOracle.getPrice(_baseToken, _quoteToken, _tokenAmount);
            price =
                (price * LTV[_baseToken][_quoteToken]) /
                EFFICIENCY_DENOMINATOR;
            return price;
        }
    }    

    function queryCollateralValue(
        address _quoteToken,
        address _holder
    ) public view returns (uint256 sum) {
        address[] storage acceptedCollaterals = whitelist[_quoteToken];
        for (uint256 i = 0; i < acceptedCollaterals.length; ) {
            uint256 collateralAmount = IERC20(acceptedCollaterals[i]).balanceOf(_holder);
            if (collateralAmount > 0) {
                sum += queryPriceLTV(acceptedCollaterals[i], _quoteToken, collateralAmount);
            }
            unchecked { i++; }
        }
        // because whitelist exclude _quoteToken, so we need to add the balance of _quoteToken
        sum += IERC20(_quoteToken).balanceOf(_holder);
    }
}
