// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "src/Raffle.sol";
import {DeployRaffle} from "script/Raffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {ScriptConstants} from "script/HelperConfig.s.sol";

contract RaffleTest is Test, ScriptConstants {
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

    modifier fastForward() {
        vm.warp(block.timestamp + config.interval);
        vm.roll(block.number + 1);

        _;
    }

    modifier skipFork() {
        if (block.chainid != LOCAL_CHAIN_ID) {
            return;
        }

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

    function testCheckUpkeepReturnsFalseWhenTimeHasntPassed() public enterRaffle {
        (bool upKeepNeeded,) = raffle.checkUpkeep("");

        assertFalse(upKeepNeeded);
    }

    function testCheckUpkeepReturnsFalseWhenCalculating() public enterRaffle fastForward calculating {
        (bool upKeepNeeded,) = raffle.checkUpkeep("");

        assertFalse(upKeepNeeded);
    }

    function testCheckUpkeepReturnsFalseWhenNoOneEntered() public fastForward {
        (bool upKeepNeeded,) = raffle.checkUpkeep("");

        assertFalse(upKeepNeeded);
    }

    function testCheckUpkeepReturnsTrueWhenAllConditionsAreMet() public enterRaffle fastForward {
        (bool upKeepNeeded,) = raffle.checkUpkeep("");

        assertTrue(upKeepNeeded);
    }

    /*////////////////////////////////////////////////////////
                        performUpkeep  
    ///////////////////////////////////////////////////////*/

    function testRevertWhenNotEnoughTimePassed() public enterRaffle {
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpKeepNotNeeded.selector, config.entryFee, 1, uint256(raffle.getRaffleState())
            )
        );
        raffle.performUpkeep("");
    }

    function testWillPassWhenUpKeepNeededIsTrue() public enterRaffle fastForward {
        raffle.performUpkeep("");
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsEvent() public enterRaffle fastForward {
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 requestId = logs[1].topics[1];

        assert(uint256(requestId) > 0);
        assertEq(uint256(raffle.getRaffleState()), 1);
    }

    /*////////////////////////////////////////////////////////
                        fulfillRandomWords  
    ///////////////////////////////////////////////////////*/

    function testRaffleStateShouldTurnOpenAfterFulfillRandomWords(uint256 randomRequestId)
        public
        enterRaffle
        fastForward
        skipFork
    {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(config.vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney() public fastForward skipFork {
        uint256 numParticipants = 4;
        address excpectedWinner = address(1);
        for (uint256 i = 0; i < numParticipants; i++) {
            address newParticipant = address(uint160(i));
            hoax(newParticipant, 1 ether);
            raffle.enterRaffle{value: config.entryFee}();
        }
        uint256 startTime = raffle.getLastTimestamp();
        uint256 winnerStartingBalance = excpectedWinner.balance;

        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 requestId = logs[1].topics[1];
        vm.expectEmit(true, false, false, false, address(raffle));
        emit WinnerPicked(address(excpectedWinner));
        VRFCoordinatorV2_5Mock(config.vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        address lastWinner = raffle.getLastWinner();
        uint256 prizePool = numParticipants * config.entryFee;
        uint256 endTime = raffle.getLastTimestamp();
        assertEq(uint256(raffle.getRaffleState()), 0);
        assertEq(address(raffle).balance, 0);
        assertEq(lastWinner, excpectedWinner);
        assertEq(excpectedWinner.balance, winnerStartingBalance + prizePool);
        assert(endTime > startTime);
    }
}
