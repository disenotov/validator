// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/// @title RewardToken
/// @dev This contract represents an ERC20 token with access control for minting.
/// It is designed to be used as a reward token, where only specific addresses can mint new tokens.
contract RewardToken is ERC20, AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");

    /// @notice Constructor that initializes the ERC20 token and sets up role-based access control.
    /// @param admin The address that will be granted the ADMIN_ROLE.
    /// @param name The name of the ERC20 token.
    /// @param symbol The symbol of the ERC20 token.
    constructor(address admin, string memory name, string memory symbol) ERC20(name, symbol) {
        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
        _setRoleAdmin(EXECUTOR_ROLE, ADMIN_ROLE);

        _grantRole(ADMIN_ROLE, admin);
    }

    /// @notice Allows an address with the EXECUTOR_ROLE to mint new tokens to a user.
    /// @param user The address that will receive the newly minted tokens.
    /// @param amount The number of tokens to mint.
    function mint(address user, uint256 amount) external onlyRole(EXECUTOR_ROLE) {
        _mint(user, amount);
    }
}