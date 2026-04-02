// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IReputationManager {
    function recordVerification(address tutor, bytes32 credentialHash, address operator) external;
    function recordCompletion(uint256 orderId, address tutor, address student) external;
    function recordDispute(uint256 orderId, address tutor, uint8 resultType) external;
}

