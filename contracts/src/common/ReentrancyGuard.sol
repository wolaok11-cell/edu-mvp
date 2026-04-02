// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

abstract contract ReentrancyGuard {
    uint256 private _reentrancyState = 1;

    modifier nonReentrant() {
        require(_reentrancyState == 1, "REENTRANCY_GUARD:REENTRANT");
        _reentrancyState = 2;
        _;
        _reentrancyState = 1;
    }
}

