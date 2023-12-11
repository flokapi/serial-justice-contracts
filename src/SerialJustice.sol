// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {MainDAO} from "./MainDAO.sol";
import {JusticeToken} from "./JusticeToken.sol";

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";

contract SerialJustice is VRFConsumerBaseV2, AutomationCompatibleInterface {
    error SerialJustice__IsNotAMember();
    error SerialJustice__NotEnoughBalance();
    error SerialJustice__InvalidQuestionId();
    error SerialJustice__NewVoteRequestNotAllowed();
    error SerialJustice__NewVoteNotAllowed();
    error SerialJustice__NotAllowedToVoteOnThisQuestion();
    error SerialJustice__UpkeepNotNeeded();

    enum QuestionState {
        IDLE,
        AWAITING_VOTER_DESIGNATION,
        AWAITING_VOTER_ANSWER,
        FINAL_ANSWER
    }

    struct Question {
        QuestionState state;
        string text;
        address submitter;
        address nextVoter;
        uint256 nbVotesYes;
        uint256 nbVotesNo;
        uint256 voteUntil;
    }

    // Chainlink VRF variables
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    uint64 private immutable i_subscriptionId;
    bytes32 private immutable i_gasLane;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    uint256 private immutable i_nbValidations;
    uint256 private immutable i_voteTimeout;
    MainDAO private immutable i_mainDAO;
    JusticeToken private immutable i_justiceToken;
    Question[] private s_questionArray;
    mapping(uint256 => uint256) private s_requestIdToQuestionId;

    event RequestedNewVoter(uint256 requestId);

    modifier onlyMember() {
        if (i_mainDAO.isMember(msg.sender) == false) {
            revert SerialJustice__IsNotAMember();
        }
        _;
    }

    modifier hasEnoughBalance() {
        if (
            i_justiceToken.balanceOf(msg.sender) <
            i_justiceToken.getAnswerPrice()
        ) {
            revert SerialJustice__NotEnoughBalance();
        }
        _;
    }

    constructor(
        address vrfCoordinatorV2,
        uint64 subscriptionId,
        bytes32 gasLane,
        uint32 callbackGasLimit,
        address daoAddress,
        uint256 tokenUpdateInterval,
        uint256 voteTimeout,
        uint256 nbValidations
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_subscriptionId = subscriptionId;
        i_gasLane = gasLane;
        i_callbackGasLimit = callbackGasLimit;

        i_mainDAO = MainDAO(daoAddress);
        i_justiceToken = new JusticeToken(
            address(this),
            daoAddress,
            tokenUpdateInterval
        );
        i_nbValidations = nbValidations;
        i_voteTimeout = voteTimeout;
    }

    function submitQuestion(
        string memory text
    ) public onlyMember hasEnoughBalance {
        Question storage newQuestion = s_questionArray.push();
        newQuestion.state = QuestionState.IDLE;
        newQuestion.text = text;
        newQuestion.submitter = msg.sender;

        i_justiceToken.burnOne(msg.sender);
        pickRandomVoter(s_questionArray.length - 1);
    }

    function requestNewVote(
        uint256 questionId
    ) public onlyMember hasEnoughBalance {
        if (questionId >= s_questionArray.length)
            revert SerialJustice__InvalidQuestionId();

        if (s_questionArray[questionId].state != QuestionState.IDLE)
            revert SerialJustice__NewVoteRequestNotAllowed();

        i_justiceToken.burnOne(msg.sender);
        pickRandomVoter(questionId);
    }

    function pickRandomVoter(uint256 questionId) private {
        s_questionArray[questionId].state = QuestionState
            .AWAITING_VOTER_DESIGNATION;

        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        s_requestIdToQuestionId[requestId] = questionId;
        emit RequestedNewVoter(requestId);
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        uint256 questionId = s_requestIdToQuestionId[requestId];
        uint256 voterId = randomWords[0] % i_mainDAO.getMemberCount();
        address nextVoter = i_mainDAO.getMemberAddress(voterId);

        s_questionArray[questionId].nextVoter = nextVoter;
        s_questionArray[questionId].state = QuestionState.AWAITING_VOTER_ANSWER;
        s_questionArray[questionId].voteUntil = block.timestamp + i_voteTimeout;
        delete s_requestIdToQuestionId[requestId];
    }

    function answerQuestion(uint256 questionId, bool answer) public {
        if (questionId >= s_questionArray.length)
            revert SerialJustice__InvalidQuestionId();

        if (
            s_questionArray[questionId].state !=
            QuestionState.AWAITING_VOTER_ANSWER
        ) revert SerialJustice__NewVoteNotAllowed();

        if (s_questionArray[questionId].nextVoter != msg.sender)
            revert SerialJustice__NotAllowedToVoteOnThisQuestion();

        if (answer == true) {
            s_questionArray[questionId].nbVotesYes += 1;
        } else {
            s_questionArray[questionId].nbVotesNo += 1;
        }

        s_questionArray[questionId].nextVoter = address(0);
        s_questionArray[questionId].voteUntil = 0;

        if (
            s_questionArray[questionId].nbVotesYes >= i_nbValidations ||
            s_questionArray[questionId].nbVotesNo >= i_nbValidations
        ) {
            s_questionArray[questionId].state = QuestionState.FINAL_ANSWER;
        } else {
            s_questionArray[questionId].state = QuestionState.IDLE;
        }
    }

    function checkUpkeep(
        bytes memory
    ) public view returns (bool, bytes memory) {
        for (
            uint256 questionId = 0;
            questionId < s_questionArray.length;
            questionId++
        ) {
            if (isVoteTimeout(questionId)) {
                return (true, "0x");
            }
        }
        return (false, "0x");
    }

    function performUpkeep(bytes calldata) external override {
        (bool upkeepNeeded, ) = checkUpkeep("0x");
        if (!upkeepNeeded) {
            revert SerialJustice__UpkeepNotNeeded();
        }
        for (
            uint256 questionId = 0;
            questionId < s_questionArray.length;
            questionId++
        ) {
            if (isVoteTimeout(questionId)) {
                pickRandomVoter(questionId);
            }
        }
    }

    function isVoteTimeout(uint256 questionId) public view returns (bool) {
        return (s_questionArray[questionId].state ==
            QuestionState.AWAITING_VOTER_ANSWER &&
            s_questionArray[questionId].voteUntil < block.timestamp);
    }

    function getQuestionCount() public view returns (uint256) {
        return s_questionArray.length;
    }

    function getQuestionData(
        uint256 questionId
    )
        public
        view
        returns (
            QuestionState,
            string memory,
            address,
            address,
            uint256,
            uint256,
            uint256
        )
    {
        if (questionId >= s_questionArray.length) {
            revert SerialJustice__InvalidQuestionId();
        }

        return (
            s_questionArray[questionId].state,
            s_questionArray[questionId].text,
            s_questionArray[questionId].submitter,
            s_questionArray[questionId].nextVoter,
            s_questionArray[questionId].nbVotesYes,
            s_questionArray[questionId].nbVotesNo,
            s_questionArray[questionId].voteUntil
        );
    }

    function getVoteTimeout() public view returns (uint256) {
        return i_voteTimeout;
    }

    function getDaoAddress() public view returns (address) {
        return address(i_mainDAO);
    }

    function getJusticeTokenAddress() public view returns (address) {
        return address(i_justiceToken);
    }
}
