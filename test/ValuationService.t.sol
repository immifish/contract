// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "../src/ValuationService.sol";
import "../src/PriceOracle.sol";
import "../src/interface/IOracleAdapter.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockOracleAdapter is IOracleAdapter {
    function priceIn(
        address /* inputToken */, 
        address /* baseToken */, 
        uint256 amount
    ) external pure returns (uint256) {
        // Simple deterministic multiplier to make chaining behavior clear
        return amount * 2;
    }
}

contract ValuationServiceTest is Test {
    ValuationService public valuation;
    PriceOracle public oracle;

    address public owner;
    address public other;

    MockERC20 public tokenA;      // collateral A
    MockERC20 public tokenLoan;   // loan asset
    MockERC20 public tokenQuote;  // quote token

    function setUp() public {
        owner = address(this);
        other = makeAddr("other");

        oracle = new PriceOracle();
        oracle.initialize();

        valuation = new ValuationService();
        valuation.initialize(address(oracle));

        tokenA = new MockERC20("TokenA", "A");
        tokenLoan = new MockERC20("Loan", "LOAN");
        tokenQuote = new MockERC20("Quote", "Q");
    }

    function test_Initialize_SetsOwnerAndOracle() public {
        assertEq(valuation.owner(), owner);
        assertEq(address(valuation.priceOracle()), address(oracle));
    }

    function test_Reinitialize_Reverts() public {
        vm.expectRevert();
        valuation.initialize(address(oracle));
    }

    function test_SetOracleRegister_OnlyOwner() public {
        PriceOracle newOracle = new PriceOracle();
        newOracle.initialize();

        vm.prank(other);
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
                other
            )
        );
        valuation.setOracleRegister(address(newOracle));

        valuation.setOracleRegister(address(newOracle));
        assertEq(address(valuation.priceOracle()), address(newOracle));
    }

    function test_SetLTV_OnlyOwner() public {
        vm.prank(other);
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
                other
            )
        );
        valuation.setLTV(address(tokenA), address(tokenLoan), 5000, true);
    }

    function test_SetLTV_InvalidAddresses_Revert() public {
        vm.expectRevert(bytes("Invalid asset address"));
        valuation.setLTV(address(0), address(tokenLoan), 5000, true);

        vm.expectRevert(bytes("Invalid asset address"));
        valuation.setLTV(address(tokenA), address(0), 5000, true);
    }

    function test_SetLTV_SameAsset_MustBeScaleFactor() public {
        // Revert when same-asset and LTV != SCALE_FACTOR
        uint256 sf = valuation.SCALE_FACTOR();
        vm.expectRevert();
        valuation.setLTV(address(tokenLoan), address(tokenLoan), sf - 1, true);

        // Succeeds when equal to SCALE_FACTOR
        valuation.setLTV(address(tokenLoan), address(tokenLoan), sf, true);
        assertEq(valuation.LTV(address(tokenLoan), address(tokenLoan)), sf);

        address[] memory wl = valuation.queryWhitelist(address(tokenLoan));
        assertEq(wl.length, 1);
        assertEq(wl[0], address(tokenLoan));
    }

    function test_SetLTV_LTVTooHigh_Revert() public {
        uint256 sf = valuation.SCALE_FACTOR();
        vm.expectRevert();
        valuation.setLTV(address(tokenA), address(tokenLoan), sf + 1, true);
    }

    function test_SetLTV_AddsAndRemovesWhitelist() public {
        // Add
        valuation.setLTV(address(tokenA), address(tokenLoan), 5000, true);
        address[] memory wl1 = valuation.queryWhitelist(address(tokenLoan));
        assertEq(wl1.length, 1);
        assertEq(wl1[0], address(tokenA));

        // Setting again should not duplicate
        valuation.setLTV(address(tokenA), address(tokenLoan), 5000, true);
        address[] memory wl2 = valuation.queryWhitelist(address(tokenLoan));
        assertEq(wl2.length, 1);

        // Remove
        valuation.setLTV(address(tokenA), address(tokenLoan), 0, false);
        address[] memory wl3 = valuation.queryWhitelist(address(tokenLoan));
        assertEq(wl3.length, 0);
    }

    function test_QuerySpotPrice_DelegatesToOracle() public {
        // Set adapter for tokenA -> quote
        MockOracleAdapter adapter = new MockOracleAdapter();
        oracle.setAdapter(address(tokenA), address(tokenQuote), address(adapter));

        uint256 amount = 123;
        uint256 price = valuation.querySpotPrice(address(tokenA), address(tokenQuote), amount);
        assertEq(price, amount * 2);
    }

    function test_QueryRelativePriceViaQuote_ChainsTwoHops() public {
        MockOracleAdapter adapter1 = new MockOracleAdapter();
        MockOracleAdapter adapter2 = new MockOracleAdapter();
        // tokenA -> quote (x2), quote -> loan (x2)
        oracle.setAdapter(address(tokenA), address(tokenQuote), address(adapter1));
        oracle.setAdapter(address(tokenQuote), address(tokenLoan), address(adapter2));

        uint256 amount = 10;
        uint256 price = valuation.queryRelativePriceViaQuote(
            address(tokenA),
            address(tokenLoan),
            address(tokenQuote),
            amount
        );
        // 10 -> 20 (A->Q) -> 40 (Q->LOAN)
        assertEq(price, 40);
    }

    function test_QueryPriceLTV_SameAsset_AppliesLTV() public {
        // Same-asset LTV must be 1x (SCALE_FACTOR)
        valuation.setLTV(address(tokenLoan), address(tokenLoan), valuation.SCALE_FACTOR(), true);

        uint256 amount = 1000;
        uint256 value = valuation.queryPriceLTV(
            address(tokenLoan),
            address(tokenLoan),
            address(tokenQuote), // unused in same-asset price path
            amount
        );
        // price == amount, LTV == 1x
        assertEq(value, amount);
    }

    function test_QueryPriceLTV_CrossAsset_AppliesPriceAndLTV() public {
        // tokenA priced via quote -> loan, with LTV = 50%
        valuation.setLTV(address(tokenA), address(tokenLoan), 5000, true);

        MockOracleAdapter adapter1 = new MockOracleAdapter();
        MockOracleAdapter adapter2 = new MockOracleAdapter();
        oracle.setAdapter(address(tokenA), address(tokenQuote), address(adapter1));
        oracle.setAdapter(address(tokenQuote), address(tokenLoan), address(adapter2));

        uint256 amount = 25;
        uint256 value = valuation.queryPriceLTV(
            address(tokenA),
            address(tokenLoan),
            address(tokenQuote),
            amount
        );
        // amount 25 -> 50 -> 100, then * 50% = 50
        assertEq(value, 50);
    }

    function test_QueryCollateralValue_SumsAcrossWhitelisted() public {
        // Configure LTVs
        valuation.setLTV(address(tokenA), address(tokenLoan), 5000, true); // 50%
        valuation.setLTV(address(tokenLoan), address(tokenLoan), valuation.SCALE_FACTOR(), true); // 100%

        // Configure oracle routes: A->Q (x2), Q->LOAN (x2)
        MockOracleAdapter adapter1 = new MockOracleAdapter();
        MockOracleAdapter adapter2 = new MockOracleAdapter();
        oracle.setAdapter(address(tokenA), address(tokenQuote), address(adapter1));
        oracle.setAdapter(address(tokenQuote), address(tokenLoan), address(adapter2));

        // Holder balances
        address holder = makeAddr("holder");
        tokenA.mint(holder, 100);
        tokenLoan.mint(holder, 50);

        uint256 sum = valuation.queryCollateralValue(
            address(tokenLoan),
            address(tokenQuote),
            holder
        );
        // tokenA: 100 -> 200 -> 400, *50% = 200
        // tokenLoan: same-asset, 50 * 100% = 50
        // total = 250
        assertEq(sum, 250);
    }
} 