"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.DEPLOYMENTS = exports.INTERVALS = exports.Drip = void 0;
const ethers_1 = require("ethers");
const DRIP_ABI = [
    "function createPlan(address token, uint256 amount, uint256 interval) external returns (uint256)",
    "function subscribe(uint256 planId) external returns (uint256)",
    "function cancelSubscription(uint256 subscriptionId) external",
    "function cancelPlan(uint256 planId) external",
    "function cancelSubscriptionAsMerchant(uint256 subscriptionId) external",
    "function executePayment(uint256 subscriptionId) external",
    "function plans(uint256) external view returns (address token, uint256 amount, uint256 interval, address merchant, bool active)",
    "function subscriptions(uint256) external view returns (uint256 planId, address subscriber, uint256 nextPayment, bool active)",
    "function subscriptionCount() external view returns (uint256)",
    "function planCount() external view returns (uint256)",
    "function feeBps() external view returns (uint256)",
    "function feeRecipient() external view returns (address)",
    "event PlanCreated(uint256 indexed planId, address indexed merchant, address token, uint256 amount, uint256 interval)",
    "event Subscribed(uint256 indexed subscriptionId, uint256 indexed planId, address indexed subscriber)",
    "event PaymentExecuted(uint256 indexed subscriptionId, uint256 amount, uint256 fee)",
    "event SubscriptionCancelled(uint256 indexed subscriptionId)",
    "event PlanCancelled(uint256 indexed planId)"
];
const ERC20_ABI = [
    "function approve(address spender, uint256 amount) external returns (bool)",
    "function allowance(address owner, address spender) external view returns (uint256)",
    "function balanceOf(address account) external view returns (uint256)",
    "function decimals() external view returns (uint8)",
    "function symbol() external view returns (string)"
];
const MAX_UINT256 = BigInt("0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff");
class Drip {
    constructor(config) {
        this.contractAddress = config.contractAddress;
        this.signer = config.signer;
        this.contract = new ethers_1.ethers.Contract(config.contractAddress, DRIP_ABI, config.signer);
    }
    // ─── Plans ───────────────────────────────────────────────
    async createPlan(tokenAddress, amount, intervalSeconds) {
        const tx = await this.contract.createPlan(tokenAddress, amount, intervalSeconds);
        const receipt = await tx.wait();
        const event = receipt.logs
            .map((log) => {
            try {
                return this.contract.interface.parseLog(log);
            }
            catch {
                return null;
            }
        })
            .find((e) => e?.name === "PlanCreated");
        if (!event || !event.args) {
            throw new Error("PlanCreated event not found in transaction receipt — refetch planCount to get your planId");
        }
        return { planId: event.args.planId, tx };
    }
    async getPlan(planId) {
        const result = await this.contract.plans(planId);
        return {
            planId,
            token: result.token,
            amount: result.amount,
            interval: result.interval,
            merchant: result.merchant,
            active: result.active,
        };
    }
    async cancelPlan(planId) {
        return await this.contract.cancelPlan(planId);
    }
    // ─── Subscriptions ───────────────────────────────────────
    async subscribe(planId, options = {}) {
        const { autoApprove = true, approvalAmount } = options;
        if (autoApprove) {
            const plan = await this.getPlan(planId);
            const amount = approvalAmount ?? MAX_UINT256;
            const approveTx = await this.approveToken(plan.token, amount);
            if (approveTx) {
                await approveTx.wait();
            }
        }
        const tx = await this.contract.subscribe(planId);
        const receipt = await tx.wait();
        const event = receipt.logs
            .map((log) => {
            try {
                return this.contract.interface.parseLog(log);
            }
            catch {
                return null;
            }
        })
            .find((e) => e?.name === "Subscribed");
        if (!event || !event.args) {
            throw new Error("Subscribed event not found in transaction receipt — refetch subscriptionCount to get your subscriptionId");
        }
        return { subscriptionId: event.args.subscriptionId, tx };
    }
    async getSubscription(subscriptionId) {
        const result = await this.contract.subscriptions(subscriptionId);
        return {
            subscriptionId,
            planId: result.planId,
            subscriber: result.subscriber,
            nextPayment: result.nextPayment,
            active: result.active,
        };
    }
    async cancelSubscription(subscriptionId) {
        return await this.contract.cancelSubscription(subscriptionId);
    }
    async cancelSubscriptionAsMerchant(subscriptionId) {
        return await this.contract.cancelSubscriptionAsMerchant(subscriptionId);
    }
    async executePayment(subscriptionId) {
        return await this.contract.executePayment(subscriptionId);
    }
    // ─── Token helpers ───────────────────────────────────────
    async approveToken(tokenAddress, amount) {
        const token = new ethers_1.ethers.Contract(tokenAddress, ERC20_ABI, this.signer);
        const signerAddress = await this.signer.getAddress();
        const allowance = await token.allowance(signerAddress, this.contractAddress);
        if (allowance >= amount) {
            return null;
        }
        return await token.approve(this.contractAddress, amount);
    }
    async getTokenInfo(tokenAddress) {
        const token = new ethers_1.ethers.Contract(tokenAddress, ERC20_ABI, this.signer);
        const signerAddress = await this.signer.getAddress();
        const [symbol, decimals, balance] = await Promise.all([
            token.symbol(),
            token.decimals(),
            token.balanceOf(signerAddress),
        ]);
        return { symbol, decimals, balance };
    }
    // ─── Protocol stats ──────────────────────────────────────
    async getStats() {
        const [planCount, subscriptionCount, feeBps, feeRecipient] = await Promise.all([
            this.contract.planCount(),
            this.contract.subscriptionCount(),
            this.contract.feeBps(),
            this.contract.feeRecipient(),
        ]);
        return { planCount, subscriptionCount, feeBps, feeRecipient };
    }
}
exports.Drip = Drip;
// ─── Convenience constants ───────────────────────────────
exports.INTERVALS = {
    DAILY: BigInt(86400),
    WEEKLY: BigInt(604800),
    MONTHLY: BigInt(2592000),
    YEARLY: BigInt(31536000),
};
exports.DEPLOYMENTS = {
    "base-sepolia": "0xba23e6f93982de89106E9E69065573b0405825A6",
    "base": "0xba23e6f93982de89106E9E69065573b0405825A6",
};
exports.default = Drip;
//# sourceMappingURL=index.js.map