// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {Drip} from "../src/Drip.sol";

contract Deploy is Script {
    function run() external {
        address feeRecipient = vm.envAddress("FEE_RECIPIENT");

        vm.startBroadcast();
        Drip drip = new Drip(feeRecipient);
        vm.stopBroadcast();
    }
}
