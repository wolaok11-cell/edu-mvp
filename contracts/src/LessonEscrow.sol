// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "./common/Ownable.sol";
import {Pausable} from "./common/Pausable.sol";
import {ReentrancyGuard} from "./common/ReentrancyGuard.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {ITutorRegistry} from "./interfaces/ITutorRegistry.sol";
import {IReputationManager} from "./interfaces/IReputationManager.sol";

contract LessonEscrow is Ownable, Pausable, ReentrancyGuard {
    enum OrderStatus {
        NONE,
        CREATED,
        FUNDED,
        TUTOR_MARKED_COMPLETE,
        DISPUTED,
        RELEASED,
        AUTO_RELEASED,
        PARTIAL_REFUNDED,
        REFUNDED,
        CANCELLED
    }

    struct Order {
        address student;
        address tutor;
        address token;
        uint128 amount;
        uint128 feeAmount;
        uint64 createdAt;
        uint64 fundedAt;
        uint64 confirmDeadline;
        bytes32 metadataHash;
        OrderStatus status;
    }

    mapping(uint256 => Order) public orders;
    mapping(address => bool) public allowedTokens;

    address public treasury;
    address public disputeResolver;
    ITutorRegistry public tutorRegistry;
    IReputationManager public reputationManager;
    uint64 public confirmWindow;

    event OrderCreated(
        uint256 indexed orderId,
        address indexed student,
        address indexed tutor,
        address token,
        uint256 amount,
        uint256 feeAmount,
        bytes32 metadataHash
    );
    event OrderFunded(uint256 indexed orderId, address indexed payer, uint256 amount, uint256 fundedAt);
    event TutorMarkedComplete(uint256 indexed orderId, address indexed tutor, uint256 confirmDeadline);
    event OrderReleased(
        uint256 indexed orderId,
        address indexed tutor,
        uint256 tutorAmount,
        uint256 feeAmount,
        bool autoReleased
    );
    event DisputeOpened(uint256 indexed orderId, address indexed openedBy, uint256 openedAt, bytes32 reasonHash);
    event DisputeResolved(
        uint256 indexed orderId,
        uint8 resolutionType,
        uint256 tutorAmount,
        uint256 refundAmount,
        address indexed resolver
    );
    event OrderCancelled(uint256 indexed orderId, address indexed operator, uint256 refundedAmount);
    event TreasuryUpdated(address indexed treasury);
    event DisputeResolverUpdated(address indexed resolver);
    event ConfirmWindowUpdated(uint64 confirmWindow);
    event AllowedTokenUpdated(address indexed token, bool allowed);

    modifier onlyDisputeResolver() {
        require(msg.sender == disputeResolver, "ESCROW:NOT_DISPUTE_RESOLVER");
        _;
    }

    constructor(
        address owner_,
        address treasury_,
        address tutorRegistry_,
        address reputationManager_,
        uint64 confirmWindow_
    ) Ownable(owner_) {
        require(treasury_ != address(0), "ESCROW:ZERO_TREASURY");
        require(confirmWindow_ > 0, "ESCROW:INVALID_WINDOW");
        treasury = treasury_;
        tutorRegistry = ITutorRegistry(tutorRegistry_);
        reputationManager = IReputationManager(reputationManager_);
        confirmWindow = confirmWindow_;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setTreasury(address treasury_) external onlyOwner {
        require(treasury_ != address(0), "ESCROW:ZERO_TREASURY");
        treasury = treasury_;
        emit TreasuryUpdated(treasury_);
    }

    function setDisputeResolver(address resolver_) external onlyOwner {
        require(resolver_ != address(0), "ESCROW:ZERO_RESOLVER");
        disputeResolver = resolver_;
        emit DisputeResolverUpdated(resolver_);
    }

    function setConfirmWindow(uint64 confirmWindow_) external onlyOwner {
        require(confirmWindow_ > 0, "ESCROW:INVALID_WINDOW");
        confirmWindow = confirmWindow_;
        emit ConfirmWindowUpdated(confirmWindow_);
    }

    function setAllowedToken(address token, bool allowed) external onlyOwner {
        require(token != address(0), "ESCROW:ZERO_TOKEN");
        allowedTokens[token] = allowed;
        emit AllowedTokenUpdated(token, allowed);
    }

    function createOrder(
        uint256 orderId,
        address tutor,
        address token,
        uint256 amount,
        uint256 feeAmount,
        bytes32 metadataHash
    ) external whenNotPaused {
        require(orders[orderId].status == OrderStatus.NONE, "ESCROW:ORDER_EXISTS");
        require(tutor != address(0), "ESCROW:ZERO_TUTOR");
        require(token != address(0), "ESCROW:ZERO_TOKEN");
        require(amount > 0, "ESCROW:ZERO_AMOUNT");
        require(feeAmount <= amount, "ESCROW:FEE_TOO_HIGH");
        require(allowedTokens[token], "ESCROW:TOKEN_NOT_ALLOWED");

        if (address(tutorRegistry) != address(0)) {
            require(tutorRegistry.isApprovedTutor(tutor), "ESCROW:TUTOR_NOT_APPROVED");
        }

        orders[orderId] = Order({
            student: msg.sender,
            tutor: tutor,
            token: token,
            amount: uint128(amount),
            feeAmount: uint128(feeAmount),
            createdAt: uint64(block.timestamp),
            fundedAt: 0,
            confirmDeadline: 0,
            metadataHash: metadataHash,
            status: OrderStatus.CREATED
        });

        emit OrderCreated(orderId, msg.sender, tutor, token, amount, feeAmount, metadataHash);
    }

    function fundOrder(uint256 orderId) external whenNotPaused nonReentrant {
        Order storage order = orders[orderId];
        require(order.status == OrderStatus.CREATED, "ESCROW:INVALID_STATUS");
        require(msg.sender == order.student, "ESCROW:NOT_STUDENT");

        _safeTransferFrom(order.token, msg.sender, address(this), order.amount);

        order.status = OrderStatus.FUNDED;
        order.fundedAt = uint64(block.timestamp);

        emit OrderFunded(orderId, msg.sender, order.amount, block.timestamp);
    }

    function markCompleteByTutor(uint256 orderId) external whenNotPaused {
        Order storage order = orders[orderId];
        require(order.status == OrderStatus.FUNDED, "ESCROW:INVALID_STATUS");
        require(msg.sender == order.tutor, "ESCROW:NOT_TUTOR");

        order.status = OrderStatus.TUTOR_MARKED_COMPLETE;
        order.confirmDeadline = uint64(block.timestamp + confirmWindow);

        emit TutorMarkedComplete(orderId, msg.sender, order.confirmDeadline);
    }

    function confirmCompleteByStudent(uint256 orderId) external whenNotPaused nonReentrant {
        Order storage order = orders[orderId];
        require(order.status == OrderStatus.TUTOR_MARKED_COMPLETE, "ESCROW:INVALID_STATUS");
        require(msg.sender == order.student, "ESCROW:NOT_STUDENT");

        _releaseFull(orderId, false);
    }

    function autoRelease(uint256 orderId) external whenNotPaused nonReentrant {
        Order storage order = orders[orderId];
        require(order.status == OrderStatus.TUTOR_MARKED_COMPLETE, "ESCROW:INVALID_STATUS");
        require(order.confirmDeadline > 0 && block.timestamp > order.confirmDeadline, "ESCROW:NOT_EXPIRED");

        _releaseFull(orderId, true);
    }

    function cancelBeforeFund(uint256 orderId) external whenNotPaused {
        Order storage order = orders[orderId];
        require(order.status == OrderStatus.CREATED, "ESCROW:INVALID_STATUS");
        require(msg.sender == order.student, "ESCROW:NOT_STUDENT");

        order.status = OrderStatus.CANCELLED;
        emit OrderCancelled(orderId, msg.sender, 0);
    }

    function openDispute(
        uint256 orderId,
        address openedBy,
        bytes32 reasonHash
    ) external onlyDisputeResolver whenNotPaused {
        Order storage order = orders[orderId];
        require(
            order.status == OrderStatus.FUNDED || order.status == OrderStatus.TUTOR_MARKED_COMPLETE,
            "ESCROW:DISPUTE_NOT_ALLOWED"
        );

        order.status = OrderStatus.DISPUTED;
        emit DisputeOpened(orderId, openedBy, block.timestamp, reasonHash);
    }

    function resolveDispute(
        uint256 orderId,
        uint8 resolutionType,
        uint256 refundAmount
    ) external onlyDisputeResolver whenNotPaused nonReentrant {
        Order storage order = orders[orderId];
        require(order.status == OrderStatus.DISPUTED, "ESCROW:INVALID_STATUS");

        uint256 tutorAmount;
        uint256 feeAmount;
        uint256 refundValue;

        if (resolutionType == 0) {
            tutorAmount = uint256(order.amount) - uint256(order.feeAmount);
            feeAmount = uint256(order.feeAmount);
            order.status = OrderStatus.RELEASED;

            _safeTransfer(order.token, order.tutor, tutorAmount);
            if (feeAmount > 0) {
                _safeTransfer(order.token, treasury, feeAmount);
            }

            if (address(reputationManager) != address(0)) {
                reputationManager.recordCompletion(orderId, order.tutor, order.student);
                reputationManager.recordDispute(orderId, order.tutor, resolutionType);
            }
        } else if (resolutionType == 1) {
            refundValue = uint256(order.amount);
            order.status = OrderStatus.REFUNDED;
            _safeTransfer(order.token, order.student, refundValue);

            if (address(reputationManager) != address(0)) {
                reputationManager.recordDispute(orderId, order.tutor, resolutionType);
            }
        } else if (resolutionType == 2) {
            require(refundAmount > 0 && refundAmount < uint256(order.amount), "ESCROW:BAD_REFUND_AMOUNT");

            refundValue = refundAmount;
            uint256 tutorGross = uint256(order.amount) - refundValue;
            feeAmount = (uint256(order.feeAmount) * tutorGross) / uint256(order.amount);
            tutorAmount = tutorGross - feeAmount;

            order.status = OrderStatus.PARTIAL_REFUNDED;

            _safeTransfer(order.token, order.student, refundValue);
            if (tutorAmount > 0) {
                _safeTransfer(order.token, order.tutor, tutorAmount);
            }
            if (feeAmount > 0) {
                _safeTransfer(order.token, treasury, feeAmount);
            }

            if (address(reputationManager) != address(0)) {
                reputationManager.recordDispute(orderId, order.tutor, resolutionType);
            }
        } else {
            revert("ESCROW:INVALID_RESOLUTION");
        }

        emit DisputeResolved(orderId, resolutionType, tutorAmount, refundValue, msg.sender);
    }

    function _releaseFull(uint256 orderId, bool autoReleased) internal {
        Order storage order = orders[orderId];
        uint256 tutorAmount = uint256(order.amount) - uint256(order.feeAmount);
        uint256 feeAmount = uint256(order.feeAmount);

        order.status = autoReleased ? OrderStatus.AUTO_RELEASED : OrderStatus.RELEASED;

        _safeTransfer(order.token, order.tutor, tutorAmount);
        if (feeAmount > 0) {
            _safeTransfer(order.token, treasury, feeAmount);
        }

        if (address(reputationManager) != address(0)) {
            reputationManager.recordCompletion(orderId, order.tutor, order.student);
        }

        emit OrderReleased(orderId, order.tutor, tutorAmount, feeAmount, autoReleased);
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        require(IERC20(token).transfer(to, amount), "ESCROW:TOKEN_TRANSFER_FAILED");
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        require(IERC20(token).transferFrom(from, to, amount), "ESCROW:TOKEN_TRANSFER_FROM_FAILED");
    }
}
