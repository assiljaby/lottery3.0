// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";

contract DeployRaffle is Script {
    uint256 private constant ENTRY_FEE = 0.1 ether;

    function run() external returns (Raffle) {
        vm.startBroadcast();
        Raffle raffle = new Raffle(ENTRY_FEE);
        vm.stopBroadcast();

        return raffle;
    }
}
