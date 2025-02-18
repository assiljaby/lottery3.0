// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "../src/Raffle.sol";
import {DeployRaffle} from "../script/Raffle.s.sol";

contract RaffleTest is Test {
    Raffle private raffle;

    address immutable i_user = makeAddr("user");
    uint256 constant STARTING_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        raffle = deployRaffle.run();
        vm.deal(i_user, STARTING_BALANCE);
    }

    function testRevertWhenNotEnoughEntryFee() public {
        vm.expectRevert();
        vm.prank(i_user);
        raffle.enterRaffle{value: 0.01 ether}();
    }
}
