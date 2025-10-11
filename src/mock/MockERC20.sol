// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title MockERC20
/// @notice Lightweight ERC20 token for testing/dev, configurable decimals, with owner-only mint/burn.
/// @dev Intended for use as mock assets like WBTC (8 decimals) or USDC (6 decimals).
contract MockERC20 is ERC20, Ownable {
    uint8 private immutable CUSTOM_DECIMALS;

    /// @param name_ Token name
    /// @param symbol_ Token symbol
    /// @param decimals_ Token decimals (e.g., 8 for WBTC, 6 for USDC)
    /// @param initialOwner Owner address (will control mint/burn)
    /// @param initialSupply Initial supply to mint to initialOwner (in smallest units)
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address initialOwner,
        uint256 initialSupply
    ) ERC20(name_, symbol_) Ownable(initialOwner) {
        require(initialOwner != address(0), "owner is zero");
        CUSTOM_DECIMALS = decimals_;
        if (initialSupply > 0) {
            _mint(initialOwner, initialSupply);
        }
    }

    function decimals() public view override returns (uint8) {
        return CUSTOM_DECIMALS;
    }

    /// @notice Mint tokens to an address. Only owner can call.
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /// @notice Burn tokens from an address. Only owner can call.
    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }
} 