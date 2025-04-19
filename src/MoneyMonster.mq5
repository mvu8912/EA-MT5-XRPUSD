//+------------------------------------------------------------------+
//|                                                 MoneyMonster.mq5 |
//|                                 Copyright 2025, MetaQuotes Ltd. |
//|                                   https://www.metaquotes.net |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      "https://www.metaquotes.net"
#property version   "1.00"
#property description "MoneyMonster - Multi-timeframe Scalping EA for XRPUSD"
// Removed the icon property since the file doesn't exist
#property tester_indicator "Examples\\RSI.ex5"
#property indicator_separate_window  0 // No separate indicator window

// Enumerations
enum ENUM_TP_MODE {
   TP_PIPS,       // TPs in pips
   TP_PRICE       // TPs as absolute price levels
};

// Visualization Parameters
input string VisualSettings = "===== Visualization Settings ====="; // Visualization Settings
input bool ShowInfoPanel = true;                               // Show Information Panel
input bool ShowTradeLines = true;                              // Show Trade Lines (SL/TP levels)
input color BuyColor = clrDodgerBlue;                          // Buy Color
input color SellColor = clrCrimson;                            // Sell Color
input color TPColor = clrLimeGreen;                            // Take Profit Line Color
input color SLColor = clrRed;                                  // Stop Loss Line Color
input int InfoCorner = CORNER_RIGHT_UPPER;                     // Info Panel Corner
input int InfoFontSize = 10;                                   // Info Panel Font Size
input color InfoTextColor = clrWhite;                          // Info Text Color
input color InfoBackColor = C'25,25,25';                       // Info Background Color

// Input Parameters - General
input string GeneralSettings = "===== General Settings ====="; // General Settings
input string Symbol_Name = "XRPUSD";                          // Trading Symbol
input bool EnableTrading = true;                              // Enable Trading
input double RiskPercent = 1.0;                               // Risk Percentage (%)
input double DailyLossLimit = 5.0;                            // Daily Loss Limit (%)
input int Magic_Number = 123456;                              // Magic Number
input string Comments = "MoneyMonster";                       // Trade Comments

// Input Parameters - Multi-Timeframe Settings
input string TimeframeSettings = "===== Timeframe Settings ====="; // Timeframe Settings
input ENUM_TIMEFRAMES TimeFrame1Min = PERIOD_M1;              // 1-Minute Chart
input ENUM_TIMEFRAMES TimeFrame5Min = PERIOD_M5;              // 5-Minute Chart
input ENUM_TIMEFRAMES TimeFrame15Min = PERIOD_M15;            // 15-Minute Chart

// Input Parameters - Moving Averages
input string MASettings = "===== Moving Average Settings ====="; // MA Settings
input bool Use_MA = true;                                    // Use Moving Averages
input ENUM_MA_METHOD MA_Method = MODE_EMA;                   // MA Method
input ENUM_APPLIED_PRICE MA_Applied_Price = PRICE_CLOSE;     // MA Applied Price
input int MA_Fast_Period = 8;                                // Fast MA Period
input int MA_Medium_Period = 21;                             // Medium MA Period
input int MA_Slow_Period = 50;                               // Slow MA Period

// Input Parameters - RSI
input string RSISettings = "===== RSI Settings =====";        // RSI Settings
input bool Use_RSI = true;                                   // Use RSI
input int RSI_Period = 14;                                   // RSI Period
input int RSI_Overbought = 70;                               // RSI Overbought Level
input int RSI_Oversold = 30;                                 // RSI Oversold Level
input ENUM_APPLIED_PRICE RSI_Applied_Price = PRICE_CLOSE;    // RSI Applied Price

// Input Parameters - MACD
input string MACDSettings = "===== MACD Settings =====";      // MACD Settings
input bool Use_MACD = true;                                  // Use MACD
input int MACD_Fast_EMA = 12;                                // MACD Fast EMA Period
input int MACD_Slow_EMA = 26;                                // MACD Slow EMA Period
input int MACD_Signal_Period = 9;                            // MACD Signal Period
input ENUM_APPLIED_PRICE MACD_Applied_Price = PRICE_CLOSE;   // MACD Applied Price

// Input Parameters - Bollinger Bands
input string BBSettings = "===== Bollinger Bands Settings ====="; // Bollinger Bands Settings
input bool Use_Bollinger = true;                             // Use Bollinger Bands
input int BB_Period = 20;                                    // Bollinger Period
input double BB_Deviation = 2.0;                             // Bollinger Deviation
input ENUM_APPLIED_PRICE BB_Applied_Price = PRICE_CLOSE;     // Bollinger Applied Price

// Input Parameters - ADX
input string ADXSettings = "===== ADX Settings =====";        // ADX Settings
input bool Use_ADX = true;                                   // Use ADX
input int ADX_Period = 14;                                   // ADX Period
input int ADX_Threshold = 25;                                // ADX Threshold

// Input Parameters - ATR
input string ATRSettings = "===== ATR Settings =====";        // ATR Settings
input bool Use_ATR = true;                                   // Use ATR
input int ATR_Period = 14;                                   // ATR Period
input double ATR_Multiplier = 1.5;                           // ATR Multiplier for SL

// Input Parameters - Trade Management
input string TradeSettings = "===== Trade Management =====";   // Trade Management
input ENUM_TP_MODE TP_Mode = TP_PIPS;                        // TP Mode
input double TP1_Level = 5.0;                                // TP1 Level (pips or price)
input double TP2_Level = 10.0;                               // TP2 Level (pips or price)
input double TP3_Level = 15.0;                               // TP3 Level (pips or price)
input double TP4_Level = 20.0;                               // TP4 Level (pips or price)
input double SL_Distance = 10.0;                             // Initial SL Distance (pips)
input double Dynamic_SL_Distance = 5.0;                      // Dynamic SL Distance (pips)

// Trailing stop parameters
input string TrailingSettings = "===== Trailing Stop Settings ====="; // Trailing Stop Settings
input bool Use_Trailing_Stop = true;                               // Use Trailing Stop
input double Trailing_Start = 10.0;                                // Start Trailing (pips)
input double Trailing_Step = 1.0;                                  // Trailing Step (pips)
input double Trailing_Distance = 5.0;                              // Trailing Distance (pips)

// Gap handling parameters
input string GapSettings = "===== Gap Protection Settings =====";     // Gap Protection Settings
input bool Use_Gap_Protection = true;                              // Use Gap Protection
input double Max_Gap_Size = 20.0;                                  // Maximum Gap Size (pips) for reducing position

// Volatility-based risk
input string VolRiskSettings = "===== Volatility Risk Settings ====="; // Volatility Risk Settings
input bool Use_Vol_Risk = true;                                   // Use Volatility-Based Risk
input double Vol_Risk_Factor = 1.0;                               // Volatility Risk Factor (1.0 = Default)

// Global Variables
double g_point;               // Point value
int g_digits;                 // Digits
bool g_ECN_Mode;              // ECN Mode flag
double g_tick_size;           // Tick size
double g_tick_value;          // Tick value
double g_min_lot;             // Minimum lot size
double g_max_lot;             // Maximum lot size
double g_lot_step;            // Lot step
double g_daily_loss;          // Daily loss
datetime g_last_trade_time;   // Last trade time

// Enhanced logging system
bool g_debug_mode = false;      // Debug mode flag for detailed logging
int g_log_level = 2;            // Log level: 0-None, 1-Critical, 2-Important, 3-Debug

// Statistics for EA performance
int g_total_trades = 0;        // Total trades taken
int g_winning_trades = 0;      // Winning trades
int g_losing_trades = 0;       // Losing trades
double g_gross_profit = 0.0;   // Gross profit
double g_gross_loss = 0.0;     // Gross loss
double g_max_drawdown = 0.0;   // Maximum drawdown experienced

// Runtime indicator availability flags (separate from input parameters)
bool g_use_ma = true;        // MA indicators available
bool g_use_rsi = true;       // RSI indicators available
bool g_use_macd = true;      // MACD indicators available
bool g_use_bollinger = true; // Bollinger indicators available
bool g_use_adx = true;       // ADX indicators available
bool g_use_atr = true;       // ATR indicators available

// Trade tracking
int g_total_orders = 0;       // Total orders
double g_total_lots = 0.0;    // Total lots
bool g_tp1_hit = false;       // TP1 hit flag
bool g_tp2_hit = false;       // TP2 hit flag
bool g_tp3_hit = false;       // TP3 hit flag
bool g_tp4_hit = false;       // TP4 hit flag
bool g_midway_tp4_hit = false;// Midway to TP4 hit flag

// TP tracking for each ticket
struct TP_TRACKER {
   ulong ticket;              // Order ticket
   double tp1;                // TP1 level
   double tp2;                // TP2 level
   double tp3;                // TP3 level
   double tp4;                // TP4 level
   double entry_price;        // Entry price
   double original_sl;        // Original SL
   double midway_tp4;         // Midway to TP4
   bool tp1_hit;              // TP1 hit flag
   bool tp2_hit;              // TP2 hit flag
   bool tp3_hit;              // TP3 hit flag
   bool midway_tp4_hit;       // Midway to TP4 hit flag
   double lots;               // Original lots
   double current_lots;       // Current lots
   ENUM_POSITION_TYPE pos_type; // Position type (buy or sell)
};

// Array of TP trackers
TP_TRACKER g_tp_trackers[];

// Indicator handles
int h_ma_fast_1m = INVALID_HANDLE;
int h_ma_medium_1m = INVALID_HANDLE;
int h_ma_slow_1m = INVALID_HANDLE;
int h_ma_fast_5m = INVALID_HANDLE;
int h_ma_medium_5m = INVALID_HANDLE;
int h_ma_slow_5m = INVALID_HANDLE;
int h_ma_fast_15m = INVALID_HANDLE;
int h_ma_medium_15m = INVALID_HANDLE;
int h_ma_slow_15m = INVALID_HANDLE;
int h_rsi_1m = INVALID_HANDLE;
int h_rsi_5m = INVALID_HANDLE;
int h_rsi_15m = INVALID_HANDLE;
int h_macd_1m = INVALID_HANDLE;
int h_macd_5m = INVALID_HANDLE;
int h_macd_15m = INVALID_HANDLE;
int h_bb_1m = INVALID_HANDLE;
int h_bb_5m = INVALID_HANDLE;
int h_bb_15m = INVALID_HANDLE;
int h_adx_1m = INVALID_HANDLE;
int h_adx_5m = INVALID_HANDLE;
int h_adx_15m = INVALID_HANDLE;
int h_atr_1m = INVALID_HANDLE;
int h_atr_5m = INVALID_HANDLE;
int h_atr_15m = INVALID_HANDLE;

// Indicator folder paths - for easy management of indicator locations
// Forward declarations - using a struct for signals instead of references
struct SIGNAL_STATE {
   bool buy_signal;
   bool sell_signal;
};

SIGNAL_STATE CalculateSignals();
double CalculateVolatilityAdjustedLotSize(double stop_loss_pips);

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   // Check if the specified symbol exists
   if(!SymbolSelect(Symbol_Name, true)) {
      Print("Error: Symbol ", Symbol_Name, " does not exist or is not available. EA initialization failed.");
      return INIT_FAILED;
   }
   
   // Initialize global variables
   g_point = SymbolInfoDouble(Symbol_Name, SYMBOL_POINT);
   g_digits = (int)SymbolInfoInteger(Symbol_Name, SYMBOL_DIGITS);
   g_tick_size = SymbolInfoDouble(Symbol_Name, SYMBOL_TRADE_TICK_SIZE);
   g_tick_value = SymbolInfoDouble(Symbol_Name, SYMBOL_TRADE_TICK_VALUE);
   g_min_lot = SymbolInfoDouble(Symbol_Name, SYMBOL_VOLUME_MIN);
   g_max_lot = SymbolInfoDouble(Symbol_Name, SYMBOL_VOLUME_MAX);
   g_lot_step = SymbolInfoDouble(Symbol_Name, SYMBOL_VOLUME_STEP);
   
   // Here are the explicit casts for the SymbolInfoInteger calls that were causing warnings
   long execution_mode = SymbolInfoInteger(Symbol_Name, SYMBOL_TRADE_EXEMODE);
   g_ECN_Mode = (execution_mode == SYMBOL_TRADE_EXECUTION_MARKET);
   
   g_daily_loss = 0.0;
   g_last_trade_time = 0;
   
   // Reset trade tracking
   ArrayResize(g_tp_trackers, 0);
   g_total_orders = 0;
   g_total_lots = 0.0;
   g_tp1_hit = false;
   g_tp2_hit = false;
   g_tp3_hit = false;
   g_tp4_hit = false;
   g_midway_tp4_hit = false;
   
   // Initialize indicator handles
   InitializeIndicators();
   
   // Log initialization
   Print("MoneyMonster EA initialized for ", Symbol_Name, " - Magic Number: ", Magic_Number);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   // Release indicator handles
   ReleaseIndicators();
   
   // Log deinitialization
   Print("MoneyMonster EA deinitialized. Reason code: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
   // Check if trading is enabled
   if(!EnableTrading) return;
   
   // Check daily loss limit
   if(CheckDailyLossLimit()) return;
   
   // Check if we have enough data for all timeframes
   if(!IsDataReady()) {
      Print("Not enough historical data for all timeframes. Waiting for more data...");
      return;
   }
   
   // Manage existing positions
   ManagePositions();
   
   // Calculate entry signals
   SIGNAL_STATE signals = CalculateSignals();
   
   // Process signals
   if(signals.buy_signal || signals.sell_signal) {
      // Count positions for our Symbol and Magic number
      int symbol_positions = CountSymbolPositions();
      
      // Only allow one position per symbol/magic number at a time (prevents hedging)
      if(symbol_positions > 0) {
         Print("Position already exists for ", Symbol_Name, " with Magic: ", Magic_Number, ". No new positions will be opened.");
         return;
      }
      
      // Calculate lot size based on risk
      double lot_size = CalculateVolatilityAdjustedLotSize(SL_Distance);
      
      // Open position
      if(signals.buy_signal) {
         OpenPosition(ORDER_TYPE_BUY, lot_size);
      }
      else if(signals.sell_signal) {
         OpenPosition(ORDER_TYPE_SELL, lot_size);
      }
   }
   
   // Handle market gaps
   HandleMarketGap();
   
   // Update chart visuals
   UpdateChartVisuals();
}

//+------------------------------------------------------------------+
//| Initialize all indicator handles                                 |
//+------------------------------------------------------------------+
void InitializeIndicators() {
   // Initialize Moving Average handles
   if(Use_MA) {
      // 1-Minute timeframe MA
      h_ma_fast_1m = iMA(Symbol_Name, TimeFrame1Min, MA_Fast_Period, 0, MA_Method, MA_Applied_Price);
      h_ma_medium_1m = iMA(Symbol_Name, TimeFrame1Min, MA_Medium_Period, 0, MA_Method, MA_Applied_Price);
      h_ma_slow_1m = iMA(Symbol_Name, TimeFrame1Min, MA_Slow_Period, 0, MA_Method, MA_Applied_Price);
      
      // 5-Minute timeframe MA
      h_ma_fast_5m = iMA(Symbol_Name, TimeFrame5Min, MA_Fast_Period, 0, MA_Method, MA_Applied_Price);
      h_ma_medium_5m = iMA(Symbol_Name, TimeFrame5Min, MA_Medium_Period, 0, MA_Method, MA_Applied_Price);
      h_ma_slow_5m = iMA(Symbol_Name, TimeFrame5Min, MA_Slow_Period, 0, MA_Method, MA_Applied_Price);
      
      // 15-Minute timeframe MA
      h_ma_fast_15m = iMA(Symbol_Name, TimeFrame15Min, MA_Fast_Period, 0, MA_Method, MA_Applied_Price);
      h_ma_medium_15m = iMA(Symbol_Name, TimeFrame15Min, MA_Medium_Period, 0, MA_Method, MA_Applied_Price);
      h_ma_slow_15m = iMA(Symbol_Name, TimeFrame15Min, MA_Slow_Period, 0, MA_Method, MA_Applied_Price);
      
      // Check if all MA handles were created successfully
      if(h_ma_fast_1m == (int)INVALID_HANDLE || h_ma_medium_1m == (int)INVALID_HANDLE || h_ma_slow_1m == (int)INVALID_HANDLE ||
         h_ma_fast_5m == (int)INVALID_HANDLE || h_ma_medium_5m == (int)INVALID_HANDLE || h_ma_slow_5m == (int)INVALID_HANDLE ||
         h_ma_fast_15m == (int)INVALID_HANDLE || h_ma_medium_15m == (int)INVALID_HANDLE || h_ma_slow_15m == (int)INVALID_HANDLE) {
         Print("Error creating MA indicators. MA strategy will be disabled at runtime.");
         g_use_ma = false;
      }
   } else {
      g_use_ma = false;
   }
   
   // Initialize RSI handles
   if(Use_RSI) {
      h_rsi_1m = iRSI(Symbol_Name, TimeFrame1Min, RSI_Period, RSI_Applied_Price);
      h_rsi_5m = iRSI(Symbol_Name, TimeFrame5Min, RSI_Period, RSI_Applied_Price);
      h_rsi_15m = iRSI(Symbol_Name, TimeFrame15Min, RSI_Period, RSI_Applied_Price);
      
      // Check if RSI handles were created successfully
      if(h_rsi_1m == (int)INVALID_HANDLE || h_rsi_5m == (int)INVALID_HANDLE || h_rsi_15m == (int)INVALID_HANDLE) {
         Print("Error creating RSI indicators. RSI strategy will be disabled at runtime.");
         g_use_rsi = false;
      }
   } else {
      g_use_rsi = false;
   }
   
   // Initialize MACD handles
   if(Use_MACD) {
      h_macd_1m = iMACD(Symbol_Name, TimeFrame1Min, MACD_Fast_EMA, MACD_Slow_EMA, MACD_Signal_Period, MACD_Applied_Price);
      h_macd_5m = iMACD(Symbol_Name, TimeFrame5Min, MACD_Fast_EMA, MACD_Slow_EMA, MACD_Signal_Period, MACD_Applied_Price);
      h_macd_15m = iMACD(Symbol_Name, TimeFrame15Min, MACD_Fast_EMA, MACD_Slow_EMA, MACD_Signal_Period, MACD_Applied_Price);
      
      // Check if MACD handles were created successfully
      if(h_macd_1m == (int)INVALID_HANDLE || h_macd_5m == (int)INVALID_HANDLE || h_macd_15m == (int)INVALID_HANDLE) {
         Print("Error creating MACD indicators. MACD strategy will be disabled at runtime.");
         g_use_macd = false;
      }
   } else {
      g_use_macd = false;
   }
   
   // Initialize Bollinger Bands handles
   if(Use_Bollinger) {
      h_bb_1m = iBands(Symbol_Name, TimeFrame1Min, BB_Period, BB_Deviation, 0, BB_Applied_Price);
      h_bb_5m = iBands(Symbol_Name, TimeFrame5Min, BB_Period, BB_Deviation, 0, BB_Applied_Price);
      h_bb_15m = iBands(Symbol_Name, TimeFrame15Min, BB_Period, BB_Deviation, 0, BB_Applied_Price);
      
      // Check if Bollinger Bands handles were created successfully
      if(h_bb_1m == INVALID_HANDLE || h_bb_5m == INVALID_HANDLE || h_bb_15m == INVALID_HANDLE) {
         Print("Error creating Bollinger Bands indicators. Bollinger strategy will be disabled at runtime.");
         g_use_bollinger = false;
      }
   } else {
      g_use_bollinger = false;
   }
   
   // Initialize ADX handles
   if(Use_ADX) {
      h_adx_1m = iADX(Symbol_Name, TimeFrame1Min, ADX_Period);
      h_adx_5m = iADX(Symbol_Name, TimeFrame5Min, ADX_Period);
      h_adx_15m = iADX(Symbol_Name, TimeFrame15Min, ADX_Period);
      
      // Check if ADX handles were created successfully
      if(h_adx_1m == (int)INVALID_HANDLE || h_adx_5m == (int)INVALID_HANDLE || h_adx_15m == (int)INVALID_HANDLE) {
         Print("Error creating ADX indicators. ADX strategy will be disabled at runtime.");
         g_use_adx = false;
      }
   } else {
      g_use_adx = false;
   }
   
   // Initialize ATR handles
   if(Use_ATR) {
      h_atr_1m = iATR(Symbol_Name, TimeFrame1Min, ATR_Period);
      h_atr_5m = iATR(Symbol_Name, TimeFrame5Min, ATR_Period);
      h_atr_15m = iATR(Symbol_Name, TimeFrame15Min, ATR_Period);
      
      // Check if ATR handles were created successfully
      if(h_atr_1m == (int)INVALID_HANDLE || h_atr_5m == (int)INVALID_HANDLE || h_atr_15m == (int)INVALID_HANDLE) {
         Print("Error creating ATR indicators. ATR usage will be disabled at runtime.");
         g_use_atr = false;
      }
   } else {
      g_use_atr = false;
   }
}

//+------------------------------------------------------------------+
//| Release indicator handles                                         |
//+------------------------------------------------------------------+
void ReleaseIndicators() {
   // Release Moving Average handles
   if(Use_MA) {
      IndicatorRelease(h_ma_fast_1m);
      IndicatorRelease(h_ma_medium_1m);
      IndicatorRelease(h_ma_slow_1m);
      
      IndicatorRelease(h_ma_fast_5m);
      IndicatorRelease(h_ma_medium_5m);
      IndicatorRelease(h_ma_slow_5m);
      
      IndicatorRelease(h_ma_fast_15m);
      IndicatorRelease(h_ma_medium_15m);
      IndicatorRelease(h_ma_slow_15m);
   }
   
   // Release RSI handles
   if(Use_RSI) {
      IndicatorRelease(h_rsi_1m);
      IndicatorRelease(h_rsi_5m);
      IndicatorRelease(h_rsi_15m);
   }
   
   // Release MACD handles
   if(Use_MACD) {
      IndicatorRelease(h_macd_1m);
      IndicatorRelease(h_macd_5m);
      IndicatorRelease(h_macd_15m);
   }
   
   // Release Bollinger Bands handles
   if(Use_Bollinger) {
      IndicatorRelease(h_bb_1m);
      IndicatorRelease(h_bb_5m);
      IndicatorRelease(h_bb_15m);
   }
   
   // Release ADX handles
   if(Use_ADX) {
      IndicatorRelease(h_adx_1m);
      IndicatorRelease(h_adx_5m);
      IndicatorRelease(h_adx_15m);
   }
   
   // Release ATR handles
   if(Use_ATR) {
      IndicatorRelease(h_atr_1m);
      IndicatorRelease(h_atr_5m);
      IndicatorRelease(h_atr_15m);
   }
}

//+------------------------------------------------------------------+
//| Calculate trading signals across multiple timeframes              |
//+------------------------------------------------------------------+
SIGNAL_STATE CalculateSignals() {
   SIGNAL_STATE signals;
   signals.buy_signal = false;
   signals.sell_signal = false;
   
   // Check if all required indicators are valid
   if(!AreIndicatorsValid()) {
      Print("Error: Not all required indicators are valid. Signal calculation aborted.");
      return signals;
   }
   
   // Get indicator values for all timeframes
   double ma_fast_1m = GetIndicatorValue(h_ma_fast_1m, 0);
   double ma_medium_1m = GetIndicatorValue(h_ma_medium_1m, 0);
   double ma_slow_1m = GetIndicatorValue(h_ma_slow_1m, 0);
   
   double ma_fast_5m = GetIndicatorValue(h_ma_fast_5m, 0);
   double ma_medium_5m = GetIndicatorValue(h_ma_medium_5m, 0);
   double ma_slow_5m = GetIndicatorValue(h_ma_slow_5m, 0);
   
   double ma_fast_15m = GetIndicatorValue(h_ma_fast_15m, 0);
   double ma_medium_15m = GetIndicatorValue(h_ma_medium_15m, 0);
   double ma_slow_15m = GetIndicatorValue(h_ma_slow_15m, 0);
   
   double rsi_1m = GetIndicatorValue(h_rsi_1m, 0);
   double rsi_5m = GetIndicatorValue(h_rsi_5m, 0);
   double rsi_15m = GetIndicatorValue(h_rsi_15m, 0);
   
   // MACD values (main line and signal line)
   double macd_main_1m = GetIndicatorValue(h_macd_1m, 0, 0);
   double macd_signal_1m = GetIndicatorValue(h_macd_1m, 0, 1);
   double macd_main_5m = GetIndicatorValue(h_macd_5m, 0, 0);
   double macd_signal_5m = GetIndicatorValue(h_macd_5m, 0, 1);
   double macd_main_15m = GetIndicatorValue(h_macd_15m, 0, 0);
   double macd_signal_15m = GetIndicatorValue(h_macd_15m, 0, 1);
   
   // Bollinger Bands values (upper, middle, lower bands)
   double bb_upper_1m = GetIndicatorValue(h_bb_1m, 0, 1);
   double bb_middle_1m = GetIndicatorValue(h_bb_1m, 0, 0);
   double bb_lower_1m = GetIndicatorValue(h_bb_1m, 0, 2);
   double bb_upper_5m = GetIndicatorValue(h_bb_5m, 0, 1);
   double bb_middle_5m = GetIndicatorValue(h_bb_5m, 0, 0);
   double bb_lower_5m = GetIndicatorValue(h_bb_5m, 0, 2);
   double bb_upper_15m = GetIndicatorValue(h_bb_15m, 0, 1);
   double bb_middle_15m = GetIndicatorValue(h_bb_15m, 0, 0);
   double bb_lower_15m = GetIndicatorValue(h_bb_15m, 0, 2);
   
   // ADX values (ADX, +DI, -DI)
   double adx_1m = GetIndicatorValue(h_adx_1m, 0, 0);
   double plus_di_1m = GetIndicatorValue(h_adx_1m, 0, 1);
   double minus_di_1m = GetIndicatorValue(h_adx_1m, 0, 2);
   double adx_5m = GetIndicatorValue(h_adx_5m, 0, 0);
   double plus_di_5m = GetIndicatorValue(h_adx_5m, 0, 1);
   double minus_di_5m = GetIndicatorValue(h_adx_5m, 0, 2);
   double adx_15m = GetIndicatorValue(h_adx_15m, 0, 0);
   double plus_di_15m = GetIndicatorValue(h_adx_15m, 0, 1);
   double minus_di_15m = GetIndicatorValue(h_adx_15m, 0, 2);
   
   // ATR values
   double atr_1m = GetIndicatorValue(h_atr_1m, 0);
   double atr_5m = GetIndicatorValue(h_atr_5m, 0);
   double atr_15m = GetIndicatorValue(h_atr_15m, 0);
   
   // 15-Minute timeframe trend confirmation
   bool uptrend_15m = false;
   bool downtrend_15m = false;
   
   // Check 15M trend based on MA
   if(Use_MA && g_use_ma) {
      uptrend_15m = (ma_fast_15m > ma_slow_15m) && (ma_medium_15m > ma_slow_15m);
      downtrend_15m = (ma_fast_15m < ma_slow_15m) && (ma_medium_15m < ma_slow_15m);
   }
   
   // 15M ADX trend confirmation
   if(Use_ADX && g_use_adx) {
      bool strong_trend_15m = (adx_15m > ADX_Threshold);
      
      if(strong_trend_15m) {
         if(plus_di_15m > minus_di_15m) uptrend_15m = uptrend_15m && true;
         else if(minus_di_15m > plus_di_15m) downtrend_15m = downtrend_15m && true;
      }
   }
   
   // 5-Minute timeframe signal generation
   bool buy_signal_5m = false;
   bool sell_signal_5m = false;
   
   // 5M MA Crossover
   if(Use_MA) {
      // Buy signal: Fast MA crosses above Medium MA
      if(ma_fast_5m > ma_medium_5m && GetIndicatorValue(h_ma_fast_5m, 1) <= GetIndicatorValue(h_ma_medium_5m, 1)) {
         buy_signal_5m = true;
      }
      
      // Sell signal: Fast MA crosses below Medium MA
      if(ma_fast_5m < ma_medium_5m && GetIndicatorValue(h_ma_fast_5m, 1) >= GetIndicatorValue(h_ma_medium_5m, 1)) {
         sell_signal_5m = true;
      }
   }
   
   // 5M RSI Conditions
   if(Use_RSI) {
      // Buy: RSI crossing above oversold level
      if(rsi_5m > RSI_Oversold && GetIndicatorValue(h_rsi_5m, 1) <= RSI_Oversold) {
         buy_signal_5m = true;
      }
      
      // Sell: RSI crossing below overbought level
      if(rsi_5m < RSI_Overbought && GetIndicatorValue(h_rsi_5m, 1) >= RSI_Overbought) {
         sell_signal_5m = true;
      }
   }
   
   // 5M MACD Conditions
   if(Use_MACD) {
      // Buy: MACD line crosses above Signal line
      if(macd_main_5m > macd_signal_5m && GetIndicatorValue(h_macd_5m, 1, 0) <= GetIndicatorValue(h_macd_5m, 1, 1)) {
         buy_signal_5m = true;
      }
      
      // Sell: MACD line crosses below Signal line
      if(macd_main_5m < macd_signal_5m && GetIndicatorValue(h_macd_5m, 1, 0) >= GetIndicatorValue(h_macd_5m, 1, 1)) {
         sell_signal_5m = true;
      }
   }
   
   // 5M Bollinger Bands Conditions
   if(Use_Bollinger) {
      double close_5m = iClose(Symbol_Name, TimeFrame5Min, 0);
      double prev_close_5m = iClose(Symbol_Name, TimeFrame5Min, 1);
      
      // Buy: Price bounces off lower band
      if(prev_close_5m <= GetIndicatorValue(h_bb_5m, 1, 2) && close_5m > GetIndicatorValue(h_bb_5m, 0, 2)) {
         buy_signal_5m = true;
      }
      
      // Sell: Price bounces off upper band
      if(prev_close_5m >= GetIndicatorValue(h_bb_5m, 1, 1) && close_5m < GetIndicatorValue(h_bb_5m, 0, 1)) {
         sell_signal_5m = true;
      }
   }
   
   // 1-Minute timeframe entry conditions
   bool entry_condition_1m_buy = false;
   bool entry_condition_1m_sell = false;
   
   // 1M Entry based on MA alignment
   if(Use_MA) {
      // Buy setup: All MAs aligned (fast > medium > slow)
      if(ma_fast_1m > ma_medium_1m && ma_medium_1m > ma_slow_1m) {
         entry_condition_1m_buy = true;
      }
      
      // Sell setup: All MAs aligned (fast < medium < slow)
      if(ma_fast_1m < ma_medium_1m && ma_medium_1m < ma_slow_1m) {
         entry_condition_1m_sell = true;
      }
   }
   
   // 1M Entry based on Bollinger Bands
   if(Use_Bollinger) {
      double close_1m = iClose(Symbol_Name, TimeFrame1Min, 0);
      
      // Buy: Price near lower band
      if(close_1m < bb_lower_1m + (bb_middle_1m - bb_lower_1m) * 0.2) {
         entry_condition_1m_buy = true;
      }
      
      // Sell: Price near upper band
      if(close_1m > bb_upper_1m - (bb_upper_1m - bb_middle_1m) * 0.2) {
         entry_condition_1m_sell = true;
      }
   }
   
   // 1M Entry based on RSI
   if(Use_RSI) {
      // Buy: RSI below 40 (not oversold but showing strength)
      if(rsi_1m < 40 && rsi_1m > RSI_Oversold) {
         entry_condition_1m_buy = true;
      }
      
      // Sell: RSI above 60 (not overbought but showing weakness)
      if(rsi_1m > 60 && rsi_1m < RSI_Overbought) {
         entry_condition_1m_sell = true;
      }
   }
   
   // Final Signal Decision based on multi-timeframe analysis
   
   // BUY SIGNAL: 15M uptrend + 5M buy signal + 1M entry condition
   if(uptrend_15m && buy_signal_5m && entry_condition_1m_buy) {
      signals.buy_signal = true;
      Print("BUY SIGNAL: 15M uptrend + 5M buy signal + 1M entry condition");
   }
   
   // SELL SIGNAL: 15M downtrend + 5M sell signal + 1M entry condition
   if(downtrend_15m && sell_signal_5m && entry_condition_1m_sell) {
      signals.sell_signal = true;
      Print("SELL SIGNAL: 15M downtrend + 5M sell signal + 1M entry condition");
   }
   
   return signals;
}

//+------------------------------------------------------------------+
//| Get indicator value with error handling                          |
//+------------------------------------------------------------------+
double GetIndicatorValue(int handle, int index, int buffer = 0) {
   // Check for invalid handle
   if(handle == INVALID_HANDLE) {
      Print("Error: Invalid indicator handle passed to GetIndicatorValue");
      return EMPTY_VALUE;
   }
   
   double value[1];
   
   // Copy indicator value to array with error checking
   if(CopyBuffer(handle, buffer, index, 1, value) != 1) {
      int error = GetLastError();
      Print("Failed to copy indicator buffer ", buffer, " at index ", index, ". Error: ", error);
      return EMPTY_VALUE;
   }
   
   // Check for empty or NaN value
   if(value[0] == EMPTY_VALUE || MathIsValidNumber(value[0]) == false) {
      Print("Warning: Empty or invalid value in indicator buffer ", buffer, " at index ", index);
      return EMPTY_VALUE;
   }
   
   return value[0];
}

//+------------------------------------------------------------------+
//| Check if daily loss limit has been reached                       |
//+------------------------------------------------------------------+
bool CheckDailyLossLimit() {
   // Reset daily loss at the start of a new day
   static datetime last_checked_day = 0;
   datetime current_time = TimeCurrent();
   
   // Get the day part of the current time
   MqlDateTime time_struct;
   TimeToStruct(current_time, time_struct);
   
   // Format the date as YYYY-MM-DD for comparison
   string current_day = StringFormat("%04d-%02d-%02d", time_struct.year, time_struct.mon, time_struct.day);
   string last_day = "";
   
   if(last_checked_day > 0) {
      MqlDateTime last_time_struct;
      TimeToStruct(last_checked_day, last_time_struct);
      last_day = StringFormat("%04d-%02d-%02d", last_time_struct.year, last_time_struct.mon, last_time_struct.day);
   }
   
   // Reset daily loss if it's a new day
   if(current_day != last_day) {
      g_daily_loss = 0.0;
      last_checked_day = current_time;
      Print("New day started. Daily loss reset to 0.");
   }
   
   // Check if daily loss exceeds the limit
   double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double daily_loss_limit = account_balance * (DailyLossLimit / 100.0);
   
   if(g_daily_loss >= daily_loss_limit) {
      Print("Daily loss limit reached (", g_daily_loss, " >= ", daily_loss_limit, "). Trading disabled for today.");
      return true; // Stop trading for today
   }
   
   return false; // Continue trading
}

//+------------------------------------------------------------------+
//| Calculate position size based on risk                            |
//+------------------------------------------------------------------+
double CalculateLotSize(double stop_loss_pips) {
   double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk_amount = account_balance * (RiskPercent / 100.0);
   
   // Convert pips to price
   double stop_loss_price = stop_loss_pips * 10 * g_point; // For 5-digit brokers
   
   // Calculate lot size based on risk amount and stop loss
   double lot_size = NormalizeDouble(risk_amount / (stop_loss_price * 100000), 2);
   
   // Ensure lot size is within allowed limits
   lot_size = MathMax(g_min_lot, MathMin(g_max_lot, lot_size));
   
   // Round to the nearest lot step
   lot_size = NormalizeDouble(MathFloor(lot_size / g_lot_step) * g_lot_step, 2);
   
   return lot_size;
}

//+------------------------------------------------------------------+
//| Open a new position                                              |
//+------------------------------------------------------------------+
void OpenPosition(ENUM_ORDER_TYPE order_type, double lot_size) {
   double ask = SymbolInfoDouble(Symbol_Name, SYMBOL_ASK);
   double bid = SymbolInfoDouble(Symbol_Name, SYMBOL_BID);
   double entry_price = (order_type == ORDER_TYPE_BUY) ? ask : bid;
   
   // Calculate SL and TP levels
   double sl_price = 0.0;
   double tp1_price = 0.0, tp2_price = 0.0, tp3_price = 0.0, tp4_price = 0.0;
   
   // SL calculation
   if(order_type == ORDER_TYPE_BUY) {
      sl_price = NormalizeDouble(entry_price - (SL_Distance * 10 * g_point), g_digits);
   } else {
      sl_price = NormalizeDouble(entry_price + (SL_Distance * 10 * g_point), g_digits);
   }
   
   // TP calculation based on mode
   if(TP_Mode == TP_PIPS) {
      if(order_type == ORDER_TYPE_BUY) {
         tp1_price = NormalizeDouble(entry_price + (TP1_Level * 10 * g_point), g_digits);
         tp2_price = NormalizeDouble(entry_price + (TP2_Level * 10 * g_point), g_digits);
         tp3_price = NormalizeDouble(entry_price + (TP3_Level * 10 * g_point), g_digits);
         tp4_price = NormalizeDouble(entry_price + (TP4_Level * 10 * g_point), g_digits);
      } else {
         tp1_price = NormalizeDouble(entry_price - (TP1_Level * 10 * g_point), g_digits);
         tp2_price = NormalizeDouble(entry_price - (TP2_Level * 10 * g_point), g_digits);
         tp3_price = NormalizeDouble(entry_price - (TP3_Level * 10 * g_point), g_digits);
         tp4_price = NormalizeDouble(entry_price - (TP4_Level * 10 * g_point), g_digits);
      }
   } else { // TP_PRICE mode - validate absolute price levels
      // For BUY positions, make sure price levels are above entry
      if(order_type == ORDER_TYPE_BUY) {
         // Validate that price levels are above entry and in ascending order
         tp1_price = NormalizeDouble(MathMax(entry_price + (1 * g_point), TP1_Level), g_digits);
         tp2_price = NormalizeDouble(MathMax(tp1_price + (1 * g_point), TP2_Level), g_digits);
         tp3_price = NormalizeDouble(MathMax(tp2_price + (1 * g_point), TP3_Level), g_digits);
         tp4_price = NormalizeDouble(MathMax(tp3_price + (1 * g_point), TP4_Level), g_digits);
      } 
      // For SELL positions, make sure price levels are below entry
      else {
         // Validate that price levels are below entry and in descending order
         tp1_price = NormalizeDouble(MathMin(entry_price - (1 * g_point), TP1_Level), g_digits);
         tp2_price = NormalizeDouble(MathMin(tp1_price - (1 * g_point), TP2_Level), g_digits);
         tp3_price = NormalizeDouble(MathMin(tp2_price - (1 * g_point), TP3_Level), g_digits);
         tp4_price = NormalizeDouble(MathMin(tp3_price - (1 * g_point), TP4_Level), g_digits);
      }
   }
   
   // Create TP tracker for this position
   TP_TRACKER tp_tracker;
   tp_tracker.entry_price = entry_price;
   tp_tracker.original_sl = sl_price;
   tp_tracker.tp1 = tp1_price;
   tp_tracker.tp2 = tp2_price;
   tp_tracker.tp3 = tp3_price;
   tp_tracker.tp4 = tp4_price;
   tp_tracker.midway_tp4 = (tp_tracker.tp3 + tp_tracker.tp4) / 2.0; // Midway point calculation
   tp_tracker.tp1_hit = false;
   tp_tracker.tp2_hit = false;
   tp_tracker.tp3_hit = false;
   tp_tracker.midway_tp4_hit = false;
   tp_tracker.lots = lot_size;
   tp_tracker.current_lots = lot_size;
   tp_tracker.pos_type = (order_type == ORDER_TYPE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   
   // Order sending data structure
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   // Fill order request
   request.action = TRADE_ACTION_DEAL;
   request.symbol = Symbol_Name;
   request.volume = lot_size;
   request.type = order_type;
   request.price = entry_price;
   request.sl = sl_price;
   request.tp = 0; // We'll manage TPs manually
   request.deviation = 10; // Slippage in points
   request.magic = Magic_Number;
   request.comment = Comments;
   
   // Get the supported filling modes for this symbol
   uint filling_mode = (uint)SymbolInfoInteger(Symbol_Name, SYMBOL_FILLING_MODE);
   
   // Default to ORDER_FILLING_RETURN if we can't determine the filling mode
   request.type_filling = ORDER_FILLING_RETURN;
   
   // Check supported filling modes
   if((filling_mode & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK) {
      request.type_filling = ORDER_FILLING_FOK;
      Print("Using FOK filling mode for ", Symbol_Name);
   }
   else if((filling_mode & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC) {
      request.type_filling = ORDER_FILLING_IOC;
      Print("Using IOC filling mode for ", Symbol_Name);
   }
   else {
      Print("Using RETURN filling mode for ", Symbol_Name);
   }
   
   request.type_time = ORDER_TIME_GTC;
   
   // Send order
   bool order_success = OrderSend(request, result);
   
   // If order fails, try with explicit market execution mode
   if(!order_success) {
      int error = GetLastError();
      Print("Order attempt failed with error: ", error, " (", EnumToString(request.type_filling), " filling mode)");
      
      // Try with market execution
      request.type = (order_type == ORDER_TYPE_BUY) ? ORDER_TYPE_BUY_STOP_LIMIT : ORDER_TYPE_SELL_STOP_LIMIT;
      request.type_filling = ORDER_FILLING_RETURN;
      double price_offset = 5 * g_point; // Small offset for limit orders
      
      if(order_type == ORDER_TYPE_BUY) {
         request.stoplimit = request.price - price_offset; // For buy stop limit
      } else {
         request.stoplimit = request.price + price_offset; // For sell stop limit
      }
      
      order_success = OrderSend(request, result);
      
      if(!order_success) {
         error = GetLastError();
         Print("Market execution attempt failed with error: ", error);
         
         // Final attempt - try a market order without SL and TP (add them later)
         request.action = TRADE_ACTION_DEAL;
         request.type = order_type;
         request.sl = 0;
         request.tp = 0;
         request.stoplimit = 0;
         order_success = OrderSend(request, result);
         
         if(!order_success) {
            error = GetLastError();
            Print("Failed to open position after all attempts. Final error: ", error);
            return;
         }
         else {
            // Now try to add SL/TP in a separate command
            ulong position_ticket = result.order;
            if(PositionSelectByTicket(position_ticket)) {
               ModifyPosition(position_ticket, sl_price, 0);
            }
         }
      }
   }
   
   // Store position ticket
   tp_tracker.ticket = result.order;
   
   // Add to TP trackers array
   int size = ArraySize(g_tp_trackers);
   ArrayResize(g_tp_trackers, size + 1);
   g_tp_trackers[size] = tp_tracker;
   
   // Update total position count
   g_total_orders++;
   g_total_lots += lot_size;
   
   Print("Position opened: ", EnumToString(order_type), " ", lot_size, " lots at ", entry_price, 
         ", SL: ", sl_price, ", TP1: ", tp1_price, ", TP2: ", tp2_price, ", TP3: ", tp3_price, ", TP4: ", tp4_price);
}

//+------------------------------------------------------------------+
//| Manage open positions                                             |
//+------------------------------------------------------------------+
void ManagePositions() {
   int pos_count = PositionsTotal();
   
   // Loop through all positions
   for(int i = 0; i < pos_count; i++) {
      ulong ticket = PositionGetTicket(i);
      
      // Skip positions for other symbols or with different magic numbers
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != Symbol_Name) continue;
      if(PositionGetInteger(POSITION_MAGIC) != Magic_Number) continue;
      
      // Get position info
      double current_price = PositionGetDouble(POSITION_PRICE_CURRENT);
      double entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
      double current_sl = PositionGetDouble(POSITION_SL);
      double current_tp = PositionGetDouble(POSITION_TP);
      double current_lots = PositionGetDouble(POSITION_VOLUME);
      ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      
      // Find the position in our TP trackers
      int tracker_index = -1;
      for(int j = 0; j < ArraySize(g_tp_trackers); j++) {
         if(g_tp_trackers[j].ticket == ticket) {
            tracker_index = j;
            break;
         }
      }
      
      // If position not found in trackers, create a new tracker for it
      if(tracker_index == -1) {
         Print("Position ", ticket, " not found in trackers. Creating new tracker.");
         
         // Calculate TP levels based on current settings
         double tp1, tp2, tp3, tp4;
         if(TP_Mode == TP_PIPS) {
            if(pos_type == POSITION_TYPE_BUY) {
               tp1 = NormalizeDouble(entry_price + (TP1_Level * 10 * g_point), g_digits);
               tp2 = NormalizeDouble(entry_price + (TP2_Level * 10 * g_point), g_digits);
               tp3 = NormalizeDouble(entry_price + (TP3_Level * 10 * g_point), g_digits);
               tp4 = NormalizeDouble(entry_price + (TP4_Level * 10 * g_point), g_digits);
            } else {
               tp1 = NormalizeDouble(entry_price - (TP1_Level * 10 * g_point), g_digits);
               tp2 = NormalizeDouble(entry_price - (TP2_Level * 10 * g_point), g_digits);
               tp3 = NormalizeDouble(entry_price - (TP3_Level * 10 * g_point), g_digits);
               tp4 = NormalizeDouble(entry_price - (TP4_Level * 10 * g_point), g_digits);
            }
         } else { // TP_PRICE
            tp1 = NormalizeDouble(TP1_Level, g_digits);
            tp2 = NormalizeDouble(TP2_Level, g_digits);
            tp3 = NormalizeDouble(TP3_Level, g_digits);
            tp4 = NormalizeDouble(TP4_Level, g_digits);
         }
         
         // Create new tracker
         TP_TRACKER new_tracker;
         new_tracker.ticket = ticket;
         new_tracker.entry_price = entry_price;
         new_tracker.original_sl = current_sl;
         new_tracker.tp1 = tp1;
         new_tracker.tp2 = tp2;
         new_tracker.tp3 = tp3;
         new_tracker.tp4 = tp4;
         new_tracker.midway_tp4 = (tp3 + tp4) / 2.0;
         new_tracker.tp1_hit = false;
         new_tracker.tp2_hit = false;
         new_tracker.tp3_hit = false;
         new_tracker.midway_tp4_hit = false;
         new_tracker.lots = current_lots;
         new_tracker.current_lots = current_lots;
         new_tracker.pos_type = pos_type;
         
         // Add to TP trackers array
         int size = ArraySize(g_tp_trackers);
         ArrayResize(g_tp_trackers, size + 1);
         g_tp_trackers[size] = new_tracker;
         tracker_index = size;
      }
      
      // Process all TP levels at once for the position - handles price jumps across multiple TP levels
      ProcessAllTPLevels(ticket, tracker_index);
      
      // Dynamic SL management for losing positions - only apply if TP1 hasn't been hit yet
      int tidx = tracker_index;
      if(!g_tp_trackers[tidx].tp1_hit) {
         if(pos_type == POSITION_TYPE_BUY && current_price < entry_price) {
            // For buy positions: SL = max(original SL, min(entry, current price - distance))
            double dynamic_sl = MathMax(g_tp_trackers[tidx].original_sl, 
                              MathMin(entry_price, current_price - (Dynamic_SL_Distance * 10 * g_point)));
            
            // Only update if the new SL is different from the current SL and better than the current SL
            if(dynamic_sl > current_sl) {
               ModifyPosition(ticket, dynamic_sl, current_tp);
               Print("Dynamic SL adjusted for position ", ticket, " to ", dynamic_sl);
            }
         }
         else if(pos_type == POSITION_TYPE_SELL && current_price > entry_price) {
            // For sell positions: SL = min(original SL, max(entry, current price + distance))
            double dynamic_sl = MathMin(g_tp_trackers[tidx].original_sl, 
                              MathMax(entry_price, current_price + (Dynamic_SL_Distance * 10 * g_point)));
            
            // Only update if the new SL is different from the current SL and better than the current SL
            if(dynamic_sl < current_sl) {
               ModifyPosition(ticket, dynamic_sl, current_tp);
               Print("Dynamic SL adjusted for position ", ticket, " to ", dynamic_sl);
            }
         }
      }
      
      // Apply trailing stop if enabled
      if(Use_Trailing_Stop) {
         ApplyTrailingStop(ticket);
      }
   }
}

//+------------------------------------------------------------------+
//| Process multiple take profit levels for a position               |
//+------------------------------------------------------------------+
void ProcessAllTPLevels(ulong ticket, int tracker_index) {
   if(!PositionSelectByTicket(ticket)) return;
   
   // Get position info
   double current_price = PositionGetDouble(POSITION_PRICE_CURRENT);
   double current_lots = PositionGetDouble(POSITION_VOLUME);
   double current_tp = PositionGetDouble(POSITION_TP);
   ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   
   // Access the tracker by reference
   TP_TRACKER tracker = g_tp_trackers[tracker_index];
   double tp_levels[4];
   double sl_levels[4];
   double volumes[4];
   
   // Sort TP levels and corresponding SL and volumes for sequential processing
   if(pos_type == POSITION_TYPE_BUY) {
      // For buy positions: TP1 (lowest) to TP4 (highest)
      tp_levels[0] = tracker.tp1;
      tp_levels[1] = tracker.tp2;
      tp_levels[2] = tracker.tp3;
      tp_levels[3] = tracker.tp4;
      
      sl_levels[0] = tracker.entry_price;  // SL after TP1
      sl_levels[1] = tracker.tp1;          // SL after TP2
      sl_levels[2] = tracker.tp2;          // SL after TP3
      sl_levels[3] = tracker.tp3;          // SL after midway to TP4
      
      volumes[0] = 0.4 * tracker.lots;     // 40% at TP1
      volumes[1] = 0.2 * tracker.lots;     // 20% at TP2
      volumes[2] = 0.2 * tracker.lots;     // 20% at TP3
      volumes[3] = 0.2 * tracker.lots;     // Remaining 20% at TP4
      
      // Check each TP level in sequence
      // TP1
      if(!tracker.tp1_hit && current_price >= tp_levels[0]) {
         if(ClosePartialPosition(ticket, volumes[0])) {
            tracker.tp1_hit = true;
            tracker.current_lots = NormalizeDouble(tracker.current_lots - volumes[0], 2);
            ModifyPosition(ticket, sl_levels[0], current_tp);
            Print("TP1 hit for position ", ticket, ". 40% closed. SL moved to entry price.");
         }
      }
      
      // TP2
      if(tracker.tp1_hit && !tracker.tp2_hit && current_price >= tp_levels[1]) {
         if(ClosePartialPosition(ticket, volumes[1])) {
            tracker.tp2_hit = true;
            tracker.current_lots = NormalizeDouble(tracker.current_lots - volumes[1], 2);
            ModifyPosition(ticket, sl_levels[1], current_tp);
            Print("TP2 hit for position ", ticket, ". 20% closed. SL moved to TP1.");
         }
      }
      
      // TP3
      if(tracker.tp2_hit && !tracker.tp3_hit && current_price >= tp_levels[2]) {
         if(ClosePartialPosition(ticket, volumes[2])) {
            tracker.tp3_hit = true;
            tracker.current_lots = NormalizeDouble(tracker.current_lots - volumes[2], 2);
            ModifyPosition(ticket, sl_levels[2], current_tp);
            Print("TP3 hit for position ", ticket, ". 20% closed. SL moved to TP2.");
         }
      }
      
      // Midway to TP4
      if(tracker.tp3_hit && !tracker.midway_tp4_hit && current_price >= tracker.midway_tp4) {
         if(ModifyPosition(ticket, sl_levels[3], current_tp)) {
            tracker.midway_tp4_hit = true;
            Print("Midway to TP4 hit for position ", ticket, ". SL moved to TP3.");
         }
      }
      
      // TP4
      if(tracker.tp3_hit && current_price >= tp_levels[3]) {
         if(ClosePosition(ticket)) {
            Print("TP4 hit for position ", ticket, ". Remaining 20% closed.");
         }
      }
   }
   else if(pos_type == POSITION_TYPE_SELL) {
      // For sell positions: TP1 (highest) to TP4 (lowest)
      tp_levels[0] = tracker.tp1;
      tp_levels[1] = tracker.tp2;
      tp_levels[2] = tracker.tp3;
      tp_levels[3] = tracker.tp4;
      
      sl_levels[0] = tracker.entry_price;  // SL after TP1
      sl_levels[1] = tracker.tp1;          // SL after TP2
      sl_levels[2] = tracker.tp2;          // SL after TP3
      sl_levels[3] = tracker.tp3;          // SL after midway to TP4
      
      volumes[0] = 0.4 * tracker.lots;     // 40% at TP1
      volumes[1] = 0.2 * tracker.lots;     // 20% at TP2
      volumes[2] = 0.2 * tracker.lots;     // 20% at TP3
      volumes[3] = 0.2 * tracker.lots;     // Remaining 20% at TP4
      
      // Check each TP level in sequence
      // TP1
      if(!tracker.tp1_hit && current_price <= tp_levels[0]) {
         if(ClosePartialPosition(ticket, volumes[0])) {
            tracker.tp1_hit = true;
            tracker.current_lots = NormalizeDouble(tracker.current_lots - volumes[0], 2);
            ModifyPosition(ticket, sl_levels[0], current_tp);
            Print("TP1 hit for position ", ticket, ". 40% closed. SL moved to entry price.");
         }
      }
      
      // TP2
      if(tracker.tp1_hit && !tracker.tp2_hit && current_price <= tp_levels[1]) {
         if(ClosePartialPosition(ticket, volumes[1])) {
            tracker.tp2_hit = true;
            tracker.current_lots = NormalizeDouble(tracker.current_lots - volumes[1], 2);
            ModifyPosition(ticket, sl_levels[1], current_tp);
            Print("TP2 hit for position ", ticket, ". 20% closed. SL moved to TP1.");
         }
      }
      
      // TP3
      if(tracker.tp2_hit && !tracker.tp3_hit && current_price <= tp_levels[2]) {
         if(ClosePartialPosition(ticket, volumes[2])) {
            tracker.tp3_hit = true;
            tracker.current_lots = NormalizeDouble(tracker.current_lots - volumes[2], 2);
            ModifyPosition(ticket, sl_levels[2], current_tp);
            Print("TP3 hit for position ", ticket, ". 20% closed. SL moved to TP2.");
         }
      }
      
      // Midway to TP4
      if(tracker.tp3_hit && !tracker.midway_tp4_hit && current_price <= tracker.midway_tp4) {
         if(ModifyPosition(ticket, sl_levels[3], current_tp)) {
            tracker.midway_tp4_hit = true;
            Print("Midway to TP4 hit for position ", ticket, ". SL moved to TP3.");
         }
      }
      
      // TP4
      if(tracker.tp3_hit && current_price <= tp_levels[3]) {
         if(ClosePosition(ticket)) {
            Print("TP4 hit for position ", ticket, ". Remaining 20% closed.");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Close a partial position                                          |
//+------------------------------------------------------------------+
bool ClosePartialPosition(ulong ticket, double volume) {
   if(!PositionSelectByTicket(ticket)) return false;
   
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   // Prepare close request
   request.action = TRADE_ACTION_DEAL;
   request.position = ticket;
   request.symbol = PositionGetString(POSITION_SYMBOL);
   request.volume = volume;
   request.magic = Magic_Number;
   request.comment = Comments + " (Partial Close)";
   request.deviation = 10; // Slippage in points
   
   // Set order type (opposite to current position)
   if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
      request.type = ORDER_TYPE_SELL;
      request.price = SymbolInfoDouble(request.symbol, SYMBOL_BID);
   } else {
      request.type = ORDER_TYPE_BUY;
      request.price = SymbolInfoDouble(request.symbol, SYMBOL_ASK);
   }
   
   // Try different filling modes
   // First try with IOC filling mode which works with most brokers
   request.type_filling = ORDER_FILLING_IOC;
   bool success = OrderSend(request, result);
   
   // If first attempt fails, try with FOK
   if(!success) {
      int error = GetLastError();
      Print("First partial close attempt failed with error: ", error, " (IOC filling mode)");
      
      // Try with FOK
      request.type_filling = ORDER_FILLING_FOK;
      success = OrderSend(request, result);
      
      // If still fails, try with market filling
      if(!success) {
         error = GetLastError();
         Print("Second partial close attempt failed with error: ", error, " (FOK filling mode)");
         
         // Last attempt with filling mode = market
         request.type_filling = ORDER_FILLING_RETURN;
         success = OrderSend(request, result);
         
         if(!success) {
            error = GetLastError();
            Print("Failed to partially close position after all attempts. Final error: ", error);
            return false;
         }
      }
   }
   
   Print("Partially closed position ", ticket, ". Volume: ", volume);
   return true;
}

//+------------------------------------------------------------------+
//| Close a position                                                  |
//+------------------------------------------------------------------+
bool ClosePosition(ulong ticket) {
   if(!PositionSelectByTicket(ticket)) return false;
   
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   // Prepare close request
   request.action = TRADE_ACTION_DEAL;
   request.position = ticket;
   request.symbol = PositionGetString(POSITION_SYMBOL);
   request.volume = PositionGetDouble(POSITION_VOLUME);
   request.magic = Magic_Number;
   request.comment = Comments + " (Close)";
   request.deviation = 10; // Slippage in points
   
   // Set order type (opposite to current position)
   if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
      request.type = ORDER_TYPE_SELL;
      request.price = SymbolInfoDouble(request.symbol, SYMBOL_BID);
   } else {
      request.type = ORDER_TYPE_BUY;
      request.price = SymbolInfoDouble(request.symbol, SYMBOL_ASK);
   }
   
   // Try different filling modes
   // First try with IOC filling mode
   request.type_filling = ORDER_FILLING_IOC;
   bool success = OrderSend(request, result);
   
   // If first attempt fails, try with FOK
   if(!success) {
      int error = GetLastError();
      Print("First close attempt failed with error: ", error, " (IOC filling mode)");
      
      // Try with FOK
      request.type_filling = ORDER_FILLING_FOK;
      success = OrderSend(request, result);
      
      // If still fails, try with market filling
      if(!success) {
         error = GetLastError();
         Print("Second close attempt failed with error: ", error, " (FOK filling mode)");
         
         // Last attempt with filling mode = market
         request.type_filling = ORDER_FILLING_RETURN;
         success = OrderSend(request, result);
         
         if(!success) {
            error = GetLastError();
            Print("Failed to close position after all attempts. Final error: ", error);
            return false;
         }
      }
   }
   
   Print("Closed position ", ticket);
   
   // Remove from TP trackers
   for(int i = 0; i < ArraySize(g_tp_trackers); i++) {
      if(g_tp_trackers[i].ticket == ticket) {
         // Remove this tracker by shifting elements
         for(int j = i; j < ArraySize(g_tp_trackers) - 1; j++) {
            g_tp_trackers[j] = g_tp_trackers[j + 1];
         }
         // Resize array
         ArrayResize(g_tp_trackers, ArraySize(g_tp_trackers) - 1);
         break;
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Modify a position's stop loss and take profit                     |
//+------------------------------------------------------------------+
bool ModifyPosition(ulong ticket, double sl, double tp) {
   if(!PositionSelectByTicket(ticket)) return false;
   
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   // Prepare modification request
   request.action = TRADE_ACTION_SLTP;
   request.position = ticket;
   request.symbol = PositionGetString(POSITION_SYMBOL);
   request.sl = sl;
   request.tp = tp;
   request.magic = Magic_Number;
   
   // Send order
   bool success = OrderSend(request, result);
   
   if(!success) {
      Print("Failed to modify position ", ticket, ". Error: ", GetLastError());
   } else {
      Print("Modified position ", ticket, ". New SL: ", sl, ", New TP: ", tp);
   }
   
   return success;
}

//+------------------------------------------------------------------+
//| OnTradeTransaction event handler                                  |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                       const MqlTradeRequest& request,
                       const MqlTradeResult& result) {
   // Update account balance and check for daily loss limit
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD) {
      // Get deal info
      ulong deal_ticket = trans.deal;
      if(deal_ticket == 0) return;
      
      // Select the deal
      if(!HistoryDealSelect(deal_ticket)) return;
      
      // Check deal properties
      long deal_magic = HistoryDealGetInteger(deal_ticket, DEAL_MAGIC);
      string deal_symbol = HistoryDealGetString(deal_ticket, DEAL_SYMBOL);
      
      // Skip deals that don't belong to this EA
      if(deal_magic != Magic_Number || deal_symbol != Symbol_Name) return;
      
      // Get profit/loss from the deal
      double deal_profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
      
      // Update daily loss if a loss occurred
      if(deal_profit < 0) {
         g_daily_loss += MathAbs(deal_profit);
         Print("Loss recorded: ", deal_profit, ". Total daily loss: ", g_daily_loss);
      }
   }
}

//+------------------------------------------------------------------+
//| Format price with correct number of digits                        |
//+------------------------------------------------------------------+
string FormatPrice(double price) {
   return DoubleToString(price, g_digits);
}

//+------------------------------------------------------------------+
//| Convert pips to price                                             |
//+------------------------------------------------------------------+
double PipsToPrice(double pips) {
   return pips * 10 * g_point;
}

//+------------------------------------------------------------------+
//| Convert price to pips                                             |
//+------------------------------------------------------------------+
double PriceToTicks(double price) {
   return price / g_point;
}

//+------------------------------------------------------------------+
//| Log performance metrics                                           |
//+------------------------------------------------------------------+
void LogPerformanceMetrics() {
   // Calculate performance metrics
   int total_positions = PositionsTotal();
   int total_closed = 0;
   int winning_trades = 0;
   int losing_trades = 0;
   double total_profit = 0.0;
   double max_drawdown = 0.0;
   double current_drawdown = 0.0;
   double peak_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   // Iterate through history to get closed positions
   HistorySelect(0, TimeCurrent());
   int total_deals = HistoryDealsTotal();
   
   for(int i = 0; i < total_deals; i++) {
      ulong deal_ticket = HistoryDealGetTicket(i);
      if(deal_ticket == 0) continue;
      
      // Filter deals for this EA only
      long deal_magic = HistoryDealGetInteger(deal_ticket, DEAL_MAGIC);
      string deal_symbol = HistoryDealGetString(deal_ticket, DEAL_SYMBOL);
      
      if(deal_magic != Magic_Number || deal_symbol != Symbol_Name) continue;
      
      // Process only closing deals (entries already have their profit priced in)
      if(HistoryDealGetInteger(deal_ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT) {
         total_closed++;
         double deal_profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
         total_profit += deal_profit;
         
         if(deal_profit > 0) winning_trades++;
         else if(deal_profit < 0) losing_trades++;
         
         // Update peak equity and drawdown
         double current_equity = AccountInfoDouble(ACCOUNT_EQUITY);
         peak_equity = MathMax(peak_equity, current_equity);
         current_drawdown = peak_equity - current_equity;
         max_drawdown = MathMax(max_drawdown, current_drawdown);
      }
   }
   
   // Calculate win rate
   double win_rate = (total_closed > 0) ? ((double)winning_trades / total_closed) * 100.0 : 0.0;
   
   // Get final account metrics
   double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double account_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   // Log metrics
   Print("===== Performance Metrics =====");
   Print("Account Balance: ", DoubleToString(account_balance, 2));
   Print("Account Equity: ", DoubleToString(account_equity, 2));
   Print("Total Open Positions: ", total_positions);
   Print("Total Closed Trades: ", total_closed);
   Print("Winning Trades: ", winning_trades, " (", DoubleToString(win_rate, 2), "%)");
   Print("Losing Trades: ", losing_trades);
   Print("Total Profit/Loss: ", DoubleToString(total_profit, 2));
   Print("Maximum Drawdown: ", DoubleToString(max_drawdown, 2), " (", 
         DoubleToString((max_drawdown / peak_equity) * 100.0, 2), "%)");
   Print("Current Daily Loss: ", DoubleToString(g_daily_loss, 2));
   Print("===============================");
}

//+------------------------------------------------------------------+
//| Check if a new bar has formed on the specified timeframe         |
//+------------------------------------------------------------------+
bool IsNewBar(ENUM_TIMEFRAMES timeframe) {
   // Static array to track the last bar time for each timeframe
   static datetime last_bar_times[]; 
   
   // Initialize array size if first call
   if(ArraySize(last_bar_times) == 0) {
      // Add explicit cast to int for PERIOD_MN1 to avoid conversion warning
      ArrayResize(last_bar_times, (int)(PERIOD_MN1+1));
      ArrayInitialize(last_bar_times, 0);
   }
   
   datetime current_bar_time = iTime(Symbol_Name, timeframe, 0);
   
   // Check if we have a new bar for the specific timeframe
   if(last_bar_times[timeframe] != current_bar_time) {
      last_bar_times[timeframe] = current_bar_time;
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Expert testing events: log performance metrics                    |
//+------------------------------------------------------------------+
double OnTester() {
   // Called at the end of strategy tester run
   LogPerformanceMetrics();
   
   // Return profit factor as custom max criterion
   return TesterStatistics(STAT_PROFIT_FACTOR);
}

//+------------------------------------------------------------------+
//| Expert testing function: log details on each test step           |
//+------------------------------------------------------------------+
void OnTesterInit() {
   Print("MoneyMonster EA tester initialization");
   // Reset global variables for testing
   g_daily_loss = 0.0;
   ArrayResize(g_tp_trackers, 0);
}

//+------------------------------------------------------------------+
//| Expert testing function: log details on each test step           |
//+------------------------------------------------------------------+
void OnTesterDeinit() {
   Print("MoneyMonster EA tester deinitialization");
   // Final performance log
   LogPerformanceMetrics();
}

//+------------------------------------------------------------------+
//| Check if data for all timeframes is ready                        |
//+------------------------------------------------------------------+
bool IsDataReady() {
   // Check if we have enough bars for all timeframes
   int min_required_bars = MathMax(MA_Slow_Period, MathMax(RSI_Period, BB_Period));
   min_required_bars = MathMax(min_required_bars, MathMax(ADX_Period, ATR_Period));
   min_required_bars = MathMax(min_required_bars, MACD_Slow_EMA + MACD_Signal_Period);
   
   // Add some buffer (10 bars) to ensure all indicators have enough data
   min_required_bars += 10;
   
   // Check each timeframe
   if(Bars(Symbol_Name, TimeFrame1Min) < min_required_bars) return false;
   if(Bars(Symbol_Name, TimeFrame5Min) < min_required_bars) return false;
   if(Bars(Symbol_Name, TimeFrame15Min) < min_required_bars) return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Check if all indicators required for signal calculation are valid |
//+------------------------------------------------------------------+
bool AreIndicatorsValid() {
   bool result = true;
   
   // Check Moving Averages
   if(Use_MA) {
      if(h_ma_fast_1m == (int)INVALID_HANDLE || h_ma_medium_1m == (int)INVALID_HANDLE || h_ma_slow_1m == (int)INVALID_HANDLE ||
         h_ma_fast_5m == (int)INVALID_HANDLE || h_ma_medium_5m == (int)INVALID_HANDLE || h_ma_slow_5m == (int)INVALID_HANDLE ||
         h_ma_fast_15m == (int)INVALID_HANDLE || h_ma_medium_15m == (int)INVALID_HANDLE || h_ma_slow_15m == (int)INVALID_HANDLE) {
         result = false;
      }
   }
   
   // Check RSI
   if(Use_RSI) {
      if(h_rsi_1m == (int)INVALID_HANDLE || h_rsi_5m == (int)INVALID_HANDLE || h_rsi_15m == (int)INVALID_HANDLE) {
         result = false;
      }
   }
   
   // Check MACD
   if(Use_MACD) {
      if(h_macd_1m == (int)INVALID_HANDLE || h_macd_5m == (int)INVALID_HANDLE || h_macd_15m == (int)INVALID_HANDLE) {
         result = false;
      }
   }
   
   // Check Bollinger Bands
   if(Use_Bollinger) {
      if(h_bb_1m == (int)INVALID_HANDLE || h_bb_5m == (int)INVALID_HANDLE || h_bb_15m == (int)INVALID_HANDLE) {
         result = false;
      }
   }
   
   // Check ADX
   if(Use_ADX) {
      if(h_adx_1m == (int)INVALID_HANDLE || h_adx_5m == (int)INVALID_HANDLE || h_adx_15m == (int)INVALID_HANDLE) {
         result = false;
      }
   }
   
   // Check ATR
   if(Use_ATR) {
      if(h_atr_1m == (int)INVALID_HANDLE || h_atr_5m == (int)INVALID_HANDLE || h_atr_15m == (int)INVALID_HANDLE) {
         result = false;
      }
   }
   
   if(!result) {
      Print("Warning: Some indicators are not properly initialized!");
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| Count positions for our symbol and magic number                   |
//+------------------------------------------------------------------+
int CountSymbolPositions() {
   int count = 0;
   int total = PositionsTotal();
   
   for(int i = 0; i < total; i++) {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket)) {
         if(PositionGetString(POSITION_SYMBOL) == Symbol_Name && 
            PositionGetInteger(POSITION_MAGIC) == Magic_Number) {
            count++;
         }
      }
   }
   
   return count;
}

//+------------------------------------------------------------------+
//| Apply trailing stop to position                                   |
//+------------------------------------------------------------------+
bool ApplyTrailingStop(ulong ticket) {
   if(!PositionSelectByTicket(ticket)) return false;
   
   // Get position info
   double entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
   double current_price = PositionGetDouble(POSITION_PRICE_CURRENT);
   double current_sl = PositionGetDouble(POSITION_SL);
   double current_tp = PositionGetDouble(POSITION_TP);
   ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   
   // Calculate trailing distance in price
   double trailing_start_price = Trailing_Start * 10 * g_point;
   double trailing_step_price = Trailing_Step * 10 * g_point;
   double trailing_distance_price = Trailing_Distance * 10 * g_point;
   
   // Calculate new stop loss price
   double new_sl = current_sl;
   bool should_modify = false;
   
   if(pos_type == POSITION_TYPE_BUY) {
      // For buy: Price must be at least trailing_start_price above entry
      if(current_price >= entry_price + trailing_start_price) {
         // Calculate where the SL should be (trailing_distance_price below current price)
         double ideal_sl = NormalizeDouble(current_price - trailing_distance_price, g_digits);
         
         // Only move SL up (don't move it down)
         if(ideal_sl > current_sl + trailing_step_price) {
            new_sl = NormalizeDouble(ideal_sl, g_digits);
            should_modify = true;
         }
      }
   }
   else { // POSITION_TYPE_SELL
      // For sell: Price must be at least trailing_start_price below entry
      if(current_price <= entry_price - trailing_start_price) {
         // Calculate where the SL should be (trailing_distance_price above current price)
         double ideal_sl = NormalizeDouble(current_price + trailing_distance_price, g_digits);
         
         // Only move SL down (don't move it up)
         if(ideal_sl < current_sl - trailing_step_price) {
            new_sl = NormalizeDouble(ideal_sl, g_digits);
            should_modify = true;
         }
      }
   }
   
   // Modify the position if needed
   if(should_modify) {
      if(ModifyPosition(ticket, new_sl, current_tp)) {
         Print("Trailing stop applied for position ", ticket, ". New SL: ", new_sl);
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Handle market gaps                                                |
//+------------------------------------------------------------------+
void HandleMarketGap() {
   // Only run if gap protection is enabled
   if(!Use_Gap_Protection) return;
   
   static datetime last_check_time = 0;
   datetime current_time = TimeCurrent();
   
   // Only check for gaps every 5 seconds to reduce processing load
   if(current_time - last_check_time < 5) return;
   last_check_time = current_time;
   
   // Get the current and previous candle
   double current_open = iOpen(Symbol_Name, PERIOD_M1, 0);
   double previous_close = iClose(Symbol_Name, PERIOD_M1, 1);
   
   // Calculate the gap size in pips
   double gap_size = MathAbs(current_open - previous_close) / (10 * g_point);
   
   // If gap size exceeds our threshold, take protective action
   if(gap_size > Max_Gap_Size) {
      Print("WARNING: Market gap detected! Size: ", DoubleToString(gap_size, 1), " pips");
      
      // Loop through all open positions
      int total = PositionsTotal();
      for(int i = 0; i < total; i++) {
         ulong ticket = PositionGetTicket(i);
         
         // Skip positions for other symbols or with different magic numbers
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetString(POSITION_SYMBOL) != Symbol_Name) continue;
         if(PositionGetInteger(POSITION_MAGIC) != Magic_Number) continue;
         
         ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         double entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
         double current_price = PositionGetDouble(POSITION_PRICE_CURRENT);
         
         // Determine if gap is against our position
         bool gap_against_position = false;
         
         if(pos_type == POSITION_TYPE_BUY && current_open < previous_close) {
            gap_against_position = true;
         }
         else if(pos_type == POSITION_TYPE_SELL && current_open > previous_close) {
            gap_against_position = true;
         }
         
         // If gap is against our position, reduce size or close
         if(gap_against_position) {
            double current_lots = PositionGetDouble(POSITION_VOLUME);
            
            // If big gap against us, consider closing entire position
            if(gap_size > Max_Gap_Size * 2) {
               Print("Emergency close due to large gap against position: ", ticket);
               ClosePosition(ticket);
            }
            // If moderate gap, reduce position size by 50%
            else if(current_lots > g_min_lot * 2) {
               double reduce_lots = NormalizeDouble(current_lots / 2, 2);
               Print("Reducing position due to gap: ", ticket, " by ", reduce_lots, " lots");
               ClosePartialPosition(ticket, reduce_lots);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate volatility-adjusted lot size                            |
//+------------------------------------------------------------------+
double CalculateVolatilityAdjustedLotSize(double base_stop_loss_pips) {
   if(!Use_Vol_Risk || !g_use_atr) {
      // If volatility risk is disabled or ATR is unavailable, use standard calculation
      return CalculateLotSize(base_stop_loss_pips);
   }
   
   // Get ATR for the 5M timeframe as our volatility measure
   double atr_pips = GetIndicatorValue(h_atr_5m, 0) / (10 * g_point);
   
   // Calculate the ratio of current ATR to our base stop loss
   double volatility_ratio = atr_pips / base_stop_loss_pips;
   
   // Adjust risk based on volatility
   double risk_factor = 1.0;
   
   if(volatility_ratio > 1.5) {
      // Higher volatility = reduce risk
      risk_factor = 0.5;
   }
   else if(volatility_ratio < 0.5) {
      // Lower volatility = can increase risk slightly
      risk_factor = 1.2;
   }
   
   // Apply user's preference via Vol_Risk_Factor
   risk_factor *= Vol_Risk_Factor;
   
   // Calculate the base lot size
   double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk_amount = account_balance * (RiskPercent / 100.0) * risk_factor;
   
   // Convert pips to price
   double stop_loss_price = base_stop_loss_pips * 10 * g_point;
   
   // Adjusted lot size based on risk and volatility
   double lot_size = NormalizeDouble(risk_amount / (stop_loss_price * 100000), 2);
   
   // Ensure lot size is within allowed limits
   lot_size = MathMax(g_min_lot, MathMin(g_max_lot, lot_size));
   
   // Round to the nearest lot step
   lot_size = NormalizeDouble(MathFloor(lot_size / g_lot_step) * g_lot_step, 2);
   
   Print("Volatility adjusted lot size: ", lot_size, 
         " (ATR: ", DoubleToString(atr_pips, 1), 
         " pips, Ratio: ", DoubleToString(volatility_ratio, 2),
         ", Risk Factor: ", DoubleToString(risk_factor, 2), ")");
   
   return lot_size;
}

//+------------------------------------------------------------------+
//| Enhanced logging function with levels                            |
//+------------------------------------------------------------------+
void LogMessage(string message, int level = 2) {
   // Only log messages at or below the current log level
   if(level > g_log_level) return;
   
   // Format message with timestamp and level indicator
   string level_text = "";
   switch(level) {
      case 0: level_text = "[NONE] "; break;
      case 1: level_text = "[CRITICAL] "; break;
      case 2: level_text = "[INFO] "; break;
      case 3: level_text = "[DEBUG] "; break;
   }
   
   // Add timestamp
   string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
   string formatted_message = timestamp + " " + level_text + message;
   
   // Print to log
   if(g_debug_mode || level <= 2) {
      Print(formatted_message);
   }
   
   // For critical messages, also display an alert
   if(level == 1) {
      Alert(message);
   }
}

//+------------------------------------------------------------------+
//| Information panel and visualization functions                     |
//+------------------------------------------------------------------+
string g_panel_name = "MoneyMonsterInfoPanel";
string g_line_prefix = "MoneyMonster_Line_";

//+------------------------------------------------------------------+
//| Create or update chart visuals                                    |
//+------------------------------------------------------------------+
void UpdateChartVisuals() {
   if(!ShowInfoPanel && !ShowTradeLines) return;
   
   // Create or update info panel
   if(ShowInfoPanel) {
      // Call the advanced dashboard instead of the basic panel
      CreateAdvancedDashboard();
   }
   
   // Create or update trade lines
   if(ShowTradeLines) {
      UpdateTradeLines();
   }
}

//+------------------------------------------------------------------+
//| Create information panel on chart                                 |
//+------------------------------------------------------------------+
void CreateInfoPanel() {
   // Calculate metrics for panel
   double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double account_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double account_margin = AccountInfoDouble(ACCOUNT_MARGIN);
   double account_free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double account_profit = account_equity - account_balance;
   
   // Count current positions by direction
   int buy_positions = 0;
   int sell_positions = 0;
   double buy_volume = 0.0;
   double sell_volume = 0.0;
   
   int total = PositionsTotal();
   for(int i = 0; i < total; i++) {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket)) {
         if(PositionGetString(POSITION_SYMBOL) == Symbol_Name && 
            PositionGetInteger(POSITION_MAGIC) == Magic_Number) {
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
               buy_positions++;
               buy_volume += PositionGetDouble(POSITION_VOLUME);
            } else {
               sell_positions++;
               sell_volume += PositionGetDouble(POSITION_VOLUME);
            }
         }
      }
   }
   
   // Get indicator statuses
   string ma_status = g_use_ma ? "Active" : "Inactive";
   string rsi_status = g_use_rsi ? "Active" : "Inactive";
   string macd_status = g_use_macd ? "Active" : "Inactive";
   string bb_status = g_use_bollinger ? "Active" : "Inactive";
   string adx_status = g_use_adx ? "Active" : "Inactive";
   string atr_status = g_use_atr ? "Active" : "Inactive";
   
   // Calculate panel size based on content
   int panel_width = 300;
   int panel_height = 400;
   int x = 10;
   int y = 10;
   
   // Adjust position based on corner setting
   switch(InfoCorner) {
      case CORNER_LEFT_UPPER:
         x = 10;
         y = 10;
         break;
      case CORNER_RIGHT_UPPER:
         x = (int)(ChartGetInteger(0, CHART_WIDTH_IN_PIXELS)) - panel_width - 10;
         y = 10;
         break;
      case CORNER_LEFT_LOWER:
         x = 10;
         y = (int)(ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS)) - panel_height - 10;
         break;
      case CORNER_RIGHT_LOWER:
         x = (int)(ChartGetInteger(0, CHART_WIDTH_IN_PIXELS)) - panel_width - 10;
         y = (int)(ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS)) - panel_height - 10;
         break;
   }
   
   // Remove old panel if exists
   ObjectDelete(0, g_panel_name);
   
   // Create panel background
   if(!ObjectCreate(0, g_panel_name, OBJ_RECTANGLE_LABEL, 0, 0, 0)) {
      Print("Failed to create info panel background.");
      return;
   }
   
   // Set panel properties
   ObjectSetInteger(0, g_panel_name, OBJPROP_CORNER, InfoCorner);
   ObjectSetInteger(0, g_panel_name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, g_panel_name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, g_panel_name, OBJPROP_XSIZE, panel_width);
   ObjectSetInteger(0, g_panel_name, OBJPROP_YSIZE, panel_height);
   ObjectSetInteger(0, g_panel_name, OBJPROP_BGCOLOR, InfoBackColor);
   ObjectSetInteger(0, g_panel_name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, g_panel_name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, g_panel_name, OBJPROP_BACK, false);
   ObjectSetInteger(0, g_panel_name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, g_panel_name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, g_panel_name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, g_panel_name, OBJPROP_ZORDER, 0);
   
   // Create panel content
   string panel_text = "";
   panel_text += "===== MoneyMonster EA =====\n";
   panel_text += "Symbol: " + Symbol_Name + "\n";
   panel_text += "Balance: " + DoubleToString(account_balance, 2) + "\n";
   panel_text += "Equity: " + DoubleToString(account_equity, 2) + "\n";
   panel_text += "Current P/L: " + DoubleToString(account_profit, 2) + "\n";
   panel_text += "Daily Loss: " + DoubleToString(g_daily_loss, 2) + " / " + DoubleToString(account_balance * DailyLossLimit / 100.0, 2) + "\n";
   panel_text += "\n";
   panel_text += "===== Positions =====\n";
   panel_text += "Buy: " + IntegerToString(buy_positions) + " (" + DoubleToString(buy_volume, 2) + " lots)\n";
   panel_text += "Sell: " + IntegerToString(sell_positions) + " (" + DoubleToString(sell_volume, 2) + " lots)\n";
   panel_text += "\n";
   panel_text += "===== Indicators =====\n";
   panel_text += "MA: " + ma_status + "\n";
   panel_text += "RSI: " + rsi_status + "\n";
   panel_text += "MACD: " + macd_status + "\n";
   panel_text += "BB: " + bb_status + "\n";
   panel_text += "ADX: " + adx_status + "\n";
   panel_text += "ATR: " + atr_status + "\n";
   
   // Add panel text
   string text_name = g_panel_name + "_Text";
   ObjectDelete(0, text_name);
   
   if(!ObjectCreate(0, text_name, OBJ_LABEL, 0, 0, 0)) {
      Print("Failed to create info panel text.");
      return;
   }
   
   // Set text properties
   ObjectSetInteger(0, text_name, OBJPROP_CORNER, InfoCorner);
   ObjectSetInteger(0, text_name, OBJPROP_XDISTANCE, x + 10);
   ObjectSetInteger(0, text_name, OBJPROP_YDISTANCE, y + 10);
   ObjectSetInteger(0, text_name, OBJPROP_COLOR, InfoTextColor);
   ObjectSetInteger(0, text_name, OBJPROP_FONTSIZE, InfoFontSize);
   ObjectSetString(0, text_name, OBJPROP_FONT, "Consolas");
   ObjectSetString(0, text_name, OBJPROP_TEXT, panel_text);
   ObjectSetInteger(0, text_name, OBJPROP_BACK, false);
   ObjectSetInteger(0, text_name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, text_name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, text_name, OBJPROP_HIDDEN, true);
   
   // Refresh chart
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Update trade lines on chart                                       |
//+------------------------------------------------------------------+
void UpdateTradeLines() {
   // First clear all existing lines
   DeleteAllTradeLines();
   
   // Loop through all positions to create lines
   int total = PositionsTotal();
   for(int i = 0; i < total; i++) {
      ulong ticket = PositionGetTicket(i);
      
      // Skip positions for other symbols or with different magic numbers
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != Symbol_Name) continue;
      if(PositionGetInteger(POSITION_MAGIC) != Magic_Number) continue;
      
      // Get position info
      double entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      
      // Determine position direction for colors
      color line_color = (pos_type == POSITION_TYPE_BUY) ? BuyColor : SellColor;
      
      // Create or update SL line
      string sl_line_name = g_line_prefix + "SL_" + IntegerToString(ticket);
      CreateTrendLine(sl_line_name, sl, SLColor, "SL: " + DoubleToString(sl, g_digits));
      
      // Create or update entry line
      string entry_line_name = g_line_prefix + "Entry_" + IntegerToString(ticket);
      CreateTrendLine(entry_line_name, entry_price, line_color, "Entry: " + DoubleToString(entry_price, g_digits));
      
      // Find position in TP trackers to get TP levels
      for(int j = 0; j < ArraySize(g_tp_trackers); j++) {
         if(g_tp_trackers[j].ticket == ticket) {
            // Create TP lines
            string tp1_line_name = g_line_prefix + "TP1_" + IntegerToString(ticket);
            string tp2_line_name = g_line_prefix + "TP2_" + IntegerToString(ticket);
            string tp3_line_name = g_line_prefix + "TP3_" + IntegerToString(ticket);
            string tp4_line_name = g_line_prefix + "TP4_" + IntegerToString(ticket);
            string midway_line_name = g_line_prefix + "Midway_" + IntegerToString(ticket);
            
            // Add indicators of which levels were hit
            string tp1_status = g_tp_trackers[j].tp1_hit ? " ✓" : "";
            string tp2_status = g_tp_trackers[j].tp2_hit ? " ✓" : "";
            string tp3_status = g_tp_trackers[j].tp3_hit ? " ✓" : "";
            string midway_status = g_tp_trackers[j].midway_tp4_hit ? " ✓" : "";
            
            // Create TP lines with status indicators
            CreateTrendLine(tp1_line_name, g_tp_trackers[j].tp1, TPColor, "TP1: " + DoubleToString(g_tp_trackers[j].tp1, g_digits) + tp1_status);
            CreateTrendLine(tp2_line_name, g_tp_trackers[j].tp2, TPColor, "TP2: " + DoubleToString(g_tp_trackers[j].tp2, g_digits) + tp2_status);
            CreateTrendLine(tp3_line_name, g_tp_trackers[j].tp3, TPColor, "TP3: " + DoubleToString(g_tp_trackers[j].tp3, g_digits) + tp3_status);
            CreateTrendLine(tp4_line_name, g_tp_trackers[j].tp4, TPColor, "TP4: " + DoubleToString(g_tp_trackers[j].tp4, g_digits));
            
            // Only create midway line if TP3 is hit but midway isn't
            if(g_tp_trackers[j].tp3_hit) {
               CreateTrendLine(midway_line_name, g_tp_trackers[j].midway_tp4, TPColor, 
                              "Midway: " + DoubleToString(g_tp_trackers[j].midway_tp4, g_digits) + midway_status);
            }
            
            break;
         }
      }
   }
   
   // Refresh chart
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Create a horizontal trend line on the chart                       |
//+------------------------------------------------------------------+
void CreateTrendLine(string name, double price, color line_color, string text) {
   // Delete line if it exists
   ObjectDelete(0, name);
   
   // Create horizontal line
   if(!ObjectCreate(0, name, OBJ_HLINE, 0, 0, price)) {
      Print("Failed to create trend line: ", name);
      return;
   }
   
   // Set line properties
   ObjectSetInteger(0, name, OBJPROP_COLOR, line_color);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetString(0, name, OBJPROP_TOOLTIP, text);
   
   // Add text label
   string text_name = name + "_Text";
   ObjectDelete(0, text_name);
   
   if(!ObjectCreate(0, text_name, OBJ_TEXT, 0, TimeCurrent(), price)) {
      Print("Failed to create text for trend line: ", text_name);
      return;
   }
   
   // Set text properties
   ObjectSetInteger(0, text_name, OBJPROP_COLOR, line_color);
   ObjectSetInteger(0, text_name, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, text_name, OBJPROP_FONT, "Arial");
   ObjectSetString(0, text_name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, text_name, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0, text_name, OBJPROP_BACK, false);
   ObjectSetInteger(0, text_name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, text_name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, text_name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| Delete all trade lines                                            |
//+------------------------------------------------------------------+
void DeleteAllTradeLines() {
   int total = ObjectsTotal(0, 0, OBJ_HLINE);
   
   // First collect names to avoid deleting while iterating
   string names[];
   ArrayResize(names, total);
   int count = 0;
   
   for(int i = 0; i < total; i++) {
      string name = ObjectName(0, i, 0, OBJ_HLINE);
      if(StringFind(name, g_line_prefix) == 0) {
         names[count++] = name;
      }
   }
   
   // Now delete them
   for(int i = 0; i < count; i++) {
      ObjectDelete(0, names[i]);
      ObjectDelete(0, names[i] + "_Text"); // Also delete associated text
   }
   
   // Check for any text objects that need to be cleaned up
   total = ObjectsTotal(0, 0, OBJ_TEXT);
   count = 0;
   ArrayResize(names, total);
   
   for(int i = 0; i < total; i++) {
      string name = ObjectName(0, i, 0, OBJ_TEXT);
      if(StringFind(name, g_line_prefix) == 0) {
         names[count++] = name;
      }
   }
   
   // Delete text objects
   for(int i = 0; i < count; i++) {
      ObjectDelete(0, names[i]);
   }
}

//+------------------------------------------------------------------+
//| Create advanced performance dashboard                            |
//+------------------------------------------------------------------+
void CreateAdvancedDashboard() {
   if(!ShowInfoPanel) return;
   
   // Performance statistics
   double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double account_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double current_profit = account_equity - account_balance;
   
   // Calculate win rate and other metrics
   HistorySelect(0, TimeCurrent());
   int total_deals = HistoryDealsTotal();
   int winning_trades = 0, losing_trades = 0;
   double gross_profit = 0.0, gross_loss = 0.0;
   
   for(int i = 0; i < total_deals; i++) {
      ulong deal_ticket = HistoryDealGetTicket(i);
      if(deal_ticket == 0) continue;
      
      // Only count deals from this EA
      long deal_magic = HistoryDealGetInteger(deal_ticket, DEAL_MAGIC);
      string deal_symbol = HistoryDealGetString(deal_ticket, DEAL_SYMBOL);
      
      if(deal_magic != Magic_Number || deal_symbol != Symbol_Name) continue;
      
      // Process only closing deals
      if(HistoryDealGetInteger(deal_ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT) {
         double deal_profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
         
         if(deal_profit > 0) {
            winning_trades++;
            gross_profit += deal_profit;
         } else if(deal_profit < 0) {
            losing_trades++;
            gross_loss += MathAbs(deal_profit);
         }
      }
   }
   
   // Calculate metrics
   int total_trades = winning_trades + losing_trades;
   double win_rate = (total_trades > 0) ? ((double)winning_trades / total_trades) * 100.0 : 0.0;
   double profit_factor = (gross_loss > 0) ? gross_profit / gross_loss : (gross_profit > 0 ? 9999.0 : 0.0);
   double expectancy = 0.0;
   if(total_trades > 0) {
      if(winning_trades > 0 && losing_trades > 0) {
         expectancy = ((gross_profit / winning_trades) * win_rate/100.0) - ((gross_loss / losing_trades) * (1.0 - win_rate/100.0));
      }
   }
   
   // Position information
   int buy_positions = 0, sell_positions = 0;
   double buy_volume = 0.0, sell_volume = 0.0;
   
   int total = PositionsTotal();
   for(int i = 0; i < total; i++) {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket)) {
         if(PositionGetString(POSITION_SYMBOL) == Symbol_Name && 
            PositionGetInteger(POSITION_MAGIC) == Magic_Number) {
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
               buy_positions++;
               buy_volume += PositionGetDouble(POSITION_VOLUME);
            } else {
               sell_positions++;
               sell_volume += PositionGetDouble(POSITION_VOLUME);
            }
         }
      }
   }
   
   // Create a simple one-line header at the top of the chart instead of a rectangle panel
   string header_name = "MoneyMonsterHeader";
   string header_text = "===== MoneyMonster EA =====Symbol: " + Symbol_Name + 
                       " Balance: " + DoubleToString(account_balance, 2);
   
   // Remove old objects
   ObjectDelete(0, g_panel_name);
   ObjectDelete(0, g_panel_name + "_Text");
   ObjectDelete(0, g_panel_name + "_Advanced");
   ObjectDelete(0, g_panel_name + "_Advanced_Text");
   ObjectDelete(0, header_name);
   
   // Create header text
   if(!ObjectCreate(0, header_name, OBJ_LABEL, 0, 0, 0)) {
      Print("Failed to create header text.");
      return;
   }
   
   // Position at top middle of the chart
   int x_center = (int)(ChartGetInteger(0, CHART_WIDTH_IN_PIXELS) / 2);
   
   // Set header properties
   ObjectSetInteger(0, header_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, header_name, OBJPROP_XDISTANCE, x_center - 200); // center approximately
   ObjectSetInteger(0, header_name, OBJPROP_YDISTANCE, 20);
   ObjectSetInteger(0, header_name, OBJPROP_COLOR, InfoTextColor);
   ObjectSetInteger(0, header_name, OBJPROP_FONTSIZE, InfoFontSize);
   ObjectSetString(0, header_name, OBJPROP_FONT, "Consolas");
   ObjectSetString(0, header_name, OBJPROP_TEXT, header_text);
   ObjectSetInteger(0, header_name, OBJPROP_BACK, false);
   ObjectSetInteger(0, header_name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, header_name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, header_name, OBJPROP_HIDDEN, true);
   
   // Refresh chart
   ChartRedraw(0);
}