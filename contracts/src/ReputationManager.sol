// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "./common/Ownable.sol";
import {Pausable} from "./common/Pausable.sol";

contract ReputationManager is Ownable, Pausable {
    struct TutorStats {
        bool verified;
        uint64 completedOrders;
        uint64 settledOrders;
        uint64 disputeOrders;
        uint64 disputeWins;
        uint64 updatedAt;
    }

    mapping(address => TutorStats) public tutorStats;
    mapping(address => bool) public writers;

    event WriterUpdated(address indexed writer, bool allowed);
    event CompletionRecorded(uint256 indexed orderId, address indexed tutor, address indexed student);
    event VerificationRecorded(address indexed tutor, bytes32 credentialHash, address indexed operator);
    event DisputeRecordUpdated(uint256 indexed orderId, address indexed tutor, uint8 resultType);

    modifier onlyWriter() {
        require(msg.sender == owner || writers[msg.sender], "REPUTATION:NOT_WRITER");
        _;
    }

    constructor(address owner_) Ownable(owner_) {}

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setWriter(address writer, bool allowed) external onlyOwner {
        require(writer != address(0), "REPUTATION:ZERO_WRITER");
        writers[writer] = allowed;
        emit WriterUpdated(writer, allowed);
    }

    function recordVerification(address tutor, bytes32 credentialHash, address operator) external onlyWriter whenNotPaused {
        TutorStats storage stats = tutorStats[tutor];
        stats.verified = true;
        stats.updatedAt = uint64(block.timestamp);
        emit VerificationRecorded(tutor, credentialHash, operator);
    }

    function recordCompletion(uint256 orderId, address tutor, address student) external onlyWriter whenNotPaused {
        TutorStats storage stats = tutorStats[tutor];
        stats.completedOrders += 1;
        stats.settledOrders += 1;
        stats.updatedAt = uint64(block.timestamp);
        emit CompletionRecorded(orderId, tutor, student);
    }

    function recordDispute(uint256 orderId, address tutor, uint8 resultType) external onlyWriter whenNotPaused {
        TutorStats storage stats = tutorStats[tutor];
        stats.disputeOrders += 1;

        if (resultType == 0) {
            stats.disputeWins += 1;
        }

        stats.updatedAt = uint64(block.timestamp);
        emit DisputeRecordUpdated(orderId, tutor, resultType);
    }
}
