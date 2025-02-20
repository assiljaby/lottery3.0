// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployRaffle is Script {
    // uint256 private constant SUB_ID = 78942633588309985959463098652399775825190021689239170099991759907395851985261;

    function run() external {}

    function deployContract() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        vm.startBroadcast();
        Raffle raffle = new Raffle(
            config.entryFee,
            config.interval,
            config.subId,
            config.callbackGasLimit,
            config.gasLane,
            config.vrfCoordinator
        );
        vm.stopBroadcast();

        return (raffle, helperConfig);
    }
}
