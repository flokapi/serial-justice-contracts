// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {MainDAO} from "./MainDAO.sol";
import {SerialJustice} from "./SerialJustice.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";

contract JusticeToken is ERC20, AutomationCompatibleInterface {
    error JusticeToken__UpkeepNotNeeded();
    error JusticeToken__OnlySerialJustice();

    uint256 private constant MAX_BALANCE_UNITS = 10;
    uint256 private constant ANSWER_PRICE_UNITS = 1;

    SerialJustice private immutable i_serialJustice;
    MainDAO private immutable i_mainDAO;
    uint256 private immutable i_updateIterval;
    uint256 private immutable i_max_balance;
    uint256 private immutable i_answer_price;

    uint256 private s_lastTimeStamp;
    uint256 private s_updateCounter;

    event UpdatedTokens(uint256 s_updateCounter);

    modifier onlySerialJustice() {
        if (msg.sender != address(i_serialJustice)) {
            revert JusticeToken__OnlySerialJustice();
        }
        _;
    }

    constructor(
        address serialJusticeAddress,
        address mainDAOAddress,
        uint256 updateInterval
    ) ERC20("JusticeToken", "JT") {
        i_serialJustice = SerialJustice(serialJusticeAddress);
        i_mainDAO = MainDAO(mainDAOAddress);
        i_updateIterval = updateInterval;

        i_max_balance = MAX_BALANCE_UNITS * 10 ** decimals();
        i_answer_price = ANSWER_PRICE_UNITS * 10 ** decimals();

        s_lastTimeStamp = block.timestamp;
        s_updateCounter = 0;
    }

    function checkUpkeep(
        bytes memory
    ) public view returns (bool, bytes memory) {
        bool upkeepNeeded = ((block.timestamp - s_lastTimeStamp) >
            i_updateIterval);
        return (upkeepNeeded, "0x");
    }

    function performUpkeep(bytes calldata) external override {
        (bool upkeepNeeded, ) = checkUpkeep("0x");
        if (!upkeepNeeded) {
            revert JusticeToken__UpkeepNotNeeded();
        }

        s_lastTimeStamp = block.timestamp;
        updateTokens();
    }

    function updateTokens() private {
        uint256 membersCount = i_mainDAO.getMemberCount();

        for (uint256 i = 0; i < membersCount; i++) {
            address memberAddress = i_mainDAO.getMemberAddress(i);
            uint256 currentBalance = balanceOf(memberAddress);
            if (currentBalance < i_max_balance - i_answer_price) {
                _mint(memberAddress, i_answer_price);
            }
        }

        s_updateCounter++;
        emit UpdatedTokens(s_updateCounter);
    }

    function burnOne(address accountAddress) external onlySerialJustice {
        _burn(accountAddress, i_answer_price);
    }

    function getUpdateCount() public view returns (uint256) {
        return s_updateCounter;
    }

    function getUpdateInterval() public view returns (uint256) {
        return i_updateIterval;
    }

    function getAnswerPrice() public view returns (uint256) {
        return i_answer_price;
    }

    function getSerialJusticeAddress() public view returns (address) {
        return address(i_serialJustice);
    }

    function getMainDAOAddress() public view returns (address) {
        return address(i_mainDAO);
    }
}
