// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Debtor} from "./debtor/Debtor.sol";
import {IMinerToken} from "./MinerToken.sol";
import {IValuation} from "./Valuation.sol";
import {ICycleUpdater} from "./CycleUpdater.sol";

interface IDebtorManager {

    struct DebtorParams {
        int256 minCollateralRatio;   //scaled
        int256 marginBufferedCollateralRatio; //scaled
    }

    event CreateDebtor(address owner, address debtor);

    function minerToken() external view returns (address);
    function createDebtor() external returns (address);
    function getDebtor(address _owner) external view returns (address);
    function getDebtorParams(address _debtor) external view returns (DebtorParams memory);
    function healthCheck(address _debtor) external view returns (int256 collateralRatio, 
                            bool passMinCollateralRatioCheck,
                            bool passMarginBufferedCollateralRatioCheck,
                            int256 interestReserveAdjusted);
}

/**
the calculation of this contract is also int256 based
 */
contract DebtorManager is IDebtorManager, Initializable, OwnableUpgradeable, UUPSUpgradeable {
    
    address public minerToken;
    IValuation valuationService;
    ICycleUpdater cycleUpdater;

    DebtorParams public defaultDebtorParams;

    // 2 times of interest rate for safety
    int256 public constant SAFE_INTEREST_BUFFER = 2000; // 20%
    int256 public constant SCALE_FACTOR = 10000;


    mapping(address => address) private _debtorMapping;

    mapping(address => DebtorParams) private _customDebtorParams;

    function initialize(address _minerToken, 
                        address _cycleUpdater,
                        address _valuationService, 
                        int256 _minCollateralRatio, 
                        int256 _marginBufferedCollateralRatio
                        ) external initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        minerToken = _minerToken;
        cycleUpdater = ICycleUpdater(_cycleUpdater);
        valuationService = IValuation(_valuationService);
        defaultDebtorParams = DebtorParams({
            minCollateralRatio: _minCollateralRatio,
            marginBufferedCollateralRatio: _marginBufferedCollateralRatio
        });
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}


    function setValuationService(address _valuationService) external onlyOwner {
        valuationService = IValuation(_valuationService);
    }

    // reserved for upgrade
    function setCycleUpdater(address _newCycleUpdater) external onlyOwner {
        cycleUpdater = ICycleUpdater(_newCycleUpdater);
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
        return _debtorMapping[_owner];
    }

    function createDebtor() external returns (address) {
        address sender = msg.sender;
        require(_debtorMapping[sender] == address(0), "Factory: debtor already exists");
        bytes32 salt;
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, sender)
            mstore(add(ptr, 0x20), address())
            salt := keccak256(ptr, 0x40)
        }
        Debtor debtor = new Debtor{salt: salt}();
        _debtorMapping[sender] = address(debtor);
        IMinerToken(minerToken).registerDebtor(address(debtor));
        emit CreateDebtor(sender, address(debtor));
        return address(debtor);
    }

    function _estimateDebtUsingLastCycleByFactor(uint256 _debtFactor) internal view returns (int256) {
        // Get normalized debt estimate from CycleUpdater (handles SCALING_FACTOR)
        uint256 normalizedDebt = cycleUpdater.estimateDebtByFactor(_debtFactor);
        
        // Apply DebtorManager's buffer using SCALE_FACTOR (basis points)
        return SafeCast.toInt256(normalizedDebt) * (SCALE_FACTOR + SAFE_INTEREST_BUFFER) / SCALE_FACTOR;
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
                                         _estimateDebtUsingLastCycleByFactor(debtFactor);
        
        //2. check collateral rate
        int256 revaluedCollateralValue = collateralValueInDebtorContract + valuationService.queryPriceLtv(IMinerToken(minerToken).interestToken(), minerToken, interestReserveAdjusted);
        int256 outStandingValue = valuationService.queryMinerPrice(minerToken, SafeCast.toInt256(_minerDebtor.outStandingBalance));

        if (outStandingValue == 0) {
            collateralRatio = SCALE_FACTOR * 100; //make it fixed
            passMinCollateralRatioCheck = true;
            passMarginBufferedCollateralRatioCheck = true;
        }else {
            collateralRatio = revaluedCollateralValue * SCALE_FACTOR / outStandingValue;
            passMinCollateralRatioCheck = collateralRatio >= minCollateralRatio;
            passMarginBufferedCollateralRatioCheck = collateralRatio >= marginBufferedCollateralRatio;
        }
    }

    function healthCheck(address _debtor) public view returns (int256 collateralRatio, 
                            bool passMinCollateralRatioCheck,
                            bool passMarginBufferedCollateralRatioCheck,
                           int256 interestReserveAdjusted) {

        IMinerToken.Debtor memory minerDebtor = IMinerToken(minerToken).getDebtor(_debtor);
        DebtorParams memory debtorParams = getDebtorParams(_debtor);
        int256 collateralValueInDebtorContract = valuationService.queryCollateralValue(address(minerToken), _debtor);
        (collateralRatio, passMinCollateralRatioCheck, passMarginBufferedCollateralRatioCheck, interestReserveAdjusted) = 
        healthCheckSimulation(minerDebtor, collateralValueInDebtorContract, debtorParams.minCollateralRatio, debtorParams.marginBufferedCollateralRatio);
    }

}