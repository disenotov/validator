// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {License} from "./License.sol";
import {RewardToken} from "./RewardToken.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

/// @title Validator Contract
/// @dev This contract allows users to lock ERC721 licenses and earn rewards in ERC20 tokens over time.
/// Users can lock licenses, unlock them after a full epoch, and claim rewards based on the time licenses were locked.
contract ValidatorContract is ERC721Holder {
    // Address of the License (ERC721) contract
    address public immutable licenseContract;

    // Address of the RewardToken (ERC20) contract
    address public immutable rewardTokenContract;

    // Number of blocks that define an epoch
    uint256 public immutable epochInBlocks;

    // Block number when the contract starts counting epochs
    uint256 public immutable startingPoint;

    // Initial reward amount per epoch for locked licenses
    uint256 public immutable rewardStartAmount;

    // Rate at which rewards decrease over epochs
    uint256 public immutable rewardDecreaseRate;

    // Struct to store information about each locked license
    struct Lock {
        uint32 unpaidEpoch; // The last unpaid epoch for reward calculation
        uint32 lockEpoch; // The epoch when the license was locked
        uint192 tokenId; // The ID of the locked token
    }

    // Mapping of user addresses to their list of locked licenses
    mapping(address => Lock[]) public lockedTokens;

    // Events to log key contract actions
    event LicenseLocked(address user, uint tokenId);
    event LicenseUnlocked(address user, uint tokenId);
    event RewardClaimed(address user, uint rewardAmount);

    /// @notice Constructor initializes the contract with relevant parameters.
    /// @param _licenseContract Address of the License (ERC721) contract.
    /// @param _rewardTokenContract Address of the RewardToken (ERC20) contract.
    /// @param _epochInBlocks Number of blocks in one epoch.
    /// @param _rewardStartAmount Initial reward amount per epoch.
    /// @param _rewardDecreaseRate Rate at which rewards decrease per epoch.
    constructor(
        address _licenseContract,
        address _rewardTokenContract,
        uint256 _epochInBlocks,
        uint256 _rewardStartAmount,
        uint256 _rewardDecreaseRate
    ) {
        licenseContract = _licenseContract;
        rewardTokenContract = _rewardTokenContract;
        epochInBlocks = _epochInBlocks;
        startingPoint = block.number;
        rewardStartAmount = _rewardStartAmount;
        rewardDecreaseRate = _rewardDecreaseRate;
    }

    /// @notice Locks an ERC721 license in the contract, registering the user for rewards.
    /// @param tokenId The ID of the license (ERC721) token to be locked.
    function lockLicense(uint256 tokenId) external {
        require(
            tokenId < type(uint192).max,
            "tokenIds > uint192 are not supported"
        );

        address user = msg.sender;

        // Transfer the license from the user to the contract
        License(licenseContract).safeTransferFrom(user, address(this), tokenId);

        // Register the lock with the current epoch
        uint32 currentEpoch = uint32(getEpochAtBlock(block.number));
        lockedTokens[user].push(
            Lock({
                unpaidEpoch: currentEpoch,
                lockEpoch: currentEpoch,
                tokenId: uint192(tokenId)
            })
        );

        emit LicenseLocked(user, tokenId);
    }

    /// @notice Unlocks a locked license and returns it to the user.
    /// Only allowed after a full epoch has passed since locking.
    /// If there are unpaid rewards, they are claimed before unlocking.
    /// @param tokenId The ID of the license (ERC721) token to be unlocked.
    function unlockLicense(uint256 tokenId) external {
        address user = msg.sender;
        uint len = lockedTokens[user].length;
        uint index = getIndexFromTokenId(tokenId, user, len);

        uint currentEpoch = getEpochAtBlock(block.number);
        require(
            currentEpoch > lockedTokens[user][index].lockEpoch,
            "need to wait at least 1 epoch"
        );

        // Claim unpaid rewards if any
        if (lockedTokens[user][index].unpaidEpoch < currentEpoch) {
            uint rewardAmount = claimRewardForToken(user, index, currentEpoch);
            RewardToken(rewardTokenContract).mint(user, rewardAmount);
            emit RewardClaimed(user, rewardAmount);
        }

        // Transfer the license back to the user
        License(licenseContract).safeTransferFrom(address(this), user, tokenId);

        // Remove the license from the user's locked tokens
        deleteLicense(index, user, len);

        emit LicenseUnlocked(user, tokenId);
    }

    /// @notice Retrieves the index of a locked license by its token ID.
    /// @param tokenId The ID of the license to find.
    /// @param user The address of the user who locked the license.
    /// @param len The number of locked licenses for the user.
    /// @return The index of the license in the user's locked list.
    function getIndexFromTokenId(
        uint tokenId,
        address user,
        uint len
    ) internal view returns (uint) {
        for (uint i = 0; i < len; i++) {
            if (lockedTokens[user][i].tokenId == tokenId) {
                return i;
            }
        }
        revert("token not found");
    }

    /// @notice Deletes a license from the user's locked tokens by index.
    /// @param index The index of the license to delete.
    /// @param user The address of the user whose license is being deleted.
    /// @param len The number of locked licenses for the user.
    function deleteLicense(uint index, address user, uint len) internal {
        uint lastIndex = len - 1;
        if (index != lastIndex) {
            lockedTokens[user][index] = lockedTokens[user][lastIndex];
        }
        lockedTokens[user].pop();
    }

    /// @notice Claims all unpaid rewards for a user.
    function claimRewards() external {
        address user = msg.sender;
        uint currentEpoch = getEpochAtBlock(block.number);
        uint len = lockedTokens[user].length;

        uint rewardAmount = 0;
        for (uint i = 0; i < len; i++) {
            rewardAmount += claimRewardForToken(user, i, currentEpoch);
        }

        // Mint reward tokens to the user
        RewardToken(rewardTokenContract).mint(user, rewardAmount);
        emit RewardClaimed(user, rewardAmount);
    }

    /// @notice Claims the reward for a specific locked token.
    /// @param user The address of the user.
    /// @param index The index of the locked token in the user's list.
    /// @param currentEpoch The current epoch number.
    /// @return The reward amount for the token.
    function claimRewardForToken(
        address user,
        uint index,
        uint currentEpoch
    ) internal returns (uint) {
        uint unpaidEpoch = lockedTokens[user][index].unpaidEpoch;
        uint rewardAmount = getRewardAmount(unpaidEpoch, currentEpoch);

        // Update unpaid epoch to current
        lockedTokens[user][index].unpaidEpoch = uint32(currentEpoch);

        return rewardAmount;
    }

    /// @notice Calculates the reward amount between two epochs.
    /// @param epochStart The starting epoch.
    /// @param epochEnd The ending epoch.
    /// @return The total reward amount for the period.
    function getRewardAmount(
        uint epochStart,
        uint epochEnd
    ) public view returns (uint) {
        require(
            epochStart <= epochEnd,
            "epochStart needs to be less than epochEnd"
        );

        uint result = 0;
        for (uint i = epochStart; i < epochEnd; i++) {
            result += getRewardForSpecificEpoch(i);
        }

        return result;
    }

    /// @notice Calculates the reward amount for a specific epoch.
    /// @param epoch The epoch number.
    /// @return The reward amount for that epoch.
    function getRewardForSpecificEpoch(uint epoch) public view returns (uint) {
        if (epoch * rewardDecreaseRate > rewardStartAmount) {
            return 0;
        }
        return rewardStartAmount - (epoch * rewardDecreaseRate);
    }

    /// @notice Returns the epoch number for a given block number.
    /// @param blockNumber The block number to calculate the epoch for.
    /// @return The epoch number.
    function getEpochAtBlock(uint blockNumber) public view returns (uint256) {
        if (blockNumber < startingPoint) {
            return 0;
        }
        return (blockNumber - startingPoint) / epochInBlocks;
    }

    /// @notice Retrieves all locked tokens for a specific user.
    /// @param user The address of the user.
    /// @return An array of locked tokens for the user.
    function getLockDataForUser(
        address user
    ) public view returns (Lock[] memory) {
        return lockedTokens[user];
    }
}
