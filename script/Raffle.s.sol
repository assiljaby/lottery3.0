// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";

contract DeployRaffle is Script {
    uint256 private constant ENTRY_FEE = 0.1 ether;
    uint256 private constant INTERVAL = 100;
    uint256 private constant SUB_ID = 78942633588309985959463098652399775825190021689239170099991759907395851985261;
    address private constant VRF_COORDINATOR = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;
    bytes32 private constant GAS_LANE = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    uint32 private constant CALLBACK_GAS_LIMIT = 2_500_000;

    function run() external returns (Raffle) {
        vm.startBroadcast();
        Raffle raffle = new Raffle(ENTRY_FEE, INTERVAL, GAS_LANE, SUB_ID, CALLBACK_GAS_LIMIT, VRF_COORDINATOR);
        vm.stopBroadcast();

        return raffle;
    }
}
