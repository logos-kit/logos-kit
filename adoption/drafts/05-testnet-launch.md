<!-- DRAFTS: need the maintainer's go-ahead before anything is posted. Post AFTER the 0.3.0 catalog release is live (the ui/wallet-v3 PR merged, catalog moved) and the docs site is redeployed with the new landing. Every fact below is verified; re-check the version numbers on the day. -->

# Logos Kit on testnet 0.3: launch posts

Where (per fryorcraken in the LP-0021 Discord thread, 30 Sep): the forum thread, the Discord LP-0021 thread in #builder-hub, and #general. Logos tweets what's posted there.

---

## 1. Forum: reply in "New λPrize: LP-0021, LEZ Wallet and Provider SDK" (forum.logos.co/t/1949)

**Logos Kit is live on testnet 0.3: a LEZ wallet and provider SDK for Basecamp (LP-0021)**

Logos Kit is a wallet for the Logos Execution Zone, plus the SDK your Basecamp app uses to ask it for things. It now runs on the official testnet 0.3.

**For people trying LEZ**
- Public and private accounts, as many as you like. Private balances are visible only to you; private sends are proved on your own machine.
- Every approval says what it does: who pays whom, which program, whether the program's source is verified, the network fee, and which app is asking.
- Get test LGO from inside the wallet: one click, 1 LGO an hour.
- Light and dark themes; one screen per job, with no clutter.
- Install in Basecamp: Settings → Package Repositories → add
  `https://raw.githubusercontent.com/logos-kit/logos-kit-modules/refs/heads/main/logos-repo.json`
  then install **Logos Kit Wallet** (and the **Testimonials** and **Faucet** apps).

**Help us with LP-0021: leave a testimonial.** Open the Testimonials app, connect your wallet, and say in a sentence what you used it for. It's stored on-chain on the testnet (the program is immutable and source-verified: `5YoH3xjhgeKt2mcJXW7c31bqDNCWWA4CRJxVdvzFvVef`).

**For Basecamp builders**
- `nix flake init -t github:logos-kit/logos-kit#dapp` gives you an app with connect, balance, in-flow test funds and a receipt already wired.
- QML SDK: `kit.api.connect / transfer / watchTransaction / requestFunds`. TypeScript client on npm: `@logos-kit/client`.
- Docs with worked examples: https://logos-kit-docs.vercel.app
- If you're building a Basecamp app, we'll help you add wallet support. Reply here or ping us on Discord.

Code: https://github.com/logos-kit/logos-kit (MIT or Apache-2.0). Testnets only, unaudited.

---

## 2. Discord: the LP-0021 thread in #builder-hub

Logos Kit is live on **testnet 0.3** 🎉 It's an LP-0021 wallet + provider SDK for Basecamp.

• Install: Basecamp → Settings → Package Repositories → `https://raw.githubusercontent.com/logos-kit/logos-kit-modules/refs/heads/main/logos-repo.json` → install Logos Kit Wallet
• Public + private accounts, approvals that say what they do, 1-click test LGO
• Builders: `nix flake init -t github:logos-kit/logos-kit#dapp`. Docs: https://logos-kit-docs.vercel.app
• Testimonials app → one sentence on-chain helps us a lot

Building a Basecamp app and want wallet support? We'll help you wire it in.

---

## 3. Discord: #general (non-dev users)

Want to try private payments on Logos? 👋

Logos Kit is a wallet that runs inside Basecamp, on the testnet:
1. In Basecamp: Settings → Package Repositories → add `https://raw.githubusercontent.com/logos-kit/logos-kit-modules/refs/heads/main/logos-repo.json`
2. Install **Logos Kit Wallet** and press **Test LGO** to get free test tokens
3. Send some to a private account and watch your own machine prove it

If it works for you, leave a one-line testimonial in the **Testimonials** app. It goes on-chain and helps our LP-0021 entry. Test tokens only, no real value.

---

## 4. X thread (from the maintainer's account; tag @Logos_network)

1/ Logos Kit is live on @Logos_network testnet 0.3: a wallet for the Logos Execution Zone, and an SDK so Basecamp apps can ask it for things.

2/ Public and private accounts. Private balances are visible only to you, and private sends are proved on your own machine before anything leaves it.

3/ Every approval says what it does: who pays whom, which program, whether its source is verified, the network fee, and which app is asking. No raw calldata.

4/ Builders: `nix flake init -t github:logos-kit/logos-kit#dapp` gives you connect, balances, in-flow test funds and receipts. Docs: logos-kit-docs.vercel.app

5/ Try it in Basecamp and leave a testimonial. It lands on-chain and counts toward our λPrize LP-0021 entry. github.com/logos-kit/logos-kit
