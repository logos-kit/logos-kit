//! `logos-kit-drip`: the self-hostable faucet behind [`HttpFaucet`] (the
//! wallet's `lez_requestFunds` on zones without an official faucet).
//!
//! `POST /fund {"account", "requestKey"}` answers a `FundOutcome`, exactly as
//! the engine's `KeyFaucet` decides it: one drop in flight, a per-account
//! wait, idempotent request keys, and `outcome_unknown` rather than paying
//! twice. On top: a per-client-IP budget, so fresh accounts can't drain the
//! treasury. `GET /` describes the faucet (treasury, drop, limits).
//!
//! Configuration (env):
//! - `LK_DRIP_KEY` (required): the treasury's private key, hex.
//! - `LK_DRIP_SEQUENCER` (default `http://127.0.0.1:3040`).
//! - `LK_DRIP_AMOUNT` base units per drop (default 1 000 000 000).
//! - `LK_DRIP_EVERY_SECS` per-account wait (default 3600).
//! - `LK_DRIP_IP_PER_HOUR` drops per client IP per hour (default 5).
//! - `LK_DRIP_LISTEN` (default `0.0.0.0:8080`).
//! - `LK_DRIP_TRUST_PROXY=1`: take the client IP from `X-Forwarded-For`
//!   (only behind a proxy that sets it, e.g. Traefik).
//!
//! [`HttpFaucet`]: wallet_engine::faucet::HttpFaucet

use std::{
    collections::HashMap,
    net::{IpAddr, SocketAddr},
    sync::{Arc, Mutex},
    time::{Duration, Instant},
};

use anyhow::{Context as _, Result};
use axum::{
    Json, Router,
    extract::{ConnectInfo, State},
    http::{HeaderMap, Method, StatusCode, header},
    routing::{get, post},
};
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
    trust_proxy: bool,
    ips: Mutex<HashMap<IpAddr, Vec<Instant>>>,
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
    let drip = Arc::new(Drip {
        faucet: KeyFaucet::new("Logos Kit drip", &sequencer, &key, amount, every)?,
        amount,
        every,
        ip_per_hour: env_or("LK_DRIP_IP_PER_HOUR", 5)?,
        trust_proxy: std::env::var("LK_DRIP_TRUST_PROXY").is_ok_and(|v| v == "1"),
        ips: Mutex::new(HashMap::new()),
    });
    drop(key);
    println!(
        "logos-kit-drip on {listen}: treasury {}, sequencer {sequencer}",
        drip.faucet.treasury()
    );

    // Browser dApps may call it directly; it holds no user data.
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods([Method::GET, Method::POST])
        .allow_headers([header::CONTENT_TYPE]);
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
    }))
}

impl Drip {
    fn client_ip(&self, peer: SocketAddr, headers: &HeaderMap) -> IpAddr {
        if self.trust_proxy
            && let Some(ip) = headers
                .get("x-forwarded-for")
                .and_then(|v| v.to_str().ok())
                .and_then(|v| v.split(',').next())
                .and_then(|v| v.trim().parse().ok())
        {
            return ip;
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

    /// A drop that paid nothing gives the IP its slot back.
    fn refund_ip(&self, ip: IpAddr) {
        let mut ips = self
            .ips
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner);
        if let Some(times) = ips.get_mut(&ip) {
            times.pop();
        }
    }
}

async fn fund(
    State(d): State<Arc<Drip>>,
    ConnectInfo(peer): ConnectInfo<SocketAddr>,
    headers: HeaderMap,
    Json(req): Json<FundRequest>,
) -> (StatusCode, Json<Value>) {
    let reply = |status, outcome: &FundOutcome| {
        (
            status,
            Json(serde_json::to_value(outcome).unwrap_or(Value::Null)),
        )
    };
    let Ok(account) = req.account.trim().parse::<AccountId>() else {
        return reply(
            StatusCode::BAD_REQUEST,
            &FundOutcome::Rejected {
                reason: "not a public LEZ account id".to_owned(),
            },
        );
    };
    let ip = d.client_ip(peer, &headers);
    if let Some(wait) = d.take_ip(ip) {
        return reply(
            StatusCode::TOO_MANY_REQUESTS,
            &FundOutcome::RateLimited {
                retry_after_seconds: wait,
            },
        );
    }
    match d.faucet.fund(account, &req.request_key).await {
        Ok(outcome) => {
            if matches!(
                outcome,
                FundOutcome::Rejected { .. } | FundOutcome::RateLimited { .. }
            ) {
                d.refund_ip(ip);
            }
            reply(StatusCode::OK, &outcome)
        }
        // Errors come before anything is sent (see KeyFaucet): nothing paid.
        Err(e) => {
            d.refund_ip(ip);
            reply(
                StatusCode::BAD_REQUEST,
                &FundOutcome::Rejected {
                    reason: format!("{e:#}"),
                },
            )
        }
    }
}
