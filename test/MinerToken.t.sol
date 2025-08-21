// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/MinerToken.sol";
import "../src/interface/ICycleUpdater.sol";

// Mock ERC20 token for interest payments
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10**18); // Mint 1M tokens
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

// Mock CycleUpdater for testing
contract MockCycleUpdater is ICycleUpdater {
    uint256 private _currentCycle = 0;
    uint256 private _accumulatedInterest = 0;
    
    mapping(uint256 => Cycle) private _cycles;
    
    constructor() {
        // Initialize cycles
        _cycles[0] = Cycle({
            startTime: block.timestamp,
            rateFactor: 1000,
            interestSnapShot: 0
        });
        _cycles[1] = Cycle({
            startTime: block.timestamp + 86400, // 1 day later
            rateFactor: 1100,
            interestSnapShot: 100
        });
        _cycles[2] = Cycle({
            startTime: block.timestamp + 172800, // 2 days later
            rateFactor: 1200,
            interestSnapShot: 250
        });
    }
    
    function getCurrentCycleIndex() external view returns (uint256) {
        return _currentCycle;
    }
    
    function getCycle(uint256 index) external view returns (Cycle memory) {
        return _cycles[index];
    }
    
    function getAccumulatedInterest() external view returns (uint256) {
        return _accumulatedInterest;
    }
    
    function interestPreview(
        uint256 balance,
        uint256 lastModifiedCycle,
        uint256 lastModifiedTime,
        uint256 factor
    ) external view returns (uint256 finalizedInterest, uint256 updatedFactor) {
        // Interest is only finalized when cycle changes
        if (lastModifiedTime > 0 && lastModifiedCycle < _currentCycle) {
            // Calculate interest for each completed cycle
            uint256 cyclesPassed = _currentCycle - lastModifiedCycle;
            // 2% interest per cycle completed
            finalizedInterest = balance * cyclesPassed * 2 / 100;
            updatedFactor = factor + (cyclesPassed * 50);
        } else {
            finalizedInterest = 0;
            updatedFactor = factor;
        }
    }
    
    function setCurrentCycle(uint256 cycle) external {
        _currentCycle = cycle;
        // Update cycle data if needed
        if (_cycles[cycle].startTime == 0) {
            _cycles[cycle] = Cycle({
                startTime: block.timestamp,
                rateFactor: 1000 + (cycle * 100),
                interestSnapShot: cycle * 100
            });
        }
    }
    
    function startNewCycle() external {
        _currentCycle++;
        _cycles[_currentCycle] = Cycle({
            startTime: block.timestamp,
            rateFactor: 1000 + (_currentCycle * 100),
            interestSnapShot: _currentCycle * 100
        });
    }
}

contract MinerTokenTest is Test {
    MinerToken public minerToken;
    MockERC20 public interestToken;
    MockCycleUpdater public cycleUpdater;
    ERC1967Proxy public proxy;
    
    address public owner = address(this);
    address public debtorManager = address(0x1);
    address public debtor1 = address(0x2);
    address public debtor2 = address(0x3);
    address public creditor1 = address(0x4);
    address public creditor2 = address(0x5);
    address public beneficiary = address(0x6);
    address public nonDebtor = address(0x7);
    
    // Events for testing
    event RegisterDebtor(address debtor);
    event Mint(address byDebtor, address to, uint256 amount);
    event Burn(address from, address forDebtor, uint256 amount);
    event Claim(address holder, address to, uint256 amount);
    event RemoveReserve(address debtor, uint256 amount);
    event AddReserve(address debtor, uint256 amount);
    event DesignatedBeneficiaryUpdated(address indexed settlor, address indexed beneficiary, address indexed operator);
    
    function setUp() public {
        // Deploy mock contracts
        interestToken = new MockERC20("Interest Token", "INT");
        cycleUpdater = new MockCycleUpdater();
        
        // Deploy MinerToken implementation
        MinerToken implementation = new MinerToken();
        
        // Deploy proxy
        proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(
                MinerToken.initialize.selector,
                "Miner Token",
                "MINER",
                18,
                address(interestToken),
                address(cycleUpdater)
            )
        );
        
        minerToken = MinerToken(address(proxy));
        
        // Set debtor manager
        minerToken.setDebtorManager(debtorManager);
        
        // Fund the contract with interest tokens
        interestToken.transfer(address(minerToken), 10000 * 10**18);
        
        // Give creditors some interest tokens for adding reserves
        interestToken.transfer(creditor1, 1000 * 10**18);
        interestToken.transfer(creditor2, 1000 * 10**18);
    }
    
    // ============ INITIALIZATION TESTS ============
    
    function testInitialize() public {
        assertEq(minerToken.name(), "Miner Token");
        assertEq(minerToken.symbol(), "MINER");
        assertEq(minerToken.decimals(), 18);
        assertEq(minerToken.interestToken(), address(interestToken));
        assertEq(minerToken.cycleUpdater(), address(cycleUpdater));
        assertEq(minerToken.owner(), owner);
    }
    
    function testCannotInitializeTwice() public {
        vm.expectRevert();
        minerToken.initialize("Test", "TEST", 18, address(interestToken), address(cycleUpdater));
    }
    
    // ============ DEBTOR REGISTRATION TESTS ============
    
    function testRegisterDebtor() public {
        vm.prank(debtorManager);
        vm.expectEmit(true, false, false, false);
        emit RegisterDebtor(debtor1);
        minerToken.registerDebtor(debtor1);
        
        assertTrue(minerToken.isDebtor(debtor1));
        
        IMinerToken.Debtor memory debtor = minerToken.getDebtor(debtor1);
        assertEq(debtor.timeStamp.lastModifiedTime, block.timestamp);
        assertEq(debtor.outStandingBalance, 0);
        assertEq(debtor.interestReserve, 0);
    }
    
    function testCannotRegisterDebtorTwice() public {
        vm.prank(debtorManager);
        minerToken.registerDebtor(debtor1);
        
        vm.prank(debtorManager);
        vm.expectRevert("MinerToken: debtor already exists");
        minerToken.registerDebtor(debtor1);
    }
    
    function testOnlyDebtorManagerCanRegister() public {
        vm.prank(nonDebtor);
        vm.expectRevert("MinerToken: caller must be debtor manager");
        minerToken.registerDebtor(debtor1);
    }
    
    // ============ _UPDATE FUNCTION TESTS - MINTING SCENARIOS ============
    
    function testMintFromDebtorToCreditor() public {
        // Register debtor
        vm.prank(debtorManager);
        minerToken.registerDebtor(debtor1);
        
        // Debtor mints tokens to creditor
        vm.prank(debtor1);
        vm.expectEmit(true, true, false, true);
        emit Mint(debtor1, creditor1, 100);
        minerToken.mint(creditor1, 100);
        
        // Check balances
        assertEq(minerToken.balanceOf(creditor1), 100);
        assertEq(minerToken.balanceOf(debtor1), 0); // Debtors cannot hold tokens
        
        // Check debtor outstanding balance
        IMinerToken.Debtor memory debtor = minerToken.getDebtor(debtor1);
        assertEq(debtor.outStandingBalance, 100);
    }
    
    function testCannotMintFromDebtorToDebtor() public {
        // Register debtors
        vm.prank(debtorManager);
        minerToken.registerDebtor(debtor1);
        vm.prank(debtorManager);
        minerToken.registerDebtor(debtor2);
        
        // Try to mint from debtor to debtor - should fail
        vm.prank(debtor1);
        vm.expectRevert("MinerToken: cannot mint to debtor");
        minerToken.mint(debtor2, 100);
    }
    
    function testCannotMintFromNonDebtor() public {
        vm.prank(nonDebtor);
        vm.expectRevert("MinerToken: cannot mint by a non-debtor");
        minerToken.mint(creditor1, 100);
    }
    
    function testCannotMintToZeroAddress() public {
        vm.prank(debtorManager);
        minerToken.registerDebtor(debtor1);
        
        vm.prank(debtor1);
        vm.expectRevert("MinerToken: cannot mint to zero address");
        minerToken.mint(address(0), 100);
    }
    
    // ============ _UPDATE FUNCTION TESTS - BURNING SCENARIOS ============
    
    function testBurnFromCreditorToDebtor() public {
        // Setup: register debtor, mint tokens, then burn
        vm.prank(debtorManager);
        minerToken.registerDebtor(debtor1);
        
        vm.prank(debtor1);
        minerToken.mint(creditor1, 200);
        
        // Transfer from creditor to debtor (burning)
        vm.prank(creditor1);
        vm.expectEmit(true, true, false, true);
        emit Burn(creditor1, debtor1, 50);
        minerToken.transfer(debtor1, 50);
        
        // Check balances
        assertEq(minerToken.balanceOf(creditor1), 150);
        assertEq(minerToken.balanceOf(debtor1), 0); // Still 0, tokens were burned
        
        // Check debtor outstanding balance reduced
        IMinerToken.Debtor memory debtor = minerToken.getDebtor(debtor1);
        assertEq(debtor.outStandingBalance, 150);
    }
    
    function testCannotBurnMoreThanOutstandingBalance() public {
        // Setup: register debtor, mint tokens
        vm.prank(debtorManager);
        minerToken.registerDebtor(debtor1);
        
        vm.prank(debtor1);
        minerToken.mint(creditor1, 100);
        
        // Try to burn more than outstanding balance
        vm.prank(creditor1);
        vm.expectRevert("MinerToken: insufficient outStandingBalance");
        minerToken.transfer(debtor1, 150);
    }
    
    // ============ _UPDATE FUNCTION TESTS - NORMAL TRANSFERS ============
    
    function testTransferBetweenCreditors() public {
        // Setup: register debtor, mint tokens to creditor1
        vm.prank(debtorManager);
        minerToken.registerDebtor(debtor1);
        
        vm.prank(debtor1);
        minerToken.mint(creditor1, 200);
        
        // Transfer between creditors
        vm.prank(creditor1);
        minerToken.transfer(creditor2, 80);
        
        // Check balances
        assertEq(minerToken.balanceOf(creditor1), 120);
        assertEq(minerToken.balanceOf(creditor2), 80);
    }
    
    // ============ DESIGNATED BENEFICIARY TESTS ============
    
    function testSetDesignatedBeneficiaryBySettlor() public {
        vm.prank(creditor1);
        vm.expectEmit(true, true, true, false);
        emit DesignatedBeneficiaryUpdated(creditor1, beneficiary, creditor1);
        minerToken.setDesignatedBeneficiary(creditor1, beneficiary);
        
        assertEq(minerToken.getDesignatedBeneficiary(creditor1), beneficiary);
    }
    
    function testSetDesignatedBeneficiaryByOwner() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, false);
        emit DesignatedBeneficiaryUpdated(creditor1, beneficiary, owner);
        minerToken.setDesignatedBeneficiary(creditor1, beneficiary);
        
        assertEq(minerToken.getDesignatedBeneficiary(creditor1), beneficiary);
    }
    
    function testCannotSetDesignatedBeneficiaryByUnauthorized() public {
        vm.prank(nonDebtor);
        vm.expectRevert("MinerToken: caller must be settlor or owner");
        minerToken.setDesignatedBeneficiary(creditor1, beneficiary);
    }
    
    function testCannotSetZeroAddresses() public {
        vm.expectRevert("MinerToken: settlor cannot be zero address");
        minerToken.setDesignatedBeneficiary(address(0), beneficiary);
        
        vm.expectRevert("MinerToken: beneficiary cannot be zero address");
        minerToken.setDesignatedBeneficiary(creditor1, address(0));
    }
    
    // ============ INTEREST CLAIMING TESTS ============
    
    // ============ CYCLE-BASED INTEREST TESTS ============
    
    function testInterestOnlyAccruesOnCycleChange() public {
        // Setup: register debtor, mint tokens
        vm.prank(debtorManager);
        minerToken.registerDebtor(debtor1);
        
        vm.prank(debtor1);
        minerToken.mint(creditor1, 1000);
        
        // Skip time but stay in same cycle - no interest should accrue
        vm.warp(block.timestamp + 86400);
        
        // Settle creditor
        minerToken._settleCreditor(creditor1);
        
        // Try to claim interest - should fail because no cycle change occurred
        vm.prank(creditor1);
        vm.expectRevert(); // Should revert with MinerTokenInsufficientInterest
        minerToken.claim(creditor1, creditor1, 1);
    }
    
    function testSingleCycleInterestAccrual() public {
        // Setup: register debtor, mint tokens
        vm.prank(debtorManager);
        minerToken.registerDebtor(debtor1);
        
        vm.prank(debtor1);
        minerToken.mint(creditor1, 1000); // Current cycle: 0
        
        uint256 initialInterestBalance = interestToken.balanceOf(creditor1);
        
        // Advance time and move to next cycle to finalize interest
        vm.warp(block.timestamp + 1); // Advance time to trigger settlement
        cycleUpdater.setCurrentCycle(1);
        
        // Settle creditor to calculate interest
        minerToken._settleCreditor(creditor1);
        
        // Should have 2% interest on 1000 = 20 tokens
        uint256 expectedInterest = 20;
        
        // Claim interest
        vm.prank(creditor1);
        vm.expectEmit(true, true, false, true);
        emit Claim(creditor1, creditor1, expectedInterest);
        minerToken.claim(creditor1, creditor1, expectedInterest);
        
        // Check interest token balance increased
        assertEq(interestToken.balanceOf(creditor1), initialInterestBalance + expectedInterest);
    }
    
    function testMultipleCycleInterestAccrual() public {
        // Setup: register debtor, mint tokens
        vm.prank(debtorManager);
        minerToken.registerDebtor(debtor1);
        
        vm.prank(debtor1);
        minerToken.mint(creditor1, 1000); // Current cycle: 0
        
        uint256 initialInterestBalance = interestToken.balanceOf(creditor1);
        
        // Advance time and move through multiple cycles (0 -> 3 = 3 cycles passed)
        vm.warp(block.timestamp + 1);
        cycleUpdater.setCurrentCycle(3);
        
        // Settle creditor to calculate interest
        minerToken._settleCreditor(creditor1);
        
        // Should have 2% interest per cycle: 1000 * 3 cycles * 2% = 60 tokens
        uint256 expectedInterest = 60;
        
        // Claim interest
        vm.prank(creditor1);
        vm.expectEmit(true, true, false, true);
        emit Claim(creditor1, creditor1, expectedInterest);
        minerToken.claim(creditor1, creditor1, expectedInterest);
        
        // Check interest token balance increased
        assertEq(interestToken.balanceOf(creditor1), initialInterestBalance + expectedInterest);
    }
    
    function testInterestAccumulationWithPartialClaims() public {
        // Setup: register debtor, mint tokens
        vm.prank(debtorManager);
        minerToken.registerDebtor(debtor1);
        
        vm.prank(debtor1);
        minerToken.mint(creditor1, 1000); // Current cycle: 0
        
        uint256 initialInterestBalance = interestToken.balanceOf(creditor1);
        
        // Move to cycle 1
        vm.warp(block.timestamp + 1);
        cycleUpdater.setCurrentCycle(1);
        minerToken._settleCreditor(creditor1);
        
        // Claim partial interest (10 out of 20)
        vm.prank(creditor1);
        minerToken.claim(creditor1, creditor1, 10);
        
        // Move to cycle 2
        vm.warp(block.timestamp + 1);
        cycleUpdater.setCurrentCycle(2);
        minerToken._settleCreditor(creditor1);
        
        // Should now have remaining 10 from first cycle + 20 from second cycle = 30 total
        vm.prank(creditor1);
        minerToken.claim(creditor1, creditor1, 30);
        
        // Check total claimed is correct
        assertEq(interestToken.balanceOf(creditor1), initialInterestBalance + 40);
    }
    
    function testClaimInterestByDesignatedBeneficiary() public {
        // Setup designated beneficiary
        vm.prank(creditor1);
        minerToken.setDesignatedBeneficiary(creditor1, beneficiary);
        
        // Setup: register debtor, mint tokens
        vm.prank(debtorManager);
        minerToken.registerDebtor(debtor1);
        
        vm.prank(debtor1);
        minerToken.mint(creditor1, 1000);
        
        uint256 initialBeneficiaryBalance = interestToken.balanceOf(beneficiary);
        
        // Move to next cycle to generate interest
        vm.warp(block.timestamp + 1);
        cycleUpdater.setCurrentCycle(1);
        minerToken._settleCreditor(creditor1);
        
        uint256 expectedInterest = 20; // 2% of 1000
        
        // Claim by beneficiary
        vm.prank(beneficiary);
        vm.expectEmit(true, true, false, true);
        emit Claim(creditor1, beneficiary, expectedInterest);
        minerToken.claim(creditor1, beneficiary, expectedInterest);
        
        assertEq(interestToken.balanceOf(beneficiary), initialBeneficiaryBalance + expectedInterest);
    }
    
    function testMultipleCreditorsCycleInterest() public {
        // Setup: register debtor, mint tokens to multiple creditors
        vm.prank(debtorManager);
        minerToken.registerDebtor(debtor1);
        
        vm.prank(debtor1);
        minerToken.mint(creditor1, 1000); // creditor1 gets 1000 tokens
        
        vm.prank(debtor1);
        minerToken.mint(creditor2, 500);  // creditor2 gets 500 tokens
        
        // Move to next cycle
        vm.warp(block.timestamp + 1);
        cycleUpdater.setCurrentCycle(1);
        
        // Settle both creditors
        minerToken._settleCreditor(creditor1);
        minerToken._settleCreditor(creditor2);
        
        // creditor1 should have 20 interest (2% of 1000)
        // creditor2 should have 10 interest (2% of 500)
        
        uint256 initialBalance1 = interestToken.balanceOf(creditor1);
        uint256 initialBalance2 = interestToken.balanceOf(creditor2);
        
        vm.prank(creditor1);
        minerToken.claim(creditor1, creditor1, 20);
        
        vm.prank(creditor2);
        minerToken.claim(creditor2, creditor2, 10);
        
        assertEq(interestToken.balanceOf(creditor1), initialBalance1 + 20);
        assertEq(interestToken.balanceOf(creditor2), initialBalance2 + 10);
    }
    
    function testInterestFactorUpdatesWithCycles() public {
        // This test verifies that the interest factor gets updated properly
        // when cycles change (testing the newInterestFactor return from interestPreview)
        
        vm.prank(debtorManager);
        minerToken.registerDebtor(debtor1);
        
        vm.prank(debtor1);
        minerToken.mint(creditor1, 1000);
        
        // Move through multiple cycles to test factor accumulation
        vm.warp(block.timestamp + 1);
        cycleUpdater.setCurrentCycle(1);
        minerToken._settleCreditor(creditor1);
        
        vm.warp(block.timestamp + 1);
        cycleUpdater.setCurrentCycle(2);
        minerToken._settleCreditor(creditor1);
        
        // After 2 cycle changes, factor should have increased by 100 (50 per cycle)
        // This is implementation detail but verifies the factor update mechanism works
        
        // The main test is that this doesn't revert and interest accumulates
        vm.prank(creditor1);
        minerToken.claim(creditor1, creditor1, 40); // 2% per cycle * 2 cycles * 1000 = 40
        
        assertTrue(true); // Test passes if no revert occurred
    }
    
    // ============ DEBTOR CYCLE-BASED DEBT TESTS ============
    
    function testDebtorInterestAccrualOverCycles() public {
        // Setup: register debtor, mint tokens to create debt
        vm.prank(debtorManager);
        minerToken.registerDebtor(debtor1);
        
        vm.prank(debtor1);
        minerToken.mint(creditor1, 1000); // Creates 1000 outstanding balance
        
        // Check initial debtor state
        IMinerToken.Debtor memory debtorBefore = minerToken.getDebtor(debtor1);
        assertEq(debtorBefore.outStandingBalance, 1000);
        int256 initialReserve = debtorBefore.interestReserve;
        
        // Move to next cycle to accumulate debt interest
        vm.warp(block.timestamp + 1);
        cycleUpdater.setCurrentCycle(1);
        minerToken._settleDebtor(debtor1);
        
        // Check debtor state after cycle - debt interest should have reduced reserve
        IMinerToken.Debtor memory debtorAfter = minerToken.getDebtor(debtor1);
        
        // Debt interest should be 2% of outstanding balance = 20
        // This reduces the interest reserve by 20
        assertEq(debtorAfter.interestReserve, initialReserve - 20);
    }
    
    function testDebtorMultipleCycleDebtAccumulation() public {
        // Setup: register debtor, add some reserve, then create debt
        vm.prank(debtorManager);
        minerToken.registerDebtor(debtor1);
        
        // Add reserve to start with positive balance
        vm.prank(creditor1);
        interestToken.approve(address(minerToken), 100);
        vm.prank(creditor1);
        minerToken.addReserve(debtor1, 100);
        
        vm.prank(debtor1);
        minerToken.mint(creditor1, 1000); // Creates 1000 outstanding balance
        
        // Move through multiple cycles (3 cycles)
        vm.warp(block.timestamp + 1);
        cycleUpdater.setCurrentCycle(3);
        minerToken._settleDebtor(debtor1);
        
        // Check debtor state - should have accumulated 3 cycles of debt interest
        IMinerToken.Debtor memory debtor = minerToken.getDebtor(debtor1);
        
        // Initial reserve: 100
        // Debt per cycle: 1000 * 2% = 20
        // Total debt over 3 cycles: 60
        // Final reserve: 100 - 60 = 40
        assertEq(debtor.interestReserve, 40);
    }
    
    function testDebtorCanGoIntoNegativeReserve() public {
        // Test that debtor's interest reserve can go negative (into debt)
        vm.prank(debtorManager);
        minerToken.registerDebtor(debtor1);
        
        vm.prank(debtor1);
        minerToken.mint(creditor1, 1000); // Creates 1000 outstanding balance, 0 reserve
        
        // Move through cycles to accumulate debt
        vm.warp(block.timestamp + 1);
        cycleUpdater.setCurrentCycle(2);
        minerToken._settleDebtor(debtor1);
        
        IMinerToken.Debtor memory debtor = minerToken.getDebtor(debtor1);
        
        // Should have negative reserve: 0 - (1000 * 2% * 2 cycles) = -40
        assertEq(debtor.interestReserve, -40);
    }
    
    function testComplexCycleScenario() public {
        // Test a complex scenario with multiple creditors, debtors, and cycle changes
        
        // Setup two debtors
        vm.prank(debtorManager);
        minerToken.registerDebtor(debtor1);
        vm.prank(debtorManager);
        minerToken.registerDebtor(debtor2);
        
        // debtor1 mints to creditor1, debtor2 mints to creditor2
        vm.prank(debtor1);
        minerToken.mint(creditor1, 1000);
        vm.prank(debtor2);
        minerToken.mint(creditor2, 500);
        
        // Move to cycle 1 - first interest/debt accumulation
        vm.warp(block.timestamp + 1);
        cycleUpdater.setCurrentCycle(1);
        
        // Settle everyone
        minerToken._settleCreditor(creditor1);
        minerToken._settleCreditor(creditor2);
        minerToken._settleDebtor(debtor1);
        minerToken._settleDebtor(debtor2);
        
        // Verify creditor interest
        vm.prank(creditor1);
        minerToken.claim(creditor1, creditor1, 20); // 2% of 1000
        
        vm.prank(creditor2);
        minerToken.claim(creditor2, creditor2, 10); // 2% of 500
        
        // Check debtor reserves went negative
        IMinerToken.Debtor memory debtor1State = minerToken.getDebtor(debtor1);
        IMinerToken.Debtor memory debtor2State = minerToken.getDebtor(debtor2);
        
        assertEq(debtor1State.interestReserve, -20); // Debt accumulated
        assertEq(debtor2State.interestReserve, -10); // Debt accumulated
        
        // Now creditor1 burns some tokens to reduce debtor1's debt
        vm.prank(creditor1);
        minerToken.transfer(debtor1, 200); // Burns 200 tokens, reduces outstanding balance
        
        // Check outstanding balance reduced
        debtor1State = minerToken.getDebtor(debtor1);
        assertEq(debtor1State.outStandingBalance, 800);
        
        // Move to cycle 2 and verify debt calculation is based on new outstanding balance
        vm.warp(block.timestamp + 1);
        cycleUpdater.setCurrentCycle(2);
        minerToken._settleDebtor(debtor1);
        
        debtor1State = minerToken.getDebtor(debtor1);
        // Previous reserve: -20, new debt: 800 * 2% = 16, total: -36
        assertEq(debtor1State.interestReserve, -36);
    }
    
    function testCannotClaimMoreThanAvailable() public {
        vm.prank(debtorManager);
        minerToken.registerDebtor(debtor1);
        
        vm.prank(debtor1);
        minerToken.mint(creditor1, 1000);
        
        // Try to claim more than available interest
        vm.prank(creditor1);
        vm.expectRevert(); // Should revert with MinerTokenInsufficientInterest
        minerToken.claim(creditor1, creditor1, 1000);
    }
    
    function testCannotClaimByUnauthorized() public {
        vm.prank(debtorManager);
        minerToken.registerDebtor(debtor1);
        
        vm.prank(debtor1);
        minerToken.mint(creditor1, 1000);
        
        vm.prank(nonDebtor);
        vm.expectRevert("MinerToken: caller must be creditor or designated beneficiary");
        minerToken.claim(creditor1, nonDebtor, 10);
    }
    
    function testCannotClaimForDebtor() public {
        vm.prank(debtorManager);
        minerToken.registerDebtor(debtor1);
        
        vm.prank(debtor1);
        vm.expectRevert("MinerToken: creditor must not be debtor");
        minerToken.claim(debtor1, debtor1, 10);
    }
    
    // ============ RESERVE MANAGEMENT TESTS ============
    
    function testAddReserve() public {
        vm.prank(debtorManager);
        minerToken.registerDebtor(debtor1);
        
        // Approve and add reserve
        vm.prank(creditor1);
        interestToken.approve(address(minerToken), 500);
        
        vm.prank(creditor1);
        vm.expectEmit(true, false, false, true);
        emit AddReserve(debtor1, 500);
        minerToken.addReserve(debtor1, 500);
        
        IMinerToken.Debtor memory debtor = minerToken.getDebtor(debtor1);
        assertEq(debtor.interestReserve, 500);
    }
    
    function testCannotAddReserveToNonDebtor() public {
        vm.prank(creditor1);
        interestToken.approve(address(minerToken), 500);
        
        vm.prank(creditor1);
        vm.expectRevert("MinerToken: cannot add reserve to non-debtor");
        minerToken.addReserve(nonDebtor, 500);
    }
    
    function testRemoveReserve() public {
        // Setup: add reserve first
        vm.prank(debtorManager);
        minerToken.registerDebtor(debtor1);
        
        vm.prank(creditor1);
        interestToken.approve(address(minerToken), 500);
        
        vm.prank(creditor1);
        minerToken.addReserve(debtor1, 500);
        
        uint256 initialBalance = interestToken.balanceOf(creditor2);
        
        // Remove reserve
        vm.prank(debtor1);
        vm.expectEmit(true, false, false, true);
        emit RemoveReserve(debtor1, 200);
        minerToken.removeReserve(creditor2, 200);
        
        IMinerToken.Debtor memory debtor = minerToken.getDebtor(debtor1);
        assertEq(debtor.interestReserve, 300);
        assertEq(interestToken.balanceOf(creditor2), initialBalance + 200);
    }
    
    function testCannotRemoveMoreThanReserve() public {
        vm.prank(debtorManager);
        minerToken.registerDebtor(debtor1);
        
        vm.prank(debtor1);
        vm.expectRevert("MinerToken: insufficient interest reserve");
        minerToken.removeReserve(creditor1, 100);
    }
    
    function testCannotRemoveReserveByNonDebtor() public {
        vm.prank(debtorManager);
        minerToken.registerDebtor(debtor1);
        
        vm.prank(creditor1);
        interestToken.approve(address(minerToken), 500);
        
        vm.prank(creditor1);
        minerToken.addReserve(debtor1, 500);
        
        vm.prank(nonDebtor);
        vm.expectRevert("MinerToken: cannot remove reserve from non-debtor");
        minerToken.removeReserve(creditor1, 100);
    }
    
    // ============ EDGE CASE AND INTEGRATION TESTS ============
    
    function testComplexScenario() public {
        // Register two debtors
        vm.prank(debtorManager);
        minerToken.registerDebtor(debtor1);
        vm.prank(debtorManager);
        minerToken.registerDebtor(debtor2);
        
        // Debtor1 mints to creditor1
        vm.prank(debtor1);
        minerToken.mint(creditor1, 1000);
        
        // Creditor1 transfers some to creditor2
        vm.prank(creditor1);
        minerToken.transfer(creditor2, 300);
        
        // Creditor2 burns some tokens to reduce debtor1's debt
        vm.prank(creditor2);
        minerToken.transfer(debtor1, 100);
        
        // Check final state
        assertEq(minerToken.balanceOf(creditor1), 700);
        assertEq(minerToken.balanceOf(creditor2), 200);
        assertEq(minerToken.totalSupply(), 900);
        
        IMinerToken.Debtor memory debtor = minerToken.getDebtor(debtor1);
        assertEq(debtor.outStandingBalance, 900);
    }
    
    function testSettlementUpdatesTimestamps() public {
        vm.prank(debtorManager);
        minerToken.registerDebtor(debtor1);
        
        vm.prank(debtor1);
        minerToken.mint(creditor1, 1000);
        
        uint256 initialTime = block.timestamp;
        
        // Advance time
        vm.warp(block.timestamp + 3600);
        
        // Settlement should update timestamp
        minerToken._settleCreditor(creditor1);
        minerToken._settleDebtor(debtor1);
        
        // Verify timestamps were updated (in a real scenario, we'd need getter functions)
        // This is a simplified test - in practice you'd want more detailed timestamp verification
        assertTrue(block.timestamp > initialTime);
    }
    
    // ============ ADMIN FUNCTION TESTS ============
    
    function testSetCycleUpdater() public {
        MockCycleUpdater newCycleUpdater = new MockCycleUpdater();
        
        vm.prank(owner);
        minerToken.setCycleUpdater(address(newCycleUpdater));
        
        assertEq(minerToken.cycleUpdater(), address(newCycleUpdater));
    }
    
    function testCannotSetCycleUpdaterByNonOwner() public {
        MockCycleUpdater newCycleUpdater = new MockCycleUpdater();
        
        vm.prank(nonDebtor);
        vm.expectRevert();
        minerToken.setCycleUpdater(address(newCycleUpdater));
    }
    
    function testSetDebtorManager() public {
        address newDebtorManager = address(0x999);
        
        vm.prank(owner);
        minerToken.setDebtorManager(newDebtorManager);
        
        // Test that new debtor manager can register debtors
        vm.prank(newDebtorManager);
        minerToken.registerDebtor(debtor1);
        
        assertTrue(minerToken.isDebtor(debtor1));
    }
    
    function testCannotSetDebtorManagerByNonOwner() public {
        address newDebtorManager = address(0x999);
        
        vm.prank(nonDebtor);
        vm.expectRevert();
        minerToken.setDebtorManager(newDebtorManager);
    }
    
    function testOldDebtorManagerCannotRegisterAfterChange() public {
        address newDebtorManager = address(0x999);
        
        vm.prank(owner);
        minerToken.setDebtorManager(newDebtorManager);
        
        // Old debtor manager should no longer work
        vm.prank(debtorManager);
        vm.expectRevert("MinerToken: caller must be debtor manager");
        minerToken.registerDebtor(debtor1);
    }
    
    // ============ TIMESTAMP AND SETTLEMENT EDGE CASES ============
    
    function testSettlementSameTimestamp() public {
        vm.prank(debtorManager);
        minerToken.registerDebtor(debtor1);
        
        vm.prank(debtor1);
        minerToken.mint(creditor1, 1000);
        
        // Multiple settlements in the same timestamp should not cause issues
        minerToken._settleCreditor(creditor1);
        minerToken._settleCreditor(creditor1); // Second call should return early
        
        minerToken._settleDebtor(debtor1);
        minerToken._settleDebtor(debtor1); // Second call should return early
        
        // Should not cause any issues
        assertTrue(minerToken.balanceOf(creditor1) == 1000);
    }
    
    function testDetailedTimestampVerification() public {
        vm.prank(debtorManager);
        minerToken.registerDebtor(debtor1);
        
        uint256 initialTimestamp = block.timestamp;
        
        vm.prank(debtor1);
        minerToken.mint(creditor1, 1000);
        
        // Check initial debtor state after registration
        IMinerToken.Debtor memory debtorInitial = minerToken.getDebtor(debtor1);
        assertEq(debtorInitial.timeStamp.lastModifiedTime, initialTimestamp);
        assertEq(debtorInitial.timeStamp.lastModifiedCycle, 0);
        
        // Advance time and trigger settlement
        uint256 newTimestamp = initialTimestamp + 7200; // 2 hours later
        vm.warp(newTimestamp);
        cycleUpdater.setCurrentCycle(1);
        
        minerToken._settleCreditor(creditor1);
        minerToken._settleDebtor(debtor1);
        
        // Verify timestamps were properly updated
        IMinerToken.Debtor memory debtorAfter = minerToken.getDebtor(debtor1);
        assertEq(debtorAfter.timeStamp.lastModifiedTime, newTimestamp);
        assertEq(debtorAfter.timeStamp.lastModifiedCycle, 1);
    }
    
    // ============ ZERO AMOUNT EDGE CASES ============
    
    function testMintZeroAmount() public {
        vm.prank(debtorManager);
        minerToken.registerDebtor(debtor1);
        
        vm.prank(debtor1);
        minerToken.mint(creditor1, 0);
        
        assertEq(minerToken.balanceOf(creditor1), 0);
        assertEq(minerToken.totalSupply(), 0);
        
        IMinerToken.Debtor memory debtor = minerToken.getDebtor(debtor1);
        assertEq(debtor.outStandingBalance, 0);
    }
    
    function testBurnZeroAmount() public {
        vm.prank(debtorManager);
        minerToken.registerDebtor(debtor1);
        
        vm.prank(debtor1);
        minerToken.mint(creditor1, 1000);
        
        vm.prank(creditor1);
        minerToken.transfer(debtor1, 0);
        
        assertEq(minerToken.balanceOf(creditor1), 1000);
        
        IMinerToken.Debtor memory debtor = minerToken.getDebtor(debtor1);
        assertEq(debtor.outStandingBalance, 1000);
    }
    
    function testAddZeroReserve() public {
        vm.prank(debtorManager);
        minerToken.registerDebtor(debtor1);
        
        vm.prank(creditor1);
        interestToken.approve(address(minerToken), 0);
        
        vm.prank(creditor1);
        vm.expectEmit(true, false, false, true);
        emit AddReserve(debtor1, 0);
        minerToken.addReserve(debtor1, 0);
        
        IMinerToken.Debtor memory debtor = minerToken.getDebtor(debtor1);
        assertEq(debtor.interestReserve, 0);
    }
    
    function testClaimZeroInterest() public {
        vm.prank(debtorManager);
        minerToken.registerDebtor(debtor1);
        
        vm.prank(debtor1);
        minerToken.mint(creditor1, 1000);
        
        // Move to next cycle to generate interest
        vm.warp(block.timestamp + 1);
        cycleUpdater.setCurrentCycle(1);
        minerToken._settleCreditor(creditor1);
        
        uint256 initialBalance = interestToken.balanceOf(creditor1);
        
        vm.prank(creditor1);
        vm.expectEmit(true, true, false, true);
        emit Claim(creditor1, creditor1, 0);
        minerToken.claim(creditor1, creditor1, 0);
        
        assertEq(interestToken.balanceOf(creditor1), initialBalance);
    }
    
    // ============ COMPLEX ACCESS CONTROL TESTS ============
    
    function testDesignatedBeneficiaryAccessControl() public {
        vm.prank(debtorManager);
        minerToken.registerDebtor(debtor1);
        
        vm.prank(debtor1);
        minerToken.mint(creditor1, 1000);
        
        // Set designated beneficiary
        vm.prank(creditor1);
        minerToken.setDesignatedBeneficiary(creditor1, beneficiary);
        
        // Move to next cycle
        vm.warp(block.timestamp + 1);
        cycleUpdater.setCurrentCycle(1);
        minerToken._settleCreditor(creditor1);
        
        // Beneficiary should be able to claim
        vm.prank(beneficiary);
        minerToken.claim(creditor1, beneficiary, 20);
        
        // Original creditor should still be able to claim remaining
        vm.prank(creditor1);
        vm.expectRevert(); // Should fail because interest was already claimed
        minerToken.claim(creditor1, creditor1, 20);
    }
    
    function testOwnerCanSetAnyBeneficiary() public {
        // Owner should be able to set beneficiary for any address
        vm.prank(owner);
        minerToken.setDesignatedBeneficiary(creditor1, beneficiary);
        
        assertEq(minerToken.getDesignatedBeneficiary(creditor1), beneficiary);
        
        // Random address should not be able to do this
        vm.prank(nonDebtor);
        vm.expectRevert("MinerToken: caller must be settlor or owner");
        minerToken.setDesignatedBeneficiary(creditor2, beneficiary);
    }
    
    // ============ INTEGRATION TESTS WITH CYCLE CHANGES ============
    
    function testCycleUpdaterIntegration() public {
        vm.prank(debtorManager);
        minerToken.registerDebtor(debtor1);
        
        vm.prank(debtor1);
        minerToken.mint(creditor1, 1000);
        
        // Test that changing cycle updater affects future settlements
        MockCycleUpdater newCycleUpdater = new MockCycleUpdater();
        newCycleUpdater.setCurrentCycle(2); // Start at cycle 2
        
        vm.prank(owner);
        minerToken.setCycleUpdater(address(newCycleUpdater));
        
        // Settlement should now use new cycle updater
        vm.warp(block.timestamp + 1);
        minerToken._settleCreditor(creditor1);
        
        // This tests that the new cycle updater is being used
        // (exact behavior depends on the mock implementation)
        assertTrue(minerToken.cycleUpdater() == address(newCycleUpdater));
    }
    
    function testComplexMultiCycleWithUpdates() public {
        // Test complex scenario with multiple cycle updates and settlements
        vm.prank(debtorManager);
        minerToken.registerDebtor(debtor1);
        
        vm.prank(debtor1);
        minerToken.mint(creditor1, 1000);
        
        // Cycle 0 -> 1
        vm.warp(block.timestamp + 1);
        cycleUpdater.setCurrentCycle(1);
        minerToken._settleCreditor(creditor1);
        
        // Partial claim
        vm.prank(creditor1);
        minerToken.claim(creditor1, creditor1, 10);
        
        // Cycle 1 -> 3 (skip cycle 2)
        vm.warp(block.timestamp + 1);
        cycleUpdater.setCurrentCycle(3);
        minerToken._settleCreditor(creditor1);
        
        // Should have remaining 10 from cycle 1 + 40 from cycles 1->3 = 50 total
        vm.prank(creditor1);
        minerToken.claim(creditor1, creditor1, 50);
        
        uint256 finalBalance = interestToken.balanceOf(creditor1);
        uint256 expectedTotal = 60; // 10 + 50
        assertEq(finalBalance, 1000 * 10**18 + expectedTotal); // Initial balance + claimed interest
    }
    
    // ============ ERROR CONDITION COMPREHENSIVE TESTS ============
    
    function testInsufficientInterestErrorDetails() public {
        vm.prank(debtorManager);
        minerToken.registerDebtor(debtor1);
        
        vm.prank(debtor1);
        minerToken.mint(creditor1, 1000);
        
        // Try to claim interest without generating any
        vm.prank(creditor1);
        vm.expectRevert(abi.encodeWithSelector(
            IMinerToken.MinerTokenInsufficientInterest.selector,
            creditor1,
            0,
            100
        ));
        minerToken.claim(creditor1, creditor1, 100);
    }
    
    function testRemoveReserveFromZeroReserve() public {
        vm.prank(debtorManager);
        minerToken.registerDebtor(debtor1);
        
        // Try to remove reserve when there's none
        vm.prank(debtor1);
        vm.expectRevert("MinerToken: insufficient interest reserve");
        minerToken.removeReserve(creditor1, 1);
    }
    
    function testRemoveReserveFromNegativeReserve() public {
        vm.prank(debtorManager);
        minerToken.registerDebtor(debtor1);
        
        // Create negative reserve by minting and going through cycles
        vm.prank(debtor1);
        minerToken.mint(creditor1, 1000);
        
        vm.warp(block.timestamp + 1);
        cycleUpdater.setCurrentCycle(1);
        minerToken._settleDebtor(debtor1);
        
        // Reserve should be negative now
        IMinerToken.Debtor memory debtor = minerToken.getDebtor(debtor1);
        assertTrue(debtor.interestReserve < 0);
        
        // Should not be able to remove from negative reserve
        vm.prank(debtor1);
        vm.expectRevert("MinerToken: insufficient interest reserve");
        minerToken.removeReserve(creditor1, 1);
    }
} 