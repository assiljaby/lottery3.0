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

    event RaffleEntered(address indexed participant);
    event WinnerPicked(address indexed winner);

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.deployContract();
        config = helperConfig.getConfig();
        vm.deal(i_participant, STARTING_BALANCE);
    }

    modifier enterRaffle() {
        vm.prank(i_participant);
        raffle.enterRaffle{value: config.entryFee}();

        _;
    }

    modifier calculating() {
        vm.warp(block.timestamp + config.interval);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        _;
    }

    function testRevertWhenNotEnoughEntryFee() public {
        vm.prank(i_participant);
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        raffle.enterRaffle{value: 0.001 ether}();
    }

    function testRaffleShouldBeOpeninitially() public view {
        assertEq(uint256(raffle.getRaffleState()), 0);
    }

    function testRevertWhenNotEnoughTimePassed() public {
        vm.expectRevert();
        raffle.performUpkeep("");
    }

    function testEnterShouldRevertIfStateIsCalculating() public enterRaffle calculating {
        vm.prank(i_participant);
        vm.expectRevert(Raffle.Raffle__NotOpen.selector);
        raffle.enterRaffle();
    }

    function testParticipenthShouldExistAfterEnteringTheRaffle() public enterRaffle {
        assertEq(raffle.getParticipent(0), i_participant);
    }

    function testEventIsEmittedWhenParticipantEnters() public {
        vm.prank(i_participant);

        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(i_participant);

        raffle.enterRaffle{value: config.entryFee}();
    }
}
