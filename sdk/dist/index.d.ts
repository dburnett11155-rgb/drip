import { ethers } from "ethers";
export interface Plan {
    planId: bigint;
    token: string;
    amount: bigint;
    interval: bigint;
    merchant: string;
    active: boolean;
}
export interface Subscription {
    subscriptionId: bigint;
    planId: bigint;
    subscriber: string;
    nextPayment: bigint;
    active: boolean;
}
export interface DripConfig {
    contractAddress: string;
    signer: ethers.Signer;
}
export interface SubscribeOptions {
    autoApprove?: boolean;
    approvalAmount?: bigint;
}
export declare class Drip {
    private contract;
    private signer;
    contractAddress: string;
    constructor(config: DripConfig);
    createPlan(tokenAddress: string, amount: bigint, intervalSeconds: bigint): Promise<{
        planId: bigint;
        tx: ethers.TransactionResponse;
    }>;
    getPlan(planId: bigint): Promise<Plan>;
    cancelPlan(planId: bigint): Promise<ethers.TransactionResponse>;
    subscribe(planId: bigint, options?: SubscribeOptions): Promise<{
        subscriptionId: bigint;
        tx: ethers.TransactionResponse;
    }>;
    getSubscription(subscriptionId: bigint): Promise<Subscription>;
    cancelSubscription(subscriptionId: bigint): Promise<ethers.TransactionResponse>;
    cancelSubscriptionAsMerchant(subscriptionId: bigint): Promise<ethers.TransactionResponse>;
    executePayment(subscriptionId: bigint): Promise<ethers.TransactionResponse>;
    approveToken(tokenAddress: string, amount: bigint): Promise<ethers.TransactionResponse | null>;
    getTokenInfo(tokenAddress: string): Promise<{
        symbol: string;
        decimals: number;
        balance: bigint;
    }>;
    getStats(): Promise<{
        planCount: bigint;
        subscriptionCount: bigint;
        feeBps: bigint;
        feeRecipient: string;
    }>;
}
export declare const INTERVALS: {
    readonly DAILY: bigint;
    readonly WEEKLY: bigint;
    readonly MONTHLY: bigint;
    readonly YEARLY: bigint;
};
export declare const DEPLOYMENTS: Record<string, string>;
export default Drip;
//# sourceMappingURL=index.d.ts.map