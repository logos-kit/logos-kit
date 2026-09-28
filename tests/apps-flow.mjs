#!/usr/bin/env node
// S8 in a real Basecamp: the testimonial and faucet apps through the shell's
// intents and sandbox (e2e/basecamp-apps.sh sets it up).
//
//   testimonial: connect → compose → approve in the wallet → included → count
//   faucet: connect → claim (rate-limited: onboarding just funded it) → countdown → claim → funded
//
//   PROGRAM=<testimonial program id> node tests/apps-flow.mjs --shots docs/reviews/s8/basecamp
import {
  chooseWallet,
  click,
  ids,
  ins,
  openApp,
  PW,
  say,
  send,
  shot,
  sleep,
  step,
  text,
  type,
  visibleId,
  waitFor,
  waitVisible,
} from './bc-lib.mjs'

const PROGRAM = process.env.PROGRAM
if (!PROGRAM) throw new Error('set PROGRAM to the testimonial program id')

// The shell may ask which app handles an intent: pick the wallet until `name`
// shows. A new request waits while an earlier result is still on the wallet's
// sheet (a notice says so): close that result, as a user would.
async function viaWallet(name, what) {
  await waitFor(
    what,
    async () => {
      if (await visibleId(name)) return true
      if (await visibleId('intentQueued')) {
        for (const done of ['proofDone', 'fundsDone', 'keepRunning'])
          if (await visibleId(done)) {
            await click(done)
            break
          }
        return false
      }
      await chooseWallet()
      return false
    },
    60000,
  )
}

await step('wallet: first run on the local zone', async () => {
  await openApp('Logos Kit Wallet')
  await waitVisible('createWallet', 60000)
  await send('findAndClick', { text: 'lez:local' })
  await sleep(1500)
  await click('createWallet')
  await type('password', PW)
  await type('password2', PW)
  await click('continueCreate')
  await click('revealPhrase', 60000)
  const ob = (await ids('onboarding'))[0]
  const words = (
    await ins.send('evaluate', { objectId: ob, expression: "this.words.join(' ')" })
  ).result.split(' ')
  await click('savedPhrase')
  for (const n of [3, 11, 19]) await type(`confirmWord${n}`, words[n - 1])
  await click('confirmPhrase')
  await click('readyFunds')
  await waitVisible('homeSend', 60000)
  await sleep(8000)
  await shot('01-wallet-home')
})

await step('testimonial: connect through the shell', async () => {
  await openApp('Logos Kit Testimonials')
  await type('tmProgram', PROGRAM)
  await click('tmConnect', 30000)
  await viaWallet('connectApprove', 'wallet connect sheet')
  await type('connectPassword', PW)
  await click('connectApprove')
  await waitVisible('tmText', 60000)
  await shot('10-testimonial-compose')
})

await step('testimonial: post, approve, included', async () => {
  await type('tmName', 'basecamp')
  await type('tmText', 'I use the Logos Kit wallet on LEZ inside Basecamp.')
  await click('tmPost')
  await viaWallet('approve', 'wallet approval')
  await shot('11-testimonial-approval')
  await click('approve')
  await waitVisible('tmDone', 120000)
  await waitFor('count 1', async () => (await text('tmCount')) === '1', 60000)
  await shot('12-testimonial-done')
})

await step('faucet: connect, rate limit, claim', async () => {
  await openApp('Logos Kit Faucet')
  await click('fcConnect', 30000)
  await viaWallet('connectApprove', 'wallet connect sheet')
  await type('connectPassword', PW)
  await click('connectApprove')
  await waitVisible('fcAccount_0', 60000)
  // The wallet's first run just funded this account: the faucet says wait.
  await click('fcRequest')
  await viaWallet('fundsApprove', 'wallet faucet sheet')
  await click('fundsApprove')
  await click('fundsDone', 60000)
  await openApp('Logos Kit Faucet')
  await waitVisible('fcLimited', 60000)
  await shot('20-faucet-limited')
  // The countdown reopens the button; the next claim pays.
  // (`click` waits 20 s for a button to enable; the countdown takes up to 60 s.)
  await waitFor(
    'countdown over',
    async () => {
      const id = await visibleId('fcRequest')
      return (
        !!id &&
        (await ins.send('evaluate', { objectId: id, expression: 'this.enabled' })).result === true
      )
    },
    150000,
  )
  await click('fcRequest')
  await viaWallet('fundsApprove', 'wallet faucet sheet')
  await click('fundsApprove')
  await click('fundsDone', 60000)
  await openApp('Logos Kit Faucet')
  await waitVisible('fcDone', 120000)
  await shot('21-faucet-funded')
})

say('\nOK: testimonial posted; faucet rate-limited then funded, in Basecamp')
ins.disconnect()
process.exit(0)
