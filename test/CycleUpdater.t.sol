// SPDX-License-Identifier: MIT
pragma solidity =0.8.29;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/CycleUpdater.sol";

contract CycleUpdaterTest is Test {
    CycleUpdater public cycleUpdater;
    ERC1967Proxy public proxy;
    address owner = address(this);
    address nonOwner = address(0x123);

    function setUp() public {
        CycleUpdater implementation = new CycleUpdater();
        proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(
                CycleUpdater.initialize.selector,
                "Test CycleUpdater",
                address(this)
            )
        );
        cycleUpdater = CycleUpdater(address(proxy));
        cycleUpdater.startNewCycle(0, 1000 ether);
    }

    function testInitialize() pure public {
        console.log("Testing initial state...");
    }

    function testStartNewEpoch() public {

        // Warp forward in time, e.g., 1 day (86400 seconds)
        vm.warp(block.timestamp + 1 days);

        // Start the first epoch
        cycleUpdater.startNewCycle(0, 0);

        // Warp forward in time, e.g., 1 day (86400 seconds)
        vm.warp(block.timestamp + 1 days);
        // Call again with a reward, enough time has passed
        cycleUpdater.startNewCycle(1, 1000 ether);

        // Destructure the tuple to access rewardFactor
        CycleUpdater.Cycle memory cycle = cycleUpdater.getCycle(1);
        assertGt(cycle.rateFactor, 0); // Just to verify it's not zero
    }
}
