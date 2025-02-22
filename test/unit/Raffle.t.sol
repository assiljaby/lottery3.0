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

    /*////////////////////////////////////////////////////////
                        Modifiers  
    ///////////////////////////////////////////////////////*/
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

    modifier pastForward() {
        vm.warp(block.timestamp + config.interval);
        vm.roll(block.number + 1);

        _;
    }

    /*////////////////////////////////////////////////////////
                        constructor  
    ///////////////////////////////////////////////////////*/

    function testAllStateVariableInitializedWhenCallingConstructor() public view {
        assertEq(raffle.getEntryFee(), config.entryFee);
        assertEq(raffle.getGasLane(), config.gasLane);
        assertEq(raffle.getGasLimit(), config.callbackGasLimit);
        assertEq(raffle.getInterval(), config.interval);
        assertGe(block.timestamp, raffle.getLastTimestamp());
        assertEq(uint256(raffle.getRaffleState()), 0);
        assertEq(raffle.getSubId(), config.subId);
    }

    /*////////////////////////////////////////////////////////
                        enterRaffle  
    ///////////////////////////////////////////////////////*/

    function testRevertWhenNotEnoughEntryFee() public {
        vm.prank(i_participant);
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        raffle.enterRaffle{value: 0.001 ether}();
    }

    function testParticipenthShouldExistAfterEnteringTheRaffle() public enterRaffle {
        assertEq(raffle.getParticipent(0), i_participant);
    }

    function testEnterShouldRevertIfStateIsCalculating() public enterRaffle calculating {
        vm.prank(i_participant);
        vm.expectRevert(Raffle.Raffle__NotOpen.selector);
        raffle.enterRaffle();
    }

    function testEventIsEmittedWhenParticipantEnters() public {
        vm.prank(i_participant);

        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(i_participant);

        raffle.enterRaffle{value: config.entryFee}();
    }

    /*////////////////////////////////////////////////////////
                        checkUpkeep  
    ///////////////////////////////////////////////////////*/

    function testCheckUpkeepReturnsFalseWhenTimeHasntPassed() enterRaffle public {
        (bool upKeepNeeded,) = raffle.checkUpkeep("");

        assertFalse(upKeepNeeded);
    }

    function testCheckUpkeepReturnsFalseWhenCalculating() enterRaffle pastForward calculating public {
        (bool upKeepNeeded,) = raffle.checkUpkeep("");

        assertFalse(upKeepNeeded);
    }

    function testCheckUpkeepReturnsFalseWhenNoOneEntered() pastForward public {
        (bool upKeepNeeded,) = raffle.checkUpkeep("");

        assertFalse(upKeepNeeded);
    }

    function testCheckUpkeepReturnsTrueWhenAllConditionsAreMet() enterRaffle pastForward public {
        (bool upKeepNeeded,) = raffle.checkUpkeep("");

        assertTrue(upKeepNeeded);
    }

    /*////////////////////////////////////////////////////////
                        performUpkeep  
    ///////////////////////////////////////////////////////*/

    function testRevertWhenNotEnoughTimePassed() public {
        vm.expectRevert();
        raffle.performUpkeep("");
    }

    function testWillPassWhenUpKeepNeededIsTrue() enterRaffle pastForward public {
        raffle.performUpkeep("");
    }

    /*////////////////////////////////////////////////////////
                        fulfillRandomWords  
    ///////////////////////////////////////////////////////*/

    // function testRaffleStateShouldTurnOpenAfterFulfillRandomWords() calculating public {
    //     raffle.fulfillRandomWords(12, [12]);
    //     assertEq(uint256(raffle.getRaffleState()), 0);
    // }
}
