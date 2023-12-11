// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {MainDAO} from "../src/MainDAO.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract DeployMainDAO is Script {
    function run() external returns (MainDAO, HelperConfig) {
        console.log("===> deploying main dao");
        HelperConfig helperConfig = new HelperConfig();
        (
            uint256 updateInterval,
            uint256 nbValidations,
            address vrfCoordinator,
            bytes32 gasLane,
            uint64 subscriptionId,
            uint32 callBackGasLimit,
            address linkToken,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();

        if (subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            subscriptionId = createSubscription.createSubscription(vrfCoordinator, deployerKey);

            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(vrfCoordinator, subscriptionId, linkToken, deployerKey);
        }

        vm.startBroadcast(deployerKey);
        MainDAO mainDAO =
            new MainDAO(vrfCoordinator, subscriptionId, gasLane, callBackGasLimit, updateInterval, nbValidations);
        vm.stopBroadcast();

        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(mainDAO.getSerialJusticeAddress(), vrfCoordinator, subscriptionId, deployerKey);

        return (mainDAO, helperConfig);
    }
}
