//+------------------------------------------------------------------+
//|                                                MoneyMonster.mq5 |
//|                               Copyright 2025, MetaQuotes Ltd.   |
//|                                 https://www.metaquotes.net      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.metaquotes.net"
#property version   "1.00"
#property description "MoneyMonster - Volume Profile Trader EA"
#property strict
// Include necessary libraries
#include <Trade\Trade.mqh>
#include <Arrays\ArrayObj.mqh>
#include <Files\File.mqh> // Include for file operations
// Enumerations
enum ENUM_TRADE_SIGNAL {
   SIGNAL_NONE,   // No signal
   SIGNAL_BUY,    // Buy signal
   SIGNAL_SELL    // Sell signal
};
//--- input parameters
input string   GeneralSection         = "====== General Settings ======"; // General Settings
input int      MagicNumber            = 12345;                           // Magic Number
input bool     StopEA                 = false;                           // Stop EA (closes all positions)
input bool     UseTradingHours        = true;                            // Use trading hours restriction
input int      TradingStartHour       = 8;                               // Trading start hour (GMT)
input int      TradingEndHour         = 20;                              // Trading end hour (GMT)
input string   VolumeProfileSection   = "====== Volume Profile Settings ======"; // Volume Profile Settings
input int      VolumeProfilePeriod    = 20;                              // Volume Profile Period (bars)
input double   ValueAreaPercent       = 70;                              // Value Area Percent (%)
input int      VolumeBars             = 30;                              // Number of volume bars to display
input string   RiskSection            = "====== Risk Management ======"; // Risk Management Settings
input double   RiskPercent            = 1.0;                             // Risk Percent (%)
input double   DynamicSLDistance      = 5.0;                             // Dynamic SL Distance (pips)
// Distance scaling for SL and TP
input double   DistanceMultiplier     = 2.0;                             // Multiplier for SL and TP distances
input double   LossMultiplier         = 1.0;                             // Lot size multiplier after a loss (1.0 = disabled)
// Risk:Reward Ratio input (e.g. "1:3" means risk 1, reward 3)
input string   RiskRewardRatio       = "1:3";                            // Risk:Reward Ratio (risk:reward)
// Trend Filter Settings
input string   TrendFilterSection     = "====== Trend Filter Settings ======"; // Trend Filter Settings
input bool     UseTrendFilter         = true;                            // Enable Trend Filter
input int      TrendMAPeriod          = 100;                             // Trend Moving Average Period
input ENUM_MA_METHOD TrendMAMethod    = MODE_SMA;                        // Trend Moving Average Method
input ENUM_APPLIED_PRICE TrendMAPrice = PRICE_CLOSE;                     // Trend Moving Average Applied Price
input int MaxBarsInTrade = 48; // Maximum bars to hold a trade before forced exit (default: 48 bars)
input ENUM_TIMEFRAMES VP_HigherTF = PERIOD_H1; // Higher timeframe for volume profile confirmation
input ENUM_TIMEFRAMES VP_HigherTF2 = PERIOD_H4; // Second higher timeframe for VP confirmation
// New global variables for volume profile key levels entry
input string   VPKeyLevelsSection    = "====== Volume Profile Key Levels ======"; // Volume Profile Key Levels
input bool     UseKeyLevelsEntry     = true;                              // Use entry only at key VP levels
input bool     AvoidMiddleValueArea  = true;                              // Avoid trading in middle of value area
input double   DistanceFromVPLevels  = 0.5;                               // Max distance from VP levels (% of level height)
input bool     RequireMTFAgreement   = true;                              // Require multi-timeframe agreement
input bool     UseBreakoutRejection  = true;                              // Use breakout/rejection patterns
// Input Parameters
// ... existing parameters ...
input bool   UseATRFilter        = true;         // Use ATR Volatility Filter
input int    ATRPeriod           = 14;           // ATR Period for current volatility
input int    ATRAveragePeriod    = 100;          // Period for calculating average ATR
input double DynamicATRThresholdFactor = 0.75;   // Required ATR % of Average ATR (e.g., 0.75 = 75%)
// Volume Spike Filter Settings
input string   VolumeSpikeSection    = "====== Volume Spike Filter ======"; // Volume Spike Filter
input bool     UseVolumeSpikeFilter  = true;         // Enable Volume Spike Filter
input int      VolumeSpikePeriod     = 20;           // Period for average volume calculation
input double   VolumeSpikeMultiplier = 1.5;          // Required volume multiplier (e.g., 1.5 = 150% of average)

// Trailing Stop Settings
input string   TrailingStopSection   = "====== Trailing Stop Settings ======"; // Trailing Stop Settings
input bool     UseTrailingStop       = true;         // Enable Trailing Stop after VTP4
input double   TrailingStopDistance  = 5.0;          // Trailing Stop Distance (pips)

// Close on Opposite Signal Setting
input string   OppositeSignalSection = "====== Opposite Signal Settings ======"; // Opposite Signal Settings
input bool     CloseOnOppositeSignal = true;         // Close trade if opposite signal occurs
// Global variables
CTrade         Trade;                  // Trading object
bool           g_initialized = false;  // Flag to check if EA is properly initialized
string         g_detected_pair = "";   // Detected pair name
double         g_vah = 0;              // Value Area High
double         g_val = 0;              // Value Area Low
double         g_poc = 0;              // Point of Control
ENUM_TRADE_SIGNAL g_current_signal = SIGNAL_NONE; // Current trade signal
bool           g_in_position = false;  // Flag to check if we're in a position
int            g_chart_id = 0;         // Chart ID for display panel
string         g_panel_name = "MoneyMonsterPanel"; // Panel name
color          g_bull_color = clrGreen; // Bull candle color
color          g_bear_color = clrRed;   // Bear candle color
bool           g_stopping = false;     // Flag indicating if EA is in stopping mode
double         g_point;                // Point value
int            g_digits;               // Digits for the current symbol
bool           g_is_forex_pair = false; // Flag to check if it's a forex pair
bool           g_use_trading_hours = true; // Enable/disable trading hours restriction
int            g_trading_start_hour = 8;   // Default trading start hour (GMT)
int            g_trading_end_hour = 20;    // Default trading end hour (GMT)
// For tracking if price is near key volume profile levels
double         g_level_height = 0;                                        // Current level height
bool           g_is_at_key_level = false;                                 // Flag if price is at key level
bool           g_is_vpbreakout = false;                                   // Flag if there's a breakout
bool           g_is_vprejection = false;                                  // Flag if there's a rejection
string         g_key_level_type = "";                                     // Type of key level (VAH, VAL, POC)
// TP Tracking
struct TP_LEVEL {
   double price;          // TP price level
   bool hit;              // Whether this level was hit
   double position_part;  // Position part to close at this level
};
struct POSITION_TRACKER {
   ulong ticket;          // Position ticket
   double entry_price;    // Entry price
   double original_sl;    // Original stop loss
   double current_sl;     // Current stop loss
   double original_volume; // Original volume
   double current_volume; // Current volume
   TP_LEVEL entry;
   TP_LEVEL tp1;          // TP1 level
   TP_LEVEL tp2;          // TP2 level
   TP_LEVEL tp3;          // TP3 level
   TP_LEVEL tp4;          // TP4 level
   double midway_tp4;     // Midway to TP4
   bool midway_hit;       // Flag for midway hit
   double midway_tp1;     // Midway to TP1
   bool midway_tp1_hit;   // Flag for midway to TP1 hit
   double vtp1_5;         // VTP1.5 - midway from entry to TP1
   bool dynamic_sl_disabled; // Flag to disable dynamic SL
   ENUM_POSITION_TYPE position_type; // Position type (buy/sell)
   datetime open_time; // Time when the position was opened
};
// Array to store position tracking data
POSITION_TRACKER g_positions[];
// Use 0 for chart_id to ensure objects are created on the current chart
#define PANEL_CHART_ID 0
string         g_last_debug_message = ""; // Last debug message for deduplication
double         g_dynamicATRThresholdFactor = 0.75; // Effective ATR Threshold Factor used in calculations
bool           g_apply_loss_multiplier = false; // Flag to apply loss multiplier on next trade
string         g_log_file_name = "MoneyMonster.log"; // Log file name
double         g_risk_reward_ratio = 3.0; // Default reward/risk ratio (e.g. 3.0 for 1:3)
//+------------------------------------------------------------------+
//| Centralized debug print to avoid duplicate consecutive messages   |
//| and write the latest status to a dedicated log file.             |
//+------------------------------------------------------------------+
void DebugPrint(string msg) {
   if (g_last_debug_message == msg) return;
    // Print to standard Experts log (optional, can be removed if only file log is desired)
    g_last_debug_message = msg;
    // Write the latest status to the dedicated log file
    int handle = FileOpen(g_log_file_name, FILE_WRITE | FILE_TXT | FILE_ANSI); // Overwrite mode
    if (handle == INVALID_HANDLE) {
       Print(msg);
       return;
    }
    // Get current time for timestamp
    datetime now = TimeCurrent();
    string timestamp = TimeToString(now, TIME_DATE | TIME_SECONDS);
    // Write timestamp and message
    FileWriteString(handle, timestamp + " | " + msg + "\n");
    // Close the file handle
    FileClose(handle);
}
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   // Initialize trading object
   Trade.SetExpertMagicNumber(MagicNumber);
   // Get chart info
   g_chart_id = 0; // Always use 0 for current chart
   // Store point and digits for price calculations
   g_point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   g_digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   // Detect if this is a forex pair (for pip value calculation)
   g_is_forex_pair = (g_digits == 4 || g_digits == 5);
   // Initialize arrays
   ArrayResize(g_positions, 0);
   // Detect which pair we're trading
   if (!DetectTradingPair()) {
      DebugPrint("Error: Unsupported trading pair. This EA only works with XAUUSD, XAGUSD, XRPUSD, and GBPUSD.");
      return INIT_FAILED;
   }
   // Customize chart appearance
   CustomizeChart();
   // Create the information panel
   CreatePanel();
   // Load existing positions if any
   LoadExistingPositions();
   // Calculate initial volume profile
   CalculateVolumeProfile();
   double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   int lot_digits = (int)MathLog10(1.0/lot_step);
   DebugPrint(StringFormat("[Init] Symbol=%s min_lot=%.2f max_lot=%.2f lot_step=%.2f lot_digits=%d", _Symbol, min_lot, max_lot, lot_step, lot_digits));
   g_digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   // Validate ATR Average Period and Factor
   if (UseATRFilter) {
      if (ATRAveragePeriod <= ATRPeriod) {
         Print("Warning: ATRAveragePeriod should ideally be larger than ATRPeriod for dynamic threshold calculation.");
      }
      // Validate the INPUT parameter
      if (DynamicATRThresholdFactor <= 0 || DynamicATRThresholdFactor > 2.0) { // Factor should be reasonable
         Print("Warning: Input DynamicATRThresholdFactor is outside a reasonable range (e.g., 0.1 to 2.0). Using default 0.75.");
         g_dynamicATRThresholdFactor = 0.75; // Assign default to the GLOBAL variable
      }
      else {
         g_dynamicATRThresholdFactor = DynamicATRThresholdFactor; // Assign valid input to the GLOBAL variable
      }
   }
   else {
       g_dynamicATRThresholdFactor = DynamicATRThresholdFactor; // Still assign if filter is off, might be used elsewhere later
   }
   // Validate Volume Spike Filter parameters
   if (UseVolumeSpikeFilter) {
      if (VolumeSpikePeriod <= 1) {
         Print("Warning: VolumeSpikePeriod must be greater than 1. Using user value: ", VolumeSpikePeriod);
         // Cannot modify input constant, just warn.
      }
      if (VolumeSpikeMultiplier <= 0) {
         Print("Warning: VolumeSpikeMultiplier must be positive. Using user value: ", VolumeSpikeMultiplier);
         // Cannot modify input constant, just warn.
      }
   }
   // Validate Loss Multiplier
   if (LossMultiplier < 1.0) {
      Print("Warning: LossMultiplier cannot be less than 1.0. Setting to 1.0.");
      // Cannot modify input LossMultiplier directly, but logic in ExecuteTrade will handle it effectively.
   }
   // Initialize log file path (relative to MQL5/Files)
   g_log_file_name = TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\MQL5\\Files\\" + g_log_file_name;
   Print("Log file path: ", g_log_file_name); // Optional: print path to Experts log for verification
   // Clear the log file on initialization
   int handle = FileOpen(g_log_file_name, FILE_WRITE | FILE_TXT);
   if(handle != INVALID_HANDLE) {
      FileWriteString(handle, TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS) + " | EA Initializing...\n");
      FileClose(handle);
   }
   // Parse RiskRewardRatio input
   int colon_pos = StringFind(RiskRewardRatio, ":");
   if (colon_pos > 0) {
      string risk_str = StringSubstr(RiskRewardRatio, 0, colon_pos);
      string reward_str = StringSubstr(RiskRewardRatio, colon_pos + 1);
      double risk_val = StringToDouble(risk_str);
      double reward_val = StringToDouble(reward_str);
      if (risk_val > 0 && reward_val > 0) {
         g_risk_reward_ratio = reward_val / risk_val;
         PrintFormat("RiskRewardRatio '%s' parsed successfully. Using ratio: %.2f", RiskRewardRatio, g_risk_reward_ratio);
      } else {
         g_risk_reward_ratio = 3.0; // fallback default
         PrintFormat("Warning: Invalid RiskRewardRatio input '%s', using default 1:3 (Ratio: %.2f)", RiskRewardRatio, g_risk_reward_ratio);
      }
   } else {
      g_risk_reward_ratio = 3.0; // fallback default
      PrintFormat("Warning: Invalid RiskRewardRatio input format '%s', using default 1:3 (Ratio: %.2f)", RiskRewardRatio, g_risk_reward_ratio);
   }
   g_initialized = true;
   DebugPrint("MoneyMonster EA initialized successfully for " + g_detected_pair);
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   // Clean up panel and chart objects
   ObjectDelete(g_chart_id, g_panel_name);
   for (int i = 0; i < 20; i++) {
      string obj_name = g_panel_name + "_Text_" + IntegerToString(i);
      ObjectDelete(0, obj_name);
   }
   ObjectDelete(0, g_panel_name + "_Text");
   DeleteVolumeProfileObjects();
   // Clean up volume profile lines
   ObjectDelete(0, "VAH_Line");
   ObjectDelete(0, "VAL_Line");
   ObjectDelete(0, "POC_Line");
   DebugPrint("MoneyMonster EA deinitialized. Reason code: " + IntegerToString(reason));
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
   if (!g_initialized) return;
   // If StopEA is activated, close all positions and stop
   if (StopEA && !g_stopping) {
      g_stopping = true;
      DebugPrint("StopEA activated - closing all positions and stopping EA");
      CloseAllPositions();
      UpdatePanel();
      return;
   }
   // If we're in stopping mode but all positions are closed, just update panel and return
   if (g_stopping) {
      if (CountOpenPositions() == 0) {
         UpdatePanel();
         return;
      }
   }
   // Don't proceed with new trades if StopEA is true
   if (StopEA) return;
   // Calculate volume profile if needed (periodically)
   static datetime last_volume_calc = 0;
   datetime current_time = TimeCurrent();
   if (current_time - last_volume_calc > 60) { // Recalculate every minute
      CalculateVolumeProfile();
      last_volume_calc = current_time;
   }
   // Check for signals
   g_current_signal = CheckForSignals();
   // Handle active positions (move SL, check TP levels)
   ManagePositions();
   // Execute trades if there's a signal
   if (g_current_signal != SIGNAL_NONE) {
      // If we already have a position, don't open another one
      if (CountOpenPositions() > 0) {
         DebugPrint("Signal detected but position already exists - not executing new trade");
      }
      else {
         ExecuteTrade(g_current_signal);
      }
   }
   // Update the information panel
   UpdatePanel();
}
//+------------------------------------------------------------------+
//| Remove regexp special symbols from a string                      |
//+------------------------------------------------------------------+
string RemoveRegExpSpecialSymbols(string pair) {
   string specials = "^$.*+?()[]{}|\\";
   string clean = "";
   for (int i = 0; i < StringLen(pair); i++) {
      string ch = StringSubstr(pair, i, 1);
      if (StringFind(specials, ch) < 0) clean += ch;
   }
   return clean;
}
//+------------------------------------------------------------------+
//| Detect which trading pair we're on                               |
//+------------------------------------------------------------------+
bool DetectTradingPair() {
   string symbol = RemoveRegExpSpecialSymbols(_Symbol);
   // Use substring checks instead of regexp (RegularExpressions.mqh is not available)
   if (StringFind(symbol, "XAUUSD") >= 0) {
      g_detected_pair = "XAUUSD";
      return true;
   }
   if (StringFind(symbol, "XAGUSD") >= 0) {
      g_detected_pair = "XAGUSD";
      return true;
   }
   if (StringFind(symbol, "XRPUSD") >= 0) {
      g_detected_pair = "XRPUSD";
      return true;
   }
   if (StringFind(symbol, "GBPUSD") >= 0) {
      g_detected_pair = "GBPUSD";
      return true;
   }
   DebugPrint("[DetectTradingPair] Unsupported trading pair: " + symbol);
   return false;
}
//+------------------------------------------------------------------+
//| Calculate Volume Profile (VAH, VAL, POC)                         |
//+------------------------------------------------------------------+
void CalculateVolumeProfile() {
   int total_bars = MathMin(VolumeProfilePeriod, Bars(_Symbol, PERIOD_CURRENT));
   if (total_bars < 10) {
      DebugPrint("Not enough bars to calculate volume profile");
      return;
   }
   // Define price range
   double high_array[];
   double low_array[];
   // First ensure arrays are properly resized
   ArrayResize(high_array, total_bars);
   ArrayResize(low_array, total_bars);
   // Set as series AFTER resizing
   ArraySetAsSeries(high_array, true);
   ArraySetAsSeries(low_array, true);
   // Copy price data with safety checks
   if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, total_bars, high_array) != total_bars) {
      DebugPrint("Failed to copy high prices, aborting volume profile calculation");
      return;
   }
   if(CopyLow(_Symbol, PERIOD_CURRENT, 0, total_bars, low_array) != total_bars) {
      DebugPrint("Failed to copy low prices, aborting volume profile calculation");
      return;
   }
   // Validate array sizes
   if(ArraySize(high_array) < total_bars || ArraySize(low_array) < total_bars) {
      DebugPrint("Array size mismatch after copy, aborting volume profile calculation");
      return;
   }
   double high = high_array[ArrayMaximum(high_array, 0, total_bars)];
   double low = low_array[ArrayMinimum(low_array, 0, total_bars)];
   double range = high - low;
   if (range <= 0) {
      DebugPrint("Invalid price range (zero or negative), aborting volume profile calculation");
      return;
   }
   // Create price levels and volumes array
   int levels = VolumeBars;
   double level_height = range / levels;
   double price_levels[];
   long level_volumes[];
   ArrayResize(price_levels, levels);
   ArrayResize(level_volumes, levels);
   // Initialize arrays
   for (int i = 0; i < levels; i++) {
      price_levels[i] = low + i * level_height;
      level_volumes[i] = 0;
   }
   // Collect volume data with safety checks
   double volume_array[];
   double open_array[];
   double close_array[];
   // Properly resize arrays first
   ArrayResize(volume_array, total_bars);
   ArrayResize(open_array, total_bars);
   ArrayResize(close_array, total_bars);
   // Set as series AFTER resizing
   ArraySetAsSeries(volume_array, true);
   ArraySetAsSeries(open_array, true);
   ArraySetAsSeries(close_array, true);
   bool data_ok = true;
   // Just use iVolume directly since Copy functions are not available
   for (int i = 0; i < total_bars; i++) {
      volume_array[i] = iVolume(_Symbol, PERIOD_CURRENT, i);
      if(volume_array[i] <= 0 && i < 3) { // We need at least first few bars
         data_ok = false;
         break;
      }
   }
   if(!data_ok) {
      DebugPrint("Failed to get volume data, aborting volume profile calculation");
      return;
   }
   // Get open and close prices with error checking
   if(CopyOpen(_Symbol, PERIOD_CURRENT, 0, total_bars, open_array) != total_bars) {
      for (int i = 0; i < total_bars; i++) {
         open_array[i] = iOpen(_Symbol, PERIOD_CURRENT, i);
      }
   }
   if(CopyClose(_Symbol, PERIOD_CURRENT, 0, total_bars, close_array) != total_bars) {
      for (int i = 0; i < total_bars; i++) {
         close_array[i] = iClose(_Symbol, PERIOD_CURRENT, i);
      }
   }
   // Recheck array sizes to ensure all data is valid
   if(ArraySize(volume_array) < total_bars ||
      ArraySize(open_array) < total_bars ||
      ArraySize(close_array) < total_bars) {
      DebugPrint("Data arrays not completely filled, aborting volume profile calculation");
      return;
   }
   // Rest of function remains unchanged
   for (int i = 0; i < total_bars; i++) {
      double bar_high = high_array[i];
      double bar_low = low_array[i];
      long bar_volume = (long)volume_array[i];
      // Calculate how much of this bar's volume goes to each level
      // Ensure the loop condition uses 'level' and not 'i'
      for (int level = 0; level < levels; level++) { // <<< Explicitly ensure condition is level < levels
         double level_low = price_levels[level];
         double level_high = level_low + level_height;
         // Calculate overlap
         double overlap_low = MathMax(bar_low, level_low);
         double overlap_high = MathMin(bar_high, level_high);
         double overlap = overlap_high - overlap_low;
         if (overlap > 0) {
            // Distribute volume proportionally
            double bar_range = bar_high - bar_low;
            if(bar_range > 0) { // Prevent division by zero
               double volume_portion = (double)bar_volume * (overlap / bar_range);
               level_volumes[level] += (long)volume_portion;
            }
         }
      }
   }
   // Find POC (Point of Control) - level with highest volume
   long max_volume = 0;
   int poc_level = 0;
   // Check if levels array is valid
   if (levels <= 0) {
      DebugPrint("Invalid levels count in volume profile calculation");
      return;
   }
   // Find level with maximum volume with boundary checks
   for (int i = 0; i < levels; i++) {
      if (level_volumes[i] > max_volume) {
         max_volume = level_volumes[i];
         poc_level = i;
      }
   }
   // Check if we found a valid POC
   if (max_volume <= 0 || poc_level >= levels) {
      DebugPrint("No valid volume data found, aborting volume profile calculation");
      return;
   }
   // Ensure poc_level is within bounds
   poc_level = MathMin(poc_level, levels - 1);
   g_poc = price_levels[poc_level] + level_height / 2;
   // Calculate total volume
   long total_volume = 0;
   for (int i = 0; i < levels; i++) {
      total_volume += level_volumes[i];
   }
   // Ensure we have some volume data
   if (total_volume <= 0) {
      DebugPrint("Total volume is zero, aborting volume profile calculation");
      return;
   }
   // Find Value Area (70% of total volume centered around POC)
   long value_area_volume = (long)(total_volume * ValueAreaPercent / 100.0);
   long current_volume = level_volumes[poc_level];
   int upper_level = poc_level;
   int lower_level = poc_level;
   while (current_volume < value_area_volume && (upper_level < levels - 1 || lower_level > 0)) {
      // Decide whether to expand up or down
      long volume_up = (upper_level < levels - 1) ? level_volumes[upper_level + 1] : 0;
      long volume_down = (lower_level > 0) ? level_volumes[lower_level - 1] : 0;
      if (volume_up > volume_down && upper_level < levels - 1) {
         upper_level++;
         current_volume += level_volumes[upper_level];
      }
      else if (lower_level > 0) {
         lower_level--;
         current_volume += level_volumes[lower_level];
      }
      else if (upper_level < levels - 1) {
         upper_level++;
         current_volume += level_volumes[upper_level];
      }
   }
   // Set VAH and VAL
   g_vah = price_levels[upper_level] + level_height;
   g_val = price_levels[lower_level];
   // Display volume profile
   DisplayVolumeProfile(price_levels, level_volumes, levels, level_height);
}
//+------------------------------------------------------------------+
//| Display Volume Profile on chart                                  |
//+------------------------------------------------------------------+
void DisplayVolumeProfile(double &price_levels[], long &level_volumes[], int levels, double level_height) {
   // Delete existing profile first
   DeleteVolumeProfileObjects();
   // Find max volume for scaling
   long max_volume = 0;
   for (int i = 0; i < levels; i++) {
      if (level_volumes[i] > max_volume) max_volume = level_volumes[i];
   }
   double max_volume_d = (double)max_volume;
   // Max width for volume profile (percentage of chart width in pixels)
   int chart_width = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
   int panel_width = 260 + 16; // panel width + margin (match panel)
   int max_bar_width = (int)(chart_width * 0.22); // 22% of chart width for better visibility
   if (max_bar_width < 30) max_bar_width = 30;
   // Place bars on the right side of the chart, leaving space for the panel on the left
   int right_margin = 20; // pixels from right edge
   for (int i = 0; i < levels; i++) {
      double level_price = price_levels[i] + level_height / 2;
      double width_ratio = max_volume_d > 0 ? ((double)level_volumes[i] / max_volume_d) : 0.0;
      int bar_width = (int)(width_ratio * max_bar_width);
      if (bar_width < 2) bar_width = 2;
      string obj_name = "VolProfBar_" + IntegerToString(i);
      // Robust deletion: loop until object is gone
      int del_attempts = 0;
      while (ObjectFind(g_chart_id, obj_name) >= 0 && del_attempts < 3) {
         ObjectDelete(g_chart_id, obj_name);
         Sleep(10);
         del_attempts++;
      }
      // Try to create, retry if error 4101
      int create_attempts = 0;
      bool created = false;
      while (!created && create_attempts < 3) {
         if (ObjectCreate(0, obj_name, OBJ_RECTANGLE_LABEL, 0, 0, 0)) {
            created = true;
         }
         else {
            int err = GetLastError();
            if (err == 4101) { // ERR_OBJECT_ALREADY_EXISTS
               ObjectDelete(0, obj_name);
               Sleep(10);
               create_attempts++;
               continue;
            }
            else {
               Print("[VolumeProfile] Failed to create OBJ_RECTANGLE_LABEL: ", obj_name, " error=", err);
               break;
            }
         }
      }
      if (!created) continue;
      // Set bar color
      color bar_color = (level_price >= g_val && level_price <= g_vah) ? clrDodgerBlue : clrMediumPurple;
      if (MathAbs(level_price - g_poc) < level_height / 2) bar_color = clrRed;
      // Set bar properties for right side, flip bars leftward
      ObjectSetInteger(0, obj_name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      // XDISTANCE is the distance from the right edge, so to flip the bar leftward:
      ObjectSetInteger(0, obj_name, OBJPROP_XDISTANCE, right_margin + bar_width);
      ObjectSetInteger(0, obj_name, OBJPROP_YSIZE, 12); // bar height
      ObjectSetInteger(0, obj_name, OBJPROP_XSIZE, bar_width);
      ObjectSetInteger(0, obj_name, OBJPROP_YDISTANCE, ChartPriceToY(level_price) - 6);
      ObjectSetInteger(0, obj_name, OBJPROP_BGCOLOR, bar_color);
      ObjectSetInteger(0, obj_name, OBJPROP_COLOR, bar_color);
      ObjectSetInteger(0, obj_name, OBJPROP_BACK, true);
      ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, obj_name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, obj_name, OBJPROP_ZORDER, 1);
      ObjectSetString(0, obj_name, OBJPROP_TEXT, "");
   }
   // Draw VAH, VAL, and POC lines
   DrawHorizontalLine("VAH_Line", g_vah, clrDodgerBlue, "VAH: " + DoubleToString(g_vah, g_digits));
   DrawHorizontalLine("VAL_Line", g_val, clrDodgerBlue, "VAL: " + DoubleToString(g_val, g_digits));
   DrawHorizontalLine("POC_Line", g_poc, clrRed, "POC: " + DoubleToString(g_poc, g_digits));
}
// Helper: Convert price to Y pixel coordinate
int ChartPriceToY(double price) {
   double min_price = ChartGetDouble(0, CHART_PRICE_MIN, 0);
   double max_price = ChartGetDouble(0, CHART_PRICE_MAX, 0);
   int chart_height = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
   if (max_price == min_price) return chart_height / 2;
   double rel = (max_price - price) / (max_price - min_price);
   int y = (int)(rel * chart_height);
   return y;
}
//+------------------------------------------------------------------+
//| Delete volume profile objects                                    |
//+------------------------------------------------------------------+
void DeleteVolumeProfileObjects() {
   // Delete level bars
   for (int i = 0; i < VolumeBars; i++) {
      ObjectDelete(0, "VolProfBar_" + IntegerToString(i));
   }
   // Delete VAH, VAL, POC lines
   ObjectDelete(0, "VAH_Line");
   ObjectDelete(0, "VAL_Line");
   ObjectDelete(0, "POC_Line");
}
//+------------------------------------------------------------------+
//| Draw horizontal line                                             |
//+------------------------------------------------------------------+
void DrawHorizontalLine(string name, double price, color clr, string text) {
   if (ObjectFind(0, name) >= 0) {
      ObjectDelete(0, name);
   }
   ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetString(0, name, OBJPROP_TOOLTIP, text);
}
//+------------------------------------------------------------------+
//| Check for trading signals                                        |
//+------------------------------------------------------------------+
ENUM_TRADE_SIGNAL CheckForSignals() {
   if (g_vah == 0 || g_val == 0 || g_poc == 0) return SIGNAL_NONE;
   // --- Volume Spike Filter ---
   if (UseVolumeSpikeFilter) {
      int bars_needed_vol = VolumeSpikePeriod + 1; // Need period + current bar
      if (Bars(_Symbol, _Period) < bars_needed_vol) {
         DebugPrint("Not enough bars for Volume Spike Filter calculation.");
         return SIGNAL_NONE;
      }
      // Prepare array for volume data
      long volume_buffer[];
      ArrayResize(volume_buffer, VolumeSpikePeriod + 1);
      ArraySetAsSeries(volume_buffer, true);
      // Copy volume data for the last VolumeSpikePeriod+1 bars (index 0 to VolumeSpikePeriod)
      int copied_bars = CopyTickVolume(_Symbol, _Period, 0, VolumeSpikePeriod + 1, volume_buffer);
      if (copied_bars != (VolumeSpikePeriod + 1)) {
         // Fallback to iVolume if CopyTickVolume fails or returns less data
         bool vol_ok = true;
         for(int k=0; k < VolumeSpikePeriod + 1; k++) {
            volume_buffer[k] = iVolume(_Symbol, _Period, k);
            if (volume_buffer[k] < 0) { // Check for invalid volume
               vol_ok = false;
               break;
            }
         }
         if (!vol_ok) {
            DebugPrint("Failed to copy or retrieve sufficient volume data for Volume Spike Filter.");
            return SIGNAL_NONE;
         }
      }
      // Calculate average volume of the last 'VolumeSpikePeriod' completed bars (index 1 to VolumeSpikePeriod)
      long sum_volume = 0;
      for (int k = 1; k <= VolumeSpikePeriod; k++) {
         sum_volume += volume_buffer[k];
      }
      double average_volume = (double)sum_volume / VolumeSpikePeriod;
      // Get volume of the most recently completed bar (index 1)
      long last_completed_volume = volume_buffer[1];
      if (average_volume > 0) { // Avoid division by zero or comparison if avg is zero
         double required_volume = average_volume * VolumeSpikeMultiplier;
         /*
         DebugPrint(StringFormat("[Volume Spike] Last Vol: %d, Avg Vol(%d): %.2f, Required Vol (x%.2f): %.2f",
                                  last_completed_volume, VolumeSpikePeriod, average_volume, VolumeSpikeMultiplier, required_volume));
         */
         if (last_completed_volume < required_volume) {
            DebugPrint("[Volume Spike Filter] Volume below threshold. No signal generated.");
            return SIGNAL_NONE;
         }
      }
      else {
         DebugPrint("[Volume Spike Filter] Average volume is zero. Skipping filter check.");
      }
   }
   // --- End Volume Spike Filter ---
   // --- ATR Volatility Filter ---
   // Use the GLOBAL variable g_dynamicATRThresholdFactor here
   if (UseATRFilter && g_dynamicATRThresholdFactor > 0) {
      // 1. Calculate Current ATR (using ATRPeriod)
      double current_atr_buffer[1];
      int current_atr_handle = iATR(_Symbol, _Period, ATRPeriod);
      if (current_atr_handle == INVALID_HANDLE) {
         DebugPrint("Failed to create Current ATR indicator handle. Error: " + IntegerToString(GetLastError()));
         return SIGNAL_NONE;
      }
      // Get ATR value for the most recently completed bar (index 1)
      if (CopyBuffer(current_atr_handle, 0, 1, 1, current_atr_buffer) != 1) {
         DebugPrint("Failed to copy Current ATR buffer. Error: " + IntegerToString(GetLastError()));
         IndicatorRelease(current_atr_handle);
         return SIGNAL_NONE;
      }
      IndicatorRelease(current_atr_handle);
      double current_atr = current_atr_buffer[0];
      if (current_atr <= 0) { // Basic validation
         DebugPrint("Current ATR is zero or negative. Skipping filter.");
         return SIGNAL_NONE;
      }
      // 2. Calculate Average ATR (using ATRAveragePeriod)
      double average_atr_buffer[];
      int average_atr_handle = iATR(_Symbol, _Period, ATRAveragePeriod);
      if (average_atr_handle == INVALID_HANDLE) {
         DebugPrint("Failed to create Average ATR indicator handle. Error: " + IntegerToString(GetLastError()));
         return SIGNAL_NONE;
      }
      // Need enough bars for the average calculation + 1 for the current value
      int bars_needed = ATRAveragePeriod + 1;
      if (Bars(_Symbol, _Period) < bars_needed) {
          DebugPrint("Not enough bars for Average ATR calculation.");
          IndicatorRelease(average_atr_handle);
          return SIGNAL_NONE;
      }
      ArrayResize(average_atr_buffer, ATRAveragePeriod); // Resize buffer to hold the period's values
      // Copy values from bar 1 (most recent completed) up to ATRAveragePeriod bars ago
      if (CopyBuffer(average_atr_handle, 0, 1, ATRAveragePeriod, average_atr_buffer) != ATRAveragePeriod) {
         DebugPrint("Failed to copy Average ATR buffer. Error: " + IntegerToString(GetLastError()));
         IndicatorRelease(average_atr_handle);
         return SIGNAL_NONE;
      }
      IndicatorRelease(average_atr_handle);
      // Calculate the actual average
      double sum_atr = 0;
      for (int k = 0; k < ATRAveragePeriod; k++) {
         sum_atr += average_atr_buffer[k];
      }
      double average_atr = sum_atr / ATRAveragePeriod;
       if (average_atr <= 0) { // Basic validation
         DebugPrint("Average ATR is zero or negative. Skipping filter.");
         return SIGNAL_NONE;
      }
      // 3. Calculate Dynamic Threshold using the GLOBAL variable
      double dynamic_threshold = average_atr * g_dynamicATRThresholdFactor;
      DebugPrint(StringFormat("[ATR Filter] Current ATR(%d)=%.5f, Avg ATR(%d)=%.5f, Factor=%.2f, DynThreshold=%.5f",
                               ATRPeriod, current_atr, ATRAveragePeriod, average_atr, g_dynamicATRThresholdFactor, dynamic_threshold)); // Use global variable in print
      // 4. Compare Current ATR to Dynamic Threshold
      if (current_atr < dynamic_threshold) {
         DebugPrint("[ATR Filter] Volatility below dynamic threshold. No signal generated.");
         return SIGNAL_NONE;
      }
   }
   // --- End ATR Filter ---
   // Calculate higher timeframe volume profiles
   double vah_htf, val_htf, poc_htf;
   CalculateVolumeProfileTF(VP_HigherTF, vah_htf, val_htf, poc_htf);
   if (vah_htf == 0 || val_htf == 0 || poc_htf == 0) {
       DebugPrint("Failed to calculate VP for Higher TF1: " + EnumToString(VP_HigherTF));
       return SIGNAL_NONE;
   }
   double vah_htf2, val_htf2, poc_htf2;
   CalculateVolumeProfileTF(VP_HigherTF2, vah_htf2, val_htf2, poc_htf2);
   if (vah_htf2 == 0 || val_htf2 == 0 || poc_htf2 == 0) {
       DebugPrint("Failed to calculate VP for Higher TF2: " + EnumToString(VP_HigherTF2));
       return SIGNAL_NONE;
   }
   // Check if we're within trading hours
   if (UseTradingHours) {
      datetime current_time = TimeCurrent();
      MqlDateTime time_struct;
      TimeToStruct(current_time, time_struct);
      int current_hour = time_struct.hour;
      // If outside trading hours, don't generate signals
      if (current_hour < TradingStartHour || current_hour >= TradingEndHour) {
         return SIGNAL_NONE;
      }
   }
   // First check for breakout/rejection patterns if enabled
   ENUM_TRADE_SIGNAL breakout_signal = SIGNAL_NONE;
   if (UseBreakoutRejection && CheckBreakoutRejection(breakout_signal)) {
      // We found a breakout/rejection pattern
      if (RequireMTFAgreement) {
         // Check if higher timeframe agrees
         ENUM_TRADE_SIGNAL htf_signal = GetVolumeProfileSignalTF(vah_htf, val_htf, poc_htf, VP_HigherTF);
         ENUM_TRADE_SIGNAL htf2_signal = GetVolumeProfileSignalTF(vah_htf2, val_htf2, poc_htf2, VP_HigherTF2);
         // Require agreement from BOTH higher timeframes if MTF agreement is on
         if (breakout_signal != htf_signal || breakout_signal != htf2_signal) {
            DebugPrint(StringFormat("Breakout/rejection signal (%s) doesn't match HTF1 (%s) or HTF2 (%s), ignoring",
                                     EnumToString(breakout_signal), EnumToString(htf_signal), EnumToString(htf2_signal)));
            return SIGNAL_NONE;
         }
      }
      return breakout_signal;
   }
   // Check if price is at key level if enabled
   if (UseKeyLevelsEntry) {
      if (!IsPriceAtKeyLevel()) {
         // Not at key level, no signal
         DebugPrint("Price not at key volume profile level, no signal");
         return SIGNAL_NONE;
      }
      // Inside at middle of value area check
      if (AvoidMiddleValueArea) {
         double current_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double middle_val = (g_vah + g_val) / 2.0;
         double quarter_range = (g_vah - g_val) / 4.0;
         // If price is in the middle zone (25% to 75% of VA range), avoid trading
         if (current_price > (middle_val - quarter_range) && current_price < (middle_val + quarter_range)) {
            DebugPrint("Price in middle of value area, avoiding signal");
            return SIGNAL_NONE;
         }
      }
   }
   // Get signals from current and higher timeframes
   ENUM_TRADE_SIGNAL signal_ctf = SIGNAL_NONE;
   ENUM_TRADE_SIGNAL signal_htf = SIGNAL_NONE;
   ENUM_TRADE_SIGNAL signal_htf2 = SIGNAL_NONE; // Signal for second higher timeframe
   // Trend Filter Check
   if (UseTrendFilter) {
      // MQL5: Use iMA to get handle, then CopyBuffer to get MA value
      int ma_handle = iMA(_Symbol, _Period, TrendMAPeriod, 0, TrendMAMethod, (int)TrendMAPrice);
      if(ma_handle == INVALID_HANDLE) {
         DebugPrint("Failed to create MA handle");
         return SIGNAL_NONE;
      }
      double ma_buffer[2];
      if(CopyBuffer(ma_handle, 0, 0, 2, ma_buffer) != 2) {
         DebugPrint("Failed to copy MA buffer");
         return SIGNAL_NONE;
      }
      double trend_ma_value = ma_buffer[1]; // previous bar
      double current_close = iClose(_Symbol, _Period, 0);
      // Release handle
      IndicatorRelease(ma_handle);
      if (trend_ma_value <= 0 || current_close <= 0) {
         DebugPrint("Trend filter MA or price calculation failed.");
         return SIGNAL_NONE;
      }
      bool is_uptrend = (current_close > trend_ma_value);
      bool is_downtrend = (current_close < trend_ma_value);
      signal_ctf = GetVolumeProfileSignal();
      signal_htf = GetVolumeProfileSignalTF(vah_htf, val_htf, poc_htf, VP_HigherTF);
      signal_htf2 = GetVolumeProfileSignalTF(vah_htf2, val_htf2, poc_htf2, VP_HigherTF2); // Get signal for TF2
      // If trend filter is active, ensure signal aligns with trend
      if (signal_ctf == SIGNAL_BUY && !is_uptrend) signal_ctf = SIGNAL_NONE;
      if (signal_ctf == SIGNAL_SELL && !is_downtrend) signal_ctf = SIGNAL_NONE;
   }
   else {
      signal_ctf = GetVolumeProfileSignal();
      signal_htf = GetVolumeProfileSignalTF(vah_htf, val_htf, poc_htf, VP_HigherTF);
      signal_htf2 = GetVolumeProfileSignalTF(vah_htf2, val_htf2, poc_htf2, VP_HigherTF2); // Get signal for TF2
   }
   // If we require multi-timeframe agreement
   if (RequireMTFAgreement) {
      // Check for agreement between current TF and BOTH higher TFs
      if (signal_ctf != SIGNAL_NONE && signal_ctf == signal_htf && signal_ctf == signal_htf2) {
         DebugPrint(StringFormat("Signal (%s) confirmed by HTF1 (%s) and HTF2 (%s)",
                                  EnumToString(signal_ctf), EnumToString(signal_htf), EnumToString(signal_htf2)));
         return signal_ctf;
      }
      else {
         DebugPrint(StringFormat("Signal (%s) not confirmed by HTF1 (%s) or HTF2 (%s)",
                                  EnumToString(signal_ctf), EnumToString(signal_htf), EnumToString(signal_htf2)));
         return SIGNAL_NONE;
      }
   }
   else {
      // Just use current timeframe signal
      return signal_ctf;
   }
}
//+------------------------------------------------------------------+
//| Get signal based purely on Volume Profile logic                  |
//+------------------------------------------------------------------+
ENUM_TRADE_SIGNAL GetVolumeProfileSignal() {
   // This function contains the original logic from CheckForSignals
   // before the trend filter was added.
   double current_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK); // Use Ask for buy check
   double current_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID); // Use Bid for sell check
   // Get volumes for trend analysis
   // Use dynamic arrays - volume should be long
   long volume_array[]; // Changed to long[]
   double open_array[];
   double close_array[];
   // Set as series AFTER resizing
   ArrayResize(volume_array, 3);
   ArrayResize(open_array, 3);
   ArrayResize(close_array, 3);
   // Correctly resize arrays before accessing elements
   ArrayResize(volume_array, 3);
   ArrayResize(open_array, 3);
   ArrayResize(close_array, 3);
   // Initialize with default values
   for (int i = 0; i < 3; i++) {
      volume_array[i] = 0;
      open_array[i] = 0;
      close_array[i] = 0;
   }
   // Safely access volume data with bounds checking
   int bars_available = Bars(_Symbol, PERIOD_CURRENT);
   if (bars_available < 3) {
      DebugPrint("Not enough bars available for signal calculation. Only " + IntegerToString(bars_available) + " bars.");
      return SIGNAL_NONE;
   }
   // Use iVolume with bounds checking
   for (int i = 0; i < 3; i++) {
      if (i < bars_available) {
         volume_array[i] = iVolume(_Symbol, PERIOD_CURRENT, i); // Directly assign long
         open_array[i] = iOpen(_Symbol, PERIOD_CURRENT, i);
         close_array[i] = iClose(_Symbol, PERIOD_CURRENT, i);
      }
   }
   if(volume_array[0] <= 0 || volume_array[1] <= 0) {
      DebugPrint("Invalid volume data for signal calculation");
      return SIGNAL_NONE;
   }
   long current_volume = volume_array[0]; // No cast needed
   long prev_volume = volume_array[1];    // No cast needed
   // Buy signal: Price breaks above VAH or POC with increasing volume
   if ((current_price > g_vah && close_array[0] > open_array[0]) ||
       (current_price > g_poc && close_array[0] > open_array[0] && current_price < g_vah)) {
      if (current_volume > prev_volume) {
         return SIGNAL_BUY;
      }
   }
   // Sell signal: Price breaks below VAL or POC with decreasing volume
   // Use current_bid for sell signal check
   if ((current_bid < g_val && close_array[0] < open_array[0]) ||
       (current_bid < g_poc && close_array[0] < open_array[0] && current_bid > g_val)) {
      if (current_volume < prev_volume) {
         return SIGNAL_SELL;
      }
   }
   return SIGNAL_NONE;
}
//+------------------------------------------------------------------+
//| Execute trade based on signal                                    |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_TRADE_SIGNAL signal) {
   // Close any existing positions if needed
   if (CountOpenPositions() > 0) {
      CloseAllPositions();
   }
   // Get current prices
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double entry_price, sl_price, final_tp_price;
   double pip_value = g_is_forex_pair ? g_point * 10 : g_point;
   double sl_distance = 0, tp_distance = 0;
   if (g_detected_pair == "XAUUSD") { sl_distance = 5.0; }
   else if (g_detected_pair == "XAGUSD") { sl_distance = 0.03; }
   else if (g_detected_pair == "XRPUSD") { sl_distance = 0.005; }
   else { sl_distance = 10 * pip_value; }
   sl_distance *= DistanceMultiplier;
   // Calculate TP distance based on SL distance and the parsed risk:reward ratio
   tp_distance = sl_distance * g_risk_reward_ratio;
   DebugPrint(StringFormat("[ExecuteTrade] SL Distance: %.5f, TP Distance (Ratio %.2f): %.5f", sl_distance, g_risk_reward_ratio, tp_distance));
   if (signal == SIGNAL_BUY) {
      entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      sl_price = entry_price - sl_distance;
      final_tp_price = entry_price + tp_distance;
   } else {
      entry_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      sl_price = entry_price + sl_distance;
      final_tp_price = entry_price - tp_distance;
   }
   // Calculate VTPs as fractions between entry and final TP
   double vtp1, vtp2, vtp3, vtp35;
   if (signal == SIGNAL_BUY) {
      vtp1 = entry_price + 0.25 * (final_tp_price - entry_price);
      vtp2 = entry_price + 0.50 * (final_tp_price - entry_price);
      vtp3 = entry_price + 0.75 * (final_tp_price - entry_price);
      vtp35 = entry_price + 0.875 * (final_tp_price - entry_price);
   } else {
      vtp1 = entry_price - 0.25 * (entry_price - final_tp_price);
      vtp2 = entry_price - 0.50 * (entry_price - final_tp_price);
      vtp3 = entry_price - 0.75 * (entry_price - final_tp_price);
      vtp35 = entry_price - 0.875 * (entry_price - final_tp_price);
   }
   // Calculate lot size based on risk
   double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk_amount = account_balance * (RiskPercent / 100.0);
   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double sl_distance_in_price = MathAbs(entry_price - sl_price);
   double sl_distance_in_ticks = sl_distance_in_price / tick_size;
   double lot_size;
   // Always calculate the base lot size based on risk first
   lot_size = NormalizeDouble(risk_amount / (sl_distance_in_ticks * tick_value), 2);
   DebugPrint(StringFormat("[Order] Calculated base lot size: %.2f", lot_size));
   // Apply loss multiplier if the flag is set
   if (g_apply_loss_multiplier && LossMultiplier > 1.0) {
      DebugPrint(StringFormat("[Order] Applying Loss Multiplier: %.2f. Base Lot: %.2f", LossMultiplier, lot_size));
      lot_size *= LossMultiplier;
      g_apply_loss_multiplier = false; // Reset the flag after applying it
      DebugPrint(StringFormat("[Order] Lot size after multiplier: %.2f", lot_size));
   }
   // Ensure lot size is within allowed range and rounded to step
   double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   int lot_digits = (int)MathLog10(1.0/lot_step);
   DebugPrint(StringFormat("[Order] Symbol=%s min_lot=%.2f max_lot=%.2f lot_step=%.2f lot_digits=%d raw_lot_size=%.2f", _Symbol, min_lot, max_lot, lot_step, lot_digits, lot_size));
   // Use MathRound for better accuracy
   lot_size = MathRound(lot_size / lot_step) * lot_step;
   lot_size = MathMax(min_lot, MathMin(max_lot, lot_size));
   lot_size = NormalizeDouble(lot_size, lot_digits);
   DebugPrint("[Order] final_lot_size=" + DoubleToString(lot_size));
   if (lot_size < min_lot || lot_size > max_lot || lot_size <= 0) {
      DebugPrint("Invalid lot size after rounding: " + DoubleToString(lot_size) + ". Aborting trade.");
      return;
   }
   // Create position tracker
   POSITION_TRACKER pos;
   pos.entry_price = entry_price;
   pos.original_sl = sl_price;
   pos.current_sl = sl_price;
   pos.original_volume = lot_size;
   pos.current_volume = lot_size;
   pos.position_type = (signal == SIGNAL_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   pos.open_time = TimeCurrent();
   pos.tp1.price = vtp1; pos.tp1.hit = false; pos.tp1.position_part = 0.4;
   pos.tp2.price = vtp2; pos.tp2.hit = false; pos.tp2.position_part = 0.3;
   pos.tp3.price = vtp3; pos.tp3.hit = false; pos.tp3.position_part = 0.2;
   pos.tp4.price = final_tp_price; pos.tp4.hit = false; pos.tp4.position_part = 0.1;
   pos.midway_tp4 = vtp35; pos.midway_hit = false;
   // Calculate midway point to TP1 for safety net
   if (signal == SIGNAL_BUY) {
      pos.midway_tp1 = entry_price + 0.5 * (vtp1 - entry_price);
      pos.vtp1_5 = entry_price + 0.5 * (vtp1 - entry_price); // VTP1.5 is the same as midway to TP1
   } else {
      pos.midway_tp1 = entry_price - 0.5 * (entry_price - vtp1);
      pos.vtp1_5 = entry_price - 0.5 * (entry_price - vtp1); // VTP1.5 is the same as midway to TP1
   }
   pos.midway_tp1_hit = false;
   pos.dynamic_sl_disabled = false;
   // Execute the trade with fallback logic
   bool trade_placed = false;
   int attempts = 0;
   int max_attempts = 4;
   double slippage = 3; // Initial slippage in points
   while (!trade_placed && attempts < max_attempts) {
      attempts++;
      Trade.SetDeviationInPoints(slippage);
      bool result = false;
      if (signal == SIGNAL_BUY) {
         result = Trade.Buy(lot_size, _Symbol, 0, sl_price, 0, "MoneyMonster");
      }
      else {
         result = Trade.Sell(lot_size, _Symbol, 0, sl_price, 0, "MoneyMonster");
      }
      if (result) {
         trade_placed = true;
         pos.ticket = (ulong)Trade.ResultOrder(); // Explicit cast to ulong
         // Add to position tracker array
         int size = (int)ArraySize(g_positions);
         ArrayResize(g_positions, size + 1);
         g_positions[size] = pos;
         string signal_str = (signal == SIGNAL_BUY) ? "BUY" : "SELL";
         Print("Trade executed: ", signal_str, " ", lot_size, " lots at ", entry_price,
              ", SL: ", sl_price);
         LogTradeEvent("OPEN", pos.ticket, entry_price, lot_size, (signal == SIGNAL_BUY ? "BUY" : "SELL"));
      }
      else {
         int last_error = GetLastError();
         DebugPrint("Trade attempt " + IntegerToString(attempts) + " failed. Error: " + IntegerToString(last_error));
         // Adjust parameters for next attempt
         if (attempts == 1) {
            slippage = 5; // Increase slippage
         }
         else if (attempts == 2) {
            // Try with pending order at current price
            if (signal == SIGNAL_BUY) {
               result = Trade.BuyStop(lot_size, entry_price, _Symbol, sl_price, 0, ORDER_TIME_GTC, 0, "MoneyMonster");
            }
            else {
               result = Trade.SellStop(lot_size, entry_price, _Symbol, sl_price, 0, ORDER_TIME_GTC, 0, "MoneyMonster");
            }
            if (result) {
               trade_placed = true;
               pos.ticket = (ulong)Trade.ResultOrder(); // Explicit cast to ulong
               // Add to position tracker array
               int size = (int)ArraySize(g_positions);
               ArrayResize(g_positions, size + 1);
               g_positions[size] = pos;
               string signal_str = (signal == SIGNAL_BUY) ? "BUY STOP" : "SELL STOP";
               DebugPrint("Pending order placed: " + signal_str + " " + DoubleToString(lot_size) + " lots at " + DoubleToString(entry_price) + ", SL: " + DoubleToString(sl_price));
            }
         }
         else if (attempts == 3) {
            // Try with reduced lot size
            lot_size = NormalizeDouble(lot_size * 0.8, 2);
            if (lot_size < min_lot) lot_size = min_lot;
            DebugPrint("Reduced lot size to " + DoubleToString(lot_size) + " for final attempt");
         }
         // Handle specific errors
         // Define error code constants as they might not be available
         #define ERR_TRADE_CONTEXT_BUSY 146
         #define ERR_TRADE_NOT_ALLOWED 4109
         #define ERR_SERVER_BUSY 4
         if (last_error == ERR_TRADE_CONTEXT_BUSY) {
            Sleep(100); // Wait for trade context to become available
         }
         else if (last_error == ERR_TRADE_NOT_ALLOWED) {
            DebugPrint("Trading is not allowed on this account");
            break;
         }
         else if (last_error == ERR_SERVER_BUSY) {
            Sleep(500); // Wait longer for server
         }
      }
   }
   if (!trade_placed) {
      DebugPrint("Failed to execute trade after " + IntegerToString(max_attempts) + " attempts");
   }
}
//+------------------------------------------------------------------+
//| Manage open positions (SL/TP levels)                             |
//+------------------------------------------------------------------+
void ManagePositions() {
   int total_positions = (int)ArraySize(g_positions);
   if (total_positions == 0) return;
   for (int i = 0; i < total_positions; i++) {
      ulong ticket = g_positions[i].ticket;
      if (!PositionSelectByTicket(ticket)) { RemovePosition(i); i--; total_positions--; continue; }
      double current_price = SymbolInfoDouble(_Symbol, (g_positions[i].position_type == POSITION_TYPE_BUY) ? SYMBOL_BID : SYMBOL_ASK);
      DebugPrint(StringFormat("[ManagePositions] Ticket=%I64u Type=%s Price=%.5f Vol=%.2f TP1=%.5f TP1.hit=%d TP2=%.5f TP2.hit=%d TP3=%.5f TP3.hit=%d TP4=%.5f TP4.hit=%d SL=%.5f", ticket, (g_positions[i].position_type == POSITION_TYPE_BUY ? "BUY" : "SELL"), current_price, g_positions[i].current_volume, g_positions[i].tp1.price, g_positions[i].tp1.hit, g_positions[i].tp2.price, g_positions[i].tp2.hit, g_positions[i].tp3.price, g_positions[i].tp3.hit, g_positions[i].tp4.price, g_positions[i].tp4.hit, g_positions[i].current_sl));
      // --- Safety Net: Close if price crosses original stop loss ---
      if (g_positions[i].position_type == POSITION_TYPE_BUY && current_price <= g_positions[i].original_sl) {
         // If BUY position price drops to original SL or lower, force close
         DebugPrint(StringFormat("[SafetyNet] BUY position %I64u hit original SL (%.5f). Current price: %.5f. Closing position.",
                                  ticket, g_positions[i].original_sl, current_price));
         if (Trade.PositionClose(ticket)) {
            LogTradeEvent("CLOSE", ticket, current_price, g_positions[i].current_volume, "SAFETY_NET_SL");
            RemovePosition(i);
            i--; total_positions--;
            continue;
         } else {
            DebugPrint(StringFormat("[SafetyNet] Failed to close position %I64u. Error: %d", ticket, GetLastError()));
         }
      }
      else if (g_positions[i].position_type == POSITION_TYPE_SELL && current_price >= g_positions[i].original_sl) {
         // If SELL position price rises to original SL or higher, force close
         DebugPrint(StringFormat("[SafetyNet] SELL position %I64u hit original SL (%.5f). Current price: %.5f. Closing position.",
                                  ticket, g_positions[i].original_sl, current_price));
         if (Trade.PositionClose(ticket)) {
            LogTradeEvent("CLOSE", ticket, current_price, g_positions[i].current_volume, "SAFETY_NET_SL");
            RemovePosition(i);
            i--; total_positions--;
            continue;
         } else {
            DebugPrint(StringFormat("[SafetyNet] Failed to close position %I64u. Error: %d", ticket, GetLastError()));
         }
      }
      // --- End Safety Net ---
      // --- Opposite Signal Close Logic ---
      if (CloseOnOppositeSignal && g_current_signal != SIGNAL_NONE) {
         ENUM_POSITION_TYPE pos_type = g_positions[i].position_type;
         if ((pos_type == POSITION_TYPE_BUY && g_current_signal == SIGNAL_SELL) ||
             (pos_type == POSITION_TYPE_SELL && g_current_signal == SIGNAL_BUY)) {
            double close_price = PositionGetDouble(POSITION_PRICE_CURRENT);
            double close_volume = PositionGetDouble(POSITION_VOLUME);
            if (Trade.PositionClose(ticket)) {
               LogTradeEvent("CLOSE", ticket, close_price, close_volume, "OPPOSITE_SIGNAL");
               RemovePosition(i);
               i--; total_positions--;
               continue;
            } else {
               DebugPrint(StringFormat("[OppositeSignal] Failed to close position %I64u. Error: %d", ticket, GetLastError()));
            }
         }
      }
      // --- TP/SL Management ---
      if (g_positions[i].position_type == POSITION_TYPE_BUY) {
         // TP4
         if (current_price >= g_positions[i].tp4.price) { Trade.PositionClose(ticket); RemovePosition(i); i--; total_positions--; continue; }
         // Safety net: If price crosses midway to TP1 and hasn't hit TP1 yet, move SL to entry + commission
         if (current_price >= g_positions[i].midway_tp1 && !g_positions[i].midway_tp1_hit && !g_positions[i].tp1.hit) {
            // Calculate commission-adjusted SL that ensures a small profit
            double commission_fee = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) * 8; // Approximate commission as 8 ticks
            double adjusted_sl = g_positions[i].entry_price + commission_fee;
            
            // Make sure we don't set SL too close to current price (broker restrictions)
            double stopLevelPoints = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
            double stopLevelPrice = stopLevelPoints * g_point;
            double min_sl = SymbolInfoDouble(_Symbol, SYMBOL_BID) - stopLevelPrice;
            if (adjusted_sl > min_sl) adjusted_sl = min_sl;
            
            ModifyStopLoss(ticket, adjusted_sl, g_positions[i].position_type, g_positions[i].entry_price);
            g_positions[i].current_sl = adjusted_sl;
            g_positions[i].dynamic_sl_disabled = true; // Disable dynamic SL
            g_positions[i].midway_tp1_hit = true;
            DebugPrint(StringFormat("[SafetyNet] BUY position %I64u passed midway to TP1 (%.5f). Moving SL to entry+commission: %.5f",
                                     ticket, g_positions[i].midway_tp1, adjusted_sl));
         }
         // VTP3.5 (Midway to VTP4)
         if (current_price >= g_positions[i].midway_tp4 && !g_positions[i].midway_hit) {
            // Calculate midway point between TP3 and TP4 for SL placement
            double midway_vtp4 = (g_positions[i].tp3.price + g_positions[i].tp4.price) / 2.0;
            ModifyStopLoss(ticket, midway_vtp4, g_positions[i].position_type, g_positions[i].entry_price);
            g_positions[i].current_sl = midway_vtp4;
            g_positions[i].midway_hit = true;
            DebugPrint(StringFormat("[TrailingStop] BUY position %I64u reached VTP3.5. Moving SL to midway VTP4: %.5f",
                                     ticket, midway_vtp4));
         }
         // Trailing Stop Logic for BUY - Activates after VTP3.5 is hit (midway to VTP4)
         else if (UseTrailingStop && g_positions[i].midway_hit && current_price > g_positions[i].tp3.price) {
            double pip_value = g_is_forex_pair ? g_point * 10 : g_point;
            double trailDistance = TrailingStopDistance * pip_value;
            double newSL = current_price - trailDistance;
            
            // Only move SL up, never down (one-direction trailing)
            if (newSL > g_positions[i].current_sl) {
               // Make sure we don't set SL too close to current price (broker restrictions)
               double stopLevelPoints = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
               double stopLevelPrice = stopLevelPoints * g_point;
               double min_sl = SymbolInfoDouble(_Symbol, SYMBOL_BID) - stopLevelPrice;
               if (newSL > min_sl) newSL = min_sl;
               
               ModifyStopLoss(ticket, newSL, g_positions[i].position_type, g_positions[i].entry_price);
               g_positions[i].current_sl = newSL;
               DebugPrint(StringFormat("[TrailingStop] BUY position %I64u trailing SL moved to: %.5f", ticket, newSL));
            }
         }
         // VTP3
         else if (current_price >= g_positions[i].tp3.price && !g_positions[i].tp3.hit) {
            double close_vol = NormalizeDouble(g_positions[i].current_volume * 0.2, 2);
            if (ClosePartialPosition(ticket, close_vol)) {
               g_positions[i].tp3.hit = true;
               g_positions[i].current_volume -= close_vol;
               ModifyStopLoss(ticket, g_positions[i].tp2.price, g_positions[i].position_type, g_positions[i].entry_price);
               g_positions[i].current_sl = g_positions[i].tp2.price;
            }
         }
         // VTP2
         else if (current_price >= g_positions[i].tp2.price && !g_positions[i].tp2.hit) {
            double close_vol = NormalizeDouble(g_positions[i].current_volume * 0.3, 2);
            if (ClosePartialPosition(ticket, close_vol)) {
               g_positions[i].tp2.hit = true;
               g_positions[i].current_volume -= close_vol;
               ModifyStopLoss(ticket, g_positions[i].tp1.price, g_positions[i].position_type, g_positions[i].entry_price);
               g_positions[i].current_sl = g_positions[i].tp1.price;
            }
         }
         // VTP1
         else if (current_price >= g_positions[i].tp1.price && !g_positions[i].tp1.hit) {
            double close_vol = NormalizeDouble(g_positions[i].current_volume * 0.4, 2);
            if (ClosePartialPosition(ticket, close_vol)) {
               g_positions[i].tp1.hit = true;
               g_positions[i].current_volume -= close_vol;
               // Move SL to VTP1.5 (midway between entry and TP1) instead of entry
               ModifyStopLoss(ticket, g_positions[i].vtp1_5, g_positions[i].position_type, g_positions[i].entry_price);
               g_positions[i].current_sl = g_positions[i].vtp1_5;
               DebugPrint(StringFormat("[SL_Management] BUY position %I64u hit TP1. Moving SL to VTP1.5: %.5f",
                          ticket, g_positions[i].vtp1_5));
            }
         }
         // If price falls back to entry after VTP1, close at breakeven
         else if (g_positions[i].tp1.hit && current_price <= g_positions[i].entry_price) {
            Trade.PositionClose(ticket); RemovePosition(i); i--; total_positions--; continue;
         }
         // Dynamic SL for BUY if not disabled by safety net
         else if (!g_positions[i].tp1.hit && current_price < g_positions[i].entry_price && !g_positions[i].dynamic_sl_disabled) {
            double pip_value = g_is_forex_pair ? g_point * 10 : g_point;
            double distance = DynamicSLDistance * pip_value;
            double new_sl = MathMin(g_positions[i].entry_price, current_price - distance);
            new_sl = MathMax(new_sl, g_positions[i].original_sl);
            // --- FIX: Enforce StopLevel ---
            double stopLevelPoints = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
            double stopLevelPrice = stopLevelPoints * g_point;
            double min_sl = SymbolInfoDouble(_Symbol, SYMBOL_BID) - stopLevelPrice;
            if (new_sl > min_sl) new_sl = min_sl;
            // --- END FIX ---
            if (new_sl != g_positions[i].current_sl) {
               ModifyStopLoss(ticket, new_sl, g_positions[i].position_type, g_positions[i].entry_price);
               g_positions[i].current_sl = new_sl;
            }
         }
         // Between entry and VTP1: SL remains at last value set
      } else if (g_positions[i].position_type == POSITION_TYPE_SELL) {
         // TP4
         if (current_price <= g_positions[i].tp4.price) { Trade.PositionClose(ticket); RemovePosition(i); i--; total_positions--; continue; }
         // Safety net: If price crosses midway to TP1 and hasn't hit TP1 yet, move SL to entry - commission
         if (current_price <= g_positions[i].midway_tp1 && !g_positions[i].midway_tp1_hit && !g_positions[i].tp1.hit) {
            // Calculate commission-adjusted SL that ensures a small profit
            double commission_fee = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) * 8; // Approximate commission as 8 ticks
            double adjusted_sl = g_positions[i].entry_price - commission_fee;
            
            // Make sure we don't set SL too close to current price (broker restrictions)
            double stopLevelPoints = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
            double stopLevelPrice = stopLevelPoints * g_point;
            double max_sl = SymbolInfoDouble(_Symbol, SYMBOL_ASK) + stopLevelPrice;
            if (adjusted_sl < max_sl) adjusted_sl = max_sl;
            
            ModifyStopLoss(ticket, adjusted_sl, g_positions[i].position_type, g_positions[i].entry_price);
            g_positions[i].current_sl = adjusted_sl;
            g_positions[i].dynamic_sl_disabled = true; // Disable dynamic SL
            g_positions[i].midway_tp1_hit = true;
            DebugPrint(StringFormat("[SafetyNet] SELL position %I64u passed midway to TP1 (%.5f). Moving SL to entry-commission: %.5f", 
                                    ticket, g_positions[i].midway_tp1, adjusted_sl));
         }
         // VTP3.5
         if (current_price <= g_positions[i].midway_tp4 && !g_positions[i].midway_hit) {
            // Calculate midway point between TP3 and TP4 for SL placement
            double midway_vtp4 = (g_positions[i].tp3.price + g_positions[i].tp4.price) / 2.0;
            ModifyStopLoss(ticket, midway_vtp4, g_positions[i].position_type, g_positions[i].entry_price);
            g_positions[i].current_sl = midway_vtp4;
            g_positions[i].midway_hit = true;
            DebugPrint(StringFormat("[TrailingStop] SELL position %I64u reached VTP3.5. Moving SL to midway VTP4: %.5f",
                                    ticket, midway_vtp4));
         }
         // Trailing Stop Logic for SELL - Activates after VTP3.5 is hit (midway to VTP4)
         else if (UseTrailingStop && g_positions[i].midway_hit && current_price < g_positions[i].tp3.price) {
            double pip_value = g_is_forex_pair ? g_point * 10 : g_point;
            double trailDistance = TrailingStopDistance * pip_value;
            double newSL = current_price + trailDistance;
            
            // Only move SL down, never up (one-direction trailing)
            if (newSL < g_positions[i].current_sl) {
               // Make sure we don't set SL too close to current price (broker restrictions)
               double stopLevelPoints = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
               double stopLevelPrice = stopLevelPoints * g_point;
               double max_sl = SymbolInfoDouble(_Symbol, SYMBOL_ASK) + stopLevelPrice;
               if (newSL < max_sl) newSL = max_sl;
               
               ModifyStopLoss(ticket, newSL, g_positions[i].position_type, g_positions[i].entry_price);
               g_positions[i].current_sl = newSL;
               DebugPrint(StringFormat("[TrailingStop] SELL position %I64u trailing SL moved to: %.5f", ticket, newSL));
            }
         }
         // VTP3
         else if (current_price <= g_positions[i].tp3.price && !g_positions[i].tp3.hit) {
            double close_vol = NormalizeDouble(g_positions[i].current_volume * 0.2, 2);
            if (ClosePartialPosition(ticket, close_vol)) {
               g_positions[i].tp3.hit = true;
               g_positions[i].current_volume -= close_vol;
               ModifyStopLoss(ticket, g_positions[i].tp2.price, g_positions[i].position_type, g_positions[i].entry_price);
               g_positions[i].current_sl = g_positions[i].tp2.price;
            }
         }
         // VTP2
         else if (current_price <= g_positions[i].tp2.price && !g_positions[i].tp2.hit) {
            double close_vol = NormalizeDouble(g_positions[i].current_volume * 0.3, 2);
            if (ClosePartialPosition(ticket, close_vol)) {
               g_positions[i].tp2.hit = true;
               g_positions[i].current_volume -= close_vol;
               ModifyStopLoss(ticket, g_positions[i].tp1.price, g_positions[i].position_type, g_positions[i].entry_price);
               g_positions[i].current_sl = g_positions[i].tp1.price;
            }
         }
         // VTP1
         else if (current_price <= g_positions[i].tp1.price && !g_positions[i].tp1.hit) {
            double close_vol = NormalizeDouble(g_positions[i].current_volume * 0.4, 2);
            if (ClosePartialPosition(ticket, close_vol)) {
               g_positions[i].tp1.hit = true;
               g_positions[i].current_volume -= close_vol;
               // Move SL to VTP1.5 (midway between entry and TP1) instead of entry
               ModifyStopLoss(ticket, g_positions[i].vtp1_5, g_positions[i].position_type, g_positions[i].entry_price);
               g_positions[i].current_sl = g_positions[i].vtp1_5;
               DebugPrint(StringFormat("[SL_Management] SELL position %I64u hit TP1. Moving SL to VTP1.5: %.5f", ticket, g_positions[i].vtp1_5));
            }
         }
         // If price rises back to entry after VTP1, close at breakeven
         else if (g_positions[i].tp1.hit && current_price >= g_positions[i].entry_price) {
            Trade.PositionClose(ticket); RemovePosition(i); i--; total_positions--; continue;
         }
         // Dynamic SL for SELL if not disabled by safety net
         else if (!g_positions[i].tp1.hit && current_price > g_positions[i].entry_price && !g_positions[i].dynamic_sl_disabled) {
            double pip_value = g_is_forex_pair ? g_point * 10 : g_point;
            double distance = DynamicSLDistance * pip_value;
            double new_sl = MathMax(g_positions[i].entry_price, current_price + distance);
            new_sl = MathMin(new_sl, g_positions[i].original_sl);
            // --- FIX: Enforce StopLevel ---
            double stopLevelPoints = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
            double stopLevelPrice = stopLevelPoints * g_point;
            double max_sl = SymbolInfoDouble(_Symbol, SYMBOL_ASK) + stopLevelPrice;
            if (new_sl < max_sl) new_sl = max_sl;
            // --- END FIX ---
            if (new_sl != g_positions[i].current_sl) {
               ModifyStopLoss(ticket, new_sl, g_positions[i].position_type, g_positions[i].entry_price);
               g_positions[i].current_sl = new_sl;
            }
         }
         // Between entry and VTP1: SL remains at last value set
      }
      else {
          // Max bars in trade logic
          int bars_held = (int)((TimeCurrent() - g_positions[i].open_time) / (PeriodSeconds(PERIOD_CURRENT)));
          if (bars_held >= MaxBarsInTrade) {
             DebugPrint("[MaxBars] Closing position " + IntegerToString(ticket) + " after " + IntegerToString(bars_held) + " bars.");
             Trade.PositionClose(ticket);
             LogTradeEvent("CLOSE", ticket, current_price, g_positions[i].current_volume, "MAX_BARS");
             RemovePosition(i);
             i--; total_positions--;
             continue;
          }
       }
   }
}
//+------------------------------------------------------------------+
//| Close partial position                                            |
//+------------------------------------------------------------------+
bool ClosePartialPosition(ulong ticket, double volume) {
   double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   int lot_digits = (int)MathLog10(1.0/lot_step);
   double current_volume = 0;
   if (PositionSelectByTicket(ticket)) {
      current_volume = PositionGetDouble(POSITION_VOLUME);
   }
   // If the requested volume is less than min_lot, close min_lot instead
   double close_volume = volume;
   if (close_volume < min_lot) close_volume = min_lot;
   // If the remaining volume after close would be less than min_lot, close the whole position
   if (current_volume - close_volume < min_lot) close_volume = current_volume;
   // Round to lot step and digits
   double rounded_volume = MathRound(close_volume / lot_step) * lot_step;
   rounded_volume = MathMax(min_lot, MathMin(max_lot, rounded_volume));
   rounded_volume = NormalizeDouble(rounded_volume, lot_digits);
   DebugPrint("[PartialClose] final_volume=" + DoubleToString(rounded_volume));
   if (rounded_volume <= 0) {
      DebugPrint("Invalid partial close volume after rounding: " + DoubleToString(rounded_volume) + ". Aborting partial close.");
      return false;
   }
   bool closed = Trade.PositionClosePartial(ticket, rounded_volume);
   if (closed) {
      double price = PositionGetDouble(POSITION_PRICE_CURRENT);
      LogTradeEvent("PARTIAL_CLOSE", ticket, price, rounded_volume);
   }
   return closed;
}
//+------------------------------------------------------------------+
//| Remove position from tracking array                              |
//+------------------------------------------------------------------+
void RemovePosition(int index) {
   int size = (int)ArraySize(g_positions);
   if (index < 0 || index >= size) return;
   // Shift array elements
   for (int i = index; i < size - 1; i++) {
      g_positions[i] = g_positions[i + 1];
   }
   // Resize array
   ArrayResize(g_positions, size - 1);
}
//+------------------------------------------------------------------+
//| Close all positions                                              |
//+------------------------------------------------------------------+
void CloseAllPositions() {
   int total = PositionsTotal();
   for (int i = total - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if (PositionSelectByTicket(ticket)) {
         if (PositionGetInteger(POSITION_MAGIC) == MagicNumber) {
            double price = PositionGetDouble(POSITION_PRICE_CURRENT);
            double volume = PositionGetDouble(POSITION_VOLUME);
            Trade.PositionClose(ticket);
            LogTradeEvent("CLOSE", ticket, price, volume, "STOP_EA");
            DebugPrint("Position closed: " + IntegerToString(ticket));
         }
      }
   }
}
//+------------------------------------------------------------------+
//| Count open positions                                             |
//+------------------------------------------------------------------+
int CountOpenPositions() {
   int count = 0;
   int total = PositionsTotal();
   for (int i = 0; i < total; i++) {
      ulong ticket = PositionGetTicket(i);
      if (PositionSelectByTicket(ticket)) {
         if (PositionGetInteger(POSITION_MAGIC) == MagicNumber) {
            count++;
         }
      }
   }
   return count;
}
//+------------------------------------------------------------------+
//| Load existing positions                                          |
//+------------------------------------------------------------------+
void LoadExistingPositions() {
   int total = PositionsTotal();
   for (int i = 0; i < total; i++) {
      ulong ticket = PositionGetTicket(i);
      if (PositionSelectByTicket(ticket)) {
         // Check if this is our position
         if (PositionGetInteger(POSITION_MAGIC) == MagicNumber) {
            // Create position tracker
            POSITION_TRACKER pos;
            pos.ticket = ticket;
            pos.entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
            pos.current_sl = PositionGetDouble(POSITION_SL);
            pos.original_sl = pos.current_sl; // Use current SL as original
            pos.original_volume = PositionGetDouble(POSITION_VOLUME);
            pos.current_volume = pos.original_volume;
            pos.position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            pos.open_time = (datetime)PositionGetInteger(POSITION_TIME);
            // Determine TP levels based on position type and entry
            double pip_value = g_is_forex_pair ? g_point * 10 : g_point;
            double tp_distance = 0;
            // Set default values based on pair
            if (g_detected_pair == "XAUUSD") {
               tp_distance = 1.0; // Base distance in dollars
            }
            else if (g_detected_pair == "XAGUSD") {
               tp_distance = 0.03; // Base distance in dollars
            }
            else if (g_detected_pair == "XRPUSD") {
               tp_distance = 0.005; // Base distance in dollars
            }
            else { // GBPUSD { { {
               tp_distance = 10 * pip_value; // Base distance in pips converted to price
            }
            // Apply multiplier to TP distances
            tp_distance *= DistanceMultiplier;
            // Set TP levels
            if (pos.position_type == POSITION_TYPE_BUY) {
               pos.tp1.price = pos.entry_price + tp_distance;
               pos.tp2.price = pos.entry_price +tp_distance * 2;
               pos.tp3.price = pos.entry_price + tp_distance * 3;
               pos.tp4.price= pos.entry_price + tp_distance * 5;
            }
            else {
               pos.tp1.price = pos.entry_price - tp_distance;
               pos.tp2.price = pos.entry_price - tp_distance * 2;
               pos.tp3.price = pos.entry_price - tp_distance * 3;
               pos.tp4.price = pos.entry_price - tp_distance * 5;
            }
            // Set default values for TP levels
            pos.tp1.hit = false;
            pos.tp1.position_part = 0.4; // 40% of position
            pos.tp2.hit = false;
            pos.tp2.position_part = 0.3; // 20% of position
            pos.tp3.hit = false;
            pos.tp3.position_part = 0.2; // 20% of position
            pos.tp4.hit = false;
            pos.tp4.position_part = 0.1; // 20% of position
            pos.midway_tp4 = (pos.tp3.price + pos.tp4.price) / 2;
            pos.midway_hit = false;
            // Determine which TPs have been hit based on position size
            double original_size = pos.original_volume;
            double current_size = pos.current_volume;
            double closed_percent = (original_size - current_size) / original_size * 100;
            if (closed_percent >= 40) {
               pos.tp1.hit = true;
            }
            if (closed_percent >= 60) {
               pos.tp2.hit = true;
            }
            if (closed_percent >= 80) {
               pos.tp3.hit = true;
            }
            // Add to positions array
            int size = (int)ArraySize(g_positions);
            ArrayResize(g_positions, size + 1);
            g_positions[size] = pos;
            DebugPrint("Loaded existing position: " + IntegerToString(ticket) + ", Type: " + (pos.position_type == POSITION_TYPE_BUY ? "BUY" : "SELL") + ", Volume: " + DoubleToString(pos.current_volume, 2) + ", Entry: " + DoubleToString(pos.entry_price));
         }
      }
   }
}
//+------------------------------------------------------------------+
//| Customize chart appearance                                       |
//+------------------------------------------------------------------+
void CustomizeChart() {
   #define CHART_MODE_BARS 0
   ChartSetInteger(0, CHART_MODE, CHART_MODE_BARS);
   ChartSetInteger(0, CHART_COLOR_CHART_UP, g_bull_color);
   ChartSetInteger(0, CHART_COLOR_CHART_DOWN, g_bear_color);
   ChartSetInteger(0, CHART_SHOW_GRID, false);
   ChartSetInteger(0, CHART_SHOW_PERIOD_SEP, false);
}
//+------------------------------------------------------------------+
//| Create information panel                                         |
//+------------------------------------------------------------------+
void CreatePanel() {
   // Delete panel if it exists
   ObjectDelete(0, g_panel_name);
   // Delete all possible label lines to avoid overlap
   for (int i = 0; i < 20; i++) {
      string obj_name = g_panel_name + "_Text_" + IntegerToString(i);
      ObjectDelete(0, obj_name);
   }
   ObjectDelete(0, g_panel_name + "_Text");
   // Calculate required panel height based on number of lines and font size
   int font_size = 9;
   int line_height = font_size + 3;
   int n_lines = 10; // Minimum lines, will be increased if more positions
   int positions = CountOpenPositions();
   if (positions > 0) n_lines += (int)ArraySize(g_positions);
   int panel_height = 2 * 10 + n_lines * line_height; // margin + lines
   // Create a left-side panel sized to fit all lines
   if (!ObjectCreate(0, g_panel_name, OBJ_RECTANGLE_LABEL, 0, 0, 0)) {
      DebugPrint("[Panel] Failed to create OBJ_RECTANGLE_LABEL: " + g_panel_name + " error=" + IntegerToString(GetLastError()));
   }
   ObjectSetInteger(0, g_panel_name, OBJPROP_XDISTANCE, 8); // closer to left
   ObjectSetInteger(0, g_panel_name, OBJPROP_YDISTANCE, 8); // closer to top
   ObjectSetInteger(0, g_panel_name, OBJPROP_XSIZE, 260); // width for multiline text (increased)
   ObjectSetInteger(0, g_panel_name, OBJPROP_YSIZE, panel_height); // dynamic height
   ObjectSetInteger(0, g_panel_name, OBJPROP_BGCOLOR, clrMidnightBlue);
   ObjectSetInteger(0, g_panel_name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, g_panel_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, g_panel_name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, g_panel_name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, g_panel_name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, g_panel_name, OBJPROP_BACK, true); // behind chart objects
   ObjectSetInteger(0, g_panel_name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, g_panel_name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, g_panel_name, OBJPROP_HIDDEN, false); // Make panel visible
   ObjectSetInteger(0, g_panel_name, OBJPROP_ZORDER, 1); // Panel below labels
   // Update panel content
   UpdatePanel();
}
//+------------------------------------------------------------------+
//| Update information panel                                         |
//+------------------------------------------------------------------+
void UpdatePanel() {
   // Remove all previous label lines
   for (int i = 0; i < 20; i++) {
      string obj_name = g_panel_name + "_Text_" + IntegerToString(i);
      ObjectDelete(0, obj_name);
   }
   ObjectDelete(0, g_panel_name + "_Text"); // Remove old single label if present
   string status = g_stopping ? "STOPPED" : "ACTIVE";
   string signal = "";
   switch(g_current_signal) {
      case SIGNAL_BUY: signal = "BUY"; break;
      case SIGNAL_SELL: signal = "SELL"; break;
      default: signal = "NONE";
   }
   string lines[20];
   int n = 0;
   lines[n++] = "MoneyMonster EA";
   lines[n++] = "-------------------------";
   lines[n++] = "Pair: " + g_detected_pair;
   lines[n++] = "Status: " + status;
   lines[n++] = "Signal: " + signal;
   lines[n++] = "VAH: " + DoubleToString(g_vah, g_digits);
   lines[n++] = "POC: " + DoubleToString(g_poc, g_digits);
   lines[n++] = "VAL: " + DoubleToString(g_val, g_digits);
   int positions = CountOpenPositions();
   lines[n++] = "Open: " + IntegerToString(positions);
   if (positions > 0) {
      for (int i = 0; i < (int)ArraySize(g_positions); i++) {
         POSITION_TRACKER pos = g_positions[i];
         string type = (pos.position_type == POSITION_TYPE_BUY) ? "BUY" : "SELL";
         double profit = 0;
         if (PositionSelectByTicket(pos.ticket)) {
            profit = PositionGetDouble(POSITION_PROFIT);
         }
         lines[n++] = type + " " + DoubleToString(pos.current_volume, 2) + " lots, P/L: " + DoubleToString(profit, 2);
      }
   }
   // Get panel position and size
   int panel_x = (int)ObjectGetInteger(0, g_panel_name, OBJPROP_XDISTANCE);
   int panel_y = (int)ObjectGetInteger(0, g_panel_name, OBJPROP_YDISTANCE);
   int panel_w = (int)ObjectGetInteger(0, g_panel_name, OBJPROP_XSIZE);
   int panel_h = (int)ObjectGetInteger(0, g_panel_name, OBJPROP_YSIZE);
   int margin_x = 10;
   int margin_y = 10;
   int font_size = 9;
   int line_height = font_size + 3;
   // Place each label with CORNER_LEFT_UPPER and relative to the panel's top-left
   for (int i = 0; i < n; i++) {
      string obj_name = g_panel_name + "_Text_" + IntegerToString(i);
      if (!ObjectCreate(0, obj_name, OBJ_LABEL, 0, 0, 0)) {
         DebugPrint("[Panel] Failed to create OBJ_LABEL: " + obj_name + " error=" + IntegerToString(GetLastError()));
         continue;
      }
      ObjectSetInteger(0, obj_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, obj_name, OBJPROP_XDISTANCE, panel_x + margin_x);
      ObjectSetInteger(0, obj_name, OBJPROP_YDISTANCE, panel_y + margin_y + i * line_height);
      ObjectSetInteger(0, obj_name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, obj_name, OBJPROP_FONTSIZE, font_size);
      ObjectSetInteger(0, obj_name, OBJPROP_ALIGN, ALIGN_LEFT);
      ObjectSetString(0, obj_name, OBJPROP_FONT, "Arial");
      ObjectSetString(0, obj_name, OBJPROP_TEXT, lines[i]);
      ObjectSetInteger(0, obj_name, OBJPROP_BACK, false);
      ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, obj_name, OBJPROP_HIDDEN, false); // Make label visible
      ObjectSetInteger(0, obj_name, OBJPROP_ZORDER, 2); // Ensure label is above panel
   }
   ChartRedraw(0);
}
//+------------------------------------------------------------------+
//| Modify stop loss                                                 |
//+------------------------------------------------------------------+
bool ModifyStopLoss(ulong ticket, double new_sl, ENUM_POSITION_TYPE pos_type, double entry_price) {
   if (!PositionSelectByTicket(ticket)) {
      DebugPrint(StringFormat("[ModifyStopLoss] Failed to select position ticket %I64u. Error: %d", ticket, GetLastError()));
      return false;
   }
   double current_tp = PositionGetDouble(POSITION_TP);
   double current_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double current_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double stop_level_points = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double stop_level_price = stop_level_points * g_point;
   new_sl = NormalizeDouble(new_sl, g_digits);
   if (pos_type == POSITION_TYPE_BUY) {
      double max_allowed_sl = current_bid - stop_level_price;
      if (new_sl > max_allowed_sl) {
         DebugPrint(StringFormat("[ModifyStopLoss] BUY SL %.5f above max allowed %.5f, adjusting.", new_sl, max_allowed_sl));
         new_sl = max_allowed_sl;
      }
      // If SL is not below current Bid, it's invalid
      if (new_sl >= current_bid) {
         DebugPrint(StringFormat("[ModifyStopLoss] BUY SL %.5f is not below current Bid %.5f. Not modifying.", new_sl, current_bid));
         return false;
      }
   }
   else if (pos_type == POSITION_TYPE_SELL) {
      double min_allowed_sl = current_ask + stop_level_price;
      if (new_sl < min_allowed_sl) {
         DebugPrint(StringFormat("[ModifyStopLoss] SELL SL %.5f below min allowed %.5f, adjusting.", new_sl, min_allowed_sl));
         new_sl = min_allowed_sl;
      }
      // If SL is not above current Ask, it's invalid
      if (new_sl <= current_ask) {
         DebugPrint(StringFormat("[ModifyStopLoss] SELL SL %.5f is not above current Ask %.5f. Not modifying.", new_sl, current_ask));
         return false;
      }
   }
   bool result = Trade.PositionModify(ticket, new_sl, current_tp);
   if (result) {
      LogTradeEvent("SL_MODIFY", ticket, new_sl, PositionGetDouble(POSITION_VOLUME));
   } else {
      int err = GetLastError();
      DebugPrint(StringFormat("[ModifyStopLoss] Failed to modify SL for ticket %I64u to %.5f (TP: %.5f). Error: %d", ticket, new_sl, current_tp, err));
   }
   return result;
}
//+------------------------------------------------------------------+
//| Log trade events                                                 |
//+------------------------------------------------------------------+
void LogTradeEvent(string eventType, ulong ticket, double price, double volume, string extra="") {
   string msg = StringFormat("[TradeLog] %s | Ticket: %I64u | Price: %.5f | Volume: %.2f %s", eventType, ticket, price, volume, extra);
   Print(msg);
}
//+------------------------------------------------------------------+
//| Calculate volume profile for any timeframe                       |
//+------------------------------------------------------------------+
void CalculateVolumeProfileTF(ENUM_TIMEFRAMES tf, double &vah, double &val, double &poc) {
   int total_bars = MathMin(VolumeProfilePeriod, Bars(_Symbol, tf));
   if (total_bars < 10) {
      vah = 0; val = 0; poc = 0;
      DebugPrint("Not enough bars in " + EnumToString(tf) + " for VP calculation. Found: " + IntegerToString(total_bars));
      return;
   }
   double high_array[];
   double low_array[];
   ArrayResize(high_array, total_bars);
   ArrayResize(low_array, total_bars);
   // Set as series AFTER resizing
   ArraySetAsSeries(high_array, true);
   ArraySetAsSeries(low_array, true);
   if(CopyHigh(_Symbol, tf, 0, total_bars, high_array) != total_bars) {
      vah=val=poc=0;
      DebugPrint("Failed to copy high prices for " + EnumToString(tf));
      return;
   }
   if(CopyLow(_Symbol, tf, 0, total_bars, low_array) != total_bars) {
      vah=val=poc=0;
      DebugPrint("Failed to copy low prices for " + EnumToString(tf));
      return;
   }
   double high = high_array[ArrayMaximum(high_array, 0, total_bars)];
   double low = low_array[ArrayMinimum(low_array, 0, total_bars)];
   double range = high - low;
   if (range <= 0) {
      vah=val=poc=0;
      DebugPrint("Invalid price range (zero or negative) for " + EnumToString(tf));
      return;
   }
   int levels = VolumeBars;
   double level_height = range / levels;
   double price_levels[];
   long level_volumes[];
   ArrayResize(price_levels, levels);
   ArrayResize(level_volumes, levels);
   for (int i = 0; i < levels; i++) {
      price_levels[i] = low + i * level_height;
      level_volumes[i] = 0;
   }
   // Try to use CopyTickVolume first
   long volume_array[];
   ArrayResize(volume_array, total_bars);
   ArraySetAsSeries(volume_array, true);
   int copied = CopyTickVolume(_Symbol, tf, 0, total_bars, volume_array);
   bool data_ok = copied == total_bars;
   // Fallback to iVolume if CopyTickVolume failed
   if (!data_ok) {
      for (int i = 0; i < total_bars; i++) {
         volume_array[i] = iVolume(_Symbol, tf, i);
         if(volume_array[i] <= 0 && i < 3) { // We need at least first few bars
            data_ok = false;
            DebugPrint("Failed to get volume data for " + EnumToString(tf));
            vah=val=poc=0;
            return;
         }
      }
   }
   for (int i = 0; i < total_bars; i++) {
      double bar_high = high_array[i];
      double bar_low = low_array[i];
      long bar_volume = (long)volume_array[i];
      // Calculate how much of this bar's volume goes to each level
      // Ensure the loop condition uses 'level' and not 'i'
      for (int level = 0; level < levels; level++) { // <<< Explicitly ensure condition is level < levels
         double level_low = price_levels[level];
         double level_high = level_low + level_height;
         // Calculate overlap
         double overlap_low = MathMax(bar_low, level_low);
         double overlap_high = MathMin(bar_high, level_high);
         double overlap = overlap_high - overlap_low;
         if (overlap > 0) {
            // Distribute volume proportionally
            double bar_range = bar_high - bar_low;
            if(bar_range > 0) { // Prevent division by zero
               double volume_portion = (double)bar_volume * (overlap / (double)bar_range);
               level_volumes[level] += (long)volume_portion;
            }
         }
      }
   }
   // Find POC (Point of Control) - level with highest volume
   long max_volume = 0;
   int poc_level = 0;
   // Check if levels array is valid
   if (levels <= 0) {
      DebugPrint("Invalid levels count in volume profile calculation");
      return;
   }
   // Find level with maximum volume with boundary checks
   for (int i = 0; i < levels; i++) {
      if (level_volumes[i] > max_volume) {
         max_volume = level_volumes[i];
         poc_level = i;
      }
   }
   // Check if we found a valid POC
   if (max_volume <= 0 || poc_level >= levels) {
      vah=val=poc=0;
      DebugPrint("No valid volume data found for " + EnumToString(tf));
      return;
   }
   // Ensure poc_level is within bounds
   poc_level = MathMin(poc_level, levels - 1);
   poc = price_levels[poc_level] + level_height / 2;
   // Calculate total volume
   long total_volume = 0;
   for (int i = 0; i < levels; i++) total_volume += level_volumes[i];
   if (total_volume <= 0) {
      vah=val=poc=0;
      DebugPrint("Total volume is zero for " + EnumToString(tf));
      return;
   }
   long value_area_volume = (long)(total_volume * ValueAreaPercent / 100.0);
   long current_volume = level_volumes[poc_level];
   int upper_level = poc_level;
   int lower_level = poc_level;
   while (current_volume < value_area_volume && (upper_level < levels - 1 || lower_level > 0)) {
      // Decide whether to expand up or down
      long volume_up = (upper_level < levels - 1) ? level_volumes[upper_level + 1] : 0;
      long volume_down = (lower_level > 0) ? level_volumes[lower_level - 1] : 0;
      if (volume_up > volume_down && upper_level < levels - 1) {
         upper_level++;
         current_volume += level_volumes[upper_level];
      }
      else if (lower_level > 0) {
         lower_level--;
         current_volume += level_volumes[lower_level];
      }
      else if (upper_level < levels - 1) {
         upper_level++;
         current_volume += level_volumes[upper_level];
      }
   }
   // Set VAH and VAL - FIXED: assign to output parameters, not globals
   vah = price_levels[upper_level] + level_height;
   val = price_levels[lower_level];
   // Debug output
   //DebugPrint(StringFormat("VP calculated for %s: VAH=%.5f VAL=%.5f POC=%.5f",
   //                        EnumToString(tf), vah, val, poc));
}
//+------------------------------------------------------------------+
//| Get signal based on Volume Profile logic for any timeframe       |
//+------------------------------------------------------------------+
ENUM_TRADE_SIGNAL GetVolumeProfileSignalTF(double vah, double val, double poc, ENUM_TIMEFRAMES tf) {
   double current_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double current_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   // Use dynamic arrays - volume should be long
   long volume_array[]; // Changed to long[]
   double open_array[];
   double close_array[];
   // Resize dynamic arrays
   ArrayResize(volume_array, 3);
   ArrayResize(open_array, 3);
   ArrayResize(close_array, 3);
   // Set as series AFTER resizing
   ArraySetAsSeries(volume_array, true);
   ArraySetAsSeries(open_array, true);
   ArraySetAsSeries(close_array, true);
   int bars_available = Bars(_Symbol, tf);
   for (int i = 0; i < 3; i++) {
      if (i < bars_available) {
         volume_array[i] = iVolume(_Symbol, tf, i); // Directly assign long
         open_array[i] = iOpen(_Symbol, tf, i);
         close_array[i] = iClose(_Symbol, tf, i);
      }
      else {
         volume_array[i] = 0; open_array[i] = 0; close_array[i] = 0;
      }
   }
   if(volume_array[0] <= 0 || volume_array[1] <= 0) return SIGNAL_NONE;
   long current_volume = volume_array[0]; // No cast needed
   long prev_volume = volume_array[1];    // No cast needed
   if ((current_price > vah && close_array[0] > open_array[0]) || (current_price > poc && close_array[0] > open_array[0] && current_price < vah)) {
      if (current_volume > prev_volume) return SIGNAL_BUY;
   }
   if ((current_bid < val && close_array[0] < open_array[0]) || (current_bid < poc && close_array[0] < open_array[0] && current_bid > val)) {
      if (current_volume < prev_volume) return SIGNAL_SELL; // Warning 43 might occur here implicitly, but less critical
   }
   return SIGNAL_NONE;
}
//+------------------------------------------------------------------+
//| Check if price is near a key volume profile level                 |
//+------------------------------------------------------------------+
bool IsPriceAtKeyLevel() {
   if (g_vah == 0 || g_val == 0 || g_poc == 0) return false;
   // Get current prices
   double current_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   // Calculate approximate level height based on range
   if (g_level_height == 0) {
      g_level_height = (g_vah - g_val) / VolumeBars;
   }
   // Calculate maximum allowed distance from levels in price
   double max_distance = g_level_height * DistanceFromVPLevels;
   // Check if price is near VAH
   if (MathAbs(current_price - g_vah) <= max_distance) {
      g_is_at_key_level = true;
      g_key_level_type = "VAH";
      return true;
   }
   // Check if price is near VAL
   if (MathAbs(current_price - g_val) <= max_distance) {
      g_is_at_key_level = true;
      g_key_level_type = "VAL";
      return true;
   }
   // Check if price is near POC
   if (MathAbs(current_price - g_poc) <= max_distance) {
      g_is_at_key_level = true;
      g_key_level_type = "POC";
      return true;
   }
   g_is_at_key_level = false;
   g_key_level_type = "";
   return false;
}
//+------------------------------------------------------------------+
//| Check for breakout/rejection at volume profile levels            |
//+------------------------------------------------------------------+
bool CheckBreakoutRejection(ENUM_TRADE_SIGNAL &signal) {
   if (!UseBreakoutRejection) return false;
   if (g_vah == 0 || g_val == 0 || g_poc == 0) return false;
   // Get candle data - Use dynamic arrays - volume should be long
   double high_array[];
   double low_array[];
   double open_array[];
   double close_array[];
   long volume_array[]; // Changed to long[]
   // Resize dynamic arrays
   ArrayResize(high_array, 3);
   ArrayResize(low_array, 3);
   ArrayResize(open_array, 3);
   ArrayResize(close_array, 3);
   ArrayResize(volume_array, 3); // Resize long array
   // Set as series AFTER resizing
   ArraySetAsSeries(high_array, true);
   ArraySetAsSeries(low_array, true);
   ArraySetAsSeries(open_array, true);
   ArraySetAsSeries(close_array, true);
   ArraySetAsSeries(volume_array, true); // Set long array as series
   if (CopyHigh(_Symbol, PERIOD_CURRENT, 0, 3, high_array) != 3) return false;
   if (CopyLow(_Symbol, PERIOD_CURRENT, 0, 3, low_array) != 3) return false;
   if (CopyOpen(_Symbol, PERIOD_CURRENT, 0, 3, open_array) != 3) return false;
   if (CopyClose(_Symbol, PERIOD_CURRENT, 0, 3, close_array) != 3) return false;
   for (int i = 0; i < 3; i++) {
      volume_array[i] = iVolume(_Symbol, PERIOD_CURRENT, i); // Directly assign long
   }
   // Calculate level height if not done yet
   if (g_level_height == 0) {
      g_level_height = (g_vah - g_val) / VolumeBars;
   }
   // Check for VAH breakout
   if (close_array[1] < g_vah && close_array[0] > g_vah && volume_array[0] > volume_array[1]) {
      // Bullish breakout of VAH
      g_is_vpbreakout = true;
      g_is_vprejection = false;
      g_key_level_type = "VAH";
      signal = SIGNAL_BUY;
      return true;
   }
   // Check for VAL breakout
   if (close_array[1] > g_val && close_array[0] < g_val && volume_array[0] > volume_array[1]) {
      // Bearish breakout of VAL
      g_is_vpbreakout = true;
      g_is_vprejection = false;
      g_key_level_type = "VAL";
      signal = SIGNAL_SELL;
      return true;
   }
   // Check for VAH rejection (price tried to break but failed)
   if (high_array[1] > g_vah && close_array[1] < g_vah && high_array[0] < g_vah && volume_array[0] > volume_array[1]) {
      // Bearish rejection at VAH
      g_is_vpbreakout = false;
      g_is_vprejection = true;
      g_key_level_type = "VAH";
      signal = SIGNAL_SELL;
      return true;
   }
   // Check for VAL rejection (price tried to break but failed)
   if (low_array[1] < g_val && close_array[1] > g_val && low_array[0] > g_val && volume_array[0] > volume_array[1]) {
      // Bullish rejection at VAL
      g_is_vpbreakout = false;
      g_is_vprejection = true;
      g_key_level_type = "VAL";
      signal = SIGNAL_BUY;
      return true;
   }
   // Check for POC rejection (price bounced off POC)
   double max_distance = g_level_height * DistanceFromVPLevels;
   // Bullish POC rejection (price bounced up from POC)
   if (MathAbs(low_array[1] - g_poc) <= max_distance && close_array[0] > open_array[0] && volume_array[0] > volume_array[1]) {
      g_is_vpbreakout = false;
      g_is_vprejection = true;
      g_key_level_type = "POC";
      signal = SIGNAL_BUY;
      return true;
   }
   // Bearish POC rejection (price bounced down from POC)
   if (MathAbs(high_array[1] - g_poc) <= max_distance && close_array[0] < open_array[0] && volume_array[0] > volume_array[1]) {
      g_is_vpbreakout = false;
      g_is_vprejection = true;
      g_key_level_type = "POC";
      signal = SIGNAL_SELL;
      return true;
   }
   g_is_vpbreakout = false;
   g_is_vprejection = false;
   return false;
}
//+------------------------------------------------------------------+
//| TradeTransaction function                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result) {
   ENUM_TRADE_TRANSACTION_TYPE type=trans.type;
   if (type==TRADE_TRANSACTION_DEAL_ADD) {
      long     deal_ticket = trans.deal;
      long     deal_magic = HistoryDealGetInteger(deal_ticket, DEAL_MAGIC);
      string   deal_symbol = HistoryDealGetString(deal_ticket, DEAL_SYMBOL);
      double   deal_profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
      long     deal_entry = HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
      if (deal_magic == MagicNumber && deal_symbol == _Symbol && (deal_entry == DEAL_ENTRY_OUT || deal_entry == DEAL_ENTRY_INOUT)) {
         if (deal_profit < 0) {
            DebugPrint(StringFormat("[Transaction] Loss detected on deal #%d (Profit: %.2f). Multiplying lot size for next trade.", deal_ticket, deal_profit));
            if (LossMultiplier > 1.0) {
               g_apply_loss_multiplier = true;
            }
         }
         else {
            DebugPrint(StringFormat("[Transaction] Profit/BE detected on deal #%d (Profit: %.2f). Resetting lot size to base.", deal_ticket, deal_profit));
            g_apply_loss_multiplier = false;
         }
      }
   }
}