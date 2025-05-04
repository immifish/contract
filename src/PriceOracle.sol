// SPDX-License-Identifier: MIT

pragma solidity =0.8.29;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interface/IPriceOracle.sol";
import "./interface/IOracleAdapter.sol";    

contract PriceOracle is Initializable, OwnableUpgradeable, IPriceOracle {
    // inputToken => baseToken => oracleAdapter
    mapping(address => mapping(address => address)) public oracleMapping;

    // Event emitted when a new adapter is set
    event AdapterSet(address indexed baseToken, address indexed quoteToken, address indexed oracleAdapter);

    function initialize() public initializer {
        __Ownable_init(msg.sender);
    }

    function setAdapter(
        address _baseToken,
        address _quoteToken,
        address _oracleAdapter
    ) public onlyOwner {
        require(_baseToken != address(0), "Base token address cannot be zero");
        require(_quoteToken != address(0), "Quote token address cannot be zero");
        require(_oracleAdapter != address(0), "Oracle adapter address cannot be zero");

        oracleMapping[_baseToken][_quoteToken] = _oracleAdapter;
        emit AdapterSet(_baseToken, _quoteToken, _oracleAdapter);
    }

    // infure, it should find the most liquid trading route between baseToken and quoteToken
    function getPrice(
        address _baseToken,
        address _quoteToken,
        uint256 _tokenAmount
    ) public view returns (uint256) {
        if (_baseToken == _quoteToken) return _tokenAmount;
        address oracleAdpater = oracleMapping[_baseToken][_quoteToken];
        if (_tokenAmount == 0 || oracleAdpater == address(0)) return 0;
        return
            IOracleAdapter(oracleAdpater).priceIn(
                _baseToken,
                _quoteToken,
                _tokenAmount
            );
    }
}
