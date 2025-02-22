// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

abstract contract ScriptConstants {
    uint256 internal constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 internal constant LOCAL_CHAIN_ID = 31337;

    uint96 internal constant MOCK_BASE_FEE = 0.25 ether;
    uint96 internal constant MOCK_GAS_PRICE_LINK = 1e9;
    // LINK / ETH price
    int256 internal constant MOCK_WEI_PER_UNIT_LINK = 4e15;
}

contract HelperConfig is Script, ScriptConstants {
    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        uint256 entryFee;
        uint256 interval;
        uint256 subId;
        uint32 callbackGasLimit;
        bytes32 gasLane;
        address vrfCoordinator;
        address link;
    }

    NetworkConfig public localNetworkConfig;
    mapping(uint256 => NetworkConfig) configMappings;

    constructor() {
        configMappings[ETH_SEPOLIA_CHAIN_ID] = getSepoliaConfig();
    }

    function getConfigByChainId(uint256 chainId) internal returns (NetworkConfig memory) {
        if (configMappings[chainId].vrfCoordinator != address(0)) {
            return configMappings[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getAnvilConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getSepoliaConfig() internal pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entryFee: 0.01 ether,
            interval: 30,
            subId: 0,
            callbackGasLimit: 2_500_000,
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789
        });
    }

    function getAnvilConfig() internal returns (NetworkConfig memory) {
        // This checks if the vrfCoord was assgined
        // We are checking here if it is not equal to the default value
        // default value of an address is `address(0)`
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }

        // Deploy Mocks
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorMock =
            new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK, MOCK_WEI_PER_UNIT_LINK);
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            entryFee: 0.01 ether,
            interval: 30,
            subId: 0,
            callbackGasLimit: 2_500_000,
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            vrfCoordinator: address(vrfCoordinatorMock),
            link: address(linkToken)
        });
        return localNetworkConfig;
    }
}
