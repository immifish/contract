// SPDX-License-Identifier: MIT

pragma solidity =0.8.29;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interface/IDebtorManager.sol";
import "./Debtor.sol";
import "./interface/IMinerToken.sol";
import "./interface/IValuationService.sol";

contract DebtorManager is IDebtorManager, Initializable, OwnableUpgradeable {
    
    address minerToken;
    IValuationService valuationService;

    uint256 public minCollateralRate;
    uint256 public minPaymentCycle;
    uint256 public healthyCollateralRate;
    uint256 public healthyPaymentCycle;

    mapping(address => address) private _debtors;

    function initialize(address _minerToken, address _valuationService, uint256 _minCollateralRate, uint256 _minPaymentCycle, uint256 _healthyCollateralRate, uint256 _healthyPaymentCycle) external initializer {
        __Ownable_init(msg.sender);
        minerToken = _minerToken;
        valuationService = IValuationService(_valuationService);
        minCollateralRate = _minCollateralRate;
        minPaymentCycle = _minPaymentCycle;
        healthyCollateralRate = _healthyCollateralRate;
        healthyPaymentCycle = _healthyPaymentCycle;
    }

    function setValuationService(address _valuationService) external onlyOwner {
        valuationService = IValuationService(_valuationService);
    }

    function editCollateralParams(uint256 _minCollateralRate, uint256 _minPaymentCycle, uint256 _healthyCollateralRate, uint256 _healthyPaymentCycle) external onlyOwner {
        minCollateralRate = _minCollateralRate;
        minPaymentCycle = _minPaymentCycle;
        healthyCollateralRate = _healthyCollateralRate;
        healthyPaymentCycle = _healthyPaymentCycle;
        emit ChangeCollateralParams(_minCollateralRate, _minPaymentCycle, _healthyCollateralRate, _healthyPaymentCycle);
    }
    
    function getDebtor(address _debtor) external view returns (address) {
        return _debtors[_debtor];
    }

    function createDebtor() external returns (address) {
        address sender = msg.sender;
        require(_debtors[sender] == address(0), "Factory: debtor already exists");
        bytes32 salt = keccak256(abi.encodePacked(sender, address(this)));
        Debtor debtor = new Debtor{salt: salt}(minerToken, minCollateralRate, minPaymentCycle, healthyCollateralRate, healthyPaymentCycle);
        _debtors[sender] = address(debtor);
        IMinerToken(minerToken).registerDebtor(address(debtor));
        emit CreateDebtor(sender, address(debtor));
        return address(debtor);
    }

    function healthCheck(
        address _debtor,
        address _quoteToken,
        uint256 _useOutstandingBalance,
        uint256 _useCollateralRate,
        uint256 _usePaymentCycle
    ) public view returns (uint256 status) {
        uint256 collateralValueInDebtorContract = valuationService.queryCollateralValue(_quoteToken, _debtor);
        //retrive Obligation
        

    }


}