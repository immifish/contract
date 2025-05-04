// SPDX-License-Identifier: MIT
pragma solidity =0.8.29;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/BlockUpdater.sol";

contract BlockUpdaterTest is Test {
    BlockUpdater public blockUpdater;
    ERC1967Proxy public proxy;
    address owner = address(this);
    address nonOwner = address(0x123);

    function setUp() public {
        BlockUpdater implementation = new BlockUpdater();
        proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(
                BlockUpdater.initialize.selector,
                "Test BlockUpdater",
                address(this)
            )
        );
        blockUpdater = BlockUpdater(address(proxy));
        blockUpdater.startNewEpoch(0, 1000 ether);
    }

    function testInitialize() view public {
        console.log("Testing initial state...");
        assertEq(blockUpdater.name(), "Test BlockUpdater");
    }

    function testStartNewEpoch() public {

        // Warp forward in time, e.g., 1 day (86400 seconds)
        vm.warp(block.timestamp + 1 days);

        // Start the first epoch
        blockUpdater.startNewEpoch(0, 0);

        // Warp forward in time, e.g., 1 day (86400 seconds)
        vm.warp(block.timestamp + 1 days);
        // Call again with a reward, enough time has passed
        blockUpdater.startNewEpoch(1, 1000 ether);

        // Destructure the tuple to access rewardFactor
        (, uint256 rewardFactor, ) = blockUpdater.epochs(1);
        assertGt(rewardFactor, 0); // Just to verify it's not zero
    }
}
