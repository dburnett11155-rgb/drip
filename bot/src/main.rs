use alloy::{
    network::EthereumWallet,
    primitives::{Address, U256},
    providers::{Provider, ProviderBuilder},
    signers::local::PrivateKeySigner,
    sol,
};
use dotenv::dotenv;
use eyre::Result;
use rusqlite::{params, Connection};
use std::{
    env,
    str::FromStr,
    sync::{Arc, Mutex},
    time::{Duration, SystemTime, UNIX_EPOCH},
};
use tokio::sync::Semaphore;
use tracing::{error, info, warn};

sol!(
    #[allow(missing_docs)]
    #[sol(rpc)]
    DripContract,
    "./Drip.json"
);

const MAX_CONCURRENT_TXS: usize = 10;

fn now_secs() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs()
}

fn init_db(conn: &Connection) -> Result<()> {
    conn.execute_batch(
        "CREATE TABLE IF NOT EXISTS backoff (
            sub_id INTEGER PRIMARY KEY,
            retry_after INTEGER NOT NULL
        );"
    )?;
    Ok(())
}

fn get_backoff(conn: &Connection, sub_id: u64) -> Option<u64> {
    conn.query_row(
        "SELECT retry_after FROM backoff WHERE sub_id = ?1",
        params![sub_id],
        |row| row.get(0),
    ).ok()
}

fn set_backoff(conn: &Connection, sub_id: u64, retry_after: u64) {
    conn.execute(
        "INSERT OR REPLACE INTO backoff (sub_id, retry_after) VALUES (?1, ?2)",
        params![sub_id, retry_after],
    ).ok();
}

fn clear_backoff(conn: &Connection, sub_id: u64) {
    conn.execute(
        "DELETE FROM backoff WHERE sub_id = ?1",
        params![sub_id],
    ).ok();
}

#[tokio::main]
async fn main() -> Result<()> {
    dotenv().ok();
    tracing_subscriber::fmt::init();

    let rpc_url = env::var("BASE_SEPOLIA_RPC_URL")
        .expect("BASE_SEPOLIA_RPC_URL not set");
    let private_key = env::var("PRIVATE_KEY")
        .expect("PRIVATE_KEY not set");
    let contract_address = env::var("CONTRACT_ADDRESS")
        .expect("CONTRACT_ADDRESS not set");

    let signer = PrivateKeySigner::from_str(&private_key)?;
    let signer_address = signer.address();
    let wallet = EthereumWallet::from(signer);

    let provider = Arc::new(
        ProviderBuilder::new()
            .wallet(wallet)
            .on_http(rpc_url.parse()?)
    );

    let contract_addr = Address::from_str(&contract_address)?;
    let contract = DripContract::new(contract_addr, provider.clone());

    let db = Arc::new(Mutex::new(Connection::open("drip-bot.db")?));
    init_db(&db.lock().unwrap())?;

    let semaphore = Arc::new(Semaphore::new(MAX_CONCURRENT_TXS));

    let initial_nonce: u64 = provider
        .get_transaction_count(signer_address)
        .await?;

    let nonce = Arc::new(tokio::sync::Mutex::new(initial_nonce));

    info!("Drip bot started");
    info!("Signer: {}", signer_address);
    info!("Contract: {}", contract_address);

    loop {
        info!("Scanning for due payments...");

        let count: u64 = contract
            .subscriptionCount()
            .call()
            .await?
            ._0
            .try_into()
            .unwrap_or(0);

        info!("Total subscriptions: {}", count);

        let mut due_subs: Vec<u64> = Vec::new();

        for i in 0..count {
            let sub = match contract.subscriptions(U256::from(i)).call().await {
                Ok(s) => s,
                Err(e) => {
                    error!("Failed to fetch sub {}: {}", i, e);
                    continue;
                }
            };

            if !sub.active {
                continue;
            }

            let db_lock = db.lock().unwrap();
            if let Some(retry_after) = get_backoff(&db_lock, i) {
                if now_secs() < retry_after {
                    warn!("Sub {} in backoff", i);
                    continue;
                } else {
                    clear_backoff(&db_lock, i);
                }
            }
            drop(db_lock);

            let next_payment: u64 = sub.nextPayment.try_into().unwrap_or(u64::MAX);
            if now_secs() >= next_payment + 15 {
                due_subs.push(i);
            }
        }

        info!("{} payments due", due_subs.len());

        for sub_id in due_subs {
            let permit = semaphore.clone().acquire_owned().await?;
            let contract_clone = DripContract::new(contract_addr, provider.clone());
            let db_clone = db.clone();
            let nonce_clone = nonce.clone();
            let provider_clone = provider.clone();

            tokio::spawn(async move {
                let _permit = permit;

                let current_nonce: u64 = {
                    let mut n = nonce_clone.lock().await;
                    let val = *n;
                    *n += 1;
                    val
                };

                info!("Executing payment sub {} nonce {}", sub_id, current_nonce);

                match contract_clone
                    .executePayment(U256::from(sub_id))
                    .nonce(current_nonce)
                    .send()
                    .await
                {
                    Ok(pending_tx) => {
                        match pending_tx.get_receipt().await {
                            Ok(receipt) => {
                                if receipt.inner.status() {
                                    info!(
                                        "Payment successful sub {} tx: {}",
                                        sub_id,
                                        receipt.transaction_hash
                                    );
                                } else {
                                    error!(
                                        "Payment REVERTED sub {} tx: {}",
                                        sub_id,
                                        receipt.transaction_hash
                                    );
                                    let db_lock = db_clone.lock().unwrap();
                                    set_backoff(&db_lock, sub_id, now_secs() + 86400);
                                }
                            }
                            Err(e) => {
                                error!("Receipt error sub {}: {}", sub_id, e);
                                let db_lock = db_clone.lock().unwrap();
                                set_backoff(&db_lock, sub_id, now_secs() + 3600);
                            }
                        }
                    }
                    Err(e) => {
                        error!("Send error sub {}: {}", sub_id, e);
                        let mut n = nonce_clone.lock().await;
                        if let Ok(network_nonce) = provider_clone
                            .get_transaction_count(signer_address)
                            .await
                        {
                            *n = network_nonce;
                        }
                        drop(n);
                        let db_lock = db_clone.lock().unwrap();
                        set_backoff(&db_lock, sub_id, now_secs() + 3600);
                    }
                }
            });
        }

        info!("Scan complete. Sleeping 60 seconds...");
        tokio::time::sleep(Duration::from_secs(60)).await;
    }
}
