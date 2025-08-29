// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/MinerToken.sol";
import "../src/CycleUpdater.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// Mock ERC20 token for testing interest
contract MockInterestToken is ERC20 {
    constructor() ERC20("Mock Interest Token", "MIT") {
        _mint(msg.sender, 1000000 * 10**18); // Mint 1M tokens
    }
}

contract MinerTokenTest is Test {
    MinerToken public minerToken;
    CycleUpdater public cycleUpdater;
    ERC1967Proxy public cycleUpdaterProxy;
    MockInterestToken public interestToken;
    
    address public owner;
    address public debtor1;
    address public debtor2;
    address public creditor1;
    address public creditor2;
    address public beneficiary;
    
    uint256 public constant INITIAL_BALANCE = 1000 * 10**18;
    uint256 public constant MINT_AMOUNT = 100 * 10**18;
    uint256 public constant RESERVE_AMOUNT = 50 * 10**18;
    uint256 public constant CLAIM_AMOUNT = 25 * 10**18;
    
    event RegisterDebtor(address debtor);
    event Mint(address byDebtor, address to, uint256 amount);
    event Burn(address from, address forDebtor, uint256 amount);
    event Claim(address holder, address to, uint256 amount);
    event RemoveReserve(address debtor, uint256 amount);
    event AddReserve(address debtor, uint256 amount);
    event DesignatedBeneficiaryUpdated(address indexed settlor, address indexed beneficiary, address indexed operator);
    
    function setUp() public {
        owner = address(this);
        debtor1 = makeAddr("debtor1");
        debtor2 = makeAddr("debtor2");
        creditor1 = makeAddr("creditor1");
        creditor2 = makeAddr("creditor2");
        beneficiary = makeAddr("beneficiary");
        
        // Deploy contracts
        interestToken = new MockInterestToken();
        
        // Deploy CycleUpdater through proxy pattern
        CycleUpdater implementation = new CycleUpdater();
        cycleUpdaterProxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(CycleUpdater.initialize.selector)
        );
        cycleUpdater = CycleUpdater(address(cycleUpdaterProxy));
        
        minerToken = new MinerToken();
        
        // Initialize contracts
        minerToken.initialize("Miner Token", "MINER", 18, address(interestToken), address(cycleUpdater));
        
        // Set debtor manager to this contract for testing
        minerToken.setDebtorManager(address(this));
        
        // Transfer some interest tokens to the test contract
        interestToken.transfer(address(this), 100000 * 10**18);
        
        // Start initial cycle
        cycleUpdater.startNewCycle(0, 0);
        
        // Note: Individual tests will register debtors and mint tokens as needed
        // This ensures tests are independent and don't interfere with each other
    }
    
    function test_Initialization() public {
        assertEq(minerToken.name(), "Miner Token");
        assertEq(minerToken.symbol(), "MINER");
        assertEq(minerToken.decimals(), 18);
        assertEq(minerToken.interestToken(), address(interestToken));
        assertEq(minerToken.cycleUpdater(), address(cycleUpdater));
        assertEq(minerToken.owner(), owner);
    }
    
    function test_RegisterDebtor() public {
        vm.startPrank(owner);
        minerToken.registerDebtor(debtor1);
        vm.stopPrank();
        
        assertTrue(minerToken.isDebtor(debtor1));
        IMinerToken.Debtor memory debtor = minerToken.getDebtor(debtor1);
        assertEq(debtor.timeStamp.lastModifiedTime, block.timestamp);
        assertEq(debtor.timeStamp.lastModifiedCycle, 0);
        assertEq(debtor.outStandingBalance, 0);
        assertEq(debtor.debtFactor, 0);
        assertEq(debtor.interestReserve, 0);
    }
    
    function test_RegisterDebtor_OnlyDebtorManager() public {
        vm.startPrank(creditor1);
        vm.expectRevert("MinerToken: caller must be debtor manager");
        minerToken.registerDebtor(debtor1);
        vm.stopPrank();
    }
    
    function test_RegisterDebtor_AlreadyExists() public {
        vm.startPrank(owner);
        minerToken.registerDebtor(debtor1);
        
        vm.expectRevert("MinerToken: debtor already exists");
        minerToken.registerDebtor(debtor1);
        vm.stopPrank();
    }
    
    function test_Mint_ByDebtor() public {
        vm.startPrank(owner);
        minerToken.registerDebtor(debtor1);
        vm.stopPrank();
        
        vm.startPrank(debtor1);
        minerToken.mint(creditor1, MINT_AMOUNT);
        vm.stopPrank();
        
        assertEq(minerToken.balanceOf(creditor1), MINT_AMOUNT);
        IMinerToken.Debtor memory debtor = minerToken.getDebtor(debtor1);
        assertEq(debtor.outStandingBalance, MINT_AMOUNT);
    }
    
    function test_Mint_OnlyByDebtor() public {
        vm.startPrank(owner);
        minerToken.registerDebtor(debtor1);
        vm.stopPrank();
        
        vm.startPrank(creditor1);
        vm.expectRevert("MinerToken: cannot mint by a non-debtor");
        minerToken.mint(creditor2, MINT_AMOUNT);
        vm.stopPrank();
    }
    
    function test_Mint_ToDebtor() public {
        vm.startPrank(owner);
        minerToken.registerDebtor(debtor1);
        minerToken.registerDebtor(debtor2);
        vm.stopPrank();
        
        vm.startPrank(debtor1);
        vm.expectRevert("MinerToken: cannot mint to debtor");
        minerToken.mint(debtor2, MINT_AMOUNT);
        vm.stopPrank();
    }
    
    function test_Mint_ToZeroAddress() public {
        vm.startPrank(owner);
        minerToken.registerDebtor(debtor1);
        vm.stopPrank();
        
        vm.startPrank(debtor1);
        vm.expectRevert("MinerToken: cannot mint to zero address");
        minerToken.mint(address(0), MINT_AMOUNT);
        vm.stopPrank();
    }
    
    function test_Burn_FromCreditorToDebtor() public {
        vm.startPrank(owner);
        minerToken.registerDebtor(debtor1);
        vm.stopPrank();
        
        vm.startPrank(debtor1);
        minerToken.mint(creditor1, MINT_AMOUNT);
        vm.stopPrank();
        
        uint256 initialBalance = minerToken.balanceOf(creditor1);
        uint256 initialOutstanding = minerToken.getDebtor(debtor1).outStandingBalance;
        
        vm.startPrank(creditor1);
        minerToken.transfer(debtor1, MINT_AMOUNT);
        vm.stopPrank();
        
        assertEq(minerToken.balanceOf(creditor1), initialBalance - MINT_AMOUNT);
        IMinerToken.Debtor memory debtor = minerToken.getDebtor(debtor1);
        assertEq(debtor.outStandingBalance, initialOutstanding - MINT_AMOUNT);
    }
    
    function test_Burn_InsufficientOutstandingBalance() public {
        vm.startPrank(owner);
        minerToken.registerDebtor(debtor1);
        vm.stopPrank();
        
        vm.startPrank(debtor1);
        minerToken.mint(creditor1, MINT_AMOUNT);
        vm.stopPrank();
        
        vm.startPrank(creditor1);
        vm.expectRevert("MinerToken: insufficient outStandingBalance");
        minerToken.transfer(debtor1, MINT_AMOUNT + 1);
        vm.stopPrank();
    }
    
    function test_AddReserve() public {
        vm.startPrank(owner);
        minerToken.registerDebtor(debtor1);
        vm.stopPrank();
        
        int256 initialReserve = minerToken.getDebtor(debtor1).interestReserve;
        
        vm.startPrank(owner);
        interestToken.approve(address(minerToken), RESERVE_AMOUNT);
        minerToken.addReserve(debtor1, RESERVE_AMOUNT);
        vm.stopPrank();
        
        IMinerToken.Debtor memory debtor = minerToken.getDebtor(debtor1);
        assertEq(debtor.interestReserve, initialReserve + int256(RESERVE_AMOUNT));
    }
    
    function test_AddReserve_ToNonDebtor() public {
        vm.startPrank(owner);
        vm.expectRevert("MinerToken: cannot add reserve to non-debtor");
        minerToken.addReserve(creditor1, RESERVE_AMOUNT);
        vm.stopPrank();
    }
    
    function test_RemoveReserve() public {
        vm.startPrank(owner);
        minerToken.registerDebtor(debtor1);
        vm.stopPrank();
        
        // Add reserve first
        vm.startPrank(owner);
        interestToken.approve(address(minerToken), RESERVE_AMOUNT);
        minerToken.addReserve(debtor1, RESERVE_AMOUNT);
        vm.stopPrank();
        
        int256 initialReserve = minerToken.getDebtor(debtor1).interestReserve;
        uint256 initialBalance = interestToken.balanceOf(owner);
        
        vm.startPrank(debtor1);
        minerToken.removeReserve(owner, RESERVE_AMOUNT);
        vm.stopPrank();
        
        IMinerToken.Debtor memory debtor = minerToken.getDebtor(debtor1);
        assertEq(debtor.interestReserve, initialReserve - int256(RESERVE_AMOUNT));
        assertEq(interestToken.balanceOf(owner), initialBalance + RESERVE_AMOUNT);
    }
    
    function test_RemoveReserve_ByNonDebtor() public {
        vm.startPrank(owner);
        minerToken.registerDebtor(debtor1);
        vm.stopPrank();
        
        vm.startPrank(creditor1);
        vm.expectRevert("MinerToken: cannot remove reserve from non-debtor");
        minerToken.removeReserve(creditor1, RESERVE_AMOUNT);
        vm.stopPrank();
    }
    
    function test_RemoveReserve_InsufficientReserve() public {
        vm.startPrank(owner);
        minerToken.registerDebtor(debtor1);
        vm.stopPrank();
        
        vm.startPrank(debtor1);
        vm.expectRevert("MinerToken: insufficient interest reserve");
        minerToken.removeReserve(owner, RESERVE_AMOUNT);
        vm.stopPrank();
    }
    
    function test_SetDesignatedBeneficiary_BySettlor() public {
        vm.startPrank(creditor1);
        minerToken.setDesignatedBeneficiary(creditor1, beneficiary);
        vm.stopPrank();
        
        assertEq(minerToken.getDesignatedBeneficiary(creditor1), beneficiary);
    }
    
    function test_SetDesignatedBeneficiary_ByOwner() public {
        vm.startPrank(owner);
        minerToken.setDesignatedBeneficiary(creditor1, beneficiary);
        vm.stopPrank();
        
        assertEq(minerToken.getDesignatedBeneficiary(creditor1), beneficiary);
    }
    
    function test_SetDesignatedBeneficiary_ByUnauthorized() public {
        vm.startPrank(creditor2);
        vm.expectRevert("MinerToken: caller must be creditor or owner");
        minerToken.setDesignatedBeneficiary(creditor1, beneficiary);
        vm.stopPrank();
    }
    
    function test_SetDesignatedBeneficiary_ZeroSettlor() public {
        vm.startPrank(owner);
        vm.expectRevert("MinerToken: creditor cannot be zero address");
        minerToken.setDesignatedBeneficiary(address(0), beneficiary);
        vm.stopPrank();
    }
    
    function test_SetDesignatedBeneficiary_ZeroBeneficiary() public {
        vm.startPrank(owner);
        vm.expectRevert("MinerToken: beneficiary cannot be zero address");
        minerToken.setDesignatedBeneficiary(creditor1, address(0));
        vm.stopPrank();
    }
    
    function test_Claim_ByCreditor() public {
        // Setup: Register debtor and mint tokens first
        vm.startPrank(owner);
        minerToken.registerDebtor(debtor1);
        vm.stopPrank();
        
        vm.startPrank(debtor1);
        minerToken.mint(creditor1, INITIAL_BALANCE);
        vm.stopPrank();
        
        // Advance time and finalize a cycle with per-token interest
        // Note: interest should be elevated by SCALING_FACTOR (10^12), not by ether (10^18)
        uint256 interestPerTokenPerDay = 0.05 * 10**12; // interest for holding 1 token over the cycle
        vm.warp(block.timestamp + 1 days);
        cycleUpdater.startNewCycle(0, interestPerTokenPerDay);
        
        // Preview exact claimable interest, fund contract accordingly, then claim
        uint256 claimable = minerToken.settleCreditorPreview(creditor1);
        vm.startPrank(owner);
        interestToken.transfer(address(minerToken), claimable);
        vm.stopPrank();
        
        uint256 initialBalance = interestToken.balanceOf(creditor1);
        vm.startPrank(creditor1);
        minerToken.claim(creditor1, creditor1, claimable);
        vm.stopPrank();
        assertEq(interestToken.balanceOf(creditor1), initialBalance + claimable);
    }
    
    function test_Claim_ByBeneficiary() public {
        // Setup: Register debtor and mint tokens first
        vm.startPrank(owner);
        minerToken.registerDebtor(debtor1);
        vm.stopPrank();
        
        vm.startPrank(debtor1);
        minerToken.mint(creditor1, INITIAL_BALANCE);
        vm.stopPrank();
        
        vm.startPrank(creditor1);
        minerToken.setDesignatedBeneficiary(creditor1, beneficiary);
        vm.stopPrank();
        
        // Advance time and finalize a cycle with per-token interest
        // Note: interest should be elevated by SCALING_FACTOR (10^12), not by ether (10^18)
        uint256 interestPerTokenPerDay = 0.05 * 10**12; // interest for holding 1 token over the cycle
        vm.warp(block.timestamp + 1 days);
        cycleUpdater.startNewCycle(0, interestPerTokenPerDay);
        
        // Preview exact claimable interest, fund contract accordingly, then claim to beneficiary
        uint256 claimable = minerToken.settleCreditorPreview(creditor1);
        vm.startPrank(owner);
        interestToken.transfer(address(minerToken), claimable);
        vm.stopPrank();
        
        uint256 initialBalance = interestToken.balanceOf(beneficiary);
        vm.startPrank(beneficiary);
        minerToken.claim(creditor1, beneficiary, claimable);
        vm.stopPrank();
        assertEq(interestToken.balanceOf(beneficiary), initialBalance + claimable);
    }
    
    function test_Claim_ByUnauthorized() public {
        vm.startPrank(creditor2);
        vm.expectRevert("MinerToken: caller must be creditor or designated beneficiary");
        minerToken.claim(creditor1, creditor2, CLAIM_AMOUNT);
        vm.stopPrank();
    }
    
    function test_Claim_CreditorIsDebtor() public {
        vm.startPrank(owner);
        minerToken.registerDebtor(creditor1);
        vm.stopPrank();
        
        vm.startPrank(creditor1);
        vm.expectRevert("MinerToken: creditor must not be debtor");
        minerToken.claim(creditor1, creditor1, CLAIM_AMOUNT);
        vm.stopPrank();
    }
    
    function test_Claim_InsufficientInterest() public {
        vm.startPrank(creditor1);
        vm.expectRevert(abi.encodeWithSelector(
            IMinerToken.MinerTokenInsufficientInterest.selector,
            creditor1,
            0,
            CLAIM_AMOUNT
        ));
        minerToken.claim(creditor1, creditor1, CLAIM_AMOUNT);
        vm.stopPrank();
    }
    
    function test_Claim_ExceedsSettledAmount() public {
        // Setup: Register debtor and mint tokens first
        vm.startPrank(owner);
        minerToken.registerDebtor(debtor1);
        vm.stopPrank();
        
        vm.startPrank(debtor1);
        minerToken.mint(creditor1, INITIAL_BALANCE);
        vm.stopPrank();
        
        // Advance time and finalize a cycle with per-token interest
        // Note: interest should be elevated by SCALING_FACTOR (10^12), not by ether (10^18)
        uint256 interestPerTokenPerDay = 0.05 * 10**12; // interest for holding 1 token over the cycle
        vm.warp(block.timestamp + 1 days);
        cycleUpdater.startNewCycle(0, interestPerTokenPerDay);
        
        // Compute exact claimable interest for creditor1
        uint256 claimable = minerToken.settleCreditorPreview(creditor1);
        
        // Fund the contract with more than claimable to ensure revert reason is insufficient interest, not token balance
        vm.startPrank(owner);
        interestToken.transfer(address(minerToken), claimable + 1);
        vm.stopPrank();
        
        // Expect revert when trying to claim more than settled amount
        vm.startPrank(creditor1);
        vm.expectRevert(abi.encodeWithSelector(
            IMinerToken.MinerTokenInsufficientInterest.selector,
            creditor1,
            claimable,
            claimable + 1
        ));
        minerToken.claim(creditor1, creditor1, claimable + 1);
        vm.stopPrank();
    }
    
    function test_Transfer_BetweenCreditors() public {
        // First register debtors and mint tokens
        vm.startPrank(owner);
        minerToken.registerDebtor(debtor1);
        minerToken.registerDebtor(debtor2);
        vm.stopPrank();
        
        vm.startPrank(debtor1);
        minerToken.mint(creditor1, INITIAL_BALANCE);
        vm.stopPrank();
        
        vm.startPrank(debtor2);
        minerToken.mint(creditor2, INITIAL_BALANCE);
        vm.stopPrank();
        
        uint256 initialBalance1 = minerToken.balanceOf(creditor1);
        uint256 initialBalance2 = minerToken.balanceOf(creditor2);
        
        vm.startPrank(creditor1);
        minerToken.transfer(creditor2, MINT_AMOUNT);
        vm.stopPrank();
        
        assertEq(minerToken.balanceOf(creditor1), initialBalance1 - MINT_AMOUNT);
        assertEq(minerToken.balanceOf(creditor2), initialBalance2 + MINT_AMOUNT);
    }
    
    function test_SetCycleUpdater() public {
        address newCycleUpdater = makeAddr("newCycleUpdater");
        
        vm.startPrank(owner);
        minerToken.setCycleUpdater(newCycleUpdater);
        vm.stopPrank();
        
        assertEq(minerToken.cycleUpdater(), newCycleUpdater);
    }
    
    function test_SetDebtorManager() public {
        address newDebtorManager = makeAddr("newDebtorManager");
        
        vm.startPrank(owner);
        minerToken.setDebtorManager(newDebtorManager);
        vm.stopPrank();
        
        // Test that new debtor manager can register debtors
        vm.startPrank(newDebtorManager);
        minerToken.registerDebtor(debtor1);
        vm.stopPrank();
        
        assertTrue(minerToken.isDebtor(debtor1));
    }
}
