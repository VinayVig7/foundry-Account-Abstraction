// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {VinayToken} from "../src/Ethereum/VinayToken.sol";

contract DeployVinayToken is Script {
    function run() external {
        vm.startBroadcast();

        // Deploy token
        VinayToken token = new VinayToken();

        // Mint tokens to your address
        token.mint(msg.sender, 1_000_000 ether); // adjust amount as needed
        vm.stopBroadcast();
    }
}
