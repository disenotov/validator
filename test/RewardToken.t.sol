// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "../src/RewardToken.sol";

contract RewardTokenTest is Test {
    RewardToken public rewardToken;
    address owner = address(1);
    address user = address(2);
    address executor = address(3);

    bytes32 ADMIN_ROLE;
    bytes32 EXECUTOR_ROLE;

    function setUp() public {
        //deploy contract
        rewardToken = new RewardToken(owner, "Reward", "RWRD");

        //get roles
        ADMIN_ROLE = rewardToken.ADMIN_ROLE();
        EXECUTOR_ROLE = rewardToken.EXECUTOR_ROLE();

        //give executor role to executor
        vm.prank(owner);
        rewardToken.grantRole(EXECUTOR_ROLE, executor);
        assertEq(rewardToken.hasRole(EXECUTOR_ROLE, executor), true);
    }

    function test_constructor() public view {
        assertEq(rewardToken.hasRole(ADMIN_ROLE, owner), true);
        assertEq(rewardToken.name(), "Reward");
        assertEq(rewardToken.symbol(), "RWRD");
    }

    function test_executor() public view {
        assertEq(rewardToken.hasRole(EXECUTOR_ROLE, executor), true);
    }

    function test_mint_not_from_executor() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, 
                user,
                EXECUTOR_ROLE
            )
        );
        vm.prank(user);
        rewardToken.mint(user, 1000);
    }

    function test_mint() public {
        vm.prank(executor);
        rewardToken.mint(user, 1000);
        assertEq(rewardToken.balanceOf(user), 1000);
        assertEq(rewardToken.totalSupply(), 1000);
    }

}
