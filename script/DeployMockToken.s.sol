// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {MockToken} from "../src/MockToken.sol";

contract DeployMockToken is Script {
    function run() external {
        vm.startBroadcast();
        MockToken token = new MockToken();
        vm.stopBroadcast();
    }
}
