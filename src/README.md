# MoneyMonster Expert Advisor - Software Specification

**Version:** Based on analysis of `MoneyMonster.mq5` code (April 28, 2025)
**Platform:** MetaTrader 5 (MQL5)

## 1. Overview

MoneyMonster is an automated trading system (Expert Advisor - EA) designed for the MetaTrader 5 platform. It primarily utilizes Volume Profile analysis across multiple timeframes to identify potential trading opportunities. The EA incorporates various filters, risk management features, and position management techniques to execute and manage trades.

## 2. Core Features

*   **Volume Profile Analysis:** Calculates and utilizes Value Area High (VAH), Value Area Low (VAL), and Point of Control (POC) for the current and two higher timeframes.
*   **Multi-Timeframe Confirmation:** Optionally requires agreement between signals generated on different timeframes.
*   **Configurable Filters:** Includes optional filters for Volume Spikes, ATR Volatility, Trend direction, Key Level proximity, Breakout/Rejection patterns, and specific Trading Hours.
*   **Risk Management:** Calculates trade volume (lot size) based on a user-defined risk percentage of the account balance and the calculated stop-loss distance.
*   **Dynamic Position Management:**
    *   Multiple partial Take Profit (VTP) levels.
    *   Dynamic trailing Stop Loss.
    *   Safety nets (move SL to Break-Even, close if original SL is hit).
    *   Option to close positions on opposite signals.
    *   Maximum holding period based on bars.
    *   Optional loss recovery multiplier.
*   **Visual Interface:** Displays the Volume Profile, key levels (VAH, VAL, POC), and an information panel directly on the chart.
*   **Persistence:** Loads and manages existing positions opened by the EA upon initialization.
*   **Trade Logging:** Records key trade events (open, partial close, SL modify, close) to the Experts log.

## 3. Strategy Logic

### 3.1. Volume Profile Calculation (`CalculateVolumeProfile`, `CalculateVolumeProfileTF`)

*   Calculates the Volume Profile for a specified period (`VolumeProfilePeriod`) and timeframe.
*   Determines the High and Low of the period.
*   Divides the price range into a defined number of levels (`VolumeBars`).
*   Distributes the tick volume (or bar volume as fallback) proportionally across the price levels touched by each bar within the period.
*   Identifies the **Point of Control (POC):** The price level with the highest accumulated volume.
*   Calculates the **Value Area (VA):** The price range where a specified percentage (`ValueAreaPercent`) of the total volume occurred, centered around the POC.
    *   **Value Area High (VAH):** The upper boundary of the Value Area.
    *   **Value Area Low (VAL):** The lower boundary of the Value Area.
*   These calculations are performed for the current chart timeframe and optionally for two higher timeframes (`VP_HigherTF`, `VP_HigherTF2`).

### 3.2. Core Signal Generation (`GetVolumeProfileSignal`, `GetVolumeProfileSignalTF`)

The basic signal logic compares the current price and recent volume patterns to the calculated Volume Profile levels (VAH, VAL, POC):

*   **Buy Signal Conditions:**
    *   Price breaks above VAH with increasing volume (current bar volume > previous bar volume).
    *   *OR* Price is above POC but below VAH, the current bar is bullish (Close > Open), and volume is increasing.
*   **Sell Signal Conditions:**
    *   Price breaks below VAL with *decreasing* volume (current bar volume < previous bar volume).
    *   *OR* Price is below POC but above VAL, the current bar is bearish (Close < Open), and volume is *decreasing*.

*Note: The decreasing volume condition for sells seems counter-intuitive and might be a specific strategy element or potential area for review.*

### 3.3. Filters and Confirmations (`CheckForSignals`)

Before executing a trade based on the core signal, several optional filters and checks can be applied:

*   **Trading Hours (`UseTradingHours`):** Restricts trading to specific hours if enabled.
*   **Volume Spike Filter (`UseVolumeSpikeFilter`):** Checks for abnormal volume spikes (details require inspecting the function body).
*   **ATR Volatility Filter (`UseATRFilter`):** Compares current ATR to a dynamic threshold (`g_dynamicATRThresholdFactor`) to filter trades during low/high volatility (details require inspecting the function body).
*   **Breakout/Rejection (`UseBreakoutRejection`, `CheckBreakoutRejection`):**
    *   Identifies specific candle patterns indicating a breakout *through* or rejection *at* VAH/VAL/POC levels.
    *   Requires increasing volume for confirmation.
    *   Can generate signals independently or act as a filter.
*   **Key Levels Entry (`UseKeyLevelsEntry`, `IsPriceAtKeyLevel`):** Checks if the current price is within a defined proximity (`DistanceFromVPLevels` based on level height) to VAH, VAL, or POC. Can be used to filter entries, requiring price to be near these levels.
*   **Trend Filter (`UseTrendFilter`):** Determines the trend on the current and/or higher timeframes (likely using Moving Averages or similar indicators - details require inspecting the function body) and only allows trades in the direction of the trend.
*   **Multi-Timeframe Agreement (`RequireMTFAgreement`):** If enabled, requires the trading signal generated on the current timeframe to align with signals generated on one or both higher timeframes (`VP_HigherTF`, `VP_HigherTF2`). If disabled, only the current timeframe signal is used.

The final signal (`g_current_signal`) is determined after applying all enabled filters and confirmations.

## 4. Trade Execution (`ExecuteTrade`)

*   **Pre-computation:** Determines if the symbol is a Forex pair (`g_is_forex_pair`) to adjust pip calculations. Parses the `RiskRewardRatio` input string.
*   **Entry Price:** Uses Ask for Buy orders, Bid for Sell orders.
*   **Stop Loss (SL):**
    *   Calculates a base SL distance based on the detected pair (e.g., 5.0 for XAUUSD, 0.03 for XAGUSD, 10 pips for Forex).
    *   Applies a `DistanceMultiplier` to the base distance.
    *   SL price is set `sl_distance` away from the entry price (below entry for Buy, above entry for Sell).
*   **Take Profit (TP):**
    *   Calculates the final TP distance based on the SL distance and the `g_risk_reward_ratio`.
    *   Sets the final TP price `tp_distance` away from the entry price (above entry for Buy, below entry for Sell).
*   **Volume Take Profits (VTPs):** Defines multiple intermediate TP levels as fractions of the total distance between entry and the final TP:
    *   `vtp1`: 25% of the way to final TP.
    *   `vtp2`: 50% of the way to final TP.
    *   `vtp3`: 75% of the way to final TP.
    *   `vtp35` (Midway TP4): 87.5% of the way to final TP.
*   **Lot Size Calculation:**
    1.  Calculates the monetary risk amount based on `AccountBalance * (RiskPercent / 100.0)`.
    2.  Determines the value per tick (`SYMBOL_TRADE_TICK_VALUE`) and tick size (`SYMBOL_TRADE_TICK_SIZE`).
    3.  Calculates the SL distance in ticks: `Abs(entry_price - sl_price) / tick_size`.
    4.  Calculates the base lot size: `risk_amount / (sl_distance_in_ticks * tick_value)`.
    5.  **Loss Multiplier (`g_apply_loss_multiplier`, `LossMultiplier`):** If the previous trade was a loss and `LossMultiplier > 1.0`, the calculated lot size is multiplied by `LossMultiplier`. The `g_apply_loss_multiplier` flag is then reset.
    6.  Adjusts the calculated lot size to comply with the symbol's minimum/maximum volume (`SYMBOL_VOLUME_MIN`, `SYMBOL_VOLUME_MAX`) and volume step (`SYMBOL_VOLUME_STEP`).
*   **Order Placement:**
    *   Uses `CTrade::Buy` or `CTrade::Sell` to place the market order with the calculated SL, final TP, and lot size.
    *   Includes retry logic with increasing slippage tolerance (`SetDeviationInPoints`) in case of initial failure (e.g., requotes, context busy).
    *   Assigns the `MagicNumber` to the order.
*   **Position Tracking:** If the order is placed successfully, a `POSITION_TRACKER` struct is created and added to the `g_positions` array, storing details like ticket, entry price, SL/TP levels, volumes, and hit status for VTPs.

## 5. Position Management (`ManagePositions`)

This function iterates through all open positions managed by the EA (`g_positions` array) on every tick:

*   **Safety Net (Original SL):** Checks if the current price has crossed the *original* stop-loss level. If so, the position is closed immediately, regardless of any subsequent SL adjustments.
*   **Opposite Signal Close (`CloseOnOppositeSignal`):** If enabled, checks if a new, confirmed signal (`g_current_signal`) has formed in the opposite direction to the open position. If so, the existing position is closed.
*   **Take Profit Handling:**
    *   **Final TP:** If the price reaches the final TP (`tp4.price`), the entire remaining position is closed.
    *   **Partial TP (VTPs):**
        *   **VTP1 (`tp1.price`):** If hit, closes 40% (`tp1.position_part`) of the *original* volume. Moves SL to Break-Even (`entry_price`). Sets `tp1.hit = true`.
        *   **VTP2 (`tp2.price`):** If hit (and `tp1` was hit), closes 30% (`tp2.position_part`) of the *original* volume. Moves SL to VTP1 level. Sets `tp2.hit = true`.
        *   **VTP3 (`tp3.price`):** If hit (and `tp2` was hit), closes 20% (`tp3.position_part`) of the *original* volume. Moves SL to VTP2 level. Sets `tp3.hit = true`.
        *   **VTP3.5 (`midway_tp4`):** If hit (and `tp3` was hit), moves SL to VTP3 level. Sets `midway_hit = true`. (No partial close here).
    *   **Partial Closing Logic (`ClosePartialPosition`):** Ensures that the volume to close is at least the minimum allowed lot size (`SYMBOL_VOLUME_MIN`) and respects the lot step. If the remaining volume would be less than the minimum, it closes the entire position instead.
*   **Stop Loss Management:**
    *   **Midway-to-TP1 Safety Net:** If the price reaches the halfway point to VTP1 (`midway_tp1`) *before* VTP1 is hit, the SL is immediately moved to Break-Even (`entry_price`), and the dynamic SL adjustment is disabled (`dynamic_sl_disabled = true`) for this position.
    *   **Break-Even After VTP1:** If VTP1 has been hit and the price retraces back to the entry price, the remaining position is closed at Break-Even.
    *   **Dynamic Trailing SL:**
        *   Active only *before* VTP1 is hit and if the midway safety net hasn't disabled it.
        *   Only trails when the price is moving *against* the initial entry (e.g., price below entry for a Buy).
        *   Calculates a new SL based on the current price plus/minus a fixed distance (`DynamicSLDistance` in pips/points).
        *   The new SL cannot be worse than the original SL or the entry price (once moved to BE).
        *   Ensures the new SL respects the broker's minimum stop level distance (`SYMBOL_TRADE_STOPS_LEVEL`).
        *   Uses `CTrade::PositionModify` to update the SL if it has changed.
*   **Max Bars in Trade (`MaxBarsInTrade`):** If a position has been open for more than the specified number of bars on the current timeframe, it is closed.
*   **Position Removal:** When a position is fully closed (or fails selection), it's removed from the `g_positions` tracking array using `RemovePosition`.

## 6. Configuration Parameters (Inputs)

*(Based on global variables and usage)*

*   `MagicNumber`: Unique identifier for trades placed by this EA instance.
*   `RiskPercent`: Percentage of account balance to risk per trade (e.g., 1.0 for 1%).
*   `RiskRewardRatio`: String representing the desired Risk:Reward ratio (e.g., "1:3"). Parsed to get the reward multiplier.
*   `DistanceMultiplier`: Multiplier applied to the default SL/TP distances calculated based on the pair.
*   `VolumeProfilePeriod`: Number of bars used for Volume Profile calculation.
*   `VolumeBars`: Number of price levels (bins) for the Volume Profile histogram.
*   `ValueAreaPercent`: Percentage of volume defining the Value Area (typically 70).
*   `VP_HigherTF`: Timeframe for the first higher timeframe VP analysis (e.g., `PERIOD_H1`).
*   `VP_HigherTF2`: Timeframe for the second higher timeframe VP analysis (e.g., `PERIOD_H4`).
*   `UseVolumeSpikeFilter`: Enable/disable the Volume Spike filter.
*   `UseATRFilter`: Enable/disable the ATR Volatility filter.
*   `ATRPeriod`: Period for ATR calculation.
*   `ATRThresholdFactor`: Factor used in the ATR filter logic.
*   `UseTrendFilter`: Enable/disable the Trend filter.
*   `TrendFilterTF`: Timeframe for trend determination.
*   `MA_Fast_Period`, `MA_Slow_Period`: Periods for Moving Averages used in trend filter (assumed).
*   `UseKeyLevelsEntry`: Enable/disable the Key Levels proximity filter.
*   `DistanceFromVPLevels`: Proximity factor (relative to level height) for the Key Levels filter.
*   `UseBreakoutRejection`: Enable/disable the Breakout/Rejection pattern filter/signal.
*   `RequireMTFAgreement`: Enable/disable the requirement for multi-timeframe signal confirmation.
*   `UseTradingHours`: Enable/disable trading time restrictions.
*   `TradingStartTime`, `TradingEndTime`: Start and end times for allowed trading (HH:MM format).
*   `DynamicSLDistance`: Distance (in pips/points) for the dynamic trailing stop loss.
*   `MaxBarsInTrade`: Maximum number of bars a trade can remain open.
*   `CloseOnOppositeSignal`: Enable/disable closing positions on opposite signals.
*   `LossMultiplier`: Lot size multiplier applied after a losing trade (e.g., 2.0 for Martingale-like behavior, 1.0 to disable).
*   `g_bull_color`, `g_bear_color`: Colors for chart customization.

## 7. Visual Elements

*   **Volume Profile Display (`DisplayVolumeProfile`):** Draws the calculated Volume Profile histogram directly on the chart using `OBJ_RECTANGLE` objects. The width of the rectangles represents the volume at each price level. VAH, VAL, and POC are typically highlighted or drawn as separate lines (`DrawHorizontalLine`).
*   **Information Panel (`CreatePanel`, `UpdatePanel`):** Displays key EA information in a panel on the chart:
    *   EA Name ("MoneyMonster EA")
    *   Trading Pair
    *   EA Status (Active/Stopped)
    *   Current Signal (Buy/Sell/None)
    *   Current VAH, POC, VAL values
    *   Number of open positions
    *   Details of each open position (Type, Volume, P/L)
*   **Chart Customization (`CustomizeChart`):** Sets chart properties like bar mode, bull/bear colors, and hides grid/period separators.

## 8. Logging (`LogTradeEvent`, `DebugPrint`)

*   Uses `Print` and custom formatting (`LogTradeEvent`) to output key events (trade open, partial close, SL modification, close reasons like STOP_EA or MAX_BARS) to the MetaTrader 5 "Experts" log tab.
*   Uses `DebugPrint` for more detailed internal logging during development or troubleshooting.

## 9. Installation and Usage

1.  Place the `MoneyMonster.mq5` file in your MetaTrader 5 `MQL5/Experts` directory.
2.  Compile the file in MetaEditor (or use the provided compile scripts if applicable). This will create `MoneyMonster.ex5`.
3.  In MetaTrader 5, open the chart for the desired symbol and timeframe.
4.  Drag the `MoneyMonster` EA from the Navigator window onto the chart.
5.  Configure the input parameters in the EA properties window.
6.  Ensure "Algo Trading" is enabled in MetaTrader 5.
7.  The EA will initialize (`OnInit`), load existing positions (`LoadExistingPositions`), calculate the initial Volume Profile, create the panel, and start monitoring for trading opportunities on each new tick (`OnTick`).
