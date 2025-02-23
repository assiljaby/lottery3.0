// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig, ScriptConstants} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
/**
 * create subscription -> fund subscription -> add consumer
 */

contract CreateSubscription is Script {
    /**
     * This function gets the current config and calls the createsubscription
     * with the vrfCoordinator address from the config.
     * @return subId - subscription ID necessary to call the performUpKeep function
     * @return vrfCoordinator
     */
    function createSubscriptionWithConfig() public returns (uint256, address) {
        HelperConfig config = new HelperConfig();
        address vrfCoordinator = config.getConfig().vrfCoordinator;
        uint256 subId = createSubscription(vrfCoordinator);

        return (subId, vrfCoordinator);
    }

    /**
     * This function creates a chainlink subscription for the vrfCoord.
     * @param _vrfCoordinator - address of the vrfCoordinator
     * @return subId - subscription ID necessary to call the pefromUpKeep function
     */
    function createSubscription(address _vrfCoordinator) public returns (uint256) {
        console.log("Creating subscription on chainId:", block.chainid);
        vm.startBroadcast();
        /**
         * We are casting _vrfCoordinator to VRFCoordinatorV2_5Mock
         * This is necessary because:
         * 1. _vrfCoordinator contains just an address
         * 2. To call methods on a contract at that address, you need to tell Solidity
         *    what interface/contract type is at that address
         * 3. The cast VRFCoordinatorV2_5Mock(_vrfCoordinator) tells Solidity
         *    to treat the address as an instance of that specific contract
         */
        uint256 subId = VRFCoordinatorV2_5Mock(_vrfCoordinator).createSubscription();
        vm.stopBroadcast();

        console.log("Subscription Id:", subId);

        return subId;
    }

    function run() public {
        createSubscriptionWithConfig();
    }
}

contract FundSubscription is Script, ScriptConstants {
    uint256 private constant FUND_AMMOUNT = 3 ether; // 3 LINK

    function fundSubscriptionWithconfig() public {
        HelperConfig config = new HelperConfig();
        address vrfCoordinator = config.getConfig().vrfCoordinator;
        address link = config.getConfig().link;
        uint256 subId = config.getConfig().subId;

        fundSubscription(subId, vrfCoordinator, link);
    }

    function fundSubscription(uint256 _subId, address _vrfCoordinator, address _link) public {
        console.log("Funding Sub ID:", _subId);
        console.log("Using vrfCoordinator with address:", _vrfCoordinator);
        console.log("On Chain Id:", block.chainid);

        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(_vrfCoordinator).fundSubscription(_subId, FUND_AMMOUNT * 100);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            LinkToken(_link).transferAndCall(_vrfCoordinator, FUND_AMMOUNT, abi.encode(_subId));
            vm.stopBroadcast();
        }
    }

    function run() public {
        fundSubscriptionWithconfig();
    }
}

contract AddConsumer is Script {
    function addConsumerWithconfig(address _latestDeployed) public {
        HelperConfig config = new HelperConfig();
        address vrfCoordinator = config.getConfig().vrfCoordinator;
        uint256 subId = config.getConfig().subId;

        addConsumer(_latestDeployed, vrfCoordinator, subId);
    }

    /**
     * This function adds the consumer to the VRF subscription.
     * @param _latestDeployed - this is the consumer contract that we are adding to the VRF subscription
     * @param _vrfCoordinator -
     * @param _subId - subscription ID
     */
    function addConsumer(address _latestDeployed, address _vrfCoordinator, uint256 _subId) public {
        console.log("Adding Consumer:", _latestDeployed);
        console.log("To vrfCoord:", _vrfCoordinator);
        console.log("Using subscription ID:", _subId);
        console.log("on chain ID:", block.chainid);

        vm.startBroadcast();
        VRFCoordinatorV2_5Mock(_vrfCoordinator).addConsumer(_subId, _latestDeployed);
        vm.stopBroadcast();
    }

    function run() public {
        address latestDeployed = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerWithconfig(latestDeployed);
    }
}
