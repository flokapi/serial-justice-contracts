// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import {DeployMainDAO} from "../script/DeployMainDAO.s.sol";
import {MainDAO} from "../src/MainDAO.sol";
import {SerialJustice} from "../src/SerialJustice.sol";
import {JusticeToken} from "../src/JusticeToken.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";

import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

contract MainDAOUnitTest is Test {
    MainDAO mainDAO;
    SerialJustice serialJustice;
    JusticeToken justiceToken;
    HelperConfig helperConfig;

    uint256 updateInterval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint32 callBackGasLimit;
    address linkToken;
    uint256 creatorKey;
    address creator;

    address[] daoMembers;
    address memberAlice;
    address memberBob;
    address notAMember;

    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 public constant NB_DAO_MEMBERS = 10;
    uint256 public constant ANSWER_PRICE = 1 * 10 ** 18;
    string public constant QUESTION_TEXT = "Is it true?";

    modifier timeToUpdateTokens() {
        vm.warp(block.timestamp + updateInterval + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier tokensUpdatedOnce() {
        vm.warp(block.timestamp + updateInterval + 1);
        vm.roll(block.number + 1);
        justiceToken.performUpkeep("0x");
        _;
    }

    modifier questionSubmitted() {
        vm.prank(memberAlice);
        serialJustice.submitQuestion(QUESTION_TEXT);
        _;
    }

    modifier questionSubmittedAndVoterDesignated() {
        vm.prank(memberAlice);
        vm.recordLogs();
        serialJustice.submitQuestion(QUESTION_TEXT);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[2];

        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(serialJustice)
        );
        _;
    }

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        } else {
            _;
        }
    }

    function addDaoMembers() public {
        for (uint256 i = 0; i < NB_DAO_MEMBERS; i++) {
            address newMember = makeAddr(Strings.toString(i));
            vm.deal(newMember, STARTING_USER_BALANCE);
            daoMembers.push(newMember);

            vm.prank(creator);
            mainDAO.addMember(newMember);
        }
    }

    function setUp() external {
        // Deploy new MainDAO contract
        DeployMainDAO deployer = new DeployMainDAO();
        (mainDAO, helperConfig) = deployer.run();

        // Get SerialJustice contract created by MainDAO
        address serialJusticeAddr = mainDAO.getSerialJusticeAddress();
        serialJustice = SerialJustice(serialJusticeAddr);

        // Get JusticeToken contract created by SerialJustice
        address justiceTokenAddr = serialJustice.getJusticeTokenAddress();
        justiceToken = JusticeToken(justiceTokenAddr);

        // Access network cfg params
        (
            updateInterval,
            ,
            vrfCoordinator,
            gasLane,
            ,
            callBackGasLimit,
            linkToken,
            creatorKey
        ) = helperConfig.activeNetworkConfig();

        creator = vm.addr(creatorKey);

        addDaoMembers();
        memberAlice = daoMembers[0]; // Submits a new question
        memberBob = daoMembers[1]; // Randomly desigated member to submit an answer
        notAMember = makeAddr("not a member");
    }

    // ************************* MainDAO

    function testMainDaoInitializesWithCorrectCreatorAddress() public view {
        address creatorRecorded = mainDAO.getCreatorAddress();
        assert(creatorRecorded == creator);
    }

    function testCorrectMemberCountRecorded() public view {
        uint256 membersCountRecorded = mainDAO.getMemberCount();
        assert(membersCountRecorded == NB_DAO_MEMBERS);
    }

    function testCannotAddAnExistingMember() public {
        address existingMember = mainDAO.getMemberAddress(0);

        vm.prank(creator);
        vm.expectRevert(
            MainDAO.MainDAO__CannotAddAlreadyExistingMember.selector
        );
        mainDAO.addMember(existingMember);
    }

    function testCannotAccessAnInvalidMember() public {
        vm.prank(creator);
        vm.expectRevert(MainDAO.MainDAO__InvalidMemberId.selector);
        mainDAO.getMemberAddress(NB_DAO_MEMBERS);
    }

    function testMemberIsAMember() public {
        vm.prank(creator);
        bool recordedIsMember = mainDAO.isMember(memberAlice);
        assert(recordedIsMember == true);
    }

    function testNotMemberIsNotAMember() public {
        vm.prank(creator);
        bool recordedIsMember = mainDAO.isMember(notAMember);
        assert(recordedIsMember == false);
    }

    function testShowsTheCorrectAddressGivenTheMemberId() public view {
        uint256 memberId = NB_DAO_MEMBERS - 1;
        address addressRecorded = mainDAO.getMemberAddress(memberId);
        assert(addressRecorded == daoMembers[memberId]);
    }

    // ************************* JusticeToken automation

    function testDoesNotAllowUpkeepWhenNotReady() public view {
        (bool performUpkeep, ) = justiceToken.checkUpkeep("0x");
        assert(performUpkeep == false);
    }

    function testAllowsUpkeepWhenEnoughTimeHasPassed()
        public
        timeToUpdateTokens
    {
        (bool performUpkeep, ) = justiceToken.checkUpkeep("0x");
        assert(performUpkeep == true);
    }

    function testPerformUpkeepRevertsWhenNotNeeded() public {
        vm.prank(creator);
        vm.expectRevert(JusticeToken.JusticeToken__UpkeepNotNeeded.selector);
        justiceToken.performUpkeep("0x");
    }

    function testPerformUpkeepUpdatesTokensWhenEnoughTimePassed()
        public
        timeToUpdateTokens
    {
        vm.prank(creator);
        justiceToken.performUpkeep("0x");

        uint256 balanceRecorded = justiceToken.balanceOf(memberAlice);
        assert(balanceRecorded == ANSWER_PRICE);
    }

    // ************************* JusticeToken security

    function testCannotBurnJusticeTokenFromAnyAccount()
        public
        tokensUpdatedOnce
    {
        vm.prank(creator);
        vm.expectRevert(JusticeToken.JusticeToken__OnlySerialJustice.selector);
        justiceToken.burnOne(creator);
    }

    function testSerialJusticeContractCanBurnTokens() public tokensUpdatedOnce {
        uint256 balanceBefore = justiceToken.balanceOf(memberAlice);
        vm.prank(address(serialJustice));
        justiceToken.burnOne(memberAlice);
        uint256 balanceAfter = justiceToken.balanceOf(memberAlice);

        assert(balanceBefore == ANSWER_PRICE);
        assert(balanceAfter == 0);
    }

    // ************************* SerialJustice questions

    function testCannotSumbitQuestionIfNotAMember() public {
        vm.prank(notAMember);
        vm.expectRevert(SerialJustice.SerialJustice__IsNotAMember.selector);
        serialJustice.submitQuestion(QUESTION_TEXT);
    }

    function testCannotSubmitQuestionIfNotEnoughBalance() public {
        vm.prank(memberAlice);
        vm.expectRevert(SerialJustice.SerialJustice__NotEnoughBalance.selector);
        serialJustice.submitQuestion(QUESTION_TEXT);
    }

    function testCanSumbitQuestionIfMemberAndEnoughBalance()
        public
        tokensUpdatedOnce
        questionSubmitted
    {
        uint256 recordedNbOfQuestion = serialJustice.getQuestionCount();
        (
            SerialJustice.QuestionState recordedState,
            string memory recordedText,
            address submitter,
            address nextVoter,
            ,

        ) = serialJustice.getQuestionData(0);

        assert(recordedNbOfQuestion == 1);
        assert(
            recordedState ==
                SerialJustice.QuestionState.AWAITING_VOTER_DESIGNATION
        );
        assert(
            keccak256(abi.encodePacked(recordedText)) ==
                keccak256(abi.encodePacked(QUESTION_TEXT))
        );
        assert(submitter == memberAlice);
        assert(nextVoter == address(0));
    }

    // ************************* SerialJustice VRF and voter designation

    function testFulfillRandomWordsCanOnlyBeCalledAfterNewVoterRequested()
        public
        skipFork
        tokensUpdatedOnce
    {
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            0,
            address(serialJustice)
        );

        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            1,
            address(serialJustice)
        );
    }

    function testFulfillRandomWordsPicksANewVoter()
        public
        skipFork
        tokensUpdatedOnce
    {
        // Arrange
        address expectedNextVoter = memberBob;

        // Act
        vm.prank(memberAlice);
        vm.recordLogs();
        serialJustice.submitQuestion(QUESTION_TEXT);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[2];

        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(serialJustice)
        );

        (
            SerialJustice.QuestionState recordedState,
            ,
            ,
            address nextVoter,
            ,

        ) = serialJustice.getQuestionData(0);

        // Assert
        assert(nextVoter == expectedNextVoter);
        assert(
            recordedState == SerialJustice.QuestionState.AWAITING_VOTER_ANSWER
        );
    }

    // ************************* SerialJustice submitted answers

    function testCanOnlySubmitAnswerIfQuestionStateAllows()
        public
        skipFork
        tokensUpdatedOnce
        questionSubmitted
    {
        vm.prank(memberBob);
        vm.expectRevert(
            SerialJustice.SerialJustice__NewVoteNotAllowed.selector
        );
        serialJustice.answerQuestion(0, true);
    }

    function testOnlyDesignatedVoterCanSubmitAnswer()
        public
        skipFork
        tokensUpdatedOnce
        questionSubmittedAndVoterDesignated
    {
        vm.prank(memberAlice);
        vm.expectRevert(
            SerialJustice.SerialJustice__NotAllowedToVoteOnThisQuestion.selector
        );
        serialJustice.answerQuestion(0, true);
    }

    function testSubmittedAnswerUpdatesQuestionCorrectly()
        public
        skipFork
        tokensUpdatedOnce
        questionSubmittedAndVoterDesignated
    {
        vm.prank(memberBob);
        serialJustice.answerQuestion(0, true);

        (
            SerialJustice.QuestionState recordedState,
            ,
            ,
            address nextVoter,
            uint256 nbVotesYes,
            uint256 nbVotesNo
        ) = serialJustice.getQuestionData(0);

        assert(recordedState == SerialJustice.QuestionState.IDLE);
        assert(nextVoter == address(0));
        assert(nbVotesYes == 1);
        assert(nbVotesNo == 0);
    }
}
