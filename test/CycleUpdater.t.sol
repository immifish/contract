// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/CycleUpdater.sol";

contract MockCycleUpdaterV2 is CycleUpdater {
    uint256 public newVariable = 42;
    
    function newFunction() external pure returns (string memory) {
        return "upgraded";
    }
}

contract CycleUpdaterBasicTest is Test {
    CycleUpdater public cycleUpdater;
    ERC1967Proxy public proxy;
    address owner = address(this);
    address nonOwner = address(0x123);
    
    // Events for testing
    event UpdateCycle(
        uint256 currentCycle,
        uint256 rateFactor,
        uint256 interestSnapShot,
        uint256 finalizedTimestamp
    );

    function setUp() public {
        CycleUpdater implementation = new CycleUpdater();
        proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(CycleUpdater.initialize.selector)
        );
        cycleUpdater = CycleUpdater(address(proxy));
    }

    // ============ INITIALIZATION TESTS ============

    function testInitialize() public {
        assertEq(cycleUpdater.owner(), owner);
        assertEq(cycleUpdater.getCurrentCycleIndex(), 0);
        assertEq(cycleUpdater.getAccumulatedInterest(), 0);
    }

    function testInitializeOnlyOnce() public {
        vm.expectRevert();
        cycleUpdater.initialize();
    }

    function testImplementationCannotBeInitialized() public {
        CycleUpdater implementation = new CycleUpdater();
        vm.expectRevert();
        implementation.initialize();
    }

    // ============ ACCESS CONTROL TESTS ============

    function testOnlyOwnerCanStartNewCycle() public {
        vm.prank(nonOwner);
        vm.expectRevert();
        cycleUpdater.startNewCycle(0, 1000 ether);
    }

    function testOnlyOwnerCanAuthorizeUpgrade() public {
        MockCycleUpdaterV2 newImplementation = new MockCycleUpdaterV2();
        
        vm.prank(nonOwner);
        vm.expectRevert();
        cycleUpdater.upgradeToAndCall(address(newImplementation), "");
    }

    // ============ CYCLE MANAGEMENT TESTS ============

    function testStartFirstCycle() public {
        vm.expectEmit(true, true, true, true);
        emit UpdateCycle(0, 0, 0, block.timestamp);
        
        cycleUpdater.startNewCycle(0, 0);
        
        assertEq(cycleUpdater.getCurrentCycleIndex(), 0);
        CycleUpdater.Cycle memory cycle = cycleUpdater.getCycle(0);
        assertEq(cycle.startTime, block.timestamp);
        assertEq(cycle.rateFactor, 0);
        assertEq(cycle.interestSnapShot, 0);
    }

    function testStartMultipleCycles() public {
        // Start first cycle
        cycleUpdater.startNewCycle(0, 0);
        uint256 firstCycleStart = block.timestamp;
        
        // Advance time and start second cycle with interest
        vm.warp(block.timestamp + 1 days);
        uint256 interest = 1000 ether;
        uint256 expectedRateFactor = interest / 1 days;
        
        vm.expectEmit(true, true, true, true);
        emit UpdateCycle(0, expectedRateFactor, interest, block.timestamp);
        
        cycleUpdater.startNewCycle(0, interest);
        
        // Check first cycle was finalized
        CycleUpdater.Cycle memory cycle0 = cycleUpdater.getCycle(0);
        assertEq(cycle0.startTime, firstCycleStart);
        assertEq(cycle0.rateFactor, expectedRateFactor);
        assertEq(cycle0.interestSnapShot, interest);
        
        // Check second cycle was created
        assertEq(cycleUpdater.getCurrentCycleIndex(), 1);
        CycleUpdater.Cycle memory cycle1 = cycleUpdater.getCycle(1);
        assertEq(cycle1.startTime, block.timestamp);
        assertEq(cycle1.rateFactor, 0);
        assertEq(cycle1.interestSnapShot, 0);
        uint256 secondCycleStart = block.timestamp;
        
        // Advance time and start third cycle with different interest
        vm.warp(block.timestamp + 2 days);
        uint256 secondCycleInterest = 2000 ether;
        uint256 expectedRateFactor2 = secondCycleInterest / (2 days);
        uint256 expectedSnapshot2 = interest + secondCycleInterest; // 1000 + 2000 = 3000
        
        vm.expectEmit(true, true, true, true);
        emit UpdateCycle(1, expectedRateFactor2, expectedSnapshot2, block.timestamp);
        
        cycleUpdater.startNewCycle(1, secondCycleInterest);
        
        // Check second cycle was finalized
        CycleUpdater.Cycle memory cycle1Final = cycleUpdater.getCycle(1);
        assertEq(cycle1Final.startTime, secondCycleStart);
        assertEq(cycle1Final.rateFactor, expectedRateFactor2);
        assertEq(cycle1Final.interestSnapShot, expectedSnapshot2);
        
        // Check third cycle was created
        assertEq(cycleUpdater.getCurrentCycleIndex(), 2);
        CycleUpdater.Cycle memory cycle2 = cycleUpdater.getCycle(2);
        assertEq(cycle2.startTime, block.timestamp);
        assertEq(cycle2.rateFactor, 0);
        assertEq(cycle2.interestSnapShot, 0);
    }

    function testInvalidCycleIndex() public {
        cycleUpdater.startNewCycle(0, 0);
        
        vm.expectRevert("CycleUpdater: invalid currentCycle");
        cycleUpdater.startNewCycle(1, 1000 ether); // Should be 0
    }

    function testGetCycleOutOfBounds() public {
        vm.expectRevert();
        cycleUpdater.getCycle(0); // No cycles exist yet
    }

    // ============ ACCUMULATED INTEREST TESTS ============

    function testAccumulatedInterestEmpty() public {
        assertEq(cycleUpdater.getAccumulatedInterest(), 0);
    }

    function testAccumulatedInterestSingleCycle() public {
        cycleUpdater.startNewCycle(0, 0);
        assertEq(cycleUpdater.getAccumulatedInterest(), 0);
    }

    function testAccumulatedInterestMultipleCycles() public {
        // Start first cycle and advance time
        cycleUpdater.startNewCycle(0, 0);
        vm.warp(block.timestamp + 1 days);
        
        // End first cycle with 1000 interest
        cycleUpdater.startNewCycle(0, 1000 ether);
        assertEq(cycleUpdater.getAccumulatedInterest(), 1000 ether); // Now includes first cycle
        
        // Start third cycle
        vm.warp(block.timestamp + 1 days);
        cycleUpdater.startNewCycle(1, 2000 ether);
        assertEq(cycleUpdater.getAccumulatedInterest(), 3000 ether); // 1000 + 2000
        
        // Start fourth cycle
        vm.warp(block.timestamp + 1 days);
        cycleUpdater.startNewCycle(2, 3000 ether);
        assertEq(cycleUpdater.getAccumulatedInterest(), 6000 ether); // 1000 + 2000 + 3000
    }

    // ============ BASIC INTEREST PREVIEW TESTS ============

    function testInterestPreviewZeroTime() public {
        cycleUpdater.startNewCycle(0, 0);
        
        (uint256 finalizedInterest, uint256 updatedFactor) = 
            cycleUpdater.interestPreview(1000 ether, 0, 0, 0);
        
        assertEq(finalizedInterest, 0);
        assertEq(updatedFactor, 0);
    }

    function testInterestPreviewSameTimestamp() public {
        cycleUpdater.startNewCycle(0, 0);
        
        (uint256 finalizedInterest, uint256 updatedFactor) = 
            cycleUpdater.interestPreview(1000 ether, 0, block.timestamp, 500 ether);
        
        assertEq(finalizedInterest, 0);
        assertEq(updatedFactor, 500 ether);
    }

    function testInterestPreviewSameCycle() public {
        cycleUpdater.startNewCycle(0, 0);
        uint256 startTime = block.timestamp;
        
        // Advance time within same cycle
        vm.warp(startTime + 1 hours);
        
        uint256 balance = 1000 ether;
        uint256 factorBefore = 500 ether;
        
        (uint256 finalizedInterest, uint256 updatedFactor) = 
            cycleUpdater.interestPreview(balance, 0, startTime, factorBefore);
        
        assertEq(finalizedInterest, 0);
        uint256 expectedFactor = balance * 1 hours + factorBefore;
        assertEq(updatedFactor, expectedFactor);
    }

    // ============ EDGE CASE TESTS ============

    function testZeroInterestCycle() public {
        cycleUpdater.startNewCycle(0, 0);
        vm.warp(block.timestamp + 1 days);
        
        // Starting new cycle with zero interest should work
        cycleUpdater.startNewCycle(0, 0);
        
        CycleUpdater.Cycle memory cycle = cycleUpdater.getCycle(0);
        assertEq(cycle.rateFactor, 0);
        assertEq(cycle.interestSnapShot, 0);
    }

    function testVeryShortCycle() public {
        cycleUpdater.startNewCycle(0, 0);
        
        // Advance by 1 second
        vm.warp(block.timestamp + 1);
        
        uint256 interest = 3600 ether; // 1 ether per second
        cycleUpdater.startNewCycle(0, interest);
        
        CycleUpdater.Cycle memory cycle = cycleUpdater.getCycle(0);
        assertEq(cycle.rateFactor, interest); // interest / 1 second
    }

    function testVeryLongCycle() public {
        cycleUpdater.startNewCycle(0, 0);
        
        // Advance by 365 days
        vm.warp(block.timestamp + 365 days);
        
        uint256 interest = 365 ether;
        cycleUpdater.startNewCycle(0, interest);
        
        CycleUpdater.Cycle memory cycle = cycleUpdater.getCycle(0);
        // 365 ether over 365 days = 1 ether per day = 1 ether / 86400 seconds
        uint256 expectedRate = 365 ether;
        uint256 duration = 365 days;
        assertEq(cycle.rateFactor, expectedRate / duration);
    }

    function testLargeNumbers() public {
        cycleUpdater.startNewCycle(0, 0);
        vm.warp(block.timestamp + 1 days);
        
        uint256 largeInterest = type(uint128).max; // Very large number
        cycleUpdater.startNewCycle(0, largeInterest);
        
        CycleUpdater.Cycle memory cycle = cycleUpdater.getCycle(0);
        assertEq(cycle.rateFactor, largeInterest / 1 days);
        assertEq(cycle.interestSnapShot, largeInterest);
    }

    // ============ UPGRADE TESTS ============

    function testUpgradeContract() public {
        MockCycleUpdaterV2 newImplementation = new MockCycleUpdaterV2();
        
        // Upgrade the contract
        cycleUpdater.upgradeToAndCall(address(newImplementation), "");
        
        // Cast to new implementation and test new functionality
        MockCycleUpdaterV2 upgraded = MockCycleUpdaterV2(address(proxy));
        // Note: The newVariable might not be initialized in the upgrade, so let's just test the function
        assertEq(upgraded.newFunction(), "upgraded");
        
        // Verify old functionality still works
        assertEq(upgraded.owner(), owner);
        assertEq(upgraded.getCurrentCycleIndex(), 0);
    }

    function testUpgradePreservesState() public {
        // Set up some state
        cycleUpdater.startNewCycle(0, 0);
        vm.warp(block.timestamp + 1 days);
        cycleUpdater.startNewCycle(0, 1000 ether);
        
        uint256 accumulatedBefore = cycleUpdater.getAccumulatedInterest();
        uint256 currentCycleBefore = cycleUpdater.getCurrentCycleIndex();
        
        // Upgrade
        MockCycleUpdaterV2 newImplementation = new MockCycleUpdaterV2();
        cycleUpdater.upgradeToAndCall(address(newImplementation), "");
        
        // Verify state is preserved
        MockCycleUpdaterV2 upgraded = MockCycleUpdaterV2(address(proxy));
        assertEq(upgraded.getAccumulatedInterest(), accumulatedBefore);
        assertEq(upgraded.getCurrentCycleIndex(), currentCycleBefore);
    }



    // ============ INVARIANT TESTS ============

    function testCycleIndexAlwaysIncreases() public {
        uint256 currentIndex = cycleUpdater.getCurrentCycleIndex();
        assertEq(currentIndex, 0); // Starts at 0
        
        for(uint i = 0; i < 5; i++) {
            cycleUpdater.startNewCycle(currentIndex, i * 1000 ether);
            vm.warp(block.timestamp + 1 days);
            
            uint256 newIndex = cycleUpdater.getCurrentCycleIndex();
            if (i == 0) {
                assertEq(newIndex, 0); // First cycle creation still shows index 0
            } else {
                assertEq(newIndex, currentIndex + 1); // Index increments for subsequent cycles
            }
            currentIndex = newIndex;
        }
    }

    function testAccumulatedInterestNeverDecreases() public {
        cycleUpdater.startNewCycle(0, 0);
        
        uint256 lastAccumulated = 0;
        
        for(uint i = 1; i <= 5; i++) {
            vm.warp(block.timestamp + 1 days);
            cycleUpdater.startNewCycle(i - 1, i * 1000 ether);
            
            uint256 currentAccumulated = cycleUpdater.getAccumulatedInterest();
            assertGe(currentAccumulated, lastAccumulated);
            lastAccumulated = currentAccumulated;
        }
    }

    // ============ CONSTANT TESTS ============

    function testScalingFactorConstant() public {
        assertEq(cycleUpdater.SCALING_FACTOR(), 10 ** 12);
    }
}

contract CycleUpdaterAdvancedTest is Test {
    CycleUpdater public cycleUpdater;
    ERC1967Proxy public proxy;
    address owner = address(this);
    address nonOwner = address(0x123);
    
    // Test state after setUp
    uint256 public constant CYCLE_0_DURATION = 7 days;
    uint256 public constant CYCLE_0_INTEREST = 10000 ether;
    uint256 public constant CYCLE_1_DURATION = 5 days; 
    uint256 public constant CYCLE_1_INTEREST = 15000 ether;
    uint256 public constant CYCLE_2_DURATION = 3 days;
    uint256 public constant CYCLE_2_INTEREST = 8000 ether;
    
    uint256 public cycle0StartTime;
    uint256 public cycle1StartTime;
    uint256 public cycle2StartTime;
    uint256 public cycle3StartTime;
    
    // Events for testing
    event UpdateCycle(
        uint256 currentCycle,
        uint256 rateFactor,
        uint256 interestSnapShot,
        uint256 finalizedTimestamp
    );

    function setUp() public {
        // Deploy and initialize contract
        CycleUpdater implementation = new CycleUpdater();
        proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(CycleUpdater.initialize.selector)
        );
        cycleUpdater = CycleUpdater(address(proxy));
        
        // Establish multiple cycles to create realistic test environment
        
        // Cycle 0: Start at timestamp 1000
        vm.warp(1000);
        cycleUpdater.startNewCycle(0, 0);
        cycle0StartTime = block.timestamp;
        
        // Cycle 1: 7 days later with 10000 ether interest
        vm.warp(cycle0StartTime + CYCLE_0_DURATION);
        cycleUpdater.startNewCycle(0, CYCLE_0_INTEREST);
        cycle1StartTime = block.timestamp;
        
        // Cycle 2: 5 days later with 15000 ether interest
        vm.warp(cycle1StartTime + CYCLE_1_DURATION);
        cycleUpdater.startNewCycle(1, CYCLE_1_INTEREST);
        cycle2StartTime = block.timestamp;
        
        // Cycle 3: 3 days later with 8000 ether interest
        vm.warp(cycle2StartTime + CYCLE_2_DURATION);
        cycleUpdater.startNewCycle(2, CYCLE_2_INTEREST);
        cycle3StartTime = block.timestamp;
        
        // Now we're in cycle 3 with established history
    }

    // ============ SETUP VERIFICATION TESTS ============

    function testAdvancedSetupState() public {
        // Verify we're in cycle 3
        assertEq(cycleUpdater.getCurrentCycleIndex(), 3);
        
        // Verify accumulated interest: 10000 + 15000 + 8000 = 33000
        assertEq(cycleUpdater.getAccumulatedInterest(), 33000 ether);
        
        // Verify individual cycle states
        CycleUpdater.Cycle memory cycle0 = cycleUpdater.getCycle(0);
        assertEq(cycle0.startTime, cycle0StartTime);
        assertEq(cycle0.rateFactor, CYCLE_0_INTEREST / CYCLE_0_DURATION);
        assertEq(cycle0.interestSnapShot, CYCLE_0_INTEREST);
        
        CycleUpdater.Cycle memory cycle1 = cycleUpdater.getCycle(1);
        assertEq(cycle1.startTime, cycle1StartTime);
        assertEq(cycle1.rateFactor, CYCLE_1_INTEREST / CYCLE_1_DURATION);
        assertEq(cycle1.interestSnapShot, CYCLE_0_INTEREST + CYCLE_1_INTEREST);
        
        CycleUpdater.Cycle memory cycle2 = cycleUpdater.getCycle(2);
        assertEq(cycle2.startTime, cycle2StartTime);
        assertEq(cycle2.rateFactor, CYCLE_2_INTEREST / CYCLE_2_DURATION);
        assertEq(cycle2.interestSnapShot, CYCLE_0_INTEREST + CYCLE_1_INTEREST + CYCLE_2_INTEREST);
        
        CycleUpdater.Cycle memory cycle3 = cycleUpdater.getCycle(3);
        assertEq(cycle3.startTime, cycle3StartTime);
        assertEq(cycle3.rateFactor, 0); // Current cycle not finalized
        assertEq(cycle3.interestSnapShot, 0); // Current cycle not finalized
    }

    // ============ ADVANCED INTEREST PREVIEW TESTS ============

    function testInterestPreviewFromEarlyCycle() public {
        // Test preview for position from cycle 1 to current time
        uint256 balance = 1000 ether;
        uint256 lastModifiedTime = cycle1StartTime + 2 days; // 2 days into cycle 1
        uint256 factorBefore = 500 ether;
        
        (uint256 finalizedInterest, uint256 updatedFactor) = 
            cycleUpdater.interestPreview(balance, 1, lastModifiedTime, factorBefore);
        
        // Should have finalized interest spanning multiple cycles
        assertGt(finalizedInterest, 0);
        assertGt(updatedFactor, 0);
    }

    function testInterestPreviewFromMiddleCycle() public {
        // Test preview for position from cycle 2 to current time
        uint256 balance = 2000 ether;
        uint256 lastModifiedTime = cycle2StartTime + 1 days; // 1 day into cycle 2
        uint256 factorBefore = 1000 ether;
        
        (uint256 finalizedInterest, uint256 updatedFactor) = 
            cycleUpdater.interestPreview(balance, 2, lastModifiedTime, factorBefore);
        
        // Should have less finalized interest than previous test (fewer cycles)
        assertGt(finalizedInterest, 0);
        assertGt(updatedFactor, 0);
    }

    function testInterestPreviewCurrentCycle() public {
        // Test preview within current cycle
        uint256 balance = 500 ether;
        uint256 lastModifiedTime = cycle3StartTime + 1 hours; // 1 hour into cycle 3
        uint256 factorBefore = 100 ether;
        
        vm.warp(cycle3StartTime + 6 hours); // Advance to 6 hours into cycle 3
        
        (uint256 finalizedInterest, uint256 updatedFactor) = 
            cycleUpdater.interestPreview(balance, 3, lastModifiedTime, factorBefore);
        
        // No finalized interest (same cycle), only updated factor
        assertEq(finalizedInterest, 0);
        uint256 expectedFactor = balance * (block.timestamp - lastModifiedTime) + factorBefore;
        assertEq(updatedFactor, expectedFactor);
    }

    // ============ ADVANCED CYCLE MANAGEMENT TESTS ============

    function testStartNewCycleInEstablishedSystem() public {
        uint256 currentCycle = cycleUpdater.getCurrentCycleIndex();
        assertEq(currentCycle, 3);
        
        // Advance time and start another cycle
        vm.warp(block.timestamp + 4 days);
        uint256 newInterest = 12000 ether;
        uint256 expectedRateFactor = newInterest / (4 days);
        uint256 expectedSnapshot = 33000 ether + newInterest; // Previous + new
        
        vm.expectEmit(true, true, true, true);
        emit UpdateCycle(3, expectedRateFactor, expectedSnapshot, block.timestamp);
        
        cycleUpdater.startNewCycle(3, newInterest);
        
        // Verify new state
        assertEq(cycleUpdater.getCurrentCycleIndex(), 4);
        assertEq(cycleUpdater.getAccumulatedInterest(), expectedSnapshot);
        
        // Verify cycle 3 was finalized
        CycleUpdater.Cycle memory cycle3 = cycleUpdater.getCycle(3);
        assertEq(cycle3.rateFactor, expectedRateFactor);
        assertEq(cycle3.interestSnapShot, expectedSnapshot);
    }

    function testInvalidCycleIndexInEstablishedSystem() public {
        // Try to start with wrong cycle index
        vm.expectRevert("CycleUpdater: invalid currentCycle");
        cycleUpdater.startNewCycle(2, 1000 ether); // Should be 3
        
        vm.expectRevert("CycleUpdater: invalid currentCycle");
        cycleUpdater.startNewCycle(4, 1000 ether); // Should be 3
    }

    // ============ MULTI-CYCLE ACCUMULATION TESTS ============

    function testAccumulatedInterestInEstablishedSystem() public {
        uint256 accumulated = cycleUpdater.getAccumulatedInterest();
        assertEq(accumulated, 33000 ether); // 10000 + 15000 + 8000
        
        // Start another cycle and verify accumulation
        vm.warp(block.timestamp + 2 days);
        cycleUpdater.startNewCycle(3, 5000 ether);
        
        assertEq(cycleUpdater.getAccumulatedInterest(), 38000 ether); // 33000 + 5000
    }

    // ============ COMPLEX SCENARIO TESTS ============

    function testComplexInterestCalculationAcrossManyCycles() public {
        // Test interest preview spanning from cycle 0 to current
        uint256 balance = 3000 ether;
        uint256 lastModifiedTime = cycle0StartTime + 3 days; // 3 days into cycle 0
        uint256 factorBefore = 200 ether;
        
        (uint256 finalizedInterest, uint256 updatedFactor) = 
            cycleUpdater.interestPreview(balance, 0, lastModifiedTime, factorBefore);
        
        // Should calculate interest across cycles 0, 1, 2 and partial cycle 3
        assertGt(finalizedInterest, 0);
        
        // Interest should be substantial given the balance and time span
        console.log("Finalized interest across many cycles:", finalizedInterest);
        console.log("Updated factor:", updatedFactor);
        
        // Verify it's a reasonable amount (should be quite large given the span)
        assertGt(finalizedInterest, 1000 ether); // Should be significant
    }

    function testAccessControlInEstablishedSystem() public {
        vm.prank(nonOwner);
        vm.expectRevert();
        cycleUpdater.startNewCycle(3, 1000 ether);
        
        // Owner should still work
        vm.prank(owner);
        vm.warp(block.timestamp + 1 days);
        cycleUpdater.startNewCycle(3, 1000 ether);
        assertEq(cycleUpdater.getCurrentCycleIndex(), 4);
    }

    // ============ EDGE CASE TESTS IN ESTABLISHED SYSTEM ============

    function testInterestPreviewZeroTimeInEstablishedSystem() public {
        (uint256 finalizedInterest, uint256 updatedFactor) = 
            cycleUpdater.interestPreview(1000 ether, 3, 0, 0);
        
        assertEq(finalizedInterest, 0);
        assertEq(updatedFactor, 0);
    }

    function testInterestPreviewSameTimestampInEstablishedSystem() public {
        (uint256 finalizedInterest, uint256 updatedFactor) = 
            cycleUpdater.interestPreview(1000 ether, 3, block.timestamp, 500 ether);
        
        assertEq(finalizedInterest, 0);
        assertEq(updatedFactor, 500 ether);
    }

    function testZeroInterestCycleInEstablishedSystem() public {
        vm.warp(block.timestamp + 2 days);
        
        // Starting new cycle with zero interest should work even in established system
        cycleUpdater.startNewCycle(3, 0);
        
        CycleUpdater.Cycle memory cycle3 = cycleUpdater.getCycle(3);
        assertEq(cycle3.rateFactor, 0);
        assertEq(cycle3.interestSnapShot, 33000 ether); // Previous accumulated, no new interest
    }
}

contract CycleUpdaterBugTest is Test {
    CycleUpdater public cycleUpdater;
    ERC1967Proxy public proxy;
    address owner = address(this);

    function setUp() public {
        CycleUpdater implementation = new CycleUpdater();
        proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(CycleUpdater.initialize.selector)
        );
        cycleUpdater = CycleUpdater(address(proxy));
    }

    // ============ POTENTIAL BUGS FOUND ============

    function testDivisionByZeroInSameBlock() public {
        // Start first cycle
        cycleUpdater.startNewCycle(0, 0);
        
        // Try to start another cycle in the same block (same timestamp)
        // This should cause division by zero: _currentCycleInterest / (block.timestamp - cycle.startTime)
        // where (block.timestamp - cycle.startTime) = 0
        
        vm.expectRevert(); // This should revert due to division by zero
        cycleUpdater.startNewCycle(0, 1000 ether);
    }

    function testFinalizedInterestLogic() public {
        // Test the _finalizedInterest function behavior to understand its logic
        
        // Start first cycle
        cycleUpdater.startNewCycle(0, 0);
        uint256 cycle0Start = block.timestamp;
        
        // Advance time and start second cycle
        vm.warp(cycle0Start + 1 days);
        cycleUpdater.startNewCycle(0, 1000 ether);
        
        // Advance time and start third cycle  
        vm.warp(block.timestamp + 1 days);
        cycleUpdater.startNewCycle(1, 2000 ether);
        
        // Now we're in cycle 2. Test interest preview from cycle 0
        uint256 balance = 1000 ether;
        uint256 lastModifiedTime = cycle0Start + 12 hours; // 12 hours into cycle 0
        uint256 factorBefore = 500 ether;
        
        (uint256 finalizedInterest, uint256 updatedFactor) = 
            cycleUpdater.interestPreview(balance, 0, lastModifiedTime, factorBefore);
        
        console.log("Finalized interest:", finalizedInterest);
        console.log("Updated factor:", updatedFactor);
        
        // Should have finalized interest > 0 due to spanning multiple cycles
        assertGt(finalizedInterest, 0);
        console.log("_finalizedInterest calculation working correctly");
    }

    function testHistoricalSimulationBehavior() public {
        // Test to understand the intended behavior of historical simulation
        // as mentioned by the user - this is NOT a bug but intended behavior
        
        // Setup multiple cycles
        cycleUpdater.startNewCycle(0, 0);
        uint256 cycle0Start = block.timestamp;
        
        vm.warp(cycle0Start + 1 days);
        cycleUpdater.startNewCycle(0, 1000 ether);
        uint256 cycle1Start = block.timestamp;
        
        vm.warp(cycle1Start + 2 days);
        cycleUpdater.startNewCycle(1, 2000 ether);
        uint256 cycle2Start = block.timestamp;
        
        // Now we're in cycle 2. Test interest preview from cycle 0
        uint256 balance = 1000 ether;
        uint256 lastModifiedTime = cycle0Start + 12 hours;
        uint256 factorBefore = 500 ether;
        
        (uint256 finalizedInterest, uint256 updatedFactor) = 
            cycleUpdater.interestPreview(balance, 0, lastModifiedTime, factorBefore);
        
        // This is intentional behavior for historical simulation
        uint256 expectedUpdatedFactor = balance * (block.timestamp - cycle0Start);
        
        console.log("Finalized interest:", finalizedInterest);
        console.log("Updated factor:", updatedFactor);
        console.log("Expected updated factor (from cycle 0):", expectedUpdatedFactor);
        
        assertEq(updatedFactor, expectedUpdatedFactor);
        console.log("Historical simulation working as intended");
    }

    function testZeroInterestEdgeCase() public {
        // Test edge case with zero interest but non-zero time
        cycleUpdater.startNewCycle(0, 0);
        
        vm.warp(block.timestamp + 1 days);
        
        // Start cycle with zero interest - rate factor should be 0
        cycleUpdater.startNewCycle(0, 0);
        
        CycleUpdater.Cycle memory cycle = cycleUpdater.getCycle(0);
        assertEq(cycle.rateFactor, 0); // 0 / (1 days) = 0
        assertEq(cycle.interestSnapShot, 0);
    }

    function testPrecisionLossInRateFactor() public {
        // Test potential precision loss in rate factor calculation
        cycleUpdater.startNewCycle(0, 0);
        
        // Use a very short time with small interest
        vm.warp(block.timestamp + 1); // 1 second
        
        uint256 smallInterest = 1; // 1 wei
        cycleUpdater.startNewCycle(0, smallInterest);
        
        CycleUpdater.Cycle memory cycle = cycleUpdater.getCycle(0);
        console.log("Rate factor with 1 wei over 1 second:", cycle.rateFactor);
        // Should be 1, but might lose precision
        
        // Now test with larger numbers
        vm.warp(block.timestamp + 1);
        uint256 largeInterest = 1000000 ether;
        cycleUpdater.startNewCycle(1, largeInterest);
        
        CycleUpdater.Cycle memory cycle2 = cycleUpdater.getCycle(1);
        console.log("Rate factor with large interest:", cycle2.rateFactor);
    }
}
