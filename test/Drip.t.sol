// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {Drip} from "../src/Drip.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Mock USDC", "mUSDC") {
        _mint(msg.sender, 1_000_000 * 10 ** 18);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract DripTest is Test {
    Drip public drip;
    MockToken public token;

    address public owner = address(1);
    address public feeRecipient = address(2);
    address public merchant = address(3);
    address public subscriber = address(4);

    uint256 public constant AMOUNT = 100 * 10 ** 18;
    uint256 public constant INTERVAL = 30 days;

    function setUp() public {
        vm.startPrank(owner);
        drip = new Drip(feeRecipient);
        token = new MockToken();
        token.mint(subscriber, 10_000 * 10 ** 18);
        vm.stopPrank();

        vm.prank(subscriber);
        token.approve(address(drip), type(uint256).max);
    }

    function test_CreatePlan() public {
        vm.prank(merchant);
        uint256 planId = drip.createPlan(address(token), AMOUNT, INTERVAL);
        (address t, uint256 a, uint256 i, address m, bool active) = drip.plans(planId);
        assertEq(t, address(token));
        assertEq(a, AMOUNT);
        assertEq(i, INTERVAL);
        assertEq(m, merchant);
        assertTrue(active);
    }

    function test_Subscribe_ChargesFirstPayment() public {
        vm.prank(merchant);
        uint256 planId = drip.createPlan(address(token), AMOUNT, INTERVAL);

        uint256 balanceBefore = token.balanceOf(subscriber);

        vm.prank(subscriber);
        drip.subscribe(planId);

        uint256 balanceAfter = token.balanceOf(subscriber);
        assertEq(balanceBefore - balanceAfter, AMOUNT);
    }

    function test_Subscribe_FeeGoesToFeeRecipient() public {
        vm.prank(merchant);
        uint256 planId = drip.createPlan(address(token), AMOUNT, INTERVAL);

        vm.prank(subscriber);
        drip.subscribe(planId);

        uint256 expectedFee = (AMOUNT * 100) / 10000;
        assertEq(token.balanceOf(feeRecipient), expectedFee);
    }

    function test_ExecutePayment_AfterInterval() public {
        vm.prank(merchant);
        uint256 planId = drip.createPlan(address(token), AMOUNT, INTERVAL);

        vm.prank(subscriber);
        uint256 subId = drip.subscribe(planId);

        vm.warp(block.timestamp + INTERVAL + 1);

        uint256 balanceBefore = token.balanceOf(subscriber);
        drip.executePayment(subId);
        uint256 balanceAfter = token.balanceOf(subscriber);

        assertEq(balanceBefore - balanceAfter, AMOUNT);
    }

    function test_ExecutePayment_FailsBeforeInterval() public {
        vm.prank(merchant);
        uint256 planId = drip.createPlan(address(token), AMOUNT, INTERVAL);

        vm.prank(subscriber);
        uint256 subId = drip.subscribe(planId);

        vm.expectRevert("Payment not due");
        drip.executePayment(subId);
    }

    function test_CancelSubscription() public {
        vm.prank(merchant);
        uint256 planId = drip.createPlan(address(token), AMOUNT, INTERVAL);

        vm.prank(subscriber);
        uint256 subId = drip.subscribe(planId);

        vm.prank(subscriber);
        drip.cancelSubscription(subId);

        (,,, bool active) = getSubscription(subId);
        assertFalse(active);
    }

    function test_CancelPlan() public {
        vm.prank(merchant);
        uint256 planId = drip.createPlan(address(token), AMOUNT, INTERVAL);

        vm.prank(merchant);
        drip.cancelPlan(planId);

        (,,,, bool active) = drip.plans(planId);
        assertFalse(active);
    }

    function test_ExecutePayment_AutoCancelsIfPlanDead() public {
        vm.prank(merchant);
        uint256 planId = drip.createPlan(address(token), AMOUNT, INTERVAL);

        vm.prank(subscriber);
        uint256 subId = drip.subscribe(planId);

        vm.prank(merchant);
        drip.cancelPlan(planId);

        vm.warp(block.timestamp + INTERVAL + 1);
        drip.executePayment(subId);

        (,,, bool active) = getSubscription(subId);
        assertFalse(active);
    }

    function test_SetFeeBps() public {
        vm.prank(owner);
        drip.setFeeBps(200);
        assertEq(drip.feeBps(), 200);
    }

    function test_SetFeeBps_FailsAboveMax() public {
        vm.prank(owner);
        vm.expectRevert("Fee too high");
        drip.setFeeBps(501);
    }

    function test_SetFeeRecipient() public {
        address newRecipient = address(5);
        vm.prank(owner);
        drip.setFeeRecipient(newRecipient);
        assertEq(drip.feeRecipient(), newRecipient);
    }

    function getSubscription(uint256 subId) internal view returns (uint256, address, uint256, bool) {
        (uint256 planId, address sub, uint256 nextPayment, bool active) = drip.subscriptions(subId);
        return (planId, sub, nextPayment, active);
    }
}
