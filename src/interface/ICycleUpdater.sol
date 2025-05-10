// SPDX-License-Identifier: MIT

pragma solidity =0.8.29;

interface ICycleUpdater {

    event UpdateCycle(
        uint256 currentCycle,
        uint256 rateFactor,
        uint256 interestSnapShot,
        uint256 finalizedTimestamp
    );

    struct Cycle {
        uint256 startTime;
        uint256 rateFactor;
        uint256 interestSnapShot;
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
