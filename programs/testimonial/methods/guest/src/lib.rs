//! The Logos Kit testimonial program (LEZ 0.3, raw `run_program`).
//!
//! `Post` stores one testimonial per `(submission, author)` and appends the
//! author to the submission's stats. The author must sign. The record's
//! timestamp is the caller's claim, bound to the including block's time by
//! the transaction's timestamp validity window. Rules and layout:
//! `testimonial_core`.
//!
//! A private author would publish its private account id in the record, so
//! the wallet only posts from public accounts; the program can't tell.

use lee_core::{
    account::AccountId,
    program::{Plan, PlanInput, ProgramEvent, TimestampValidityWindow},
};
pub use testimonial_core as core;
use testimonial_core::{Effect, Instruction, Posted, Stats, Testimonial};

fn fail(e: testimonial_core::Error) -> ! {
    panic!("{e}")
}

pub fn plan(input: &PlanInput, instruction: Instruction) -> Plan {
    let Instruction::Post {
        submission,
        username,
        text,
        timestamp_ms,
    } = instruction;
    testimonial_core::check_post(&submission, username.as_deref(), &text)
        .unwrap_or_else(|e| fail(e));
    let [author, stats, record] = input.accounts.as_slice() else {
        panic!("a post takes [author, stats, record]");
    };
    let program = input.self_account_id;
    assert_eq!(
        author.program_account_id, program,
        "the author must select this program's shard"
    );
    assert!(author.is_authorized, "the author must sign");
    let author_id = *author.account_id.value();
    assert_eq!(
        stats.account_id,
        AccountId::new(testimonial_core::stats_account(program.value(), &submission)),
        "wrong stats account for this submission"
    );
    assert_eq!(
        record.account_id,
        AccountId::new(testimonial_core::record_account(
            program.value(),
            &submission,
            &author_id
        )),
        "wrong record account for this author"
    );
    let (from, to) = testimonial_core::window(timestamp_ms).unwrap_or_else(|e| fail(e));
    let window = TimestampValidityWindow::try_from(from..to).expect("window is non-empty");

    let mut plan = Plan::new(input);
    plan.timestamp_window(window);
    plan.effect(
        stats,
        &Effect::Count {
            submission: submission.clone(),
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
            author,
            timestamp_ms,
        } => {
            let mut stats = Stats::load(&submission, pre_data).unwrap_or_else(|e| fail(e));
            stats.add(author, timestamp_ms).unwrap_or_else(|e| fail(e));
            Some(stats.to_bytes())
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
    use lee_core::program::AccountMeta;

    use super::*;

    const SUB: &str = "LP-0021/logos-kit";

    fn input(program: AccountId, author: AccountId, signed: bool) -> PlanInput {
        let p = program.value();
        PlanInput {
            self_account_id: program,
            caller_account_id: None,
            accounts: vec![
                AccountMeta::new(author, signed, program),
                AccountMeta::new(
                    AccountId::new(testimonial_core::stats_account(p, SUB)),
                    false,
                    program,
                ),
                AccountMeta::new(
                    AccountId::new(testimonial_core::record_account(p, SUB, author.value())),
                    false,
                    program,
                ),
            ],
            instruction_data: vec![],
        }
    }

    fn post() -> Instruction {
        Instruction::Post {
            submission: SUB.into(),
            username: Some("abu".into()),
            text: "I use Logos Kit".into(),
            timestamp_ms: 1_800_000_000_000,
        }
    }

    #[test]
    fn pda_matches_lee_core() {
        let program = AccountId::new([7; 32]);
        let seed = testimonial_core::stats_seed(SUB);
        assert_eq!(
            AccountId::for_public_pda(&program, &lee_core::program::PdaSeed::new(seed)).value(),
            &testimonial_core::pda(program.value(), &seed)
        );
    }

    #[test]
    fn a_signed_post_plans_stats_record_window_and_event() {
        let (program, author) = (AccountId::new([7; 32]), AccountId::new([1; 32]));
        let plan = plan(&input(program, author, true), post());
        let out = plan.output();
        assert_eq!(out.effects.len(), 2);
        assert_eq!(out.events.len(), 1);
        assert!(out.timestamp_validity_window.is_valid_for(1_800_000_000_000));
        assert!(!out.timestamp_validity_window.is_valid_for(1_800_000_600_000));

        let Effect::Create(record) = borsh::from_slice(&out.effects[1].data).unwrap() else {
            panic!("record effect")
        };
        assert_eq!(apply(Effect::Create(record.clone()), &[]), Some(record.clone()));
        let stats = apply(borsh::from_slice(&out.effects[0].data).unwrap(), &[]).unwrap();
        assert_eq!(Stats::load(SUB, &stats).unwrap().authors, [*author.value()]);
    }

    #[test]
    #[should_panic(expected = "the author must sign")]
    fn an_unsigned_author_is_refused() {
        let _ = plan(
            &input(AccountId::new([7; 32]), AccountId::new([1; 32]), false),
            post(),
        );
    }

    #[test]
    #[should_panic(expected = "already posted")]
    fn a_second_post_by_the_same_author_is_refused() {
        let _ = apply(Effect::Create(vec![1]), &[1]);
    }
}
