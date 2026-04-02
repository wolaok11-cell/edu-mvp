// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "./common/Ownable.sol";
import {Pausable} from "./common/Pausable.sol";

contract TutorRegistry is Ownable, Pausable {
    enum VerificationStatus {
        Pending,
        Approved,
        Rejected,
        Suspended
    }

    struct TutorRecord {
        bool exists;
        bool active;
        bool isListed;
        bytes32 profileHash;
        bytes32 verificationHash;
        VerificationStatus verificationStatus;
        uint64 createdAt;
        uint64 updatedAt;
    }

    mapping(address => TutorRecord) public tutors;
    mapping(address => bool) public operators;

    event TutorRegistered(address indexed tutor, bytes32 profileHash);
    event TutorVerificationUpdated(
        address indexed tutor,
        uint8 status,
        bytes32 verificationHash,
        address indexed operator
    );
    event TutorListingUpdated(address indexed tutor, bool isListed);
    event TutorActivationUpdated(address indexed tutor, bool active);
    event OperatorUpdated(address indexed operator, bool allowed);

    modifier onlyOperator() {
        require(msg.sender == owner || operators[msg.sender], "TUTOR_REGISTRY:NOT_OPERATOR");
        _;
    }

    constructor(address owner_) Ownable(owner_) {}

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setOperator(address operator, bool allowed) external onlyOwner {
        require(operator != address(0), "TUTOR_REGISTRY:ZERO_OPERATOR");
        operators[operator] = allowed;
        emit OperatorUpdated(operator, allowed);
    }

    function registerTutor(bytes32 profileHash) external whenNotPaused {
        TutorRecord storage record = tutors[msg.sender];
        require(!record.exists, "TUTOR_REGISTRY:ALREADY_REGISTERED");

        tutors[msg.sender] = TutorRecord({
            exists: true,
            active: true,
            isListed: false,
            profileHash: profileHash,
            verificationHash: bytes32(0),
            verificationStatus: VerificationStatus.Pending,
            createdAt: uint64(block.timestamp),
            updatedAt: uint64(block.timestamp)
        });

        emit TutorRegistered(msg.sender, profileHash);
    }

    function updateProfileHash(bytes32 profileHash) external whenNotPaused {
        TutorRecord storage record = tutors[msg.sender];
        require(record.exists, "TUTOR_REGISTRY:TUTOR_NOT_FOUND");
        record.profileHash = profileHash;
        record.updatedAt = uint64(block.timestamp);
    }

    function setVerification(
        address tutor,
        uint8 status,
        bytes32 verificationHash
    ) external onlyOperator whenNotPaused {
        TutorRecord storage record = tutors[tutor];
        require(record.exists, "TUTOR_REGISTRY:TUTOR_NOT_FOUND");
        require(status <= uint8(VerificationStatus.Suspended), "TUTOR_REGISTRY:INVALID_STATUS");

        record.verificationStatus = VerificationStatus(status);
        record.verificationHash = verificationHash;
        record.updatedAt = uint64(block.timestamp);

        emit TutorVerificationUpdated(tutor, status, verificationHash, msg.sender);
    }

    function setListing(bool isListed) external whenNotPaused {
        TutorRecord storage record = tutors[msg.sender];
        require(record.exists, "TUTOR_REGISTRY:TUTOR_NOT_FOUND");
        require(record.verificationStatus == VerificationStatus.Approved, "TUTOR_REGISTRY:NOT_APPROVED");

        record.isListed = isListed;
        record.updatedAt = uint64(block.timestamp);
        emit TutorListingUpdated(msg.sender, isListed);
    }

    function setActivation(address tutor, bool active) external onlyOperator whenNotPaused {
        TutorRecord storage record = tutors[tutor];
        require(record.exists, "TUTOR_REGISTRY:TUTOR_NOT_FOUND");

        record.active = active;
        record.updatedAt = uint64(block.timestamp);
        emit TutorActivationUpdated(tutor, active);
    }

    function isApprovedTutor(address tutor) external view returns (bool) {
        TutorRecord memory record = tutors[tutor];
        return
            record.exists &&
            record.active &&
            record.isListed &&
            record.verificationStatus == VerificationStatus.Approved;
    }
}

