// SPDX-License-Identifier: MIT

pragma solidity =0.8.29;

interface IBlockUpdater {
    event UpdateEpoch(
        uint256 currentEpoch,
        uint256 rewardFactor,
        uint256 rewardSnapShot,
        uint256 nextEpochStartTime
    );

    struct Epoch {
        uint256 startTime;
        uint256 rewardFactor;
        uint256 rewardSnapShot;
    }

    function getCurrentEpoch() external view returns (uint256);

    function getAccumulatedReward() external view returns (uint256);

    function pendingReward(
        uint256 balance,
        uint256 lastModifiedEpoch,
        uint256 lastModifiedTime,
        uint256 factor
    ) external view returns (uint256 epochReward, uint256 newFactor);

    function estimatedPendingReward(
        uint256 factor
    ) external view returns (uint256);

    function estimatedDailyReward(
        uint256 balance
    ) external view returns (uint256);
}
