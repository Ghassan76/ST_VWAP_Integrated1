//+------------------------------------------------------------------+
//|                                                  ST_VWAP_EA.mq5  |
//|      Expert Advisor for ST_VWAP_Integrated1 (EA-Ready v1.1)     |
//+------------------------------------------------------------------+
//|  VERSION: 1.0 - No External Libraries                            |
//|  DATE: 2025-10-18                                                |
//|                                                                  |
//|  SIGNAL SOURCE: ST_VWAP_Integrated1 indicator buffer #6         |
//|  SIGNAL VALUES: +1 = BUY | -1 = SELL | 0 = No signal            |
//|  READ POINT: Closed bar only (shift=1)                          |
//+------------------------------------------------------------------+
#property strict
#property copyright "EA for ST_VWAP_Integrated1"
#property version   "1.00"

//==================================================================
// INPUTS
//==================================================================

//--- General Trading Settings
input group "=== General Trading Settings ==="
input ulong   MagicNumber           = 567890;
input bool    ip_EnableEntry        = true;
input bool    ip_EnableBuy          = true;
input bool    ip_EnableSell         = true;
input bool    ip_OneTradeAtTime     = true;   // if true: block new entries while any EA position is open
input int     ip_MaxOpenTrades      = 1;      // 0 = unlimited
input bool    ip_VerboseLogs        = true;   // structured logs for signals, filters, orders

//--- Entry Mode & Delay
input group "=== Entry Mode & Delay ==="
enum EntryModeType { EM_IMMEDIATE, EM_DELAY_THIS_TF, EM_DELAY_CUSTOM_TF };
input EntryModeType     ip_EntryMode   = EM_IMMEDIATE;
input int               ip_DelayBars   = 2;           // bars to wait
input ENUM_TIMEFRAMES   ip_DelayTF     = PERIOD_M5;   // used only when EM_DELAY_CUSTOM_TF

//--- Entry Repeat Type
input group "=== Entry Repeat Type ==="
enum EntryRepeatType { ER_ONE_AT_A_TIME, ER_SINGLE_PER_SIGNAL };
input EntryRepeatType   ip_EntryRepeat = ER_ONE_AT_A_TIME;

//--- Spread & Time/Session Filters
input group "=== Spread Filter ==="
input int   ip_MaxSpreadPts    = 252;

input group "=== Time Filter ==="
input bool  ip_UseTimeFilter   = false;
input int   ip_BeginHour       = 15;
input int   ip_BeginMinute     = 0;
input int   ip_EndHour         = 22;
input int   ip_EndMinute       = 59;

input group "=== Trading Sessions ==="
input bool  ip_UseSession1     = false;
input int   ip_Session1StartH  = 0;
input int   ip_Session1StartM  = 0;
input int   ip_Session1EndH    = 0;
input int   ip_Session1EndM    = 0;

input bool  ip_UseSession2     = false;
input int   ip_Session2StartH  = 0;
input int   ip_Session2StartM  = 0;
input int   ip_Session2EndH    = 0;
input int   ip_Session2EndM    = 0;

input bool  ip_UseSession3     = false;
input int   ip_Session3StartH  = 0;
input int   ip_Session3StartM  = 0;
input int   ip_Session3EndH    = 0;
input int   ip_Session3EndM    = 0;

input bool  ip_UseSession4     = false;
input int   ip_Session4StartH  = 0;
input int   ip_Session4StartM  = 0;
input int   ip_Session4EndH    = 0;
input int   ip_Session4EndM    = 0;

//--- Weekday Trading
input group "=== Weekday Trading ==="
input bool ip_TradeSun = false;
input bool ip_TradeMon = true;
input bool ip_TradeTue = true;
input bool ip_TradeWed = true;
input bool ip_TradeThu = true;
input bool ip_TradeFri = true;
input bool ip_TradeSat = false;

//--- Lot Sizing
input group "=== Lot Sizing ==="
input bool   ip_DynamicLots   = false;
input double ip_RiskPct       = 1.0;   // % of equity (used if dynamic=true)
input double ip_FixedLot      = 2.00;  // used if dynamic=false

//--- Initial SL / TP
input group "=== Initial SL / TP ==="
input bool   RSLTP_UseMoneyTargets = false;
input double RSLTP_Money_SL_Amount = 50.0;   // SL USD
input double RSLTP_Money_TP_Amount = 100.0;  // TP USD
input double RSLTP_Points_SL       = 10000;  // SL points
input double RSLTP_Points_TP       = 10000;  // TP points

//--- Daily Risk & Drawdown
input group "=== Daily Risk Management ==="
input bool   DRisk_EnableMaxTradesPerDay = false;
input int    DRisk_MaxTradesPerDay       = 10;
input bool   DRisk_EnableProfitCap       = false;
input double DRisk_DailyProfitTarget     = 100.0;
input bool   DRisk_EnableLossCap         = false;
input double DRisk_DailyLossLimit        = 100.0;

input group "=== Session Drawdown Protection ==="
input bool   SDD_EnableDrawdownProtection = false;
input double SDD_MaxDrawdownUSD            = 100.0;

//--- Overall Profit Target
input group "=== Overall Profit Target ==="
input bool   Overall_EnableProfitTarget = false;
input double Overall_ProfitTargetUSD    = 500.0;

//--- Indicator Settings (must match indicator inputs for signal generation)
input group "=== Indicator Settings (Signal-Affecting) ==="
input int      ST_ATRPeriod        = 10;
input double   ST_Multiplier       = 3.0;
input ENUM_APPLIED_PRICE ST_Price  = PRICE_MEDIAN;
input ENUM_APPLIED_PRICE VWAP_PriceMethod = PRICE_TYPICAL;
input double   VWAP_MinVolume      = 1.0;
input bool     VWAP_FilterDaily     = true;
input bool     VWAP_FilterWeekly    = false;
input bool     VWAP_FilterMonthly   = false;
input bool     AVWAP_Session_Enable = false;
input int      AVWAP_Session_Hour   = 9;
input int      AVWAP_Session_Min    = 30;
input bool     AVWAP_Session_Filter = false;
input bool     Session_Enable       = false;
input int      Session_StartHour    = 0;
input int      Session_StartMinute  = 0;
input int      Session_EndHour      = 23;
input int      Session_EndMinute    = 59;

// Session Mode enum (must match indicator)
enum SessionMode
{
   SESSION_DASH_ONLY = 0,
   SESSION_SIGNALS_ONLY = 1,
   SESSION_BOTH = 2
};
input SessionMode Session_Mode = SESSION_SIGNALS_ONLY;

//+------------------------------------------------------------------+
//| ENHANCED SMART TRAILING (Break-Even + Trailing + Limits)        |
//| Drop-in module: copy/paste into any EA                          |
//+------------------------------------------------------------------+

//---------------------------
// Enhanced Smart Trailing Inputs
//---------------------------
input group "=== ENHANCED SMART TRAILING ==="
input bool   ip_EnableBreakEven            = true;   // Enable independent break-even
input bool   ip_EnableSmartTrailing        = true;   // Enable independent smart trailing
input double STrail_BreakEvenPercent       = 49.0;   // % of TP-equivalent distance before BE triggers
input double STrail_BE_SL_PctOfTP          = 1.0;    // SL moved to 'x% of TP span' past BE (0..100)
input double STrail_TrailStartPercent      = 50.0;   // % of TP-equivalent distance before trailing starts
input int    STrail_TrailingSL_StepPoints  = 1000;   // SL trail step (points)
input int    STrail_TrailingTP_StepPoints  = 1000;   // TP trail step (points)
input int    STrail_TriggerDistancePoints  = 1000;   // Minimum distance from price to SL to allow trailing (points)
input int    STrail_CheckIntervalSec       = 0;      // Optional: call from OnTimer (0 = don't set timer here)
input int    STrail_MinIntervalMS          = 0;      // Minimum milliseconds between modifications per position (0 = none)

input group "=== SL/TP MODIFICATION LIMITS ==="
input int    MaxSLModifications            = 5;      // Max SL changes per position (-1 = unlimited)
input int    MaxTPModifications            = 3;      // Max TP changes per position (-1 = unlimited)

// Optional: deviation for modification requests (does NOT depend on your EA's ip_SlippagePts)
input int    STrail_ModifyDeviationPts     = 30;

//---------------------------
// Smart Trailing Local Config
//---------------------------
#define ST_RETRY_ATTEMPTS  5
#define ST_RETRY_DELAY_MS  100

//---------------------------
// Smart Trailing Internal Structs/State
//---------------------------
struct ST_PositionTracker
{
  ulong     ticket;
  int       slMods;
  int       tpMods;
  datetime  openTime;
  bool      breakEvenApplied;

  ST_PositionTracker() : ticket(0), slMods(0), tpMods(0),
                         openTime(0), breakEvenApplied(false) {}
  ST_PositionTracker(ulong t, datetime ot)
  : ticket(t), slMods(0), tpMods(0), openTime(ot), breakEvenApplied(false) {}
};

ST_PositionTracker  ST_trackers[];      // per-ticket SL/TP limits + BE flag
ulong               ST_tickets[];       // tickets managed by this module
ulong               ST_lastTickMS[];    // per-index time gate (ms)

//---------------------------
// Smart Trailing Tracker Utilities
//---------------------------
int ST_FindTrackerIndex(const ulong ticket)
{
  for(int i=0;i<ArraySize(ST_trackers);++i)
    if(ST_trackers[i].ticket==ticket) return i;
  return -1;
}

void ST_AddTracker(const ulong ticket)
{
  if(ticket==0 || !PositionSelectByTicket(ticket)) return;
  if(ST_FindTrackerIndex(ticket)>=0) return;

  int n=ArraySize(ST_trackers);
  ArrayResize(ST_trackers,n+1);
  ST_trackers[n] = ST_PositionTracker(ticket,(datetime)PositionGetInteger(POSITION_TIME));
}

void ST_RemoveTracker(const ulong ticket)
{
  int idx = ST_FindTrackerIndex(ticket);
  if(idx<0) return;
  int n=ArraySize(ST_trackers);
  for(int i=idx;i<n-1;++i) ST_trackers[i]=ST_trackers[i+1];
  ArrayResize(ST_trackers,n-1);
}

void ST_CleanupClosedTrackers()
{
  for(int i=ArraySize(ST_trackers)-1;i>=0;--i)
  {
    if(!PositionSelectByTicket(ST_trackers[i].ticket))
    {
      // remove tracker
      int n=ArraySize(ST_trackers);
      for(int j=i;j<n-1;++j) ST_trackers[j]=ST_trackers[j+1];
      ArrayResize(ST_trackers,n-1);
    }
  }
}

bool ST_CanModifySL(const ulong ticket)
{
  if(MaxSLModifications==-1) return true;
  int i = ST_FindTrackerIndex(ticket);
  return (i<0) ? true : (ST_trackers[i].slMods < MaxSLModifications);
}
bool ST_CanModifyTP(const ulong ticket)
{
  if(MaxTPModifications==-1) return true;
  int i = ST_FindTrackerIndex(ticket);
  return (i<0) ? true : (ST_trackers[i].tpMods < MaxTPModifications);
}

void ST_IncSL(const ulong ticket){ int i=ST_FindTrackerIndex(ticket); if(i>=0) ST_trackers[i].slMods++; }
void ST_IncTP(const ulong ticket){ int i=ST_FindTrackerIndex(ticket); if(i>=0) ST_trackers[i].tpMods++; }

bool ST_IsBE(const ulong ticket){ int i=ST_FindTrackerIndex(ticket); return (i>=0)? ST_trackers[i].breakEvenApplied : false; }
void ST_SetBE(const ulong ticket,bool v){ int i=ST_FindTrackerIndex(ticket); if(i>=0) ST_trackers[i].breakEvenApplied = v; }

//---------------------------
// Smart Trailing Safe Modification Helper
//---------------------------
bool ST_PositionModifyRetry(const ulong ticket, double newSL, double newTP)
{
  if(ticket==0 || !PositionSelectByTicket(ticket)) return false;

  // Read current
  const double curSL = PositionGetDouble(POSITION_SL);
  const double curTP = PositionGetDouble(POSITION_TP);

  // If caller passes <=0, keep current (do not attempt to change)
  if(newSL<=0) newSL = curSL;
  if(newTP<=0) newTP = curTP;

  // Respect modification limits (if the desired value actually differs)
  bool wantSL = (newSL>0 && (curSL<=0 || MathAbs(newSL-curSL) > (_Point/2.0)));
  bool wantTP = (newTP>0 && (curTP<=0 || MathAbs(newTP-curTP) > (_Point/2.0)));

  if(wantSL && !ST_CanModifySL(ticket)) wantSL=false;
  if(wantTP && !ST_CanModifyTP(ticket)) wantTP=false;

  if(!wantSL && !wantTP) return false; // nothing to do

  MqlTradeRequest r; MqlTradeResult res;
  for(int attempt=0; attempt<ST_RETRY_ATTEMPTS; ++attempt)
  {
    ZeroMemory(r); ZeroMemory(res);
    r.action     = TRADE_ACTION_SLTP;
    r.position   = ticket;
    r.symbol     = _Symbol;
    r.deviation  = STrail_ModifyDeviationPts;
    r.sl         = wantSL ? NormalizeDouble(newSL, _Digits) : curSL;
    r.tp         = wantTP ? NormalizeDouble(newTP, _Digits) : curTP;

    if(OrderSend(r,res) &&
       (res.retcode==TRADE_RETCODE_DONE ||
        res.retcode==TRADE_RETCODE_PLACED ||
        res.retcode==TRADE_RETCODE_DONE_PARTIAL))
    {
      if(wantSL) ST_IncSL(ticket);
      if(wantTP) ST_IncTP(ticket);
      return true;
    }

    // Retry on transient price errors
    if(res.retcode==TRADE_RETCODE_REQUOTE ||
       res.retcode==TRADE_RETCODE_PRICE_OFF ||
       res.retcode==TRADE_RETCODE_PRICE_CHANGED)
    {
      Sleep(ST_RETRY_DELAY_MS);
      continue;
    }
    break;
  }
  return false;
}

//---------------------------
// Smart Trailing Time-Gate Helper
//---------------------------
bool ST_TimeGate(const int idx)
{
  if(STrail_MinIntervalMS<=0) return true;
  if(idx<0 || idx>=ArraySize(ST_lastTickMS)) return false;
  return (GetTickCount() - ST_lastTickMS[idx] >= (ulong)STrail_MinIntervalMS);
}

//---------------------------
// Smart Trailing Break-Even Logic
//---------------------------
bool ST_HandleBreakEven(const ulong ticket)
{
  if(!ip_EnableBreakEven) return false;
  if(ticket==0 || !PositionSelectByTicket(ticket)) return false;
  if(ST_IsBE(ticket)) return false; // already applied

  const bool   isBuy      = (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
  const int    sign       = isBuy ? 1 : -1;
  const double openPrice  = PositionGetDouble(POSITION_PRICE_OPEN);
  const double curSL      = PositionGetDouble(POSITION_SL);
  const double curTP      = PositionGetDouble(POSITION_TP);
  const double price      = isBuy ? SymbolInfoDouble(_Symbol,SYMBOL_BID)
                                  : SymbolInfoDouble(_Symbol,SYMBOL_ASK);

  if(openPrice<=0 || price<=0) return false;

  // TP span used as reference scale; if no TP, fall back to trailing TP step
  double tpSpan = MathAbs(curTP - openPrice);
  if(tpSpan < _Point)
    tpSpan = MathMax( (double)STrail_TrailingTP_StepPoints, 1.0 ) * _Point;

  const double profitPts = (isBuy ? (price-openPrice) : (openPrice-price));
  if(profitPts <= 0) return false;

  const double profitPct = 100.0 * profitPts / tpSpan;
  if(profitPct < STrail_BreakEvenPercent) return false;

  // Target SL = BE + (optional % of TP span past BE)
  double targetSL = openPrice + sign * (STrail_BE_SL_PctOfTP/100.0) * tpSpan;

  // Respect minimum stop distance
  const double stopsLevelPts = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
  const double minStop = stopsLevelPts * _Point;
  if(isBuy)
  {
    if(price - targetSL < minStop) targetSL = price - minStop;
    if(curSL>0 && targetSL <= curSL + _Point/2.0) return false;
  }
  else
  {
    if(targetSL - price < minStop) targetSL = price + minStop;
    if(curSL>0 && targetSL >= curSL - _Point/2.0) return false;
  }

  targetSL = NormalizeDouble(targetSL, _Digits);

  if(!ST_CanModifySL(ticket)) return false;
  if(ST_PositionModifyRetry(ticket, targetSL, curTP))
  {
    ST_SetBE(ticket, true);
    return true;
  }
  return false;
}

//---------------------------
// Smart Trailing Logic
//---------------------------
bool ST_HandleTrailing(const ulong ticket)
{
  if(!ip_EnableSmartTrailing) return false;
  if(ticket==0 || !PositionSelectByTicket(ticket)) return false;

  const bool   isBuy      = (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
  const int    sign       = isBuy ? 1 : -1;
  const double openPrice  = PositionGetDouble(POSITION_PRICE_OPEN);
  const double curSL      = PositionGetDouble(POSITION_SL);
  const double curTP      = PositionGetDouble(POSITION_TP);
  const double price      = isBuy ? SymbolInfoDouble(_Symbol,SYMBOL_BID)
                                  : SymbolInfoDouble(_Symbol,SYMBOL_ASK);

  if(openPrice<=0 || price<=0) return false;
  if(curSL<=0) return false; // trailing requires an SL in place (e.g., BE set)

  // TP span reference
  double tpSpan = MathAbs(curTP - openPrice);
  if(tpSpan < _Point)
    tpSpan = MathMax( (double)STrail_TrailingTP_StepPoints, 1.0 ) * _Point;

  const double profitPts = (isBuy ? (price-openPrice) : (openPrice-price));
  if(profitPts <= 0) return false;

  const double profitPct = 100.0 * profitPts / tpSpan;
  if(profitPct < STrail_TrailStartPercent) return false;

  // Minimum gap to allow trailing
  const double stopsLevelPts = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
  const double minGap = MathMax(stopsLevelPts * _Point, (double)STrail_TriggerDistancePoints * _Point);

  const double curGap = isBuy ? (price - curSL) : (curSL - price);
  const double step   = (double)STrail_TrailingSL_StepPoints * _Point;

  if(curGap < (minGap + step)) return false;

  double newSL = curSL + sign * step;
  double newTP = curTP;

  // Optional TP trailing
  const double tpStep = (double)STrail_TrailingTP_StepPoints * _Point;
  if(curTP > 0 && tpStep >= _Point && ST_CanModifyTP(ticket))
    newTP = curTP + sign * tpStep;

  // Validate SL stays at least minGap away
  if(isBuy)
  {
    if(price - newSL < minGap) newSL = price - minGap;
  }
  else
  {
    if(newSL - price < minGap) newSL = price + minGap;
  }

  newSL = NormalizeDouble(newSL, _Digits);
  newTP = NormalizeDouble(newTP, _Digits);

  bool slChanged = (MathAbs(newSL - curSL) > (_Point/2.0)) && ST_CanModifySL(ticket);
  bool tpChanged = (MathAbs(newTP - curTP) > (_Point/2.0)) && ST_CanModifyTP(ticket);

  if(!slChanged && !tpChanged) return false;

  // Try both first (if both allowed), fallback to one
  if(slChanged && tpChanged)
  {
    if(ST_PositionModifyRetry(ticket, newSL, newTP)) return true;
  }
  if(slChanged)
  {
    if(ST_PositionModifyRetry(ticket, newSL, curTP)) return true;
  }
  if(tpChanged)
  {
    if(ST_PositionModifyRetry(ticket, curSL, newTP)) return true;
  }
  return false;
}

//---------------------------
// Smart Trailing Management API
//---------------------------

// Call this when a new position (this symbol) is opened and you want it managed
void ST_RegisterTicket(const ulong ticket)
{
  if(ticket==0 || !PositionSelectByTicket(ticket)) return;
  // Avoid duplicates
  for(int i=0;i<ArraySize(ST_tickets);++i) if(ST_tickets[i]==ticket) return;

  int n = ArraySize(ST_tickets);
  ArrayResize(ST_tickets, n+1);
  ArrayResize(ST_lastTickMS, n+1);
  ST_tickets[n]   = ticket;
  ST_lastTickMS[n]= GetTickCount();

  ST_AddTracker(ticket);
}

// Rebuild cache from current positions (optionally filter by magic; pass -1 to accept any)
void ST_RebuildCache(const long magicFilter = -1)
{
  ArrayResize(ST_tickets,0);
  ArrayResize(ST_lastTickMS,0);

  for(int i=0;i<PositionsTotal();++i)
  {
    ulong ticket = PositionGetTicket(i);
    if(!PositionSelectByTicket(ticket)) continue;
    if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;

    long pmagic = (long)PositionGetInteger(POSITION_MAGIC);
    if(magicFilter!=-1 && pmagic!=magicFilter) continue;

    int n = ArraySize(ST_tickets);
    ArrayResize(ST_tickets, n+1);
    ArrayResize(ST_lastTickMS, n+1);
    ST_tickets[n]   = ticket;
    ST_lastTickMS[n]= GetTickCount();

    ST_AddTracker(ticket);
  }
  ST_CleanupClosedTrackers();
}

// Manage one ticket (index as stored in ST_tickets)
void ST_ManageOne(const int idx, const ulong ticket)
{
  if(!ST_TimeGate(idx)) return;

  bool changed=false;
  if(ST_HandleBreakEven(ticket)) changed=true;
  if(ST_HandleTrailing(ticket))  changed=true;

  if(changed)
    ST_lastTickMS[idx] = GetTickCount();
}

// Main manager — call from OnTick and/or OnTimer
void ST_ManageAll()
{
  if(!ip_EnableBreakEven && !ip_EnableSmartTrailing) return;

  int n = ArraySize(ST_tickets);
  for(int i=n-1;i>=0;--i)
  {
    const ulong ticket = ST_tickets[i];

    // Remove closed positions from cache & trackers
    if(ticket==0 || !PositionSelectByTicket(ticket))
    {
      ST_RemoveTracker(ticket);
      for(int j=i;j<n-1;++j){ ST_tickets[j]=ST_tickets[j+1]; ST_lastTickMS[j]=ST_lastTickMS[j+1]; }
      n--; ArrayResize(ST_tickets,n); ArrayResize(ST_lastTickMS,n);
      continue;
    }

    ST_ManageOne(i, ticket);
  }

  // Safety cleanup
  ST_CleanupClosedTrackers();
}

// Optional helper: call in OnInit if you want a timer for trailing
void ST_TrailingInitTimer()
{
  if(STrail_CheckIntervalSec>0) EventSetTimer(STrail_CheckIntervalSec);
}
void ST_TrailingKillTimer()
{
  EventKillTimer();
}

//==================================================================
// GLOBAL VARIABLES
//==================================================================
int            g_indicatorHandle = INVALID_HANDLE;
datetime       g_lastBarTime     = 0;
datetime       g_lastSignalTime  = 0;  // track last processed signal bar time

// Daily tracking
datetime       g_currentDay      = 0;
int            g_dailyTrades     = 0;
double         g_dailyProfit     = 0.0;
double         g_sessionStartBalance = 0.0;

// Overall tracking
double         g_overallProfit   = 0.0;
double         g_startingBalance = 0.0;

// Delayed entry tracking
struct DelayedEntry
{
   bool     active;
   int      direction;      // +1 = BUY, -1 = SELL
   datetime signalTime;
   datetime delayStartTime;
   int      barsElapsed;
   int      barsRequired;
};
DelayedEntry g_pendingEntry;

//==================================================================
// HELPER FUNCTIONS (Replace library dependencies)
//==================================================================

// Get symbol properties
double GetSymbolAsk() { return SymbolInfoDouble(_Symbol, SYMBOL_ASK); }
double GetSymbolBid() { return SymbolInfoDouble(_Symbol, SYMBOL_BID); }

// Get spread with fallback calculation
long GetSymbolSpread() 
{ 
   long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread <= 0)
   {
      // Fallback: calculate from bid/ask
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double pnt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(pnt > 0)
         spread = (long)MathRound((ask - bid) / pnt);
   }
   return spread;
}
double GetSymbolPoint() { return SymbolInfoDouble(_Symbol, SYMBOL_POINT); }
double GetSymbolTickSize() { return SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE); }
double GetSymbolTickValue() { return SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE); }
double GetSymbolLotsMin() { return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN); }
double GetSymbolLotsMax() { return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX); }
double GetSymbolLotsStep() { return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP); }
long GetSymbolStopsLevel() { return SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL); }
int GetSymbolDigits() { return (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS); }

// Normalize price
double NormalizePrice(double price)
{
   int digits = GetSymbolDigits();
   return NormalizeDouble(price, digits);
}

// Normalize lot size
double NormalizeLot(double lot)
{
   double minLot = GetSymbolLotsMin();
   double maxLot = GetSymbolLotsMax();
   double lotStep = GetSymbolLotsStep();
   
   lot = MathMax(minLot, MathMin(maxLot, lot));
   lot = MathFloor(lot / lotStep) * lotStep;
   
   return lot;
}

// Get account info
double GetAccountBalance() { return AccountInfoDouble(ACCOUNT_BALANCE); }
double GetAccountEquity() { return AccountInfoDouble(ACCOUNT_EQUITY); }

// Count positions for this EA (MQL5: use PositionGetTicket to select position)
int CountEAPositions()
{
   int count = 0;
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
            (ulong)PositionGetInteger(POSITION_MAGIC) == MagicNumber)
            count++;
      }
   }
   
   return count;
}

// Send market order with multiple filling modes (tries symbol's preferred mode first)
// Returns position ticket on success, 0 on failure
ulong SendMarketOrder(ENUM_ORDER_TYPE orderType, double lot, double price, double sl, double tp, string comment)
{
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = lot;
   request.type = orderType;
   request.price = price;
   request.sl = sl;
   request.tp = tp;
   request.deviation = 50;
   request.magic = MagicNumber;
   request.comment = comment;
   
   // Get symbol's allowed filling modes
   long filling_mode = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   
   // Build list of filling modes to try (symbol's preferred mode first)
   ENUM_ORDER_TYPE_FILLING modes[3];
   int mode_count = 0;
   
   // Add symbol's preferred modes
   if((filling_mode & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
      modes[mode_count++] = ORDER_FILLING_FOK;
   if((filling_mode & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
      modes[mode_count++] = ORDER_FILLING_IOC;
   
   // Always try RETURN as fallback
   modes[mode_count++] = ORDER_FILLING_RETURN;
   
   // Try each mode
   for(int i = 0; i < mode_count; i++)
   {
      request.type_filling = modes[i];
      
      if(OrderSend(request, result))
      {
         if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED)
         {
            if(ip_VerboseLogs)
            {
               string fill_name = (modes[i] == ORDER_FILLING_FOK) ? "FOK" : 
                                  (modes[i] == ORDER_FILLING_IOC) ? "IOC" : "RETURN";
               Print("Order executed (", fill_name, ") | Ticket: ", result.order, 
                     " | Deal: ", result.deal, " | Retcode: ", result.retcode);
            }
            
            // Find and return the position ticket
            // In MQL5, after a market order, we need to find the position by order ticket
            if(HistoryOrderSelect(result.order))
            {
               ulong posTicket = HistoryOrderGetInteger(result.order, ORDER_POSITION_ID);
               if(posTicket > 0)
                  return posTicket;
            }
            
            // Fallback: try to find position by symbol and magic
            for(int p = PositionsTotal() - 1; p >= 0; p--)
            {
               ulong ticket = PositionGetTicket(p);
               if(PositionSelectByTicket(ticket))
               {
                  if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
                     PositionGetInteger(POSITION_MAGIC) == MagicNumber)
                     return ticket;
               }
            }
            
            return result.order; // Last resort
         }
      }
      
      if(ip_VerboseLogs)
      {
         string fill_name = (modes[i] == ORDER_FILLING_FOK) ? "FOK" : 
                            (modes[i] == ORDER_FILLING_IOC) ? "IOC" : "RETURN";
         Print(fill_name, " failed | Retcode: ", result.retcode, " | ", result.comment);
      }
   }
   
   return 0;
}

//==================================================================
// INITIALIZATION
//==================================================================
int OnInit()
{
   // Validate symbol
   if(!SymbolSelect(_Symbol, true))
   {
      Print("ERROR: Failed to select symbol: ", _Symbol);
      return(INIT_FAILED);
   }
   
   // Create indicator handle - CRITICAL: pass all signal-affecting inputs in exact order
   g_indicatorHandle = iCustom(
      _Symbol, 
      _Period,
      "ST_VWAP_Integrated1",  // File name only (no "Indicators\\" path)
      // === SuperTrend Settings ===
      ST_ATRPeriod, 
      ST_Multiplier, 
      ST_Price,
      // === VWAP Settings ===
      VWAP_PriceMethod, 
      VWAP_MinVolume,
      // VWAP Filters (signal-affecting)
      VWAP_FilterDaily, 
      VWAP_FilterWeekly, 
      VWAP_FilterMonthly,
      // Anchored VWAP Session
      AVWAP_Session_Enable, 
      AVWAP_Session_Hour, 
      AVWAP_Session_Min, 
      AVWAP_Session_Filter,
      // Session gating (indicator-side)
      Session_Enable, 
      Session_StartHour, 
      Session_StartMinute, 
      Session_EndHour, 
      Session_EndMinute,
      Session_Mode
   );
   
   if(g_indicatorHandle == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create indicator handle. Error: ", GetLastError());
      Print("HINT: Ensure ST_VWAP_Integrated1.ex5 exists in Indicators folder");
      Print("HINT: Check that indicator input order matches exactly");
      return(INIT_FAILED);
   }
   
   if(ip_VerboseLogs)
   {
      Print("Indicator handle created successfully");
      Print("Signal-affecting settings passed to indicator:");
      Print("  ST: ATR=", ST_ATRPeriod, " Mult=", ST_Multiplier, " Price=", EnumToString(ST_Price));
      Print("  VWAP: Method=", EnumToString(VWAP_PriceMethod), " MinVol=", VWAP_MinVolume);
      Print("  Filters: Daily=", VWAP_FilterDaily, " Weekly=", VWAP_FilterWeekly, " Monthly=", VWAP_FilterMonthly);
      Print("  Session: Enable=", Session_Enable, " Mode=", Session_Mode);
   }
   
   // Initialize tracking variables
   g_lastBarTime = 0;
   g_lastSignalTime = 0;
   g_startingBalance = GetAccountBalance();
   g_sessionStartBalance = g_startingBalance;
   g_overallProfit = 0.0;
   g_currentDay = 0;
   g_dailyTrades = 0;
   g_dailyProfit = 0.0;
   
   // Initialize delayed entry
   g_pendingEntry.active = false;
   g_pendingEntry.direction = 0;
   g_pendingEntry.barsElapsed = 0;
   g_pendingEntry.barsRequired = ip_DelayBars;
   
   // Initialize Enhanced Smart Trailing
   ST_RebuildCache(MagicNumber);  // Load existing positions from this EA
   ST_TrailingInitTimer();         // Set up timer if configured
   
   if(ip_VerboseLogs)
   {
      Print("═══════════════════════════════════════════════════════════");
      Print("ST_VWAP_EA INITIALIZED SUCCESSFULLY");
      Print("═══════════════════════════════════════════════════════════");
      Print("Magic: ", MagicNumber, " | Symbol: ", _Symbol, " | TF: ", EnumToString((ENUM_TIMEFRAMES)_Period));
      Print("Trading: Entry=", ip_EnableEntry, " Buy=", ip_EnableBuy, " Sell=", ip_EnableSell);
      Print("Mode: ", (ip_EntryMode == EM_IMMEDIATE ? "IMMEDIATE" : (ip_EntryMode == EM_DELAY_THIS_TF ? "DELAY_THIS_TF" : "DELAY_CUSTOM_TF")));
      Print("Repeat: ", (ip_EntryRepeat == ER_ONE_AT_A_TIME ? "ONE_AT_A_TIME" : "SINGLE_PER_SIGNAL"));
      Print("Position Limits: OneAtTime=", ip_OneTradeAtTime, " MaxTrades=", ip_MaxOpenTrades);
      Print("Lots: ", (ip_DynamicLots ? "DYNAMIC " + DoubleToString(ip_RiskPct, 1) + "%" : "FIXED " + DoubleToString(ip_FixedLot, 2)));
      Print("SL/TP: ", (RSLTP_UseMoneyTargets ? "MONEY-BASED" : "POINTS-BASED"));
      Print("Smart Trailing: BE=", ip_EnableBreakEven, " Trailing=", ip_EnableSmartTrailing);
      Print("═══════════════════════════════════════════════════════════");
      Print("TIP: Disable VWAP filters temporarily if no trades appear");
      Print("     Set VWAP_FilterDaily/Weekly/Monthly = false for testing");
      Print("═══════════════════════════════════════════════════════════");
   }
   
   return(INIT_SUCCEEDED);
}

//==================================================================
// DEINITIALIZATION
//==================================================================
void OnDeinit(const int reason)
{
   if(g_indicatorHandle != INVALID_HANDLE)
      IndicatorRelease(g_indicatorHandle);
   
   // Clean up Enhanced Smart Trailing timer
   ST_TrailingKillTimer();
   
   if(ip_VerboseLogs)
      Print("ST_VWAP_EA deinitialized | Reason: ", reason);
}

//==================================================================
// ON TICK
//==================================================================
void OnTick()
{
   // Manage Enhanced Smart Trailing (break-even + trailing stop)
   ST_ManageAll();
   
   // Check for new bar
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime == g_lastBarTime)
      return;  // Not a new bar
   
   g_lastBarTime = currentBarTime;
   
   // Update daily tracking
   UpdateDailyTracking();
   
   // Check overall profit target
   if(Overall_EnableProfitTarget && g_overallProfit >= Overall_ProfitTargetUSD)
   {
      if(ip_VerboseLogs)
         Print("Overall profit target reached: $", DoubleToString(g_overallProfit, 2), " >= $", DoubleToString(Overall_ProfitTargetUSD, 2), " | No new entries allowed");
      return;
   }
   
   // Process delayed entry if active
   if(g_pendingEntry.active)
   {
      ProcessDelayedEntry();
   }
   
   // Check for new signal from indicator
   if(ip_EnableEntry)
   {
      CheckForSignal();
   }
}

//==================================================================
// ON TIMER (Optional - for timer-based trailing)
//==================================================================
void OnTimer()
{
   // Manage Enhanced Smart Trailing on timer events
   ST_ManageAll();
}

//==================================================================
// CHECK FOR SIGNAL
//==================================================================
void CheckForSignal()
{
   // Ensure indicator is ready
   if(BarsCalculated(g_indicatorHandle) <= ST_ATRPeriod + 2)
   {
      if(ip_VerboseLogs)
         Print("Indicator not ready yet | Bars calculated: ", BarsCalculated(g_indicatorHandle));
      return;
   }
   
   // Read signal from buffer #6 at shift=1 (closed bar)
   double signalBuffer[];
   ArraySetAsSeries(signalBuffer, true);
   
   if(CopyBuffer(g_indicatorHandle, 6, 1, 1, signalBuffer) <= 0)
   {
      if(ip_VerboseLogs)
         Print("Failed to copy signal buffer | Error: ", GetLastError());
      return;
   }
   
   double signal = signalBuffer[0];
   
   // Get bar time to prevent duplicate processing
   datetime barTime = iTime(_Symbol, _Period, 1);
   
   // DIAGNOSTIC: Always log signal value on new bar
   if(ip_VerboseLogs)
   {
      PrintFormat("Signal buf#6 @bar[1]=%.0f | time=%s | BarsCalculated=%d", 
                  signal, 
                  TimeToString(barTime, TIME_DATE|TIME_MINUTES),
                  BarsCalculated(g_indicatorHandle));
   }
   
   // Check if we already processed this signal
   if(barTime == g_lastSignalTime)
      return;  // Already processed
   
   // No signal
   if(signal == 0)
   {
      if(ip_VerboseLogs)
         Print("No signal on this bar (0) - waiting for flip");
      return;
   }
   
   // Mark this bar as processed
   g_lastSignalTime = barTime;
   
   int direction = (int)signal;  // +1 = BUY, -1 = SELL
   
   if(ip_VerboseLogs)
      Print("═══ NEW SIGNAL ═══ | Bar[1] Time: ", TimeToString(barTime, TIME_DATE|TIME_MINUTES), 
            " | Direction: ", (direction == 1 ? "BUY (+1)" : "SELL (-1)"));
   
   // Validate direction-specific entry
   if(direction == 1 && !ip_EnableBuy)
   {
      if(ip_VerboseLogs)
         Print("Filter REJECTED: BUY signals disabled");
      return;
   }
   
   if(direction == -1 && !ip_EnableSell)
   {
      if(ip_VerboseLogs)
         Print("Filter REJECTED: SELL signals disabled");
      return;
   }
   
   // Apply all filters
   if(!ValidateFilters(direction, barTime))
      return;
   
   // Entry mode logic
   if(ip_EntryMode == EM_IMMEDIATE)
   {
      // Execute immediately
      ExecuteEntry(direction);
   }
   else
   {
      // Delay entry
      if(g_pendingEntry.active)
      {
         if(ip_VerboseLogs)
            Print("Delayed entry already pending | Ignoring new signal");
         return;
      }
      
      g_pendingEntry.active = true;
      g_pendingEntry.direction = direction;
      g_pendingEntry.signalTime = barTime;
      g_pendingEntry.delayStartTime = TimeCurrent();
      g_pendingEntry.barsElapsed = 0;
      g_pendingEntry.barsRequired = ip_DelayBars;
      
      if(ip_VerboseLogs)
         Print("Entry DELAYED | Bars to wait: ", ip_DelayBars, " | TF: ", 
               (ip_EntryMode == EM_DELAY_THIS_TF ? EnumToString((ENUM_TIMEFRAMES)_Period) : EnumToString(ip_DelayTF)));
   }
}

//==================================================================
// PROCESS DELAYED ENTRY
//==================================================================
void ProcessDelayedEntry()
{
   if(!g_pendingEntry.active)
      return;
   
   // Determine which timeframe to count bars on
   ENUM_TIMEFRAMES delayTF = (ip_EntryMode == EM_DELAY_THIS_TF) ? (ENUM_TIMEFRAMES)_Period : ip_DelayTF;
   
   // Count bars elapsed on the delay timeframe
   datetime currentBarTime_TF = iTime(_Symbol, delayTF, 0);
   static datetime lastBarTime_TF = 0;
   
   if(currentBarTime_TF != lastBarTime_TF)
   {
      lastBarTime_TF = currentBarTime_TF;
      g_pendingEntry.barsElapsed++;
      
      if(ip_VerboseLogs)
         Print("Delayed entry | Bars elapsed: ", g_pendingEntry.barsElapsed, " / ", g_pendingEntry.barsRequired);
   }
   
   // Check if delay is complete
   if(g_pendingEntry.barsElapsed >= g_pendingEntry.barsRequired)
   {
      if(ip_VerboseLogs)
         Print("Delay complete | Re-checking filters before entry");
      
      // Re-check all filters before execution
      if(ValidateFilters(g_pendingEntry.direction, TimeCurrent()))
      {
         ExecuteEntry(g_pendingEntry.direction);
      }
      else
      {
         if(ip_VerboseLogs)
            Print("Delayed entry CANCELLED | Filters no longer valid");
      }
      
      // Clear pending entry
      g_pendingEntry.active = false;
      g_pendingEntry.direction = 0;
      g_pendingEntry.barsElapsed = 0;
   }
}

//==================================================================
// VALIDATE FILTERS
//==================================================================
bool ValidateFilters(int direction, datetime checkTime)
{
   // Weekday filter
   MqlDateTime dt;
   TimeToStruct(checkTime, dt);
   
   bool weekdayAllowed = false;
   switch(dt.day_of_week)
   {
      case 0: weekdayAllowed = ip_TradeSun; break;
      case 1: weekdayAllowed = ip_TradeMon; break;
      case 2: weekdayAllowed = ip_TradeTue; break;
      case 3: weekdayAllowed = ip_TradeWed; break;
      case 4: weekdayAllowed = ip_TradeThu; break;
      case 5: weekdayAllowed = ip_TradeFri; break;
      case 6: weekdayAllowed = ip_TradeSat; break;
   }
   
   if(!weekdayAllowed)
   {
      if(ip_VerboseLogs)
         Print("Filter REJECTED: Weekday not allowed | Day: ", dt.day_of_week);
      return false;
   }
   
   // Time window filter
   if(ip_UseTimeFilter)
   {
      int currentMinutes = dt.hour * 60 + dt.min;
      int beginMinutes = ip_BeginHour * 60 + ip_BeginMinute;
      int endMinutes = ip_EndHour * 60 + ip_EndMinute;
      
      bool inWindow = false;
      if(beginMinutes <= endMinutes)
         inWindow = (currentMinutes >= beginMinutes && currentMinutes <= endMinutes);
      else  // crosses midnight
         inWindow = (currentMinutes >= beginMinutes || currentMinutes <= endMinutes);
      
      if(!inWindow)
      {
         if(ip_VerboseLogs)
            Print("Filter REJECTED: Outside time window | Time: ", dt.hour, ":", dt.min);
         return false;
      }
   }
   
   // Session filters
   bool inAnySession = false;
   if(ip_UseSession1 || ip_UseSession2 || ip_UseSession3 || ip_UseSession4)
   {
      inAnySession = CheckSessionFilter(dt, ip_UseSession1, ip_Session1StartH, ip_Session1StartM, ip_Session1EndH, ip_Session1EndM) ||
                     CheckSessionFilter(dt, ip_UseSession2, ip_Session2StartH, ip_Session2StartM, ip_Session2EndH, ip_Session2EndM) ||
                     CheckSessionFilter(dt, ip_UseSession3, ip_Session3StartH, ip_Session3StartM, ip_Session3EndH, ip_Session3EndM) ||
                     CheckSessionFilter(dt, ip_UseSession4, ip_Session4StartH, ip_Session4StartM, ip_Session4EndH, ip_Session4EndM);
      
      if(!inAnySession)
      {
         if(ip_VerboseLogs)
            Print("Filter REJECTED: Outside all trading sessions");
         return false;
      }
   }
   
   // Spread filter
   long spread = GetSymbolSpread();
   if(spread > ip_MaxSpreadPts)
   {
      if(ip_VerboseLogs)
         Print("Filter REJECTED: Spread too high | Spread: ", spread, " pts > Max: ", ip_MaxSpreadPts, " pts");
      return false;
   }
   
   // Daily max trades
   if(DRisk_EnableMaxTradesPerDay && g_dailyTrades >= DRisk_MaxTradesPerDay)
   {
      if(ip_VerboseLogs)
         Print("Filter REJECTED: Daily max trades reached | Trades today: ", g_dailyTrades, " >= ", DRisk_MaxTradesPerDay);
      return false;
   }
   
   // Daily profit cap
   if(DRisk_EnableProfitCap && g_dailyProfit >= DRisk_DailyProfitTarget)
   {
      if(ip_VerboseLogs)
         Print("Filter REJECTED: Daily profit target reached | Profit: $", DoubleToString(g_dailyProfit, 2), " >= $", DoubleToString(DRisk_DailyProfitTarget, 2));
      return false;
   }
   
   // Daily loss cap
   if(DRisk_EnableLossCap && g_dailyProfit <= -DRisk_DailyLossLimit)
   {
      if(ip_VerboseLogs)
         Print("Filter REJECTED: Daily loss limit hit | Loss: $", DoubleToString(g_dailyProfit, 2), " <= -$", DoubleToString(DRisk_DailyLossLimit, 2));
      return false;
   }
   
   // Session drawdown protection
   if(SDD_EnableDrawdownProtection)
   {
      double currentDrawdown = GetAccountBalance() - g_sessionStartBalance;
      if(currentDrawdown <= -SDD_MaxDrawdownUSD)
      {
         if(ip_VerboseLogs)
            Print("Filter REJECTED: Session drawdown limit hit | Drawdown: $", DoubleToString(currentDrawdown, 2), " <= -$", DoubleToString(SDD_MaxDrawdownUSD, 2));
         return false;
      }
   }
   
   // Position limits
   int currentPositions = CountEAPositions();
   
   if(ip_OneTradeAtTime && currentPositions > 0)
   {
      if(ip_VerboseLogs)
         Print("Filter REJECTED: One trade at a time enabled | Current positions: ", currentPositions);
      return false;
   }
   
   if(ip_MaxOpenTrades > 0 && currentPositions >= ip_MaxOpenTrades)
   {
      if(ip_VerboseLogs)
         Print("Filter REJECTED: Max open trades limit | Current: ", currentPositions, " >= Max: ", ip_MaxOpenTrades);
      return false;
   }
   
   // Entry repeat type logic
   if(ip_EntryRepeat == ER_ONE_AT_A_TIME && currentPositions > 0)
   {
      if(ip_VerboseLogs)
         Print("Filter REJECTED: ER_ONE_AT_A_TIME mode - position already open");
      return false;
   }
   
   // All filters passed
   if(ip_VerboseLogs)
      Print("All filters PASSED | Spread: ", spread, " pts | Positions: ", currentPositions);
   
   return true;
}

//==================================================================
// CHECK SESSION FILTER
//==================================================================
bool CheckSessionFilter(MqlDateTime &dt, bool enabled, int startH, int startM, int endH, int endM)
{
   if(!enabled)
      return false;
   
   int currentMinutes = dt.hour * 60 + dt.min;
   int startMinutes = startH * 60 + startM;
   int endMinutes = endH * 60 + endM;
   
   if(startMinutes <= endMinutes)
      return (currentMinutes >= startMinutes && currentMinutes <= endMinutes);
   else  // crosses midnight
      return (currentMinutes >= startMinutes || currentMinutes <= endMinutes);
}

//==================================================================
// EXECUTE ENTRY
//==================================================================
void ExecuteEntry(int direction)
{
   // Calculate lot size
   double lotSize = CalculateLotSize();
   if(lotSize <= 0)
   {
      if(ip_VerboseLogs)
         Print("Entry FAILED: Invalid lot size calculated: ", lotSize);
      return;
   }
   
   // Normalize lot size
   lotSize = NormalizeLot(lotSize);
   
   // Calculate SL and TP
   double sl = 0, tp = 0;
   CalculateSLTP(direction, lotSize, sl, tp);
   
   // Prepare order
   ENUM_ORDER_TYPE orderType = (direction == 1) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   double price = (direction == 1) ? GetSymbolAsk() : GetSymbolBid();
   
   // Normalize SL/TP
   if(sl > 0)
      sl = NormalizePrice(sl);
   if(tp > 0)
      tp = NormalizePrice(tp);
   
   // Log order details
   if(ip_VerboseLogs)
   {
      Print("═══ EXECUTING ORDER ═══");
      Print("Type: ", (direction == 1 ? "BUY" : "SELL"), " | Lot: ", DoubleToString(lotSize, 2));
      Print("Price: ", DoubleToString(price, GetSymbolDigits()), " | SL: ", (sl > 0 ? DoubleToString(sl, GetSymbolDigits()) : "None"), 
            " | TP: ", (tp > 0 ? DoubleToString(tp, GetSymbolDigits()) : "None"));
   }
   
   // Execute order
   ulong ticket = SendMarketOrder(orderType, lotSize, price, sl, tp, "ST_VWAP_EA");
   if(ticket > 0)
   {
      g_dailyTrades++;
      
      // Register ticket for Enhanced Smart Trailing
      ST_RegisterTicket(ticket);
      
      if(ip_VerboseLogs)
         Print("Daily trades count: ", g_dailyTrades, " | Position registered for smart trailing");
   }
   else
   {
      if(ip_VerboseLogs)
         Print("Order execution FAILED after all attempts");
   }
}

//==================================================================
// CALCULATE LOT SIZE
//==================================================================
double CalculateLotSize()
{
   if(!ip_DynamicLots)
      return ip_FixedLot;
   
   // Dynamic lot sizing based on risk percentage
   double equity = GetAccountEquity();
   double riskAmount = equity * (ip_RiskPct / 100.0);
   
   // Calculate lot size based on SL in points
   double slPoints = RSLTP_Points_SL;
   if(slPoints <= 0)
      return ip_FixedLot;  // Fallback to fixed lot
   
   double tickValue = GetSymbolTickValue();
   double tickSize = GetSymbolTickSize();
   double point = GetSymbolPoint();
   
   double slDistance = slPoints * point;
   double moneyPerLot = (slDistance / tickSize) * tickValue;
   
   if(moneyPerLot <= 0)
      return ip_FixedLot;
   
   double lotSize = riskAmount / moneyPerLot;
   
   return lotSize;
}

//==================================================================
// CALCULATE SL/TP
//==================================================================
void CalculateSLTP(int direction, double lotSize, double &sl, double &tp)
{
   sl = 0;
   tp = 0;
   
   double price = (direction == 1) ? GetSymbolAsk() : GetSymbolBid();
   double point = GetSymbolPoint();
   
   if(RSLTP_UseMoneyTargets)
   {
      // Money-based SL/TP
      double tickValue = GetSymbolTickValue();
      double tickSize = GetSymbolTickSize();
      
      if(tickValue > 0 && lotSize > 0)
      {
         // SL in price distance
         if(RSLTP_Money_SL_Amount > 0)
         {
            double slMoney = RSLTP_Money_SL_Amount;
            double slDistance = (slMoney / (tickValue * lotSize)) * tickSize;
            sl = (direction == 1) ? (price - slDistance) : (price + slDistance);
         }
         
         // TP in price distance
         if(RSLTP_Money_TP_Amount > 0)
         {
            double tpMoney = RSLTP_Money_TP_Amount;
            double tpDistance = (tpMoney / (tickValue * lotSize)) * tickSize;
            tp = (direction == 1) ? (price + tpDistance) : (price - tpDistance);
         }
      }
   }
   else
   {
      // Points-based SL/TP
      if(RSLTP_Points_SL > 0)
      {
         double slDistance = RSLTP_Points_SL * point;
         sl = (direction == 1) ? (price - slDistance) : (price + slDistance);
      }
      
      if(RSLTP_Points_TP > 0)
      {
         double tpDistance = RSLTP_Points_TP * point;
         tp = (direction == 1) ? (price + tpDistance) : (price - tpDistance);
      }
   }
   
   // Validate SL/TP levels
   long stopsLevel = GetSymbolStopsLevel();
   double minStopLevel = stopsLevel * point;
   
   if(sl > 0)
   {
      double slDist = MathAbs(price - sl);
      if(slDist < minStopLevel)
         sl = 0;  // Invalid SL
   }
   
   if(tp > 0)
   {
      double tpDist = MathAbs(price - tp);
      if(tpDist < minStopLevel)
         tp = 0;  // Invalid TP
   }
}

//==================================================================
// UPDATE DAILY TRACKING
//==================================================================
void UpdateDailyTracking()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   datetime today = StringToTime(StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day));
   
   // New day detected
   if(today != g_currentDay)
   {
      if(ip_VerboseLogs && g_currentDay > 0)
      {
         Print("═══ NEW DAY ═══ | Previous day trades: ", g_dailyTrades, 
               " | Profit: $", DoubleToString(g_dailyProfit, 2));
      }
      
      g_currentDay = today;
      g_dailyTrades = 0;
      g_dailyProfit = 0.0;
      g_sessionStartBalance = GetAccountBalance();
   }
   
   // Calculate daily profit
   HistorySelect(g_currentDay, TimeCurrent() + 86400);
   
   double profit = 0.0;
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket > 0)
      {
         if(HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol &&
            HistoryDealGetInteger(ticket, DEAL_MAGIC) == MagicNumber &&
            HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
         {
            profit += HistoryDealGetDouble(ticket, DEAL_PROFIT);
            profit += HistoryDealGetDouble(ticket, DEAL_SWAP);
            profit += HistoryDealGetDouble(ticket, DEAL_COMMISSION);
         }
      }
   }
   
   g_dailyProfit = profit;
   
   // Update overall profit
   g_overallProfit = GetAccountBalance() - g_startingBalance;
}
