// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "src/Raffle.sol";
import {DeployRaffle} from "script/Raffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract RaffleTest is Test {
    Raffle private raffle;
    HelperConfig private helperConfig;
    HelperConfig.NetworkConfig private config;

    address immutable i_participant = makeAddr("participant");
    uint256 constant STARTING_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.deployContract();
        config = helperConfig.getConfig();
        vm.deal(i_participant, STARTING_BALANCE);
    }

    function testRevertWhenNotEnoughEntryFee() public {
        vm.expectRevert();
        vm.prank(i_participant);
        raffle.enterRaffle{value: 0.001 ether}();
    }

    function testRaffleShouldBeOpeninitially() public view {
        assertEq(uint256(raffle.getRaffleState()), 0);
    }

    function testRevertWhenNotEnoughTimePassed() public {
        vm.expectRevert();
        raffle.performUpkeep("");
    }

    function testEnterShouldRevertIfStateIsCalculating() public {
        raffle.setRaffleState(1);
        vm.expectRevert();
        raffle.enterRaffle();
    }

    function testParticipenthShouldExistAfterEnteringTheRaffle() public {
        vm.prank(i_participant);
        raffle.enterRaffle{value: 0.2 ether}();

        assertEq(raffle.getParticipent(0), i_participant);
    }
}
