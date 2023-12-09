// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {MainDAO} from "./MainDAO.sol";
import {JusticeToken} from "./JusticeToken.sol";

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract SerialJustice is VRFConsumerBaseV2 {
    error SerialJustice__IsNotAMember();
    error SerialJustice__NotEnoughBalance();
    error SerialJustice__InvalidQuestionId();
    error SerialJustice__NewVoteRequestNotAllowed();
    error SerialJustice__NewVoteNotAllowed();
    error SerialJustice__NotAllowedToVoteOnThisQuestion();

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
    }

    // Chainlink VRF variables
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    uint64 private immutable i_subscriptionId;
    bytes32 private immutable i_gasLane;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    uint256 private immutable i_nbValidations;
    MainDAO private immutable i_mainDAO;
    JusticeToken private immutable i_justiceToken;
    Question[] private s_questionArray;
    mapping(uint256 => uint256) private s_requestIdToQuestionId;

    event RequestedNewVoter(uint256 requestId);

    constructor(
        address vrfCoordinatorV2,
        uint64 subscriptionId,
        bytes32 gasLane,
        uint32 callbackGasLimit,
        address daoAddress,
        uint256 updateInterval,
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
            updateInterval
        );
        i_nbValidations = nbValidations;
    }

    function submitQuestion(string memory text) public {
        if (i_mainDAO.isMember(msg.sender) == false) {
            revert SerialJustice__IsNotAMember();
        }

        if (
            i_justiceToken.balanceOf(msg.sender) < i_justiceToken.ANSWER_PRICE()
        ) {
            revert SerialJustice__NotEnoughBalance();
        }

        Question storage newQuestion = s_questionArray.push();
        newQuestion.state = QuestionState.IDLE;
        newQuestion.text = text;
        newQuestion.submitter = msg.sender;

        requestNewVoter(s_questionArray.length - 1);
    }

    function requestNewVoter(uint256 questionId) public {
        if (s_questionArray[questionId].state != QuestionState.IDLE) {
            revert SerialJustice__NewVoteRequestNotAllowed();
        }

        if (
            i_justiceToken.balanceOf(s_questionArray[questionId].submitter) <
            i_justiceToken.ANSWER_PRICE()
        ) {
            revert SerialJustice__NotEnoughBalance();
        }

        i_justiceToken.burnOne(s_questionArray[questionId].submitter);
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
        delete s_requestIdToQuestionId[requestId];
    }

    function answerQuestion(uint256 questionId, bool answer) public {
        if (questionId >= s_questionArray.length) {
            revert SerialJustice__InvalidQuestionId();
        }

        if (
            s_questionArray[questionId].state !=
            QuestionState.AWAITING_VOTER_ANSWER
        ) {
            revert SerialJustice__NewVoteNotAllowed();
        }

        if (s_questionArray[questionId].nextVoter != msg.sender) {
            revert SerialJustice__NotAllowedToVoteOnThisQuestion();
        }

        if (answer == true) {
            s_questionArray[questionId].nbVotesYes += 1;
        } else {
            s_questionArray[questionId].nbVotesNo += 1;
        }

        s_questionArray[questionId].nextVoter = address(0);

        if (
            s_questionArray[questionId].nbVotesYes >= i_nbValidations ||
            s_questionArray[questionId].nbVotesNo >= i_nbValidations
        ) {
            s_questionArray[questionId].state = QuestionState.FINAL_ANSWER;
        } else {
            s_questionArray[questionId].state = QuestionState.IDLE;
        }
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
            s_questionArray[questionId].nbVotesNo
        );
    }

    function getDaoAddress() public view returns (address) {
        return address(i_mainDAO);
    }

    function getJusticeTokenAddress() public view returns (address) {
        return address(i_justiceToken);
    }
}
