// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract RewardToken is ERC20, AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");

    //giving ADMIN_ROLE to admin
    //creating executor_role, not giving it to anyone
    constructor(address admin, string memory name, string memory symbol) ERC20(name, symbol) {
        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
        _setRoleAdmin(EXECUTOR_ROLE, ADMIN_ROLE);

        _grantRole(ADMIN_ROLE, admin);
    }

    function mint(address user, uint256 amount) external onlyRole(EXECUTOR_ROLE) {
        _mint(user, amount);
    }
}