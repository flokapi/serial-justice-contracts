// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {SerialJustice} from "./SerialJustice.sol";

contract MainDAO {
    error MainDAO__NotCreator();
    error MainDAO__CannotAddAlreadyExistingMember();
    error MainDAO__InvalidMemberId();

    address private immutable i_creator;
    address[] private s_members;
    mapping(address => bool) private s_member_exists;

    SerialJustice private immutable i_serialJustice;

    modifier onlyCreator() {
        if (msg.sender != i_creator) revert MainDAO__NotCreator();
        _;
    }

    constructor(
        address vrfCoordinatorV2,
        uint64 subscriptionId,
        bytes32 gasLane,
        uint32 callbackGasLimit,
        uint256 updateInterval,
        uint256 nbValidations
    ) {
        i_creator = msg.sender;
        i_serialJustice = new SerialJustice(
            vrfCoordinatorV2, subscriptionId, gasLane, callbackGasLimit, address(this), updateInterval, nbValidations
        );
    }

    function addMember(address newMemberAddress) public onlyCreator {
        if (s_member_exists[newMemberAddress]) {
            revert MainDAO__CannotAddAlreadyExistingMember();
        }

        s_members.push(newMemberAddress);
        s_member_exists[newMemberAddress] = true;
    }

    function getMemberCount() public view returns (uint256) {
        return s_members.length;
    }

    function getMemberAddress(uint256 memberId) public view returns (address) {
        if (memberId >= s_members.length) {
            revert MainDAO__InvalidMemberId();
        }

        return s_members[memberId];
    }

    function isMember(address _address) public view returns (bool) {
        return s_member_exists[_address];
    }

    function getCreatorAddress() public view returns (address) {
        return i_creator;
    }

    function getSerialJusticeAddress() public view returns (address) {
        return address(i_serialJustice);
    }
}
