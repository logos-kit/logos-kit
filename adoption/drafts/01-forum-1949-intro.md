<!-- DRAFT: needs maintainer approval before posting to https://forum.logos.co/t/1949 -->

**Logos Kit: an LP-0021 wallet + provider SDK (building in public)**

Hi all, we're building **Logos Kit**, a LEZ wallet and Wallet Provider SDK, targeting testnet 0.3 from day one.

**What's in it**
- **Basecamp wallet:** public + private accounts, the token program, multiple accounts, and an approval sheet that shows who's asking, what you're signing, the fee, and the program's **source-verification status**.
- **An SDK Basecamp apps can adopt in minutes:** `LogosKit.qml`, a dApp template (`nix flake init`), and a **fake wallet** so you can build and test your app before touching testnet.
- **Security basics done properly:**
  - the approval authority lives in the wallet core;
  - a dApp can't sign, submit, or read a private balance without an explicit per-account grant;
  - no events leak private data;
  - keys are encrypted at rest.
- **Testimonial + faucet mini-apps**, including an in-flow "get test funds" step for your dApp's users.
- **Beyond Basecamp:** React and React Native/Expo kits with a passkey wallet, sharing the same protocol.

**For Basecamp builders**
We'd love 10 minutes of your feedback. What does your app need from a wallet?
- connect;
- sign;
- funds for new users;
- transaction receipts;
- anything else?

If you're building a Basecamp app, we'll help you integrate the SDK.

**For users**
Which dApps would you connect first? What would make you trust a wallet's approval screen?

We'll post progress here regularly. The code is MIT/Apache.
