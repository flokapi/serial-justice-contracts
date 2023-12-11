// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        uint256 tokenUpdateInterval;
        uint256 voteTimeout;
        uint256 nbValidations;
        address vrfCoordinator;
        bytes32 gasLane;
        uint64 subscriptionId;
        uint32 callBackGasLimit;
        address linkToken;
        uint256 deployerKey;
    }

    uint256 public constant DEFAULT_ANVIL_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    NetworkConfig public activeNetworkConfig;

    constructor() {
        console.log("===> new helper config");
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else if (block.chainid == 4002) {
            activeNetworkConfig = getFantomTestnetEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilConfig();
        }
    }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory) {
        return
            NetworkConfig({
                tokenUpdateInterval: 60,
                voteTimeout: 60,
                nbValidations: 3,
                vrfCoordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
                gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                subscriptionId: 0,
                callBackGasLimit: 500000,
                linkToken: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
                deployerKey: vm.envUint("PRIVATE_KEY")
            });
    }

    function getFantomTestnetEthConfig()
        public
        view
        returns (NetworkConfig memory)
    {
        return
            NetworkConfig({
                tokenUpdateInterval: 60,
                voteTimeout: 60,
                nbValidations: 3,
                vrfCoordinator: 0xbd13f08b8352A3635218ab9418E340c60d6Eb418,
                gasLane: 0x121a143066e0f2f08b620784af77cccb35c6242460b4a8ee251b4b416abaebd4,
                subscriptionId: 0,
                callBackGasLimit: 500000,
                linkToken: 0xfaFedb041c0DD4fA2Dc0d87a6B0979Ee6FA7af5F,
                deployerKey: vm.envUint("PRIVATE_KEY")
            });
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.vrfCoordinator != address(0)) {
            return activeNetworkConfig;
        }

        uint96 baseFee = 0.25 ether;
        uint96 gasPriceLink = 1e9;

        vm.startBroadcast();
        VRFCoordinatorV2Mock vrfCoordinatorV2Mock = new VRFCoordinatorV2Mock(
            baseFee,
            gasPriceLink
        );
        LinkToken link = new LinkToken();
        vm.stopBroadcast();

        return
            NetworkConfig({
                tokenUpdateInterval: 60 * 60 * 24,
                voteTimeout: 60 * 60 * 24,
                nbValidations: 6,
                vrfCoordinator: address(vrfCoordinatorV2Mock),
                gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                subscriptionId: 0,
                callBackGasLimit: 500000,
                linkToken: address(link),
                deployerKey: DEFAULT_ANVIL_KEY
            });
    }
}
