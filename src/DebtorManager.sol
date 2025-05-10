// SPDX-License-Identifier: MIT

pragma solidity =0.8.29;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "./interface/IDebtorManager.sol";
import "./Debtor.sol";
import "./interface/IMinerToken.sol";
import "./interface/IValuationService.sol";
import "./interface/ICycleUpdater.sol";


contract DebtorManager is IDebtorManager, Initializable, OwnableUpgradeable {
    
    IMinerToken public minerToken;
    IValuationService public valuationService;
    ICycleUpdater public cycleUpdater;

    uint256 public minCollateralRate;
    uint256 public minPaymentCycle;
    uint256 public healthyCollateralRate;
    uint256 public healthyPaymentCycle;

    // 2 times of interest rate for safety
    uint256 public constant SAFE_INTEREST_FACTOR = 20000;
    uint256 public constant SCALE_FACTOR = 10000;

    address public quoteToken;

    mapping(address => address) private _debtors;

    function initialize(address _minerToken, 
                        address _cycleUpdater,
                        address _quoteToken,
                        address _valuationService, 
                        uint256 _minCollateralRate, 
                        uint256 _minPaymentCycle, 
                        uint256 _healthyCollateralRate, 
                        uint256 _healthyPaymentCycle
                        ) external initializer {
        __Ownable_init(msg.sender);
        minerToken = IMinerToken(_minerToken);
        cycleUpdater = ICycleUpdater(_cycleUpdater);
        quoteToken = _quoteToken;
        valuationService = IValuationService(_valuationService);
        minCollateralRate = _minCollateralRate;
        minPaymentCycle = _minPaymentCycle;
        healthyCollateralRate = _healthyCollateralRate;
        healthyPaymentCycle = _healthyPaymentCycle;
    }

    function setQuoteToken(address _quoteToken) external onlyOwner {
        quoteToken = _quoteToken;
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
        Debtor debtor = new Debtor{salt: salt}(address(minerToken), minCollateralRate, minPaymentCycle, healthyCollateralRate, healthyPaymentCycle);
        _debtors[sender] = address(debtor);
        minerToken.registerDebtor(address(debtor));
        emit CreateDebtor(sender, address(debtor));
        return address(debtor);
    }

    function _estimateDebtUsingLastCycleByFactor(uint256 _debtFactor) internal view returns (uint256) {
        uint256 currentIndex = cycleUpdater.getCurrentCycleIndex();
        require(currentIndex > 2, "DebtorManager: not enough cycles");
        uint256 lastRateFactor = cycleUpdater.getCycle(currentIndex - 1).rateFactor;
        return _debtFactor * lastRateFactor * SAFE_INTEREST_FACTOR / 10000;
    }
    
    function _estimateFinalizedDebtUsingLastCycleByBalance(uint256 _balance) internal view returns (uint256) {
        uint256 currentIndex = cycleUpdater.getCurrentCycleIndex();
        require(currentIndex > 2, "DebtorManager: not enough cycles");
        uint256 debtDiff = cycleUpdater.getCycle(currentIndex).interestSnapShot - 
                           cycleUpdater.getCycle(currentIndex - 1).interestSnapShot;
        return _balance * debtDiff;
    }

    function _queryPriceInt256(address _inputToken, int256 _interestReserve) internal view returns (int256) {
        uint256 absInterestReserve;
        if (_interestReserve < 0) {
            absInterestReserve = uint256(-1 * _interestReserve);
        } else {
            absInterestReserve = uint256(_interestReserve);
        }
        uint256 absPrice = valuationService.queryPrice(_inputToken, quoteToken, absInterestReserve);
        if (_interestReserve < 0) {
            return SafeCast.toInt256(absPrice) * -1;
        }
        return SafeCast.toInt256(absPrice);
    }

    // status coding: [PaymentCycleStatus][CollateralRateStatus]:[coding]   0 for fail, 1 for pass, coding in binary
    //                          0                    0              0
    //                          0                    1              1      
    //                          1                    0              2
    //                          1                    1              3
    function healthCheck(
        address _debtor,
        uint256 _useOutstandingBalance,
        uint256 _againstCollateralRate,
        uint256 _againstPaymentCycle
    ) public view returns (uint256 status) {
        int256 interestReserve = minerToken.queryInterestReserve(_debtor);

        //1. check payment cycle
        IMinerToken.Debtor memory minerDebtor = minerToken.getDebtor(_debtor);
        (uint256 finalizedDebt, uint256 debtFactor) = cycleUpdater.interestPreview(
            _useOutstandingBalance, 
            minerDebtor.timeStamp.lastModifiedCycle, 
            minerDebtor.timeStamp.lastModifiedTime, 
            minerDebtor.debtFactor);
        int256 revaluedInterestReserve = interestReserve - 
                                         SafeCast.toInt256(finalizedDebt) - 
                                         SafeCast.toInt256(_estimateDebtUsingLastCycleByFactor(debtFactor));
        uint256 PaymentCycleStatus =  revaluedInterestReserve >= 
                                      SafeCast.toInt256(_againstPaymentCycle * _estimateFinalizedDebtUsingLastCycleByBalance(_useOutstandingBalance)) ? 
                                      2 : 0;
        
        //2. check collateral rate
        int256 collateralValueInDebtorContract = SafeCast.toInt256(valuationService.queryCollateralValue(quoteToken, _debtor));
        int256 revaluedCollateralValue = collateralValueInDebtorContract + _queryPriceInt256(minerToken.interestToken(), interestReserve);
        int256 outStandingValue = _queryPriceInt256(address(minerToken), SafeCast.toInt256(_useOutstandingBalance));

        uint256 CollateralRateStatus = revaluedCollateralValue >= outStandingValue * 
                                                                SafeCast.toInt256(_againstCollateralRate) /  
                                                                SafeCast.toInt256(SCALE_FACTOR)
                                                                ? 1 : 0;
        return PaymentCycleStatus + CollateralRateStatus;
    }

    
}