// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

interface ICycleUpdater {

    event UpdateCycle(
        uint256 currentCycle,
        uint256 rateFactor,
        uint256 interestSnapShot,
        uint256 finalizedTimestamp
    );

    struct Cycle {
        uint256 startTime;          // the start time of the cycle, updated when this cycle is started
        uint256 rateFactor;         // the rate factor of the cycle, updated when the cycle is finalized (the next cycle is started). Elevated by SCALING_FACTOR
        uint256 interestSnapShot;   // the interest snapshot of the cycle, updated when the cycle is finalized (the next cycle is started). Elevated by SCALING_FACTOR
    }

    function getCurrentCycleIndex() external view returns (uint256);

    function getCycle(uint256 index) external view returns (Cycle memory);

    function getAccumulatedInterest() external view returns (uint256);

    function interestPreview(
        uint256 balance,
        uint256 lastModifiedCycle,
        uint256 lastModifiedTime,
        uint256 factor
    ) external view returns (uint256 finalizedInterest, uint256 updatedFactor);

    function estimateDebtByFactor(uint256 _debtFactor) 
        external 
        view 
        returns (uint256);

    function estimateDebtByBalance(uint256 _balance) 
        external 
        view 
        returns (uint256);

}

/**
 * @title CycleUpdater
 * @dev Manages cycles for interest calculations. Supports upgradability and owner-restricted functions.
 * - Initializes with owner and name.
 * - Manages cycles, updating interest factors and snapshots.
 * - Calculates accumulated, pending, and daily interest.
 * - Handles interest calculations within and across cycles.
 */

contract CycleUpdater is Initializable, OwnableUpgradeable, UUPSUpgradeable, ICycleUpdater {
    // Array to store all cycles
    Cycle[] cycles;

    // Constant used for interest calculations to maintain precision
    uint256 public constant SCALING_FACTOR = 10 ** 30;

    constructor() {
        // Disable initializers to prevent the contract from being initialized more than once
        _disableInitializers();
    }

    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    // Function to authorize contract upgrades, restricted to the owner
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    // Returns the index of the current cycle
    function getCurrentCycleIndex() public view override returns (uint256) {
        uint256 length = cycles.length;
        return length > 0 ? length - 1 : 0;
    }

    function getCycle(uint256 index) external view returns (Cycle memory) {
        return cycles[index];
    }

    // Returns the accumulated interest up to the last completed cycle
    function getAccumulatedInterest() public view override returns (uint256) {
        uint256 length = cycles.length;
        return length > 1 ? cycles[length - 2].interestSnapShot : 0;
    }

    // Starts a new cycle, updating the interest factors for the current cycle before starting a new one
    // @param _currentCycle is the current cycle index. It is just a check to ensure the update is correct.
    // @param _currentCycleInterest is the interest generated in the current cycle by holding 1 token (not 10**18, just 1). Elevated by SCALING_FACTOR.
    function startNewCycle(
        uint256 _currentCycle,
        uint256 _currentCycleInterest
    ) public onlyOwner {
        require(
            _currentCycle == getCurrentCycleIndex(),
            "CycleUpdater: invalid currentCycle"
        );
        uint256 currentCycle = getCurrentCycleIndex();
        if (cycles.length > 0) {
            Cycle storage cycle = cycles[currentCycle];
            // Calculate the interest factor for the current cycle
            cycle.rateFactor =
                _currentCycleInterest /
                (block.timestamp - cycle.startTime);
            // Update the interest snapshot for the current cycle
            cycle.interestSnapShot =
                getAccumulatedInterest() +
                _currentCycleInterest;
            emit UpdateCycle(
                currentCycle,
                cycle.rateFactor,
                cycle.interestSnapShot,
                block.timestamp
            );
        } else {
            emit UpdateCycle(0, 0, 0, block.timestamp);
        }
        // Push a new cycle to the cycles array
        cycles.push(Cycle(block.timestamp, 0, 0));
    }

    // the return value is elevated by SCALING_FACTOR (return to normal)
    function _finalizedInterest(
        uint256 _balance,
        uint256 _lastModifiedCycle,
        uint256 _lastModifiedTime,
        uint256 _factorBeforeUpdate
    ) internal view returns (uint256) {
        Cycle storage lastModifiedCycle = cycles[_lastModifiedCycle];
        uint256 fullCycleInterest = _balance *
            (getAccumulatedInterest() - lastModifiedCycle.interestSnapShot);
        uint256 partCycleInterest = lastModifiedCycle.rateFactor *
            (_factorBeforeUpdate +
                _balance *
                (cycles[_lastModifiedCycle + 1].startTime - _lastModifiedTime));
        return (fullCycleInterest + partCycleInterest) / SCALING_FACTOR;
    }


    function interestPreview(
        uint256 _balance,
        uint256 _lastModifiedCycle,
        uint256 _lastModifiedTime,
        uint256 _factorBeforeUpdate
    )
        public
        view
        override
        returns (uint256 finalizedInterest, uint256 updatedFactor)
    {
        if (_lastModifiedTime == 0) {
            return (0, 0);
        }
        if (_lastModifiedTime == block.timestamp) {
            return (0, _factorBeforeUpdate);
        }
        if (_lastModifiedCycle == getCurrentCycleIndex()) {
            updatedFactor = _balance * 
                            (block.timestamp - _lastModifiedTime) + 
                            _factorBeforeUpdate;
        } else {
            finalizedInterest = _finalizedInterest(
                _balance,
                _lastModifiedCycle,
                _lastModifiedTime,
                _factorBeforeUpdate
            );
            // Calculate factor accumulated in the current cycle from its start to now
            updatedFactor = _balance * 
                            (block.timestamp - cycles[getCurrentCycleIndex()].startTime);
        }
    }

    /**
     * @notice Estimates debt using the last completed cycle's rateFactor
     * @param _debtFactor The debt factor to use in the calculation
     * @return The estimated debt (normalized by dividing by SCALING_FACTOR)
     * @dev This function only handles SCALING_FACTOR normalization. 
     *      The caller (DebtorManager) should apply its own SCALE_FACTOR logic for buffers.
     */
    function estimateDebtByFactor(uint256 _debtFactor) 
        external 
        view 
        returns (uint256) 
    {
        uint256 currentIndex = getCurrentCycleIndex();
        require(currentIndex > 0, "CycleUpdater: not enough cycles");
        
        // Get the last completed cycle's rateFactor (scaled by SCALING_FACTOR)
        uint256 lastRateFactor = cycles[currentIndex - 1].rateFactor;
        
        // Calculate: debtFactor * rateFactor / SCALING_FACTOR
        // This normalizes the rateFactor by dividing by SCALING_FACTOR
        return _debtFactor * lastRateFactor / SCALING_FACTOR;
    }

    /**
     * @notice Estimates yield using the last finalized cycle's interest
     * @param _balance The balance to use in the calculation
     * @return The estimated yield (normalized by dividing by SCALING_FACTOR)
     * @dev This function estimates yield based on the interest generated in the last finalized cycle.
     *      Since interestSnapShot is accumulative, we calculate the difference between
     *      the last finalized cycle's snapshot and the previous cycle's snapshot to get
     *      the interest generated in that specific cycle.
     */
    function estimateDebtByBalance(uint256 _balance) 
        external 
        view 
        returns (uint256) 
    {
        uint256 currentIndex = getCurrentCycleIndex();
        require(currentIndex > 0, "CycleUpdater: not enough cycles");
        
        // Get the last finalized cycle's interest snapshot (accumulative)
        uint256 lastCycleSnapshot = cycles[currentIndex - 1].interestSnapShot;
        
        // Get the previous cycle's interest snapshot (or 0 if this is the first cycle)
        // The difference gives us the interest generated in the last finalized cycle
        uint256 previousCycleSnapshot = currentIndex > 1 
            ? cycles[currentIndex - 2].interestSnapShot 
            : 0;
        
        // Calculate the interest generated in the last finalized cycle
        uint256 cycleInterest = lastCycleSnapshot - previousCycleSnapshot;
        
        // Calculate: balance * cycleInterest / SCALING_FACTOR
        // This normalizes by dividing by SCALING_FACTOR
        return _balance * cycleInterest / SCALING_FACTOR;
    }
}
