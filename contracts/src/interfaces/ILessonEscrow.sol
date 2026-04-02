// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ILessonEscrow {
    function openDispute(uint256 orderId, address openedBy, bytes32 reasonHash) external;
    function resolveDispute(uint256 orderId, uint8 resolutionType, uint256 refundAmount) external;
}
