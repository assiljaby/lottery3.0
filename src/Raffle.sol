// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title a Raffle / Lottery Contract
 * @author Assil Jaby
 * @notice this contract creates a lottery
 * @dev Implements Chainlink VRFv2.5
 */
contract Raffle is VRFConsumerBaseV2Plus {
    /* Errors */
    error Raffle__SendMoreToEnterRaffle();
    error Raffle__NotEnoughTimePassed();
    error Raffle__TransferFailed();
    error Raffle__NotOpen();

    /* Types Declarations */
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /* State Variables */
    uint16 private constant REQUEST_COMFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint32 private immutable i_callbackGasLimit;
    bytes32 private immutable i_gasLane;
    uint256 private immutable i_subId;
    uint256 private immutable i_entryFee;
    uint256 private immutable i_interval; // @dev Duration of the raffle in seconds
    uint256 private s_lastTimeStamp;
    address payable[] private s_participants;
    address payable private s_lastWinner;
    RaffleState private s_raffleState;

    /* Events */
    event RaffleEntered(address indexed participant);
    event WinnerPicked(address indexed winner);

    constructor(
        uint256 _entryFee,
        uint256 _interval,
        bytes32 _gasLane,
        uint256 _subId,
        uint32 _callbackGasLimit,
        address vrfCoordinator
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entryFee = _entryFee;
        i_interval = _interval;
        i_gasLane = _gasLane;
        i_subId = _subId;
        i_callbackGasLimit = _callbackGasLimit;

        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        /**
         * @dev Reverts any attempt to enter while we
         * calculate the winner of the current round
         */
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__NotOpen();
        }
        // checks if value sent is enough
        // reverts otherwise
        if (msg.value < i_entryFee) {
            // using custom errors is more
            // gas efficient than require
            revert Raffle__SendMoreToEnterRaffle();
        }

        s_participants.push(payable(msg.sender));

        emit RaffleEntered(msg.sender);
    }

    // 1. Wait for inteval
    // 1. Generate a number
    // 2. Use the number to pick a participant
    function selectWinner() external {
        if ((block.timestamp - s_lastTimeStamp) < i_interval) {
            revert Raffle__NotEnoughTimePassed();
        }

        s_raffleState = RaffleState.CALCULATING;

        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_gasLane,
                subId: i_subId,
                requestConfirmations: REQUEST_COMFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        /**
         * @dev The result of a number modulo n
         * will always be between 0 and n-1,
         * This insures we are picking an index
         * that is within the array's length
         */
        uint256 winnerIdx = randomWords[0] % s_participants.length;
        s_lastWinner = s_participants[winnerIdx];
        (bool success,) = s_lastWinner.call{value: address(this).balance}("");

        // Opens raffle and reset the participants list
        s_raffleState = RaffleState.OPEN;
        s_participants = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(s_lastWinner);

        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    /* Getter Functions */
    function getEntryFee() external view returns (uint256) {
        return i_entryFee;
    }

    function getParticipent(uint256 _idx) external view returns (address) {
        return s_participants[_idx];
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    /* Setter Functions */
    function setRaffleState(uint256 state) external {
        s_raffleState = RaffleState(state);
    }
}
