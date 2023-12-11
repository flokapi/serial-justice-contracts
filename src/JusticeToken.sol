// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {MainDAO} from "./MainDAO.sol";
import {SerialJustice} from "./SerialJustice.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";

contract JusticeToken is ERC20, AutomationCompatibleInterface {
    error JusticeToken__UpkeepNotNeeded();
    error JusticeToken__OnlySerialJustice();

    uint256 public constant MAX_BALANCE = 10 * 10 ** 18;
    uint256 public constant ANSWER_PRICE = 1 * 10 ** 18;

    SerialJustice private immutable i_serialJustice;
    MainDAO private immutable i_mainDAO;
    uint256 private immutable i_updateIterval;

    uint256 private s_lastTimeStamp;
    uint256 private s_updateCounter;

    event UpdatedTokens(uint256 s_updateCounter);

    modifier onlySerialJustice() {
        if (msg.sender != address(i_serialJustice)) {
            revert JusticeToken__OnlySerialJustice();
        }
        _;
    }

    constructor(address serialJusticeAddress, address mainDAOAddress, uint256 updateInterval)
        ERC20("JusticeToken", "JT")
    {
        i_serialJustice = SerialJustice(serialJusticeAddress);
        i_mainDAO = MainDAO(mainDAOAddress);
        i_updateIterval = updateInterval;
        s_lastTimeStamp = block.timestamp;
        s_updateCounter = 0;
    }

    function checkUpkeep(bytes memory) public view returns (bool, bytes memory) {
        bool upkeepNeeded = ((block.timestamp - s_lastTimeStamp) > i_updateIterval);
        return (upkeepNeeded, "0x0");
    }

    function performUpkeep(bytes calldata) external override {
        (bool upkeepNeeded,) = checkUpkeep("0x");
        if (!upkeepNeeded) {
            revert JusticeToken__UpkeepNotNeeded();
        }

        s_lastTimeStamp = block.timestamp;
        updateTokens();
    }

    function updateTokens() internal {
        uint256 membersCount = i_mainDAO.getMemberCount();

        for (uint256 i = 0; i < membersCount; i++) {
            address memberAddress = i_mainDAO.getMemberAddress(i);
            uint256 currentBalance = balanceOf(memberAddress);
            if (currentBalance < MAX_BALANCE - 1) {
                _mint(memberAddress, 1 * 10 ** decimals());
            }
        }

        s_updateCounter++;
        emit UpdatedTokens(1);
    }

    function burnOne(address accountAddress) public onlySerialJustice {
        _burn(accountAddress, ANSWER_PRICE);
    }

    function getUpdateCount() public view returns (uint256) {
        return s_updateCounter;
    }

    function getUpdateInterval() public view returns (uint256) {
        return i_updateIterval;
    }

    function getAnswerPrice() public pure returns (uint256) {
        return ANSWER_PRICE;
    }

    function getSerialJusticeAddress() public view returns (address) {
        return address(i_serialJustice);
    }

    function getMainDAOAddress() public view returns (address) {
        return address(i_mainDAO);
    }
}
