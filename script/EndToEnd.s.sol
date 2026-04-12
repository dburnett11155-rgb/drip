// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Drip} from "../src/Drip.sol";
import {MockToken} from "../src/MockToken.sol";

contract EndToEnd is Script {
    function run() external {
        address dripAddress = vm.envAddress("CONTRACT_ADDRESS");
        address tokenAddress = vm.envAddress("MOCK_TOKEN_ADDRESS");

        Drip drip = Drip(dripAddress);
        MockToken token = MockToken(tokenAddress);

        vm.startBroadcast();

        // approve drip to spend tokens
        token.approve(dripAddress, type(uint256).max);

        uint256 balanceBefore = token.balanceOf(msg.sender);
        console.log("Balance before:", balanceBefore);

        // create a 10 mUSDC/minute plan for fast testing
        uint256 planId = drip.createPlan(
            tokenAddress,
            10_000000,  // 10 mUSDC
            60          // 60 second interval for fast testing
        );
        console.log("Plan created:", planId);

        // subscribe — first payment charged immediately
        uint256 subId = drip.subscribe(planId);
        console.log("Subscribed:", subId);

        uint256 balanceAfter = token.balanceOf(msg.sender);
        console.log("Balance after:", balanceAfter);
        console.log("First payment charged:", balanceBefore - balanceAfter);

        vm.stopBroadcast();
    }
}
