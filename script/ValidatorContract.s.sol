// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {ValidatorContract} from "../src/ValidatorContract.sol";
import {RewardToken} from "../src/RewardToken.sol";
import {License} from "../src/License.sol";

contract ValidatorContractScript is Script {
    uint epochSize = 300; // 5 = 1 min, 300 = 1 hour, 7200 = 1 day
    uint rewardStartAmount = 10000;
    uint rewardDecreaseRate = 100;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address owner = vm.envAddress("OWNER");

        License license = new License(owner, "License", "LCNS");
        RewardToken rewardToken = new RewardToken(owner, "Reward", "RWRD");

        ValidatorContract validatorContract = new ValidatorContract(
            address(license),
            address(rewardToken),
            epochSize,
            rewardStartAmount,
            rewardDecreaseRate
        );

        bytes32 EXECUTOR_ROLE = rewardToken.EXECUTOR_ROLE();
        rewardToken.grantRole(EXECUTOR_ROLE, address(validatorContract));
        
        vm.stopBroadcast();
    }
}
