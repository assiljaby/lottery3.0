// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract DeployRaffle is Script {
    function run() external {
        deployContract();
    }

    function deployContract() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        // Create Subscription -> Fund Subscription -> Deploy Contract -> Add it as Consumer
        if (config.subId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            config.subId = createSubscription.createSubscription(config.vrfCoordinator);
        }

        FundSubscription fundSubscription = new FundSubscription();
        fundSubscription.fundSubscription(config.subId, config.vrfCoordinator, config.link);

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

        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(address(raffle), config.vrfCoordinator, config.subId);

        return (raffle, helperConfig);
    }
}
