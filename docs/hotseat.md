# Hotseat setup and handoff

Main Menu → Hotseat offers a player-count selector from 1 to 8. The scrollable setup shows exactly that many player cards. Each card has an optional name and three tribe choices; multiple players can choose the same tribe. Start Match enables after every active card has a tribe. Reducing and increasing the count preserves hidden cards' choices, but hidden players are not included in the match.

The menu validates the roster against the chunk catalog before leaving setup. If shore restrictions or invalid painted chunks prevent a valid map, an error appears in setup. A valid manifest is retained in GameSession and used by Main.

With two or more players, an accepted End Turn displays a black screen naming the next player, their slot number and the round. Gameplay pauses and action requests are rejected during handoff. Continue becomes available after a short click guard. Clicking it switches selection, camera and fog before uncovering the board. The previous player's recruitment and resource popups close on the new turn. Eliminated players are skipped; victory ends the match without another handoff.

One-player setup is solo exploration. It skips handoff and does not award an immediate last-player-standing victory; holding Sweetspire remains the win condition. Solo does not add AI opponents.

`GameSession.hotseat_mode` enables this presentation. The hotseat menu sets it and session reset clears it. Direct editor runs and future network setup retain their existing turn behavior unless hotseat mode is explicitly enabled. Networking is unchanged.

Run `scenes/hotseat_regression_test.tscn` for the hotseat checks: player counts, repeated tribes, preserved selections, session membership, eight-player setup and turn cycling, pause/continue, view changes, rejected actions, elimination skipping, solo progression and solo center victory.
