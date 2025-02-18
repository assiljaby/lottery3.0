// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * @title a Raffle / Lottery Contract
 * @author Assil Jaby
 * @notice this contract creates a lottery
 * @dev Implements Chainlink VRFv2.5
 */
contract Raffle {
    /**
     * Errors
     */
    error Raffle__SendMoreToEnterRaffle();

    uint256 private immutable i_entryFee;
    address payable[] private s_participants;

    /**
     * Events
     */
    event RaffleEntered(address indexed player);

    constructor(uint256 _entryFee) {
        i_entryFee = _entryFee;
    }

    function enterRaffle() public payable {
        // checks if value sent is enough
        // reverts otherwise
        if (msg.value < i_entryFee) {
            // using custom errors is more
            // gas efficient than require
            revert Raffle__SendMoreToEnterRaffle();
        }

        s_participants.push(payable(msg.sender));
    }

    // TODO: selectWinner
    // function selectWinner() public {}

    /**
     * Getter Functions
     */
    function getEntryFee() external view returns (uint256) {
        return i_entryFee;
    }

    function getParticipent(uint256 _idx) external view returns (address) {
        return s_participants[_idx];
    }
}
