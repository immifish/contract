// SPDX-License-Identifier: MIT

pragma solidity =0.8.29;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./interface/IBlockUpdater.sol";

/**
 * @title BlockUpdater
 * @dev Manages epochs for reward calculations. Supports upgradability and owner-restricted functions.
 * - Initializes with owner and name.
 * - Manages epochs, updating reward factors and snapshots.
 * - Calculates accumulated, pending, and daily rewards.
 * - Handles reward calculations within and across epochs.
 */

contract BlockUpdater is Initializable, OwnableUpgradeable, UUPSUpgradeable, IBlockUpdater {
    // Array to store all epochs
    Epoch[] public epochs;

    // Name of the contract
    string public name;
    // Reward of the last completed epoch
    uint256 public lastEpochReward;
    // Constant used for reward calculations to maintain precision
    uint256 public constant REWARD_DENOMINATOR = 10 ** 18;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        // Disable initializers to prevent the contract from being initialized more than once
        _disableInitializers();
    }

    // Initializer function to set up the contract
    function initialize(string memory name_) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        name = name_;
    }

    // Function to authorize contract upgrades, restricted to the owner
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    // Returns the index of the current epoch
    function getCurrentEpoch() public view override returns (uint256) {
        uint256 length = epochs.length;
        return length > 0 ? length - 1 : 0;
    }

    // Returns the accumulated reward up to the last completed epoch
    function getAccumulatedReward() public view override returns (uint256) {
        uint256 length = epochs.length;
        return length > 1 ? epochs[length - 2].rewardSnapShot : 0;
    }

    // Estimates the pending reward based on the accrued load and the reward factor of the last completed epoch
    function estimatedPendingReward(
        uint256 _interestOrDebtFactor
    ) public view override returns (uint256) {
        require(epochs.length >= 2, "BlockUpdater: no history");
        return
            (epochs[epochs.length - 2].rewardFactor * _interestOrDebtFactor) /
            REWARD_DENOMINATOR;
    }

    // Estimates the daily reward based on the balance and the last epoch's reward
    function estimatedDailyReward(
        uint256 _balance
    ) public view override returns (uint256) {
        require(epochs.length >= 2, "BlockUpdater: no history");
        return (lastEpochReward * _balance) / REWARD_DENOMINATOR;
    }

    // Starts a new epoch, updating the reward factors for the current epoch before starting a new one
    function startNewEpoch(
        uint256 _currentEpoch,
        uint256 _currentEpochReward
    ) public onlyOwner {
        require(
            _currentEpoch == getCurrentEpoch(),
            "BlockUpdater: invalid currentEpoch"
        );
        uint256 currentEpoch = getCurrentEpoch();
        if (epochs.length > 0) {
            Epoch storage epoch = epochs[currentEpoch];
            // Calculate the reward factor for the current epoch
            epoch.rewardFactor =
                _currentEpochReward /
                (block.timestamp - epoch.startTime);
            // Update the reward snapshot for the current epoch
            epoch.rewardSnapShot =
                getAccumulatedReward() +
                _currentEpochReward;
            if (lastEpochReward != _currentEpochReward) {
                lastEpochReward = _currentEpochReward;
            }
            emit UpdateEpoch(
                currentEpoch,
                epoch.rewardFactor,
                epoch.rewardSnapShot,
                block.timestamp
            );
        } else {
            emit UpdateEpoch(0, 0, 0, block.timestamp);
        }
        // Push a new epoch to the epochs array
        epochs.push(Epoch(block.timestamp, 0, 0));
    }

    // Calculates the pending load within the same epoch
    function _withinEpoch(
        uint256 _balance,
        uint256 _lastModifiedTime,
        uint256 _factor
    ) internal view returns (uint256 interestFactor) {
        interestFactor =
            _balance *
            (block.timestamp - _lastModifiedTime) +
            _factor;
    }

    // Calculates the reward and pending load when crossing epochs
    function _crossEpoch(
        uint256 _balance,
        uint256 _lastModifiedEpoch,
        uint256 _lastModifiedTime,
        uint256 _factor
    ) internal view returns (uint256 reward, uint256 interestFactor) {
        Epoch storage lastModifiedEpoch = epochs[_lastModifiedEpoch];
        uint256 fullEpochReward = _balance *
            (getAccumulatedReward() - lastModifiedEpoch.rewardSnapShot);
        uint256 partEpochReward = lastModifiedEpoch.rewardFactor *
            (_factor +
                _balance *
                (epochs[_lastModifiedEpoch + 1].startTime - _lastModifiedTime));
        reward = (fullEpochReward + partEpochReward) / REWARD_DENOMINATOR;
        interestFactor =
            _balance *
            (block.timestamp - epochs[getCurrentEpoch()].startTime);
    }

    // Calculates the pending reward and pending load for a given balance and time period
    function pendingReward(
        uint256 _balance,
        uint256 _lastModifiedEpoch,
        uint256 _lastModifiedTime,
        uint256 _factor
    )
        public
        view
        override
        returns (uint256 epochReward, uint256 newFactor)
    {
        if (_lastModifiedTime == 0) {
            return (0, 0);
        }
        if (_lastModifiedEpoch == getCurrentEpoch()) {
            newFactor = _withinEpoch(
                _balance,
                _lastModifiedTime,
                _factor
            );
        } else {
            (epochReward, newFactor) = _crossEpoch(
                _balance,
                _lastModifiedEpoch,
                _lastModifiedTime,
                _factor
            );
        }
    }
}
