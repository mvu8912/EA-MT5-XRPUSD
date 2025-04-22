# Multi-Take-Profit (TP) System in MoneyMonster.mq5

This document explains the logic behind the multiple take-profit system implemented in the `MoneyMonster.mq5` Expert Advisor, based on the code.

**1. TP Structure:**

*   The system uses a structure named `POSITION_TRACKER`.
*   This structure holds information about an open position, including:
    *   `entry_price`
    *   `original_sl`, `current_sl`
    *   `original_volume`, `current_volume`
    *   `position_type` (BUY or SELL)
    *   `ticket` (unique order ID)
    *   Four TP levels: `tp1`, `tp2`, `tp3`, `tp4`. Each TP level has:
        *   `price`: The target price level.
        *   `hit`: A boolean flag indicating if the level has been reached.
        *   `position_part`: The *intended* fraction of the original position volume to be closed (0.4, 0.3, 0.2, 0.1). **Note:** The actual implementation calculates percentages based on *current* volume at the time of partial close for TP2 and TP3 (see Section 3).
    *   A midway level: `midway_tp4` (calculated as 87.5% of the way to the final TP) and a corresponding `midway_hit` flag.

**2. TP Calculation (`ExecuteTrade`):**

1.  **Determine Final TP:**
    *   A `final_tp_price` is calculated based on the `entry_price` and a `tp_distance`.
    *   This `tp_distance` is determined either by specific values for pairs like XAUUSD, XAGUSD, XRPUSD or calculated using a base `pip_value` multiplied by a `DistanceMultiplier` input parameter.
2.  **Calculate Intermediate TPs:**
    *   `vtp1` (TP1 price) is set at 25% of the distance between entry and `final_tp_price`.
    *   `vtp2` (TP2 price) is set at 50% of the distance.
    *   `vtp3` (TP3 price) is set at 75% of the distance.
    *   `vtp35` (`midway_tp4` price) is set at 87.5% of the distance.
    *   `final_tp_price` itself serves as the TP4 price.
3.  **Store TP Info:** These calculated prices and the intended position parts are stored in the `POSITION_TRACKER` struct (`pos`) for the new trade.

**3. TP Management (`ManagePositions`):**

This function runs on every tick to check open positions. For each position:

1.  **Check TP4:** If the current price reaches or surpasses `tp4.price`, the *entire remaining* position is closed using `Trade.PositionClose()`.
2.  **Check Midway TP (VTP3.5):** If the price reaches `midway_tp4` and it hasn't been hit before (`!midway_hit`):
    *   The Stop Loss (SL) is moved to the `tp3.price` using `ModifyStopLoss()`.
    *   The `midway_hit` flag is set to true.
3.  **Check TP3:** If the price reaches `tp3.price` and it hasn't been hit before (`!tp3.hit`):
    *   A partial close is attempted for **20% of the *current* remaining volume** using `ClosePartialPosition()`.
    *   If successful, the SL is moved to `tp2.price`.
    *   The `tp3.hit` flag is set to true.
4.  **Check TP2:** If the price reaches `tp2.price` and it hasn't been hit before (`!tp2.hit`):
    *   A partial close is attempted for **30% of the *current* remaining volume**.
    *   If successful, the SL is moved to `tp1.price`.
    *   The `tp2.hit` flag is set to true.
5.  **Check TP1:** If the price reaches `tp1.price` and it hasn't been hit before (`!tp1.hit`):
    *   A partial close is attempted for **40% of the *current* (original) volume**.
    *   If successful, the SL is moved to the `entry_price` (Breakeven) using `ModifyStopLoss()`.
    *   The `tp1.hit` flag is set to true.
6.  **Check Breakeven Retracement:** If TP1 has been hit (`tp1.hit` is true) and the price falls back to or beyond the `entry_price`:
    *   The EA explicitly calls `Trade.PositionClose()` to close the *entire remaining* position.
    *   This acts as a confirmation/safety net, even though the broker *should* also trigger the SL that was previously moved to the entry price.
7.  **Check Dynamic Stop Loss (Before TP1):** If TP1 has *not* been hit (`!tp1.hit`) and the price is moving against the entry price:
    *   A potential new SL (`new_sl`) is calculated based on the `current_price` and the `DynamicSLDistance` input (converted to price distance).
    *   For a BUY: `new_sl` is the lower of `entry_price` or (`current_price` - `distance`).
    *   For a SELL: `new_sl` is the higher of `entry_price` or (`current_price` + `distance`).
    *   This `new_sl` is then capped: it cannot be worse than the `original_sl`.
    *   If this calculated `new_sl` is different from the currently tracked `current_sl`, `ModifyStopLoss()` is called to update the broker SL, and the internal `current_sl` is updated.
    *   **Important:** The dynamic SL only trails the price when it's in loss relative to the entry *before* TP1 is hit. Once TP1 is hit, the SL is managed by the TP progression logic (moved to entry, TP1, TP2, etc.).

**Step-by-Step Example (BUY Trade - Reflecting Actual Code Logic):**

Assume:
*   Entry Price: 1.25000
*   Original SL: 1.24900
*   Final TP Price: 1.25500 (50 pips away)
*   Original Lot Size: 1.0 lot

Calculated TPs:
*   TP1 Price: 1.25125
*   TP2 Price: 1.25250
*   TP3 Price: 1.25375
*   Midway TP4 Price: 1.254375
*   TP4 Price: 1.25500

Trade Progression:

1.  **Trade Opened:** BUY 1.0 lot @ 1.25000, SL @ 1.24900.
2.  **Price reaches 1.25125 (TP1):**
    *   `ClosePartialPosition(ticket, 1.0 * 0.4)` is called -> 0.4 lots closed.
    *   Remaining volume: 0.6 lots.
    *   `ModifyStopLoss(ticket, 1.25000)` is called -> SL moved to Breakeven (1.25000).
    *   `tp1.hit` becomes true.
3.  **Price reaches 1.25250 (TP2):**
    *   `ClosePartialPosition(ticket, 0.6 * 0.3)` is called -> 0.18 lots closed (may be adjusted by `NormalizeDouble` and min/step lot rules).
    *   Remaining volume: ~0.42 lots.
    *   `ModifyStopLoss(ticket, 1.25125)` is called -> SL moved to TP1 price (1.25125).
    *   `tp2.hit` becomes true.
4.  **Price reaches 1.25375 (TP3):**
    *   `ClosePartialPosition(ticket, 0.42 * 0.2)` is called -> ~0.084 lots closed (may be adjusted).
    *   Remaining volume: ~0.336 lots.
    *   `ModifyStopLoss(ticket, 1.25250)` is called -> SL moved to TP2 price (1.25250).
    *   `tp3.hit` becomes true.
5.  **Price reaches 1.254375 (Midway TP4):**
    *   `ModifyStopLoss(ticket, 1.25375)` is called -> SL moved to TP3 price (1.25375).
    *   `midway_hit` becomes true.
6.  **Price reaches 1.25500 (TP4):**
    *   `Trade.PositionClose(ticket)` is called -> Remaining ~0.336 lots closed.
    *   Trade is finished.

**Alternative Scenario: Reversal after TP1**

1.  **Trade Opened:** BUY 1.0 lot @ 1.25000, SL @ 1.24900.
2.  **Price reaches 1.25125 (TP1):**
    *   0.4 lots closed.
    *   Remaining volume: 0.6 lots.
    *   SL moved to Breakeven (1.25000) via `ModifyStopLoss`.
    *   `tp1.hit` becomes true.
3.  **Price Reverses:** The price fails to reach TP2 and instead drops back down.
4.  **Price reaches 1.25000 (Entry Price / Breakeven SL):**
    *   The `ManagePositions` function detects `tp1.hit` is true and `current_price <= entry_price`.
    *   The EA explicitly calls `Trade.PositionClose(ticket)`.
    *   The remaining 0.6 lots are closed.
    *   This EA action ensures closure, potentially slightly before or concurrently with the broker executing the SL previously set at 1.25000.
    *   The trade is finished at breakeven (excluding costs).

**Edge Case Examples:**

Here are some edge cases based on the EA's logic in `ManagePositions` and helper functions:

1.  **BUY Trade: Price Gaps Over TP1 & TP2**
    *   **Scenario:** Price is below TP1 (1.25125). The next tick price jumps to 1.25260 (above TP2).
    *   **Logic (`ManagePositions`):** The code checks TPs sequentially (TP4, Midway, TP3, TP2, TP1). It will first evaluate `current_price >= g_positions[i].tp3.price` (false), then `current_price >= g_positions[i].tp2.price` (true).
    *   **Outcome:** TP2 logic executes. 30% of the *current* volume is closed (assuming TP1 wasn't hit previously, this is 30% of original). SL is moved to TP1 price (1.25125). `tp2.hit` becomes true. The TP1 check is *skipped* because it's in an `else if` block after the TP2 check.

2.  **SELL Trade: Partial Close Failure at TP1**
    *   **Scenario:** Price reaches TP1 (e.g., 1.24875 for a sell from 1.25000). The EA calls `ClosePartialPosition(ticket, original_volume * 0.4)`.
    *   **Logic (`ClosePartialPosition`, `ManagePositions`):** Assume `Trade.PositionClosePartial()` returns `false` (e.g., due to requote, connection issue, invalid volume after rounding).
    *   **Outcome:** `ClosePartialPosition` returns `false`. The `if (ClosePartialPosition(...))` block in `ManagePositions` for TP1 does not execute. `tp1.hit` remains `false`. The SL is *not* moved to Breakeven. The position continues with its original (or dynamically adjusted) SL, and the full 1.0 lot remains open. The EA will attempt the partial close again on subsequent ticks if the price remains at or below TP1.

3.  **BUY Trade: Max Bars Reached Before TP/SL**
    *   **Scenario:** A BUY trade is open. Price meanders between entry and TP1 for a long time. `MaxBarsInTrade` is set to 48.
    *   **Logic (`ManagePositions`):** On each tick, the code calculates `bars_held = (int)((TimeCurrent() - g_positions[i].open_time) / (PeriodSeconds(_Period)))`. When `bars_held` reaches 48.
    *   **Outcome:** The condition `if (bars_held >= MaxBarsInTrade)` becomes true. `Trade.PositionClose(ticket)` is called, closing the *entire remaining* position regardless of profit/loss or proximity to TP/SL levels. The position is removed from the tracker.

4.  **SELL Trade: Breakeven Retracement**
    *   **Scenario:** SELL 1.0 lot @ 1.25000. Price drops to TP1 (e.g., 1.24875). Partial close (0.4 lots) succeeds. SL is moved to Breakeven (1.25000). Price then rallies back up.
    *   **Logic (`ManagePositions`):** The condition `else if (g_positions[i].tp1.hit && current_price >= g_positions[i].entry_price)` becomes true when the Ask price hits 1.25000.
    *   **Outcome:** `Trade.PositionClose(ticket)` is called by the EA. The remaining 0.6 lots are closed at the entry price (1.25000), resulting in a breakeven trade on the remaining portion (ignoring costs). This happens concurrently with or just before the broker might trigger the SL placed at the same level.

5.  **BUY Trade: Partial Close Volume Adjustment at TP2**
    *   **Scenario:** BUY 0.05 lots @ 1.25000. `min_lot` is 0.01. Price hits TP1 (1.25125). Partial close attempts `0.05 * 0.4 = 0.02` lots. This succeeds. Remaining volume is 0.03 lots. Price then hits TP2 (1.25250).
    *   **Logic (`ManagePositions`, `ClosePartialPosition`):** `ManagePositions` calls `ClosePartialPosition(ticket, 0.03 * 0.3)`. The requested volume is `0.009` lots.
    *   **Inside `ClosePartialPosition`:**
        *   `close_volume` starts as `0.009`.
        *   `if (close_volume < min_lot)` becomes true (0.009 < 0.01).
        *   `close_volume` is set to `min_lot` (0.01).
        *   The code checks if remaining volume (`current_volume` [0.03] - `close_volume` [0.01]) would be less than `min_lot`. `0.03 - 0.01 = 0.02`, which is not less than 0.01, so this check passes.
        *   `rounded_volume` becomes 0.01 (assuming `lot_step` allows it).
    *   **Outcome:** `Trade.PositionClosePartial(ticket, 0.01)` is called. 0.01 lots are closed (instead of the calculated 0.009). Remaining volume becomes 0.02 lots. SL is moved to TP1 price. `tp2.hit` becomes true.

6.  **BUY Trade: Dynamic SL Adjusts, Then Price Hits TP1**
    *   **Scenario:** BUY 1.0 lot @ 1.25000. Original SL @ 1.24900. `DynamicSLDistance` implies a 5-pip trail distance.
    *   Price drops to 1.24980 (below entry, but above original SL).
    *   **Logic (Dynamic SL):** `!tp1.hit` is true. `current_price < entry_price` is true. `new_sl` calculation: `distance` = 5 pips (e.g., 0.00050). `current_price - distance` = 1.24930. `MathMin(entry_price, 1.24930)` = 1.24930. `MathMax(1.24930, original_sl [1.24900])` = 1.24930. `ModifyStopLoss` is called to move SL from 1.24900 to 1.24930.
    *   Price then reverses and rallies, eventually hitting TP1 (1.25125).
    *   **Logic (TP1):** The TP1 logic executes as normal. 40% is closed. `ModifyStopLoss` is called to move the SL from its current position (1.24930) to Breakeven (1.25000). `tp1.hit` becomes true.
    *   **Outcome:** The dynamic SL adjusted the stop loss while the trade was in drawdown before TP1. Once TP1 was hit, the multi-TP logic took over SL management, moving it to breakeven, overriding the previous dynamic SL level.

7.  **SELL: Dynamic SL Active, Then Price Hits TP1**
    *   **Setup:** SELL @ 1.25000, Orig SL @ 1.25100, Dyn SL Distance 5 pips.
    *   **Action:** Price rallies to 1.25020 (above entry). Dynamic SL moves SL down from 1.25100 towards `1.25020 + 0.00050 = 1.25070`. New SL is 1.25070.
    *   **Next:** Price reverses and drops, hitting TP1 (e.g., 1.24875).
    *   **Outcome:** TP1 logic executes. Partial close occurs. SL is moved from 1.25070 to Breakeven (1.25000). Dynamic SL is no longer active.

8.  **BUY: Dynamic SL Moves SL Close to Entry, Then TP1 Hit**
    *   **Setup:** BUY @ 1.25000, Orig SL @ 1.24900, Dyn SL Distance 5 pips.
    *   **Action:** Price drops to 1.24960. Dynamic SL moves SL to `1.24960 - 0.00050 = 1.24910`.
    *   **Next:** Price rallies and hits TP1 (1.25125).
    *   **Outcome:** TP1 logic executes. Partial close occurs. SL is moved from 1.24910 to Breakeven (1.25000).

9.  **SELL: TP1 Hit (SL at BE), Price Rallies Near BE, Then Hits TP2**
    *   **Setup:** SELL @ 1.25000. TP1 hit, SL moved to 1.25000. Remaining volume 0.6 lots.
    *   **Action:** Price rallies to 1.24995 (very close to BE SL).
    *   **Next:** Price reverses again and drops, hitting TP2 (e.g., 1.24750).
    *   **Outcome:** TP2 logic executes. Partial close (30% of 0.6 lots) occurs. SL is moved from Breakeven (1.25000) down to TP1 price (1.24875).

10. **BUY: TP2 Hit (SL at TP1), Price Drops and Hits TP1 SL**
    *   **Setup:** BUY @ 1.25000. TP1 hit, TP2 hit. SL is now at TP1 price (1.25125). Remaining volume ~0.42 lots.
    *   **Action:** Price fails to reach TP3 and drops back down.
    *   **Next:** Price hits the SL at 1.25125.
    *   **Outcome:** The broker executes the Stop Loss order at 1.25125. The remaining ~0.42 lots are closed. The EA detects the position is closed and removes it from tracking.

11. **SELL: TP3 Hit (SL at TP2), Price Rallies and Hits TP2 SL**
    *   **Setup:** SELL @ 1.25000. TP1, TP2, TP3 hit. SL is now at TP2 price (e.g., 1.24750). Remaining volume ~0.336 lots.
    *   **Action:** Price fails to reach Midway/TP4 and rallies back up.
    *   **Next:** Price hits the SL at 1.24750.
    *   **Outcome:** Broker executes SL at 1.24750. Remaining ~0.336 lots closed. EA removes position.

12. **BUY: Midway TP4 Hit (SL at TP3), Price Drops and Hits TP3 SL**
    *   **Setup:** BUY @ 1.25000. TP1, TP2, TP3, Midway TP4 hit. SL is now at TP3 price (1.25375). Remaining volume ~0.336 lots.
    *   **Action:** Price fails to reach TP4 and drops back down.
    *   **Next:** Price hits the SL at 1.25375.
    *   **Outcome:** Broker executes SL at 1.25375. Remaining ~0.336 lots closed. EA removes position.

13. **SELL: Dynamic SL Active, Then Max Bars Reached**
    *   **Setup:** SELL @ 1.25000. Orig SL @ 1.25100. Price rallies, Dynamic SL moves SL down to 1.25070. `MaxBarsInTrade` = 48.
    *   **Action:** Price meanders above entry but below the dynamic SL for 48 bars. TP1 is never hit.
    *   **Outcome:** `MaxBarsInTrade` logic triggers. `Trade.PositionClose()` is called, closing the entire position at the current market price. Dynamic SL becomes irrelevant.

14. **BUY: TP1 Hit (SL at BE), Then Max Bars Reached**
    *   **Setup:** BUY @ 1.25000. TP1 hit. SL moved to Breakeven (1.25000). Remaining volume 0.6 lots. `MaxBarsInTrade` = 48.
    *   **Action:** Price meanders between BE and TP2 for 48 bars since the trade *opened*.
    *   **Outcome:** `MaxBarsInTrade` logic triggers. `Trade.PositionClose()` is called, closing the remaining 0.6 lots at the current market price.

15. **BUY: Price Gaps Over TP1, Dynamic SL Was Active**
    *   **Setup:** BUY @ 1.25000. Orig SL @ 1.24900. Price dropped, Dynamic SL moved SL to 1.24930.
    *   **Action:** Price gaps from below TP1 (e.g., 1.25100) to above TP1 (e.g., 1.25150) on the next tick.
    *   **Outcome:** TP1 logic executes. Partial close (40%) occurs. SL is moved from 1.24930 to Breakeven (1.25000). `tp1.hit` becomes true. Dynamic SL is now inactive for this trade.

16. **SELL: Price Gaps Over TP1 and TP2, Dynamic SL Was Active**
    *   **Setup:** SELL @ 1.25000. Orig SL @ 1.25100. Price rallied, Dynamic SL moved SL down to 1.25070.
    *   **Action:** Price gaps from above TP1 (e.g., 1.24900) to below TP2 (e.g., 1.24700) on the next tick.
    *   **Outcome:** `ManagePositions` checks TP4 (false), Midway (false), TP3 (false), then TP2 (true). TP2 logic executes. Partial close (30% of current) occurs. SL is moved from 1.25070 to TP1 price (1.24875). `tp2.hit` becomes true. TP1 logic is skipped. Dynamic SL is inactive.
