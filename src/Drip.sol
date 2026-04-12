// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Drip {
    using SafeERC20 for IERC20;

    address public owner;
    address public feeRecipient;
    uint256 public feeBps = 100;

    struct Plan {
        address token;
        uint256 amount;
        uint256 interval;
        address merchant;
        bool active;
    }

    struct Subscription {
        uint256 planId;
        address subscriber;
        uint256 nextPayment;
        bool active;
    }

    uint256 public planCount;
    uint256 public subscriptionCount;

    mapping(uint256 => Plan) public plans;
    mapping(uint256 => Subscription) public subscriptions;

    event PlanCreated(uint256 indexed planId, address indexed merchant, address token, uint256 amount, uint256 interval);
    event Subscribed(uint256 indexed subscriptionId, uint256 indexed planId, address indexed subscriber);
    event PaymentExecuted(uint256 indexed subscriptionId, uint256 amount, uint256 fee);
    event SubscriptionCancelled(uint256 indexed subscriptionId);
    event PlanCancelled(uint256 indexed planId);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event FeeBpsUpdated(uint256 oldBps, uint256 newBps);

    modifier onlyOwner() {
        _onlyOwner();
        _;
    }

    function _onlyOwner() internal view {
        require(msg.sender == owner, "Not owner");
    }

    constructor(address _feeRecipient) {
        require(_feeRecipient != address(0), "Invalid fee recipient");
        owner = msg.sender;
        feeRecipient = _feeRecipient;
    }

    function createPlan(address token, uint256 amount, uint256 interval) external returns (uint256) {
        require(token != address(0), "Invalid token");
        require(amount > 0, "Amount must be greater than 0");
        require(interval > 0, "Interval must be greater than 0");
        uint256 planId = planCount++;
        plans[planId] = Plan({
            token: token,
            amount: amount,
            interval: interval,
            merchant: msg.sender,
            active: true
        });
        emit PlanCreated(planId, msg.sender, token, amount, interval);
        return planId;
    }

    function subscribe(uint256 planId) external returns (uint256) {
        Plan memory plan = plans[planId];
        require(plan.active, "Plan not active");
        uint256 fee = (plan.amount * feeBps) / 10000;
        uint256 merchantAmount = plan.amount - fee;
        uint256 subId = subscriptionCount++;
        subscriptions[subId] = Subscription({
            planId: planId,
            subscriber: msg.sender,
            nextPayment: block.timestamp + plan.interval,
            active: true
        });
        IERC20(plan.token).safeTransferFrom(msg.sender, plan.merchant, merchantAmount);
        IERC20(plan.token).safeTransferFrom(msg.sender, feeRecipient, fee);
        emit Subscribed(subId, planId, msg.sender);
        emit PaymentExecuted(subId, plan.amount, fee);
        return subId;
    }

    function executePayment(uint256 subscriptionId) external {
        Subscription storage sub = subscriptions[subscriptionId];
        require(sub.active, "Subscription not active");
        require(block.timestamp >= sub.nextPayment, "Payment not due");
        Plan memory plan = plans[sub.planId];
        if (!plan.active) {
            sub.active = false;
            emit SubscriptionCancelled(subscriptionId);
            return;
        }
        uint256 fee = (plan.amount * feeBps) / 10000;
        uint256 merchantAmount = plan.amount - fee;
        uint256 timePassed = block.timestamp - sub.nextPayment;
        uint256 cyclesToAdvance = (timePassed / plan.interval) + 1;
        sub.nextPayment += cyclesToAdvance * plan.interval;
        IERC20(plan.token).safeTransferFrom(sub.subscriber, plan.merchant, merchantAmount);
        IERC20(plan.token).safeTransferFrom(sub.subscriber, feeRecipient, fee);
        emit PaymentExecuted(subscriptionId, plan.amount, fee);
    }

    function cancelSubscription(uint256 subscriptionId) external {
        Subscription storage sub = subscriptions[subscriptionId];
        require(sub.subscriber == msg.sender, "Not subscriber");
        sub.active = false;
        emit SubscriptionCancelled(subscriptionId);
    }

    function cancelPlan(uint256 planId) external {
        Plan storage plan = plans[planId];
        require(plan.merchant == msg.sender, "Not merchant");
        plan.active = false;
        emit PlanCancelled(planId);
    }

    function cancelSubscriptionAsMerchant(uint256 subscriptionId) external {
        Subscription storage sub = subscriptions[subscriptionId];
        require(sub.subscriber != address(0), "Invalid subscription");
        Plan memory plan = plans[sub.planId];
        require(plan.merchant == msg.sender, "Not merchant");
        sub.active = false;
        emit SubscriptionCancelled(subscriptionId);
    }

    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        require(_feeRecipient != address(0), "Invalid fee recipient");
        emit FeeRecipientUpdated(feeRecipient, _feeRecipient);
        feeRecipient = _feeRecipient;
    }

    function setFeeBps(uint256 _feeBps) external onlyOwner {
        require(_feeBps <= 500, "Fee too high");
        emit FeeBpsUpdated(feeBps, _feeBps);
        feeBps = _feeBps;
    }
}
