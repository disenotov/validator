// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "../src/License.sol";

contract LicenseTest is Test {
    License public license;
    address owner = address(1);
    address user = address(2);

    function setUp() public {
        license = new License(owner, "License", "LCNS");
    }

    function test_constructor() public view {
        assertEq(license.owner(), owner);
        assertEq(license.name(), "License");
        assertEq(license.symbol(), "LCNS");
    }

    function test_mint_not_from_owner() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector, 
                user
            )
        );
        vm.prank(user);
        license.mint(user);
    }

    function test_mint() public {
        vm.prank(owner);
        uint tokenId = license.mint(owner);
        assertEq(license.balanceOf(owner), 1);
        assertEq(license.ownerOf(tokenId), owner);
    }

}
