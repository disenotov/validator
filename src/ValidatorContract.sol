// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {License} from "./License.sol";
import {RewardToken} from "./RewardToken.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

/// @title Validator Contract
/// @dev This contract allows users to lock ERC721 licenses and earn rewards in ERC20 tokens over time.
/// Users can lock licenses, unlock them after a full epoch, and claim rewards based on the time licenses were locked.
contract ValidatorContract is ERC721Holder {
    address public immutable licenseContract;
    address public immutable rewardTokenContract;
    uint256 public immutable epochInBlocks;
    uint256 public immutable startingPoint;
    uint256 public immutable rewardStartAmount;
    uint256 public immutable rewardDecreaseRate;

    struct Lock {
        uint32 unpaidEpoch;
        uint32 lockEpoch;
        uint192 tokenId;
    }
    mapping(address => Lock[]) public lockedTokens;

    event LicenseLocked(address user, uint tokenId);
    event LicenseUnlocked(address user, uint tokenId);
    event RewardClaimed(address user, uint rewardAmount);

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

    /*
        Locks a license (ERC721 token) in the contract and 
        registers the validator for rewards.
        Emits an event.
        */
    function lockLicense(uint256 tokenId) external {
        require(
            tokenId < type(uint192).max,
            "tokenIds > uint192 are not supported"
        );

        address user = msg.sender;

        //transfer token
        License(licenseContract).safeTransferFrom(user, address(this), tokenId);

        uint32 currentEpoch = uint32(getEpochAtBlock(block.number));

        //set data
        lockedTokens[user].push(
            Lock({
                unpaidEpoch: currentEpoch,
                lockEpoch: currentEpoch,
                tokenId: uint192(tokenId)
            })
        );

        emit LicenseLocked(user, tokenId);
    }

    /*
        Allows unlocking the license only if one full epoch 
        has passed since it was locked.
        Returns the license to the owner.
    */
    function unlockLicense(uint256 tokenId) external {
        address user = msg.sender;
        uint len = lockedTokens[user].length;
        uint index = getIndexFromTokenId(tokenId, user, len);

        uint currentEpoch = getEpochAtBlock(block.number);
        require(currentEpoch > lockedTokens[user][index].lockEpoch, "need to wait at least 1 epoch");

        //send reward for the NFT if it's present
        if (lockedTokens[user][index].unpaidEpoch < currentEpoch) {
            uint rewardAmount = claimRewardForToken(user, index, currentEpoch);
            RewardToken(rewardTokenContract).mint(user, rewardAmount);
            emit RewardClaimed(user, rewardAmount);
        }

        //transfer NFT back
        License(licenseContract).safeTransferFrom(address(this), user, tokenId);

        //delete element from array
        deleteLicense(index, user, len);
        
        emit LicenseUnlocked(user, tokenId);
    }

    function getIndexFromTokenId(uint tokenId, address user, uint len) internal view returns(uint) {
        
        for (uint i = 0; i < len; i++) {
            if (lockedTokens[user][i].tokenId == tokenId) {
                return i;
            }
        }
        revert("token not found");
    }

    function deleteLicense(uint index, address user, uint len) internal {
        uint lastIndex = len - 1;
        if (index != lastIndex) {
            lockedTokens[user][index].unpaidEpoch = lockedTokens[user][lastIndex].unpaidEpoch;
            lockedTokens[user][index].lockEpoch = lockedTokens[user][lastIndex].lockEpoch;
            lockedTokens[user][index].tokenId = lockedTokens[user][lastIndex].tokenId;
        }
        lockedTokens[user].pop();
    }

    /*
        Transfers accumulated ERC20 rewards to the validator. 
        Rewards are proportional to the
        number of locked licenses and epochs elapsed.
    */
    function claimRewards() external {
        address user = msg.sender;
        uint currentEpoch = getEpochAtBlock(block.number);
        uint len = lockedTokens[user].length;

        uint rewardAmount = 0;
        for (uint i = 0; i < len; i++) {
            rewardAmount = rewardAmount + claimRewardForToken(user, i, currentEpoch);
        }

        //mint reward tokens
        RewardToken(rewardTokenContract).mint(user, rewardAmount);
        emit RewardClaimed(user, rewardAmount);
    }

    function claimRewardForToken(
        address user,
        uint index,
        uint currentEpoch
    ) internal returns(uint){
        uint unpaidEpoch = lockedTokens[user][index].unpaidEpoch;

        //get reward amount
        uint rewardAmount = getRewardAmount(unpaidEpoch, currentEpoch);

        //set unpaid epoch to current
        lockedTokens[user][index].unpaidEpoch = uint32(currentEpoch);

        return rewardAmount;
    }

    function getRewardAmount(
        uint epochStart,
        uint epochEnd
    ) public view returns (uint) {
        require(
            epochStart <= epochEnd,
            "epochStart needs to be less than epochEnd"
        );
        /*
        uint rewardStart = getRewardForSpecificEpoch(epochStart);
        if (epochStart == epochEnd) {
            return 0;
        }
        if (epochStart == epochEnd + 1) {
            return rewardStart;
        }

        uint rewardEnd = getRewardForSpecificEpoch(epochEnd - 1);
        uint result = ((epochEnd - epochStart) * (rewardStart + rewardEnd)) / 2;
        */
        uint result = 0;
        for (uint i = epochStart; i < epochEnd; i++) {
            result = result + getRewardForSpecificEpoch(i);
        }

        return result;
    }

    function getRewardForSpecificEpoch(uint epoch) public view returns (uint) {
        if (epoch * rewardDecreaseRate > rewardStartAmount) {
            return 0;
        }
        return rewardStartAmount - (epoch * rewardDecreaseRate);
    }

    function getEpochAtBlock(uint blockNumber) public view returns (uint256) {
        if (blockNumber < startingPoint) {
            return 0;
        }
        return (blockNumber - startingPoint) / epochInBlocks;
    }

    function getLockDataForUser(
        address user
    ) public view returns (Lock[] memory) {
        return lockedTokens[user];
    }

}
