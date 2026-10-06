//! Which tokens to trust, and how much (docs/design/ux-tokens-nfts.md §5).
//!
//! LEZ stores a token's name and nothing else that says who made it, and
//! anyone can create a token called "USDC" for almost nothing. So a token's
//! identity is its definition ID, and the wallet sorts every token into one
//! tier, first match wins:
//!
//! 1. **Hidden**: the user hid it.
//! 2. **Verified**: on the Logos Kit token list for this network.
//! 3. **Added**: the user added it by ID.
//! 4. **Spam**: its name looks like a scam (a link, airdrop bait, hidden
//!    characters, very long, or a lookalike of a verified token or LGO).
//! 5. **Unknown**: everything else that arrived.
//!
//! Unhiding or showing a token never raises its tier. Metadata and images
//! load only for Verified and Added tokens (decision D6).

use std::sync::OnceLock;

use serde::{Deserialize, Serialize};

/// The Logos Kit token list for the testnet, shipped inside the signed
/// module (decision D8); `registry/tokens/` and docs/design/token-list.md.
const TESTNET_LIST: &str = include_str!("../../../registry/tokens/lez-testnet.tokenlist.json");

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Tier {
    Hidden,
    Verified,
    Added,
    Spam,
    Unknown,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum SpamReason {
    /// "Name contains a link"
    Link,
    /// "Name looks like an airdrop offer"
    Bait,
    /// "Looks like <name>"
    Lookalike { of: String },
    /// "Hidden characters in the name"
    HiddenCharacters,
    /// "Name is very long"
    TooLong,
}

impl SpamReason {
    /// The wording the Spam tab shows.
    pub fn text(&self) -> String {
        match self {
            Self::Link => "Name contains a link".to_owned(),
            Self::Bait => "Name looks like an airdrop offer".to_owned(),
            Self::Lookalike { of } => format!("Looks like {of}"),
            Self::HiddenCharacters => "Hidden characters in the name".to_owned(),
            Self::TooLong => "Name is very long".to_owned(),
        }
    }
}

/// One entry of the token list (the fields the wallet uses).
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Listed {
    pub address: String,
    pub name: String,
    pub symbol: String,
    pub decimals: u8,
    #[serde(default)]
    pub tags: Vec<String>,
    pub extensions: Extensions,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Extensions {
    pub chain: String,
    pub kind: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub metadata_id: Option<String>,
}

#[derive(Deserialize)]
struct List {
    version: Version,
    tokens: Vec<Listed>,
}

#[derive(Clone, Copy, Debug, Deserialize, Serialize)]
pub struct Version {
    pub major: u32,
    pub minor: u32,
    pub patch: u32,
}

fn testnet() -> &'static List {
    static LIST: OnceLock<List> = OnceLock::new();
    LIST.get_or_init(|| {
        serde_json::from_str(TESTNET_LIST).unwrap_or(List {
            version: Version {
                major: 0,
                minor: 0,
                patch: 0,
            },
            tokens: Vec::new(),
        })
    })
}

/// The list entries for `chain` (empty for networks without a list).
pub fn listed(chain: &str) -> Vec<&'static Listed> {
    testnet()
        .tokens
        .iter()
        .filter(|t| t.extensions.chain == chain)
        .collect()
}

/// The list entry for a definition on `chain`.
pub fn find(chain: &str, definition: &str) -> Option<&'static Listed> {
    listed(chain).into_iter().find(|t| t.address == definition)
}

/// "Logos Kit token list v0.1.0", for the trust panel.
pub fn list_label() -> String {
    let v = testnet().version;
    format!("Logos Kit token list v{}.{}.{}", v.major, v.minor, v.patch)
}

/// What the user decided about tokens on this network.
#[derive(Clone, Debug, Default)]
pub struct Choices<'a> {
    pub hidden: &'a [String],
    pub added: &'a [String],
}

/// The tier of `definition` named `name` on `chain`.
pub fn tier(
    chain: &str,
    definition: &str,
    name: Option<&str>,
    choices: &Choices,
) -> (Tier, Option<SpamReason>) {
    if choices.hidden.iter().any(|h| h == definition) {
        return (Tier::Hidden, name.and_then(|n| spam(chain, n)));
    }
    if find(chain, definition).is_some() {
        return (Tier::Verified, None);
    }
    if choices.added.iter().any(|a| a == definition) {
        return (Tier::Added, None);
    }
    match name.and_then(|n| spam(chain, n)) {
        Some(reason) => (Tier::Spam, Some(reason)),
        None => (Tier::Unknown, None),
    }
}

/// Words airdrop scams put in token names (whole words, any case).
const BAIT: &[&str] = &[
    "claim",
    "airdrop",
    "reward",
    "rewards",
    "free",
    "gift",
    "bonus",
    "giveaway",
    "congrats",
    "congratulations",
    "visit",
    "voucher",
];
const LINKS: &[&str] = &[
    "http", "www.", ".com", ".io", ".xyz", ".org", ".net", ".app", "t.me", "@", "://",
];
/// Names a token must never pass for, besides the verified list.
const PROTECTED: &[&str] = &["LGO", "LOGOS", "Logos"];

/// Why `name` looks like spam on `chain`, if it does.
pub fn spam(chain: &str, name: &str) -> Option<SpamReason> {
    if name.chars().any(hidden_char) {
        return Some(SpamReason::HiddenCharacters);
    }
    if name.chars().count() > 32 {
        return Some(SpamReason::TooLong);
    }
    let lower = name.to_lowercase();
    if LINKS.iter().any(|l| lower.contains(l)) {
        return Some(SpamReason::Link);
    }
    if lower
        .split(|c: char| !c.is_alphanumeric())
        .any(|w| BAIT.contains(&w))
    {
        return Some(SpamReason::Bait);
    }
    let own = skeleton(name);
    let listed = listed(chain);
    let names = PROTECTED.iter().map(|p| (*p).to_owned()).chain(
        listed
            .iter()
            .flat_map(|t| [t.name.clone(), t.symbol.clone()]),
    );
    for other in names {
        if skeleton(&other) == own {
            return Some(SpamReason::Lookalike { of: other });
        }
    }
    None
}

/// UTS-39 skeleton, case-folded: "LKT", "lkt" and "ⅬКТ" compare equal.
fn skeleton(s: &str) -> String {
    let folded: String = unicode_security::confusable_detection::skeleton(s).collect();
    let folded: String =
        unicode_security::confusable_detection::skeleton(&folded.to_lowercase()).collect();
    folded.chars().filter(|c| !c.is_whitespace()).collect()
}

/// Control characters, bidi overrides and isolates, zero-width characters.
fn hidden_char(c: char) -> bool {
    c.is_control()
        || matches!(
            c,
            '\u{200B}'..='\u{200F}'
                | '\u{202A}'..='\u{202E}'
                | '\u{2060}'..='\u{2064}'
                | '\u{2066}'..='\u{2069}'
                | '\u{FEFF}'
        )
}

#[cfg(test)]
mod tests {
    use super::*;

    const T: &str = "lez:testnet";

    #[test]
    fn spam_rules() {
        assert_eq!(spam(T, "Visit claim-now.xyz"), Some(SpamReason::Link));
        assert_eq!(spam(T, "FREE tokens"), Some(SpamReason::Bait));
        assert_eq!(spam(T, "Airdrop!"), Some(SpamReason::Bait));
        assert_eq!(
            spam(T, "Freedom"),
            None,
            "a word that contains a bait word is fine"
        );
        assert_eq!(
            spam(T, "Pay\u{202E}dlo"),
            Some(SpamReason::HiddenCharacters)
        );
        assert_eq!(spam(T, "A".repeat(33).as_str()), Some(SpamReason::TooLong));
        assert_eq!(
            spam(T, "L\u{041E}G\u{041E}S"),
            Some(SpamReason::Lookalike { of: "LOGOS".into() }),
            "Cyrillic O passing for LOGOS"
        );
        assert_eq!(
            spam(T, "lgo"),
            Some(SpamReason::Lookalike { of: "LGO".into() })
        );
        assert_eq!(spam(T, "Payroll Token"), None);
    }

    #[test]
    fn tiers_first_match_wins() {
        let hidden = vec!["H".to_owned()];
        let added = vec!["A".to_owned(), "H".to_owned()];
        let c = Choices {
            hidden: &hidden,
            added: &added,
        };
        assert_eq!(tier(T, "H", Some("x"), &c).0, Tier::Hidden);
        assert_eq!(
            tier(T, "A", Some("free gift"), &c).0,
            Tier::Added,
            "added beats spam"
        );
        assert_eq!(tier(T, "S", Some("free gift"), &c).0, Tier::Spam);
        assert_eq!(tier(T, "U", Some("Payroll"), &c).0, Tier::Unknown);
        assert_eq!(tier(T, "U", None, &c).0, Tier::Unknown);
    }

    #[test]
    fn the_list_parses() {
        let _ = list_label();
        assert!(listed("lez:preview").is_empty());
    }
}
