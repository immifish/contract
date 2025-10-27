// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title BatchTransfer
 * @notice A helper contract for batch transferring multiple ERC20 tokens to a single address
 */
contract BatchTransfer {
    using SafeERC20 for IERC20;

    /**
     * @notice Transfers multiple ERC20 tokens to a single address
     * @param tokens Array of token addresses to transfer
     * @param amounts Array of amounts to transfer (must be same length as tokens)
     * @param to The recipient address
     */
    function batchTransfer(
        address[] calldata tokens,
        uint256[] calldata amounts,
        address to
    ) external {
        require(tokens.length == amounts.length, "BatchTransfer: arrays length mismatch");
        require(to != address(0), "BatchTransfer: recipient cannot be zero address");

        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20 token = IERC20(tokens[i]);
            token.safeTransferFrom(msg.sender, to, amounts[i]);
        }
    }
}