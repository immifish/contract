// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ICycleUpdater {

    event UpdateCycle(
        uint256 currentCycle,
        uint256 rateFactor,
        uint256 interestSnapShot,
        uint256 finalizedTimestamp
    );

    struct Cycle {
        uint256 startTime;          // the start time of the cycle, updated when this cycle is started
        uint256 rateFactor;         // the rate factor of the cycle, updated when the cycle is finalized (the next cycle is started)
        uint256 interestSnapShot;   // the interest snapshot of the cycle, updated when the cycle is finalized (the next cycle is started)
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

}
