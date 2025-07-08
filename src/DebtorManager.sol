// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "./interface/IDebtorManager.sol";
import "./debtor/Debtor.sol";
import "./interface/IMinerToken.sol";
import "./interface/IValuationService.sol";
import "./interface/ICycleUpdater.sol";


contract DebtorManager is IDebtorManager, Initializable, OwnableUpgradeable {
    
    IMinerToken minerToken;
    IValuationService valuationService;
    ICycleUpdater cycleUpdater;

    DebtorParams public defaultDebtorParams;

    // 2 times of interest rate for safety
    uint256 public constant SAFE_INTEREST_BUFFER = 2000; // 20%
    uint256 public constant SCALE_FACTOR = 10000;

    address public quoteToken;

    mapping(address => address) private _debtors;

    mapping(address => DebtorParams) private _customDebtorParams;

    function initialize(address _minerToken, 
                        address _cycleUpdater,
                        address _quoteToken,
                        address _valuationService, 
                        int256 _minCollateralRatio, 
                        int256 _marginBufferedCollateralRatio
                        ) external initializer {
        __Ownable_init(msg.sender);
        minerToken = IMinerToken(_minerToken);
        cycleUpdater = ICycleUpdater(_cycleUpdater);
        quoteToken = _quoteToken;
        valuationService = IValuationService(_valuationService);
        defaultDebtorParams = DebtorParams({
            minCollateralRatio: _minCollateralRatio,
            marginBufferedCollateralRatio: _marginBufferedCollateralRatio
        });
    }

    function setQuoteToken(address _quoteToken) external onlyOwner {
        quoteToken = _quoteToken;
    }

    function setValuationService(address _valuationService) external onlyOwner {
        valuationService = IValuationService(_valuationService);
    }

    function setDefaultDebtorParams(DebtorParams memory _defaultDebtorParams) external onlyOwner {
        defaultDebtorParams = _defaultDebtorParams;
    }

    function setCustomDebtorParams(address _debtor, 
                                int256 _minCollateralRatio,
                                int256 _marginBufferedCollateralRatio) external onlyOwner {
        _customDebtorParams[_debtor] = DebtorParams({
            minCollateralRatio: _minCollateralRatio,
            marginBufferedCollateralRatio: _marginBufferedCollateralRatio
        });
    }

    function getDebtorParams(address _debtor) public view returns (DebtorParams memory) {
        DebtorParams memory debtorParams = _customDebtorParams[_debtor];
        if (debtorParams.minCollateralRatio == 0) {
            return defaultDebtorParams;
        }
        return debtorParams;
    }

    function getDebtor(address _owner) external view returns (address) {
        return _debtors[_owner];
    }

    function createDebtor() external returns (address) {
        address sender = msg.sender;
        require(_debtors[sender] == address(0), "Factory: debtor already exists");
        bytes32 salt = keccak256(abi.encodePacked(sender, address(this)));
        Debtor debtor = new Debtor{salt: salt}();
        _debtors[sender] = address(debtor);
        minerToken.registerDebtor(address(debtor));
        emit CreateDebtor(sender, address(debtor));
        return address(debtor);
    }

    function _estimateDebtUsingLastCycleByFactor(uint256 _debtFactor) internal view returns (uint256) {
        uint256 currentIndex = cycleUpdater.getCurrentCycleIndex();
        require(currentIndex > 2, "DebtorManager: not enough cycles");
        uint256 lastRateFactor = cycleUpdater.getCycle(currentIndex - 1).rateFactor;
        return _debtFactor * lastRateFactor * (SCALE_FACTOR + SAFE_INTEREST_BUFFER) / SCALE_FACTOR;
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
        uint256 absPrice = valuationService.querySpotPrice(_inputToken, quoteToken, absInterestReserve);
        if (_interestReserve < 0) {
            return SafeCast.toInt256(absPrice) * -1;
        }
        return SafeCast.toInt256(absPrice);
    }

    //chcek the calcaulation first

    //need to make a safe buffer for interest reserve
    //check the calculation again for interest value calculation?? Basically what to quote.
    function healthCheckSimulation(IMinerToken.Debtor memory _minerDebtor,
                                int256 collateralValueInDebtorContract,
                                int256 minCollateralRatio,
                                int256 marginBufferedCollateralRatio
                            ) public view returns (int256 collateralRatio, 
                            bool passMinCollateralRatioCheck,
                            bool passMarginBufferedCollateralRatioCheck,
                           int256 interestReserveAdjusted) {

        //1. check interest reserve
        (uint256 finalizedDebt, uint256 debtFactor) = cycleUpdater.interestPreview(
            _minerDebtor.outStandingBalance, 
            _minerDebtor.timeStamp.lastModifiedCycle, 
            _minerDebtor.timeStamp.lastModifiedTime,
            _minerDebtor.debtFactor);
        interestReserveAdjusted = _minerDebtor.interestReserve - 
                                         SafeCast.toInt256(finalizedDebt) - 
                                         SafeCast.toInt256(_estimateDebtUsingLastCycleByFactor(debtFactor));
        
        //2. check collateral rate
        int256 revaluedCollateralValue = collateralValueInDebtorContract + _queryPriceInt256(minerToken.interestToken(), interestReserveAdjusted);
        int256 outStandingValue = _queryPriceInt256(address(minerToken), SafeCast.toInt256(_minerDebtor.outStandingBalance));

        collateralRatio = revaluedCollateralValue * SafeCast.toInt256(SCALE_FACTOR) / outStandingValue;
        passMinCollateralRatioCheck = collateralRatio >= minCollateralRatio;
        passMarginBufferedCollateralRatioCheck = collateralRatio >= marginBufferedCollateralRatio;
    }

    function healthCheck(address _debtor) public view returns (int256 collateralRatio, 
                            bool passMinCollateralRatioCheck,
                            bool passMarginBufferedCollateralRatioCheck,
                           int256 interestReserveAdjusted) {

        IMinerToken.Debtor memory minerDebtor = minerToken.getDebtor(_debtor);
        DebtorParams memory debtorParams = getDebtorParams(_debtor);
        int256 collateralValueInDebtorContract = SafeCast.toInt256(valuationService.queryCollateralValue(address(minerToken), quoteToken, _debtor));
        (collateralRatio, passMinCollateralRatioCheck, passMarginBufferedCollateralRatioCheck, interestReserveAdjusted) = 
        healthCheckSimulation(minerDebtor, collateralValueInDebtorContract, debtorParams.minCollateralRatio, debtorParams.marginBufferedCollateralRatio);
    }

}