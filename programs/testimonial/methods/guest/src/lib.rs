//! The Logos Kit testimonial program (LEZ 0.3, raw `run_program`).
//!
//! `Post` stores one testimonial per `(submission, author)` and appends the
//! author to the submission's current stats page. The author must sign, and
//! the post must be the transaction's top-level call. The record's timestamp
//! is the caller's claim, bound to the including block's time by the
//! transaction's timestamp validity window. Rules and layout:
//! `testimonial_core`.
//!
//! A private author would publish its private account id in the record, so
//! the wallet only posts from public accounts; the program can't tell.

use lee_core::{
    account::AccountId,
    program::{AccountMeta, Plan, PlanInput, ProgramEvent, TimestampValidityWindow},
};
pub use testimonial_core as core;
use testimonial_core::{Effect, Instruction, Posted, Stats, Testimonial};

fn fail(e: testimonial_core::Error) -> ! {
    panic!("{e}")
}

fn expect_account(meta: &AccountMeta, id: [u8; 32], what: &str) {
    assert_eq!(meta.account_id, AccountId::new(id), "wrong {what} account");
}

pub fn plan(input: &PlanInput, instruction: Instruction) -> Plan {
    let Instruction::Post {
        submission,
        page,
        username,
        text,
        timestamp_ms,
    } = instruction;
    // A signer's authorization reaches every program in a chained call: only
    // a post the user signed as such may use it.
    assert!(
        input.caller_account_id.is_none(),
        "a post must be the transaction's top-level call"
    );
    testimonial_core::check_post(&submission, username.as_deref(), &text)
        .unwrap_or_else(|e| fail(e));
    let program = input.self_account_id;
    let p = program.value();
    let (author, stats, record, previous) = match (page, input.accounts.as_slice()) {
        (0, [author, stats, record]) => (author, stats, record, None),
        (1.., [author, stats, record, previous]) => (author, stats, record, Some(previous)),
        _ => panic!("a post takes [author, stats(page), record] (+ stats(page - 1) after page 0)"),
    };
    assert_eq!(
        author.program_account_id, program,
        "the author must select this program's shard"
    );
    assert!(author.is_authorized, "the author must sign");
    let author_id = *author.account_id.value();
    expect_account(
        stats,
        testimonial_core::stats_account(p, &submission, page),
        "stats",
    );
    expect_account(
        record,
        testimonial_core::record_account(p, &submission, &author_id),
        "record",
    );
    let (from, to) = testimonial_core::window(timestamp_ms).unwrap_or_else(|e| fail(e));
    let window = TimestampValidityWindow::try_from(from..to).expect("window is non-empty");

    let mut plan = Plan::new(input);
    plan.timestamp_window(window);
    if let Some(previous) = previous {
        expect_account(
            previous,
            testimonial_core::stats_account(p, &submission, page - 1),
            "previous stats",
        );
        plan.effect(
            previous,
            &Effect::Full {
                submission: submission.clone(),
                page: page - 1,
            },
        );
    }
    plan.effect(
        stats,
        &Effect::Count {
            submission: submission.clone(),
            page,
            author: author_id,
            timestamp_ms,
        },
    );
    plan.event(ProgramEvent {
        selector: testimonial_core::posted_selector(),
        data: borsh::to_vec(&Posted {
            submission: submission.clone(),
            author: author_id,
            timestamp_ms,
        })
        .expect("borsh serialization is infallible"),
    });
    let bytes = Testimonial::new(submission, author_id, username, text, timestamp_ms).to_bytes();
    plan.effect(record, &Effect::Create(bytes));
    plan
}

pub fn apply(effect: Effect, pre_data: &[u8]) -> Option<Vec<u8>> {
    match effect {
        Effect::Count {
            submission,
            page,
            author,
            timestamp_ms,
        } => {
            let mut stats = Stats::load(&submission, page, pre_data).unwrap_or_else(|e| fail(e));
            stats.add(author, timestamp_ms).unwrap_or_else(|e| fail(e));
            Some(stats.to_bytes())
        }
        Effect::Full { submission, page } => {
            let stats = Stats::load(&submission, page, pre_data).unwrap_or_else(|e| fail(e));
            if !stats.is_full() {
                fail(testimonial_core::Error::NotFull);
            }
            None
        }
        Effect::Create(bytes) => {
            if !pre_data.is_empty() {
                fail(testimonial_core::Error::AlreadyPosted);
            }
            Some(bytes)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const SUB: &str = "LP-0021/logos-kit";

    fn input(program: AccountId, author: AccountId, signed: bool, page: u32) -> PlanInput {
        let p = program.value();
        let meta = |id: [u8; 32]| AccountMeta::new(AccountId::new(id), false, program);
        let mut accounts = vec![
            AccountMeta::new(author, signed, program),
            meta(testimonial_core::stats_account(p, SUB, page)),
            meta(testimonial_core::record_account(p, SUB, author.value())),
        ];
        if page > 0 {
            accounts.push(meta(testimonial_core::stats_account(p, SUB, page - 1)));
        }
        PlanInput {
            self_account_id: program,
            caller_account_id: None,
            accounts,
            instruction_data: vec![],
        }
    }

    fn post(page: u32) -> Instruction {
        Instruction::Post {
            submission: SUB.into(),
            page,
            username: Some("abu".into()),
            text: "I use Logos Kit".into(),
            timestamp_ms: 1_800_000_000_000,
        }
    }

    const PROGRAM: AccountId = AccountId::new([7; 32]);
    const AUTHOR: AccountId = AccountId::new([1; 32]);

    #[test]
    fn pda_matches_lee_core() {
        let seed = testimonial_core::stats_seed(SUB, 0);
        assert_eq!(
            AccountId::for_public_pda(&PROGRAM, &lee_core::program::PdaSeed::new(seed)).value(),
            &testimonial_core::pda(PROGRAM.value(), &seed)
        );
    }

    #[test]
    fn a_signed_post_plans_stats_record_window_and_event() {
        let plan = plan(&input(PROGRAM, AUTHOR, true, 0), post(0));
        let out = plan.output();
        assert_eq!(out.effects.len(), 2);
        assert_eq!(out.events.len(), 1);
        assert!(
            out.timestamp_validity_window
                .is_valid_for(1_800_000_000_000)
        );
        assert!(
            !out.timestamp_validity_window
                .is_valid_for(1_800_000_600_000)
        );

        let Effect::Create(record) = borsh::from_slice(&out.effects[1].data).unwrap() else {
            panic!("record effect")
        };
        assert_eq!(
            apply(Effect::Create(record.clone()), &[]),
            Some(record.clone())
        );
        let stats = apply(borsh::from_slice(&out.effects[0].data).unwrap(), &[]).unwrap();
        assert_eq!(
            Stats::load(SUB, 0, &stats).unwrap().authors,
            [*AUTHOR.value()]
        );
    }

    #[test]
    fn a_later_page_opens_only_after_a_full_one() {
        let out = plan(&input(PROGRAM, AUTHOR, true, 1), post(1))
            .output()
            .clone();
        assert_eq!(out.effects.len(), 3);
        let full: Effect = borsh::from_slice(&out.effects[0].data).unwrap();
        let mut page0 = Stats::new(SUB.into(), 0);
        for i in 0..testimonial_core::PAGE_SIZE as u32 {
            let mut a = [0; 32];
            a[..4].copy_from_slice(&i.to_le_bytes());
            page0.add(a, 0).unwrap();
        }
        assert_eq!(apply(full.clone(), &page0.to_bytes()), None);
        let half = Stats::new(SUB.into(), 0).to_bytes();
        assert!(std::panic::catch_unwind(|| apply(full, &half)).is_err());
    }

    #[test]
    #[should_panic(expected = "top-level")]
    fn a_chained_post_is_refused() {
        let mut i = input(PROGRAM, AUTHOR, true, 0);
        i.caller_account_id = Some(AccountId::new([9; 32]));
        let _ = plan(&i, post(0));
    }

    #[test]
    #[should_panic(expected = "the author must sign")]
    fn an_unsigned_author_is_refused() {
        let _ = plan(&input(PROGRAM, AUTHOR, false, 0), post(0));
    }

    #[test]
    #[should_panic(expected = "already posted")]
    fn a_second_post_by_the_same_author_is_refused() {
        let _ = apply(Effect::Create(vec![1]), &[1]);
    }
}
