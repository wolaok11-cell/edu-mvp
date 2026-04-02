// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ITutorRegistry {
    function isApprovedTutor(address tutor) external view returns (bool);
}

