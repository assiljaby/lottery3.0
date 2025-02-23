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
    error Raffle__UpKeepNotNeeded(uint256 balance, uint256 num_participants, uint256 state);
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
    event RandomWordsRequested(uint256 indexed requestId);

    constructor(
        uint256 _entryFee,
        uint256 _interval,
        uint256 _subId,
        uint32 _callbackGasLimit,
        bytes32 _gasLane,
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

    /**
     * @dev Function used to participate in the lottery.
     * The following conditions must be met to enter:
     * 1. The Raffle state should be Open
     * 2. Participant should spend the entry fee
     * -> an event will be emitted, otherwise reverts
     */
    function enterRaffle() external payable {
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__NotOpen();
        }
        if (msg.value < i_entryFee) {
            // using custom errors is more
            // gas efficient than require
            revert Raffle__SendMoreToEnterRaffle();
        }

        s_participants.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    /**
     * @dev Funtion called by Chainlink automation nodes. We are using it
     * to check if it is time to call the select winner function (performUpkeep).
     * The following should be true in order to select a winner:
     * 1. Interval that should have passed between the raffle rounds
     * 2. The raffle state should be Open
     * 3. The contract should hold money
     * 4. Chainlink sub should have LINK
     * @param - ignored
     * @return upkeepNeeded - if true -> time to select a winner
     * @return - ignored
     */
    function checkUpkeep(bytes memory /* checkData */ )
        public
        view
        returns (bool upkeepNeeded, bytes memory /* performData */ )
    {
        bool hasTimePassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool isRaffleOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_participants.length > 0;
        upkeepNeeded = hasTimePassed && isRaffleOpen && hasBalance && hasPlayers;

        return (upkeepNeeded, "");
    }

    /**
     * @dev This function is called by checkUpkeep when the above
     * conditions are met.
     * This function generates a random number using Chainlink VRFv2.5
     * then uses that number to select a participant from the array.
     * @param - ignored
     */
    function performUpkeep(bytes calldata /* performData */ ) external {
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpKeepNotNeeded(address(this).balance, s_participants.length, uint256(s_raffleState));
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
        emit RandomWordsRequested(requestId);
    }

    function fulfillRandomWords(uint256, /* requestId */ uint256[] calldata randomWords) internal override {
        /**
         * @dev The result of a number modulo n
         * will always be between 0 and n-1,
         * This insures we are picking an index
         * that is within the array's length.
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

    function getInterval() external view returns (uint256) {
        return i_interval;
    }

    function getGasLane() external view returns (bytes32) {
        return i_gasLane;
    }

    function getSubId() external view returns (uint256) {
        return i_subId;
    }

    function getGasLimit() external view returns (uint32) {
        return i_callbackGasLimit;
    }

    function getLastTimestamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getParticipent(uint256 _idx) external view returns (address) {
        return s_participants[_idx];
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getLastWinner() external view returns (address) {
        return s_lastWinner;
    }
}
