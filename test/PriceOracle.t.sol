// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/PriceOracle.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../src/interface/IOracleAdapter.sol";

contract MockOracleAdapter is IOracleAdapter {
    function priceIn(
        address /* inputToken */, 
        address /* baseToken */, 
        uint256 amount
    ) external pure returns (uint256) {
        return amount * 2;
    }
}

contract PriceOracleTest is Test {
    PriceOracle public priceOracle;

    address public owner;
    address public other;
    address public baseToken;
    address public quoteToken;

    function setUp() public {
        owner = address(this);
        other = makeAddr("other");
        baseToken = makeAddr("BASE");
        quoteToken = makeAddr("QUOTE");

        priceOracle = new PriceOracle();
        priceOracle.initialize();
    }

    function test_Initialize_SetsOwner() public {
        assertEq(priceOracle.owner(), owner);
    }

    function test_Reinitialize_Reverts() public {
        vm.expectRevert();
        priceOracle.initialize();
    }

    function test_SetAdapter_OnlyOwner() public {
        MockOracleAdapter adapter = new MockOracleAdapter();

        vm.prank(other);
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
                other
            )
        );
        priceOracle.setAdapter(baseToken, quoteToken, address(adapter));
    }

    function test_SetAdapter_RevertOnZeroBase() public {
        MockOracleAdapter adapter = new MockOracleAdapter();
        vm.expectRevert(bytes("Base token address cannot be zero"));
        priceOracle.setAdapter(address(0), quoteToken, address(adapter));
    }

    function test_SetAdapter_RevertOnZeroQuote() public {
        MockOracleAdapter adapter = new MockOracleAdapter();
        vm.expectRevert(bytes("Quote token address cannot be zero"));
        priceOracle.setAdapter(baseToken, address(0), address(adapter));
    }

    function test_SetAdapter_RevertOnZeroAdapter() public {
        vm.expectRevert(bytes("Oracle adapter address cannot be zero"));
        priceOracle.setAdapter(baseToken, quoteToken, address(0));
    }

    function test_SetAdapter_StoresAndEmits() public {
        MockOracleAdapter adapter = new MockOracleAdapter();

        vm.expectEmit(true, true, true, true);
        emit PriceOracle.AdapterSet(baseToken, quoteToken, address(adapter));
        priceOracle.setAdapter(baseToken, quoteToken, address(adapter));

        assertEq(priceOracle.oracleMapping(baseToken, quoteToken), address(adapter));
    }

    function test_GetPrice_BaseEqualsQuote_ReturnsAmount() public {
        uint256 amount = 123e18;
        uint256 price = priceOracle.getPrice(baseToken, baseToken, amount);
        assertEq(price, amount);
    }

    function test_GetPrice_ZeroAmount_ReturnsZero() public {
        uint256 price = priceOracle.getPrice(baseToken, quoteToken, 0);
        assertEq(price, 0);
    }

    function test_GetPrice_NoAdapter_ReturnsZero() public {
        uint256 price = priceOracle.getPrice(baseToken, quoteToken, 100);
        assertEq(price, 0);
    }

    function test_GetPrice_UsesAdapterPrice() public {
        MockOracleAdapter adapter = new MockOracleAdapter();
        priceOracle.setAdapter(baseToken, quoteToken, address(adapter));

        uint256 amount = 50;
        uint256 price = priceOracle.getPrice(baseToken, quoteToken, amount);
        assertEq(price, amount * 2);
    }
} 