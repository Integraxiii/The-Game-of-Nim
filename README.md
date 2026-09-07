# The Game of Nim — Nim Lab

A Godot 4 browser game and strategy trainer for learning **Nim**.

## Play / practice features

- 2–5 configurable piles
- 0–15 tokens per pile
- Choose **You**, **Computer**, or **Random** to go first
- Perfect, Practice, and Random computer difficulty
- **Standard Nim:** taking the last token wins
- **Video / Misère Nim:** taking the last token loses
- Hint system
- Binary / 4-2-1 Nim-sum reveal
- Predicts whether Player 1 or Player 2 has the winning strategy under perfect play

## Run in Godot

Open `project.godot` in Godot 4.7.2 or a compatible newer Godot 4.x release, then press F6/F5.

## Web deployment

The repository includes `.github/workflows/deploy-pages.yml`. On each push to `main`, GitHub Actions exports the project as a Godot Web build and deploys it to GitHub Pages.

If Pages has not been enabled yet, open **Settings → Pages → Build and deployment → Source** and choose **GitHub Actions**.

Once deployed, the expected game URL is:

**https://integraxiii.github.io/The-Game-of-Nim/**

## Strategy reminder

In standard Nim, XOR the pile sizes. A Nim-sum of zero is a losing position for the player whose turn it is under perfect play. Your goal is usually to finish your move by giving your opponent a zero Nim-sum.

In the last-token-loses variation, ordinary Nim strategy applies until the special endgame where all remaining piles contain only 0 or 1 token; then parity matters.
