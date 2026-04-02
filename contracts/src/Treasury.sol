// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "./common/Ownable.sol";
import {IERC20} from "./interfaces/IERC20.sol";

contract Treasury is Ownable {
    event NativeWithdrawn(address indexed to, uint256 amount);
    event TokenWithdrawn(address indexed token, address indexed to, uint256 amount);

    constructor(address owner_) Ownable(owner_) {}

    receive() external payable {}

    function withdrawNative(address payable to, uint256 amount) external onlyOwner {
        require(to != address(0), "TREASURY:ZERO_TO");
        require(address(this).balance >= amount, "TREASURY:INSUFFICIENT_NATIVE");

        (bool success, ) = to.call{value: amount}("");
        require(success, "TREASURY:NATIVE_TRANSFER_FAILED");
        emit NativeWithdrawn(to, amount);
    }

    function withdrawToken(address token, address to, uint256 amount) external onlyOwner {
        require(token != address(0), "TREASURY:ZERO_TOKEN");
        require(to != address(0), "TREASURY:ZERO_TO");
        require(IERC20(token).transfer(to, amount), "TREASURY:TOKEN_TRANSFER_FAILED");
        emit TokenWithdrawn(token, to, amount);
    }
}

