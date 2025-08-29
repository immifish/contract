// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./interface/ICycleUpdater.sol";

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
    uint256 public constant SCALING_FACTOR = 10 ** 12;

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
            updatedFactor = _balance * 
                            (block.timestamp - cycles[_lastModifiedCycle].startTime);
        }
    }
}
