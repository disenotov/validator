// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "../src/ValidatorContract.sol";

contract ValidatorContractTest is Test {
    License public license;
    RewardToken public rewardToken;
    ValidatorContract public validatorContract;

    address owner = address(1);
    address user = address(2);

    bytes32 ADMIN_ROLE;
    bytes32 EXECUTOR_ROLE;

    uint blockStart = 10;

    uint epochSize = 300; // 5 = 1 min, 300 = 1 hour, 7200 = 1 day
    uint rewardStartAmount = 10000;
    uint rewardDecreaseRate = 100;

    function setUp() public {
        //deploy license contract
        license = new License(owner, "License", "LCNS");

        //deploy rewardToken contract
        rewardToken = new RewardToken(owner, "Reward", "RWRD");


        vm.roll(blockStart);
        //deploy validator contract
        validatorContract = new ValidatorContract(
            address(license),
            address(rewardToken),
            epochSize,
            rewardStartAmount,
            rewardDecreaseRate
        );

        //get roles
        ADMIN_ROLE = rewardToken.ADMIN_ROLE();
        EXECUTOR_ROLE = rewardToken.EXECUTOR_ROLE();

        //give executor role to validator contract
        vm.prank(owner);
        rewardToken.grantRole(EXECUTOR_ROLE, address(validatorContract));
        
    }

    function test_setup() public view {
        assertEq(validatorContract.licenseContract(), address(license));
        assertEq(validatorContract.rewardTokenContract(), address(rewardToken));
        assertEq(validatorContract.epochInBlocks(), epochSize);
        assertEq(validatorContract.startingPoint(), blockStart);
        assertEq(validatorContract.rewardStartAmount(), rewardStartAmount);
        assertEq(validatorContract.rewardDecreaseRate(), rewardDecreaseRate);

        assertEq(rewardToken.hasRole(EXECUTOR_ROLE, address(validatorContract)), true);
    }

    //lockLicense
    function test_lock_claim_unlock() public {
        //mint nft
        uint tokenId = mintAndApproveNFT(user);

        //lock nft
        //check event
        vm.expectEmit(address(validatorContract));
        emit ValidatorContract.LicenseLocked(user, tokenId);
        //call lock nft
        vm.prank(user);
        validatorContract.lockLicense(tokenId);

        //check that nft was transfered
        assertEq(license.ownerOf(tokenId), address(validatorContract));

        //check storage
        ValidatorContract.Lock[] memory userdata = validatorContract.getLockDataForUser(user);
        assertEq(userdata.length, 1);
        assertEq(userdata[0].unpaidEpoch, 0);
        assertEq(userdata[0].lockEpoch, 0);
        assertEq(userdata[0].tokenId, tokenId);

        //unlocking right after locking doesn't work
        vm.prank(user);
        vm.expectRevert("need to wait at least 1 epoch");
        validatorContract.unlockLicense(tokenId);

        //wait 3 epochs and lock more tokens
        vm.roll(blockStart + (epochSize * 3));

        //mint second nft
        uint tokenId1 = mintAndApproveNFT(user);
        vm.prank(user);
        validatorContract.lockLicense(tokenId1);
        assertEq(license.ownerOf(tokenId1), address(validatorContract));
        userdata = validatorContract.getLockDataForUser(user);
        assertEq(userdata.length, 2);
        assertEq(userdata[0].unpaidEpoch, 0);
        assertEq(userdata[0].lockEpoch, 0);
        assertEq(userdata[0].tokenId, tokenId);
        assertEq(userdata[1].unpaidEpoch, 3);
        assertEq(userdata[1].lockEpoch, 3);
        assertEq(userdata[1].tokenId, tokenId1);

        //claimReward
        vm.prank(user);
        //3 epochs for 1 token, starting from epoch 0
        uint expectedReward = 10000 + 9900 + 9800;
        vm.expectEmit(address(validatorContract));
        emit ValidatorContract.RewardClaimed(user, expectedReward);
        validatorContract.claimRewards();
        assertEq(rewardToken.balanceOf(user), expectedReward);
        assertEq(rewardToken.totalSupply(), expectedReward);
        
        userdata = validatorContract.getLockDataForUser(user);
        assertEq(userdata.length, 2);
        assertEq(userdata[0].unpaidEpoch, 3);
        assertEq(userdata[0].lockEpoch, 0);
        assertEq(userdata[0].tokenId, tokenId);
        assertEq(userdata[1].unpaidEpoch, 3);
        assertEq(userdata[1].lockEpoch, 3);
        assertEq(userdata[1].tokenId, tokenId1);

        vm.prank(user);
        vm.expectEmit(address(validatorContract));
        emit ValidatorContract.RewardClaimed(user, 0);
        validatorContract.claimRewards();
        assertEq(rewardToken.balanceOf(user), expectedReward);
        assertEq(rewardToken.totalSupply(), expectedReward);

        //wait 5 epochs and claim again
        vm.roll(blockStart + (epochSize * 8));
        vm.prank(user);
        uint expectedReward1 = (9700 + 9600 + 9500 + 9400 + 9300) * 2;
        vm.expectEmit(address(validatorContract));
        emit ValidatorContract.RewardClaimed(user, expectedReward1);
        validatorContract.claimRewards();

        userdata = validatorContract.getLockDataForUser(user);
        assertEq(userdata.length, 2);
        assertEq(userdata[0].unpaidEpoch, 8);
        assertEq(userdata[0].lockEpoch, 0);
        assertEq(userdata[0].tokenId, tokenId);
        assertEq(userdata[1].unpaidEpoch, 8);
        assertEq(userdata[1].lockEpoch, 3);
        assertEq(userdata[1].tokenId, tokenId1);
        assertEq(rewardToken.balanceOf(user), expectedReward + expectedReward1);
        assertEq(rewardToken.totalSupply(), expectedReward + expectedReward1);

        //unlock the first token
        vm.prank(user);
        vm.expectEmit(address(validatorContract));
        emit ValidatorContract.LicenseUnlocked(user, tokenId);
        validatorContract.unlockLicense(tokenId);
        assertEq(license.ownerOf(tokenId), user);

        userdata = validatorContract.getLockDataForUser(user);
        assertEq(userdata.length, 1);
        assertEq(userdata[0].unpaidEpoch, 8);
        assertEq(userdata[0].lockEpoch, 3);
        assertEq(userdata[0].tokenId, tokenId1);
        assertEq(rewardToken.balanceOf(user), expectedReward + expectedReward1);
        assertEq(rewardToken.totalSupply(), expectedReward + expectedReward1);

        //unlocking second time doesn't work
        vm.prank(user);
        vm.expectRevert("token not found");
        validatorContract.unlockLicense(tokenId);

        //wait 5 epochs and unlock second token
        vm.roll(blockStart + (epochSize * 9));

        vm.prank(user);
        vm.expectEmit(address(validatorContract));
        emit ValidatorContract.LicenseUnlocked(user, tokenId1);
        emit ValidatorContract.RewardClaimed(user, 9200);
        validatorContract.unlockLicense(tokenId1);
        assertEq(license.ownerOf(tokenId1), user);

        userdata = validatorContract.getLockDataForUser(user);
        assertEq(userdata.length, 0);

        assertEq(rewardToken.balanceOf(user), expectedReward + expectedReward1 + 9200);
        assertEq(rewardToken.totalSupply(), expectedReward + expectedReward1 + 9200);

    }

    function test_lockLicense_id_too_big() public {
        //mint nft
        mintAndApproveNFT(user);

        //lock nft
        vm.prank(user);
        uint256 tokenIdTooBig = uint256(type(uint192).max) + 100;
        vm.expectRevert("tokenIds > uint192 are not supported");
        validatorContract.lockLicense(tokenIdTooBig);
    }

    function test_get_reward_for_epoch() public view {
        assertEq(validatorContract.getRewardForSpecificEpoch(0), rewardStartAmount);
        assertEq(validatorContract.getRewardForSpecificEpoch(1), rewardStartAmount - rewardDecreaseRate);
        assertEq(validatorContract.getRewardForSpecificEpoch(2), rewardStartAmount - (rewardDecreaseRate * 2));
        assertEq(validatorContract.getRewardForSpecificEpoch(90), rewardStartAmount - (rewardDecreaseRate * 90));
        assertEq(validatorContract.getRewardForSpecificEpoch(101), 0);
    }

    function test_get_reward_amount() public {
        vm.expectRevert("epochStart needs to be less than epochEnd");
        validatorContract.getRewardAmount(1, 0);

        assertEq(validatorContract.getRewardAmount(0, 0), 0);
        assertEq(validatorContract.getRewardAmount(0, 1), rewardStartAmount);
        assertEq(validatorContract.getRewardAmount(0, 1000), 505000);
        assertEq(validatorContract.getRewardAmount(0, 100), 505000);
        assertEq(validatorContract.getRewardAmount(1, 1000), 495000);
        assertEq(validatorContract.getRewardAmount(100, 101), 0);
        assertEq(validatorContract.getRewardAmount(5, 25), 171000);
    }

    function test_epoch() public view {
        //less than starting block => epoch 0
        assertEq(validatorContract.getEpochAtBlock(0), 0);

        //starting block => epoch 0
        assertEq(validatorContract.getEpochAtBlock(blockStart), 0);

        //x < epoch border
        assertEq(validatorContract.getEpochAtBlock(blockStart + epochSize - 1), 0);

        //x >= epoch border
        assertEq(validatorContract.getEpochAtBlock(blockStart + epochSize), 1);

        //x >= epoch border * 2
        assertEq(validatorContract.getEpochAtBlock(blockStart + (epochSize * 2)), 2);

        //x > epoch border * 10
        assertEq(validatorContract.getEpochAtBlock(blockStart + (epochSize * 10)), 10);
    }

    function test_epoch_fuzz(uint blockNumber) public view {
        vm.assume(blockNumber > blockStart);
        getEpoch(blockNumber);
    }

    function getEpoch(uint blockNumber) public view {
        uint result = (blockNumber - blockStart) / epochSize;
        assertEq(validatorContract.getEpochAtBlock(blockNumber), result);
    }

    function mintAndApproveNFT(address to) public returns(uint tokenId){
        //mint
        vm.prank(owner);
        tokenId = license.mint(user);
        assertEq(license.ownerOf(tokenId), user);

        //approve
        vm.prank(to);
        license.setApprovalForAll(address(validatorContract), true);
        assertEq(license.isApprovedForAll(to, address(validatorContract)), true);
    }

}
