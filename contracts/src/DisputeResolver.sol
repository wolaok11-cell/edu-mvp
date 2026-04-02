// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "./common/Ownable.sol";
import {Pausable} from "./common/Pausable.sol";
import {ILessonEscrow} from "./interfaces/ILessonEscrow.sol";

contract DisputeResolver is Ownable, Pausable {
    enum DisputeStatus {
        NONE,
        OPEN,
        UNDER_REVIEW,
        NEED_MORE_EVIDENCE,
        RESOLVED,
        CLOSED
    }

    enum ResolutionType {
        RELEASE_TO_TUTOR,
        FULL_REFUND,
        PARTIAL_REFUND
    }

    struct DisputeCase {
        uint256 orderId;
        address openedBy;
        bytes32 reasonHash;
        bytes32 resolutionHash;
        DisputeStatus status;
        ResolutionType resolutionType;
        uint64 createdAt;
        uint64 updatedAt;
    }

    mapping(uint256 => DisputeCase) public disputes;
    mapping(address => bool) public operators;

    ILessonEscrow public escrow;

    event OperatorUpdated(address indexed operator, bool allowed);
    event DisputeOpened(uint256 indexed orderId, address indexed openedBy, bytes32 reasonHash);
    event EvidenceSubmitted(uint256 indexed orderId, address indexed submittedBy, bytes32 evidenceHash);
    event DisputeStatusUpdated(uint256 indexed orderId, uint8 status);
    event DisputeResolved(uint256 indexed orderId, uint8 resolutionType, bytes32 resolutionHash, address indexed operator);

    modifier onlyOperator() {
        require(msg.sender == owner || operators[msg.sender], "DISPUTE:NOT_OPERATOR");
        _;
    }

    constructor(address owner_, address escrow_) Ownable(owner_) {
        require(escrow_ != address(0), "DISPUTE:ZERO_ESCROW");
        escrow = ILessonEscrow(escrow_);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setOperator(address operator, bool allowed) external onlyOwner {
        require(operator != address(0), "DISPUTE:ZERO_OPERATOR");
        operators[operator] = allowed;
        emit OperatorUpdated(operator, allowed);
    }

    function setEscrow(address escrow_) external onlyOwner {
        require(escrow_ != address(0), "DISPUTE:ZERO_ESCROW");
        escrow = ILessonEscrow(escrow_);
    }

    function openDispute(uint256 orderId, bytes32 reasonHash) external whenNotPaused {
        DisputeCase storage disputeCase = disputes[orderId];
        require(disputeCase.status == DisputeStatus.NONE, "DISPUTE:ALREADY_EXISTS");

        disputes[orderId] = DisputeCase({
            orderId: orderId,
            openedBy: msg.sender,
            reasonHash: reasonHash,
            resolutionHash: bytes32(0),
            status: DisputeStatus.OPEN,
            resolutionType: ResolutionType.RELEASE_TO_TUTOR,
            createdAt: uint64(block.timestamp),
            updatedAt: uint64(block.timestamp)
        });

        escrow.openDispute(orderId, msg.sender, reasonHash);
        emit DisputeOpened(orderId, msg.sender, reasonHash);
    }

    function submitEvidence(uint256 orderId, bytes32 evidenceHash) external whenNotPaused {
        DisputeCase storage disputeCase = disputes[orderId];
        require(disputeCase.status != DisputeStatus.NONE, "DISPUTE:NOT_FOUND");
        require(disputeCase.status != DisputeStatus.CLOSED, "DISPUTE:CLOSED");

        emit EvidenceSubmitted(orderId, msg.sender, evidenceHash);
    }

    function startReview(uint256 orderId) external onlyOperator whenNotPaused {
        _setStatus(orderId, DisputeStatus.UNDER_REVIEW);
    }

    function requestMoreEvidence(uint256 orderId) external onlyOperator whenNotPaused {
        _setStatus(orderId, DisputeStatus.NEED_MORE_EVIDENCE);
    }

    function resolveDispute(
        uint256 orderId,
        uint8 resolutionType,
        uint256 refundAmount,
        bytes32 resolutionHash
    ) external onlyOperator whenNotPaused {
        require(resolutionType <= uint8(ResolutionType.PARTIAL_REFUND), "DISPUTE:BAD_RESOLUTION");

        DisputeCase storage disputeCase = disputes[orderId];
        require(disputeCase.status != DisputeStatus.NONE, "DISPUTE:NOT_FOUND");
        require(disputeCase.status != DisputeStatus.RESOLVED, "DISPUTE:ALREADY_RESOLVED");
        require(disputeCase.status != DisputeStatus.CLOSED, "DISPUTE:CLOSED");

        escrow.resolveDispute(orderId, resolutionType, refundAmount);

        disputeCase.status = DisputeStatus.RESOLVED;
        disputeCase.resolutionType = ResolutionType(resolutionType);
        disputeCase.resolutionHash = resolutionHash;
        disputeCase.updatedAt = uint64(block.timestamp);

        emit DisputeResolved(orderId, resolutionType, resolutionHash, msg.sender);
    }

    function closeDispute(uint256 orderId) external onlyOperator whenNotPaused {
        _setStatus(orderId, DisputeStatus.CLOSED);
    }

    function _setStatus(uint256 orderId, DisputeStatus status) internal {
        DisputeCase storage disputeCase = disputes[orderId];
        require(disputeCase.status != DisputeStatus.NONE, "DISPUTE:NOT_FOUND");
        disputeCase.status = status;
        disputeCase.updatedAt = uint64(block.timestamp);
        emit DisputeStatusUpdated(orderId, uint8(status));
    }
}
