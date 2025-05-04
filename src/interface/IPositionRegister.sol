// SPDX-License-Identifier: MIT

pragma solidity =0.8.29;

interface IPositionRegister {
    function isValidActor(
        address _miner,
        address _actor
    ) external view returns (bool);

    function isValidClaimer(address _claimer) external view returns (bool);

    function isValidPosition(
        address _position,
        address _miner
    ) external view returns (bool);

    function createPosition(
        address _miner
    ) external returns (address positionAddress);
}
