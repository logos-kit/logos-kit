//! `logos-kit-drip`: the self-hostable faucet behind [`HttpFaucet`] (the
//! wallet's `lez_requestFunds` on zones without an official faucet).
//!
//! `POST /fund {"account", "requestKey"}` answers a `FundOutcome`. Payments go
//! through the engine's `KeyFaucet` (one drop in flight, balance-proven
//! outcomes). Around it, a durable [`ledger`] that survives restarts:
//! request-key outcomes (a repeated key gets the first answer), an in-flight
//! mark written before paying (a crash mid-payment is reconciled from the
//! target's balance, never paid twice), per-account waits and the global
//! hourly budget. Per-client-IP budgets are kept in memory. Rate-limited
//! replies carry `Retry-After`. `GET /` describes the faucet.
//!
//! Configuration (env):
//! - `LK_DRIP_KEY` (required): the treasury's private key, hex.
//! - `LK_DRIP_SEQUENCER` (default `http://127.0.0.1:3040`).
//! - `LK_DRIP_DATA` ledger directory (default `./drip-data`).
//! - `LK_DRIP_AMOUNT` lepta per drop (default 1 000 000 000 = 1 LGO).
//! - `LK_DRIP_EVERY_SECS` per-account wait (default 3600).
//! - `LK_DRIP_IP_PER_HOUR` drops per client IP per hour (default 5).
//! - `LK_DRIP_MAX_PER_HOUR` drops per hour in total (default 200).
//! - `LK_DRIP_LISTEN` (default `0.0.0.0:8080`).
//! - `LK_DRIP_TOKEN` (optional): a token definition the treasury holds in its
//!   own slot; every LGO drop that lands also sends `LK_DRIP_TOKEN_AMOUNT`
//!   base units of it (default 10 000 = 100 LKT at 2 decimals) to the
//!   account's token account, so a new wallet sees a token arrive by itself.
//! - `LK_DRIP_TRUST_PROXY=1`: take the client IP from `X-Real-Ip` (else the
//!   right-most `X-Forwarded-For` entry). Only behind a proxy that sets them
//!   from the real peer and that is the only way in: Traefik in its default
//!   (non-`insecure`) mode strips client-sent forwarded headers and sets both.
//!
//! [`HttpFaucet`]: wallet_engine::faucet::HttpFaucet

mod ledger;

use std::{
    collections::HashMap,
    net::{IpAddr, SocketAddr},
    path::PathBuf,
    sync::{Arc, Mutex},
    time::{Duration, Instant},
};

use anyhow::{Context as _, Result};
use axum::{
    Json, Router,
    extract::{ConnectInfo, State},
    http::{HeaderMap, HeaderValue, Method, StatusCode, header},
    routing::{get, post},
};
use ledger::{KeyEntry, Ledger, now_ms};
use serde::Deserialize;
use serde_json::{Value, json};
use tower_http::cors::{Any, CorsLayer};
use wallet_engine::{
    AccountId,
    faucet::{FaucetBackend as _, FundOutcome, KeyFaucet},
};

struct Drip {
    faucet: KeyFaucet,
    amount: u128,
    every: Duration,
    ip_per_hour: usize,
    max_per_hour: usize,
    trust_proxy: bool,
    /// The sample token sent with each LGO drop, and how much.
    token: Option<(AccountId, u128)>,
    ips: Mutex<HashMap<IpAddr, Vec<Instant>>>,
    /// Held only for bookkeeping, never across a payment.
    ledger: tokio::sync::Mutex<Ledger>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct FundRequest {
    account: String,
    request_key: String,
}

fn env_or<T: std::str::FromStr>(key: &str, default: T) -> Result<T> {
    match std::env::var(key) {
        Ok(v) => v
            .trim()
            .parse()
            .ok()
            .with_context(|| format!("{key} is not valid")),
        Err(_) => Ok(default),
    }
}

#[tokio::main]
async fn main() -> Result<()> {
    let key =
        std::env::var("LK_DRIP_KEY").context("LK_DRIP_KEY (treasury key, hex) is required")?;
    let sequencer: String = env_or("LK_DRIP_SEQUENCER", "http://127.0.0.1:3040".to_owned())?;
    let amount: u128 = env_or("LK_DRIP_AMOUNT", 1_000_000_000)?;
    let every = Duration::from_secs(env_or("LK_DRIP_EVERY_SECS", 3600)?);
    let listen: SocketAddr = env_or("LK_DRIP_LISTEN", "0.0.0.0:8080".parse()?)?;
    let data: PathBuf = env_or("LK_DRIP_DATA", PathBuf::from("drip-data"))?;
    let drip = Arc::new(Drip {
        faucet: KeyFaucet::new("Logos Kit drip", &sequencer, &key, amount, every)?,
        amount,
        every,
        ip_per_hour: env_or("LK_DRIP_IP_PER_HOUR", 5)?,
        max_per_hour: env_or("LK_DRIP_MAX_PER_HOUR", 200)?,
        trust_proxy: std::env::var("LK_DRIP_TRUST_PROXY").is_ok_and(|v| v == "1"),
        token: match std::env::var("LK_DRIP_TOKEN") {
            Ok(def) if !def.trim().is_empty() => Some((
                def.trim()
                    .parse()
                    .ok()
                    .context("LK_DRIP_TOKEN is not an account id")?,
                env_or("LK_DRIP_TOKEN_AMOUNT", 10_000)?,
            )),
            _ => None,
        },
        ips: Mutex::new(HashMap::new()),
        ledger: tokio::sync::Mutex::new(Ledger::open(&data)?),
    });
    drop(key);
    drip.reconcile().await?;
    println!(
        "logos-kit-drip on {listen}: treasury {}, sequencer {sequencer}, ledger {}",
        drip.faucet.treasury(),
        data.display()
    );

    // Browser dApps may call it directly; it holds no user data.
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods([Method::GET, Method::POST])
        .allow_headers([header::CONTENT_TYPE])
        .expose_headers([header::RETRY_AFTER]);
    let app = Router::new()
        .route("/", get(info))
        .route("/fund", post(fund))
        .layer(cors)
        .with_state(drip);
    let listener = tokio::net::TcpListener::bind(listen).await?;
    axum::serve(
        listener,
        app.into_make_service_with_connect_info::<SocketAddr>(),
    )
    .with_graceful_shutdown(async {
        let _ = tokio::signal::ctrl_c().await;
    })
    .await?;
    Ok(())
}

async fn info(State(d): State<Arc<Drip>>) -> Json<Value> {
    Json(json!({
        "name": "Logos Kit drip",
        "treasury": d.faucet.treasury().to_string(),
        "amount": d.amount.to_string(),
        "everySeconds": d.every.as_secs(),
        "perIpPerHour": d.ip_per_hour,
        "maxPerHour": d.max_per_hour,
        "sampleToken": d.token.map(|(def, amount)| json!({
            "definition": def.to_string(),
            "amount": amount.to_string(),
        })),
    }))
}

type Reply = (StatusCode, HeaderMap, Json<Value>);

fn reply(status: StatusCode, outcome: &FundOutcome) -> Reply {
    let mut headers = HeaderMap::new();
    if let FundOutcome::RateLimited {
        retry_after_seconds,
    } = outcome
        && let Ok(v) = HeaderValue::from_str(&retry_after_seconds.to_string())
    {
        headers.insert(header::RETRY_AFTER, v);
    }
    let body = serde_json::to_value(outcome).unwrap_or(Value::Null);
    (status, headers, Json(body))
}

fn limited(seconds: u64) -> Reply {
    reply(
        StatusCode::TOO_MANY_REQUESTS,
        &FundOutcome::RateLimited {
            retry_after_seconds: seconds.max(1),
        },
    )
}

impl Drip {
    fn client_ip(&self, peer: SocketAddr, headers: &HeaderMap) -> IpAddr {
        if self.trust_proxy {
            let header_ip = |name: &str, rightmost: bool| {
                let v = headers.get(name)?.to_str().ok()?;
                let part = if rightmost {
                    v.rsplit(',').next()
                } else {
                    v.split(',').next()
                };
                part?.trim().parse::<IpAddr>().ok()
            };
            if let Some(ip) =
                header_ip("x-real-ip", false).or_else(|| header_ip("x-forwarded-for", true))
            {
                return ip;
            }
        }
        peer.ip()
    }

    /// Seconds to wait if this IP has used its hourly budget; else counts it.
    fn take_ip(&self, ip: IpAddr) -> Option<u64> {
        const HOUR: Duration = Duration::from_secs(3600);
        let mut ips = self
            .ips
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner);
        ips.retain(|_, times| {
            times.retain(|t| t.elapsed() < HOUR);
            !times.is_empty()
        });
        let times = ips.entry(ip).or_default();
        if times.len() >= self.ip_per_hour {
            let oldest = times.iter().min().copied().unwrap_or_else(Instant::now);
            return Some(HOUR.saturating_sub(oldest.elapsed()).as_secs().max(1));
        }
        times.push(Instant::now());
        None
    }

    /// A request that paid nothing gives the IP its slot back.
    fn refund_ip(&self, ip: IpAddr) {
        let mut ips = self
            .ips
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner);
        if let Some(times) = ips.get_mut(&ip) {
            times.pop();
        }
    }

    /// Settle payments a crash left in flight, from the target's balance.
    async fn reconcile(&self) -> Result<()> {
        let mut ledger = self.ledger.lock().await;
        ledger.prune(self.every_ms());
        for (key, entry) in ledger.in_flight() {
            let outcome = self.settle(&entry).await;
            eprintln!("reconciled in-flight request {key}: {outcome:?}");
            if let Some(e) = ledger.state.keys.get_mut(&key) {
                e.outcome = Some(outcome);
            }
        }
        ledger.save()
    }

    async fn settle(&self, entry: &KeyEntry) -> FundOutcome {
        let before: Option<u128> = entry.before.as_deref().and_then(|b| b.parse().ok());
        let now = match entry.account.parse::<AccountId>() {
            Ok(id) => self.faucet.balance(id).await.ok(),
            Err(_) => None,
        };
        match (before, now) {
            (Some(b), Some(n)) if Some(n) == b.checked_add(self.amount) => FundOutcome::Funded {
                amount: self.amount,
                tx_hash: String::new(),
            },
            _ => FundOutcome::OutcomeUnknown {
                reason: "the faucet restarted during this payment; check the balance before asking again".to_owned(),
                tx_hash: None,
            },
        }
    }

    fn every_ms(&self) -> u64 {
        u64::try_from(self.every.as_millis()).unwrap_or(u64::MAX)
    }
}

async fn fund(
    State(d): State<Arc<Drip>>,
    ConnectInfo(peer): ConnectInfo<SocketAddr>,
    headers: HeaderMap,
    Json(req): Json<FundRequest>,
) -> Reply {
    let Ok(account) = req.account.trim().parse::<AccountId>() else {
        return reply(
            StatusCode::BAD_REQUEST,
            &FundOutcome::Rejected {
                reason: "not a public LEZ account id".to_owned(),
            },
        );
    };
    let key = req.request_key.trim().to_owned();
    if key.is_empty() || key.len() > 64 {
        return reply(
            StatusCode::BAD_REQUEST,
            &FundOutcome::Rejected {
                reason: "request key must be 1–64 characters".to_owned(),
            },
        );
    }
    let account_s = account.to_string();

    // Bookkeeping first, under the ledger lock (never held while paying).
    let (ip, at) = {
        let mut ledger = d.ledger.lock().await;
        ledger.prune(d.every_ms());
        if let Some(e) = ledger.state.keys.get(&key) {
            let outcome = match (&e.outcome, e.account == account_s) {
                (_, false) => FundOutcome::Rejected {
                    reason: "this request key was used for another account".to_owned(),
                },
                (Some(o), true) => o.clone(),
                (None, true) => FundOutcome::OutcomeUnknown {
                    reason: "this request is still being paid".to_owned(),
                    tx_hash: None,
                },
            };
            return reply(StatusCode::OK, &outcome);
        }
        let now = now_ms();
        if let Some(at) = ledger.state.accounts.get(&account_s) {
            let wait = d.every_ms().saturating_sub(now.saturating_sub(*at));
            if wait > 0 {
                return limited(wait.div_ceil(1000));
            }
        }
        if ledger.state.drops.len() >= d.max_per_hour {
            let oldest = ledger.state.drops.iter().min().copied().unwrap_or(now);
            let wait = ledger::HOUR_MS.saturating_sub(now.saturating_sub(oldest));
            return limited(wait.div_ceil(1000));
        }
        let ip = d.client_ip(peer, &headers);
        if let Some(wait) = d.take_ip(ip) {
            return limited(wait);
        }
        // The target's balance now proves a payment if we crash mid-way.
        let before = d.faucet.balance(account).await.ok();
        ledger.state.keys.insert(
            key.clone(),
            KeyEntry {
                account: account_s.clone(),
                at_ms: now,
                outcome: None,
                before: before.map(|b| b.to_string()),
            },
        );
        ledger.state.accounts.insert(account_s.clone(), now);
        ledger.state.drops.push(now);
        if let Err(e) = ledger.save() {
            ledger.state.keys.remove(&key);
            ledger.state.accounts.remove(&account_s);
            ledger.state.drops.pop();
            d.refund_ip(ip);
            eprintln!("ledger write failed: {e:#}");
            return reply(
                StatusCode::SERVICE_UNAVAILABLE,
                &FundOutcome::Rejected {
                    reason: "the faucet can't record requests right now; nothing was paid"
                        .to_owned(),
                },
            );
        }
        (ip, now)
    };

    let result = d.faucet.fund(account, &key).await;
    let outcome = match result {
        Ok(o) => o,
        // Errors come before anything is sent (see KeyFaucet): nothing paid.
        Err(e) => FundOutcome::Rejected {
            reason: format!("{e:#}"),
        },
    };
    let paid_nothing = matches!(
        outcome,
        FundOutcome::Rejected { .. } | FundOutcome::RateLimited { .. }
    );
    {
        let mut ledger = d.ledger.lock().await;
        if paid_nothing {
            // Free the key, the account's wait and the budget slots.
            ledger.state.keys.remove(&key);
            ledger.state.accounts.remove(&account_s);
            if let Some(pos) = ledger.state.drops.iter().position(|t| *t == at) {
                ledger.state.drops.remove(pos);
            }
            d.refund_ip(ip);
        } else if let Some(e) = ledger.state.keys.get_mut(&key) {
            e.outcome = Some(outcome.clone());
        }
        if let Err(e) = ledger.save() {
            eprintln!("ledger write failed after paying: {e:#}");
        }
    }
    // The sample token rides on a drop that landed (the LGO transaction is
    // included, so the treasury's next nonce is free). Best effort: the
    // wallet finds it by reading blocks; a failure here only skips it.
    if let (FundOutcome::Funded { .. }, Some((def, amount))) = (&outcome, d.token)
        && let Err(e) = d.faucet.send_token(def, account, amount).await
    {
        eprintln!("sample token to {account_s} not sent: {e:#}");
    }
    let status = match outcome {
        FundOutcome::RateLimited { .. } => StatusCode::TOO_MANY_REQUESTS,
        FundOutcome::Rejected { .. } => StatusCode::BAD_REQUEST,
        _ => StatusCode::OK,
    };
    reply(status, &outcome)
}
