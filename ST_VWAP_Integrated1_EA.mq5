//+------------------------------------------------------------------+
//|                                                     ST VWAP EA   |
//| Uses ST_VWAP_Integrated1 indicator signals for trade execution. |
//+------------------------------------------------------------------+
#property strict

#ifndef SYMBOL_FILLING_FOK
#define SYMBOL_FILLING_FOK   1
#endif
#ifndef SYMBOL_FILLING_IOC
#define SYMBOL_FILLING_IOC   2
#endif
#ifndef SYMBOL_FILLING_RETURN
#define SYMBOL_FILLING_RETURN 4
#endif
#property copyright ""
#property link      ""
#property version   "1.0"
#property description "Expert Advisor for ST_VWAP_Integrated1 indicator"



//--- Enumerations ---------------------------------------------------
enum EntryModeType
{
   EM_IMMEDIATE = 0,
   EM_DELAY_THIS_TF = 1,
   EM_DELAY_CUSTOM_TF = 2
};

enum EntryRepeatType
{
   ERT_WAIT_FOR_CLOSE = 0,
   ERT_SINGLE_PER_SIGNAL = 1
};

//--- Indicator parameter inputs ------------------------------------
input group "=== SuperTrend Settings ==="
input int      ST_ATRPeriod        = 10;
input double   ST_Multiplier       = 3.0;
input ENUM_APPLIED_PRICE ST_Price  = PRICE_MEDIAN;
input bool     ST_Filling          = false;

input group "=== VWAP Settings ==="
input ENUM_APPLIED_PRICE VWAP_PriceMethod = PRICE_TYPICAL;
input double   VWAP_MinVolume      = 1.0;
input bool     VWAP_ShowWeekly     = true;
input bool     VWAP_ShowMonthly    = true;
input bool     VWAP_FilterDaily    = true;
input bool     VWAP_FilterWeekly   = false;
input bool     VWAP_FilterMonthly  = false;

input group "=== Anchored VWAP (Session) ==="
input bool     AVWAP_Session_Enable = false;
input int      AVWAP_Session_Hour   = 9;
input int      AVWAP_Session_Min    = 30;
input color    AVWAP_Session_Color  = clrMagenta;
input bool     AVWAP_Session_Filter = false;

input group "=== Visuals ==="
input bool     Show_VWAP_Line      = true;
input bool     Show_Arrows         = true;
input color    BullArrowColor      = clrWhite;
input color    BearArrowColor      = clrBlue;
input color    RejectArrowColor    = clrGray;
input int      ArrowCodeUp         = 233;
input int      ArrowCodeDn         = 234;

input group "=== Alerts ==="
input bool     Alert_Enabled         = true;
input bool     Alert_Popup           = true;
input bool     Alert_Sound           = true;
input string   Alert_SoundFile       = "alert.wav";
input bool     Alert_OnlyAccepted    = true;
input bool     Alert_Long            = true;
input bool     Alert_Short           = true;
input bool     Alert_OnlyInSession   = false;
input bool     Alert_OncePerBar      = true;
input int      Alert_CooldownSeconds = 10;
input string   Alert_Prefix          = "ST·VWAP";
input int      Alert_PointsFormat    = 1;
input string   Alert_UniqueID        = "";

input group "=== Misc ==="
input bool     Show_Debug          = false;
input bool     ResetStatsOnAttach  = true;

enum SessionMode
{
   SESSION_DASH_ONLY = 0,
   SESSION_SIGNALS_ONLY = 1,
   SESSION_BOTH = 2
};

input group "=== Dashboard & Session & Stats ==="
input bool     Dash_Enable          = true;
input int      Dash_FontSize        = 11;
input color    Dash_TextColor       = clrWhite;
input int      Dash_X               = 10;
input int      Dash_Y               = 20;
input color    Dash_BgColor         = clrBlack;
input color    Dash_BorderColor     = clrDimGray;
input int      Dash_Corner          = 0;
input int      Dash_Width           = 380;
input int      Dash_Height          = 200;
input int      MFE_LookaheadBars    = 24;
input bool     Session_Enable       = false;
input int      Session_StartHour    = 0;
input int      Session_StartMinute  = 0;
input int      Session_EndHour      = 23;
input int      Session_EndMinute    = 59;
input SessionMode Session_Mode      = SESSION_SIGNALS_ONLY;

input group "=== Dashboard Layout ==="
input string   Dash_Font            = "Consolas";
input int      Dash_LabelFontSize   = 9;
input int      Dash_ValueFontSize   = 9;
input int      Dash_LabelXOffset    = 10;
input int      Dash_ValueXOffset    = 200;
input color    Dash_AccentColor     = clrYellow;
input color    Dash_GoodColor       = clrLimeGreen;
input color    Dash_BadColor        = clrTomato;
input color    Dash_MutedColor      = clrGray;
input color    Dash_BullishColor    = clrBlue;
input color    Dash_BearishColor    = clrWhite;
input color    Dash_AvgColor        = clrOrange;
input int      Dash_SpacerLines     = 1;
input int      Dash_RowGapPixels    = 2;

//--- General Trading Settings --------------------------------------
input group "=== Trading Controls ==="
input ulong   MagicNumber                 = 567890;
input bool    ip_EnableEntry              = true;
input bool    ip_EnableBuy                = true;
input bool    ip_EnableSell               = true;
input bool    ip_OneTradeAtTime           = true;
input int     ip_MaxOpenTrades            = 1;
input bool    ip_VerboseLogs              = true;
input EntryModeType   ip_EntryMode        = EM_IMMEDIATE;
input EntryRepeatType ip_EntryRepeatType  = ERT_WAIT_FOR_CLOSE;
input int     ip_DelayBars                = 2;
input ENUM_TIMEFRAMES ip_DelayTF          = PERIOD_M5;

//--- Spread & Session Filters --------------------------------------
input int     ip_MaxSpreadPts             = 252;
input bool    ip_UseTimeFilter            = false;
input int     ip_BeginHour                = 15;
input int     ip_BeginMinute              = 0;
input int     ip_EndHour                  = 22;
input int     ip_EndMinute                = 59;
input bool    ip_UseSession1              = false;
input int     ip_Session1StartH           = 0;
input int     ip_Session1StartM           = 0;
input int     ip_Session1EndH             = 0;
input int     ip_Session1EndM             = 0;
input bool    ip_UseSession2              = false;
input int     ip_Session2StartH           = 0;
input int     ip_Session2StartM           = 0;
input int     ip_Session2EndH             = 0;
input int     ip_Session2EndM             = 0;
input bool    ip_UseSession3              = false;
input int     ip_Session3StartH           = 0;
input int     ip_Session3StartM           = 0;
input int     ip_Session3EndH             = 0;
input int     ip_Session3EndM             = 0;
input bool    ip_UseSession4              = false;
input int     ip_Session4StartH           = 0;
input int     ip_Session4StartM           = 0;
input int     ip_Session4EndH             = 0;
input int     ip_Session4EndM             = 0;

//--- Weekday Trading Controls --------------------------------------
input bool    ip_TradeSun                 = false;
input bool    ip_TradeMon                 = true;
input bool    ip_TradeTue                 = true;
input bool    ip_TradeWed                 = true;
input bool    ip_TradeThu                 = true;
input bool    ip_TradeFri                 = true;
input bool    ip_TradeSat                 = false;

//--- Lot sizing -----------------------------------------------------
input group "=== Risk Settings ==="
input bool    ip_DynamicLots              = false;
input double  ip_RiskPct                  = 1.0;
input double  ip_FixedLot                 = 2.0;

//--- Initial SL / TP ------------------------------------------------
input bool    RSLTP_UseMoneyTargets       = false;
input double  RSLTP_Money_SL_Amount       = 50.0;
input double  RSLTP_Money_TP_Amount       = 100.0;
input double  RSLTP_Points_SL             = 10000.0;
input double  RSLTP_Points_TP             = 10000.0;

//--- Daily risk & draw-down ----------------------------------------
input bool    DRisk_EnableMaxTradesPerDay  = false;
input int     DRisk_MaxTradesPerDay        = 10;
input bool    DRisk_EnableProfitCap        = false;
input double  DRisk_DailyProfitTarget      = 100.0;
input bool    DRisk_EnableLossCap          = false;
input double  DRisk_DailyLossLimit         = 100.0;
input bool    SDD_EnableDrawdownProtection = false;
input double  SDD_MaxDrawdownUSD           = 100.0;

//--- Overall risk controls -----------------------------------------
input bool    ORisk_EnableGlobalProfitTarget = false;
input double  ORisk_GlobalProfitTarget       = 1000.0;
input bool    ORisk_EnableGlobalLossLimit    = false;
input double  ORisk_GlobalLossLimit          = 1000.0;

//--- Internal structures -------------------------------------------
struct PendingSignal
{
   datetime signalBarTime;
   int      direction;
   int      barsRemaining;
   bool     useCustomTF;
   int      customShiftAtSignal;
};

//--- Global variables ----------------------------------------------
int       g_indicatorHandle = INVALID_HANDLE;
bool      g_isTester = false;
datetime  g_lastProcessedBar = 0;
PendingSignal g_pending[];

int       g_dailyTradeCount = 0;
double    g_dailyNetProfit = 0.0;
datetime  g_currentDay = 0;
double    g_dayStartEquity = 0.0;
bool      g_dailyLimitHit = false;
bool      g_drawdownHit = false;
bool      g_globalLimitHit = false;
double    g_globalNetProfit = 0.0;

datetime  g_lastEntrySignalTime = 0;
ENUM_ORDER_TYPE_FILLING g_fillingMode = ORDER_FILLING_FOK;
int       g_maxDeviationPts = 20;

//--- Utility logging ------------------------------------------------
void Log(const string text)
{
   if(ip_VerboseLogs)
      Print(text);
}

//--- Helper prototypes ---------------------------------------------
bool   InitializeIndicator();
void   ResetDailyStats();
void   CheckDayRollover();
void   UpdateRiskFlags();
int    CountOpenPositions(const int direction);
bool   IsWeekdayAllowed(const datetime t);
bool   IsWithinGeneralWindow(const datetime t);
bool   IsWithinSessions(const datetime t);
bool   CheckEntryPermissions(const int direction);
void   ProcessPendingSignals(const bool isNewBar);
void   AddPendingSignal(const datetime barTime,const int direction);
bool   ExecuteSignal(const int direction,const datetime signalTime);
bool   SendMarketOrder(const int direction,const double volume,const double price,const double sl,const double tp,const string comment);
double CalculateVolume(const int direction,double &slPoints,double &tpPoints);
void   ComputeSLTPPrices(const int direction,const double price,const double slPoints,const double tpPoints,double &sl,double &tp);
int    GetSignalDirection();
void   RemovePendingSignal(const int index);
bool   CustomDelayReady(const PendingSignal &ps);
bool   IsSpreadValid();
int    ExtractDayOfWeek(const datetime value);
int    ExtractMinutesOfDay(const datetime value);
int    DetermineVolumeDigits(const double step);
int    PrepareIndicatorParams(MqlParam &params[]);
void   ParamSetInt(MqlParam &param,const int value);
void   ParamSetDouble(MqlParam &param,const double value);
void   ParamSetBool(MqlParam &param,const bool value);
void   ParamSetString(MqlParam &param,const string value);
void   ParamSetColor(MqlParam &param,const color value);

void ParamSetInt(MqlParam &param,const int value)
{
   ZeroMemory(param);
   param.type = TYPE_INT;
   param.integer_value = (long)value;
}

void ParamSetDouble(MqlParam &param,const double value)
{
   ZeroMemory(param);
   param.type = TYPE_DOUBLE;
   param.double_value = value;
}

void ParamSetBool(MqlParam &param,const bool value)
{
   ZeroMemory(param);
   param.type = TYPE_BOOL;
   param.integer_value = value ? 1 : 0;
}

void ParamSetString(MqlParam &param,const string value)
{
   ZeroMemory(param);
   param.type = TYPE_STRING;
   param.string_value = value;
}

void ParamSetColor(MqlParam &param,const color value)
{
   ZeroMemory(param);
   param.type = TYPE_INT;
   param.integer_value = (long)value;
}

int DetermineVolumeDigits(const double step)
{
   if(step<=0.0)
      return(0);

   double scaled = step;
   int digits = 0;
   while(digits<8 && MathAbs(scaled - MathRound(scaled))>1e-8)
   {
      scaled *= 10.0;
      digits++;
   }
   return(digits);
}

int PrepareIndicatorParams(MqlParam &params[])
{
   ArrayResize(params,70);
   int idx = 0;

   ParamSetString(params[idx++],"ST_VWAP_Integrated1");

   ParamSetInt   (params[idx++],ST_ATRPeriod);
   ParamSetDouble(params[idx++],ST_Multiplier);
   ParamSetInt   (params[idx++],(int)ST_Price);
   ParamSetBool  (params[idx++],ST_Filling);

   ParamSetInt   (params[idx++],(int)VWAP_PriceMethod);
   ParamSetDouble(params[idx++],VWAP_MinVolume);
   ParamSetBool  (params[idx++],VWAP_ShowWeekly);
   ParamSetBool  (params[idx++],VWAP_ShowMonthly);
   ParamSetBool  (params[idx++],VWAP_FilterDaily);
   ParamSetBool  (params[idx++],VWAP_FilterWeekly);
   ParamSetBool  (params[idx++],VWAP_FilterMonthly);

   ParamSetBool  (params[idx++],AVWAP_Session_Enable);
   ParamSetInt   (params[idx++],AVWAP_Session_Hour);
   ParamSetInt   (params[idx++],AVWAP_Session_Min);
   ParamSetColor (params[idx++],AVWAP_Session_Color);
   ParamSetBool  (params[idx++],AVWAP_Session_Filter);

   ParamSetBool  (params[idx++],Show_VWAP_Line);
   ParamSetBool  (params[idx++],Show_Arrows);
   ParamSetColor (params[idx++],BullArrowColor);
   ParamSetColor (params[idx++],BearArrowColor);
   ParamSetColor (params[idx++],RejectArrowColor);
   ParamSetInt   (params[idx++],ArrowCodeUp);
   ParamSetInt   (params[idx++],ArrowCodeDn);

   ParamSetBool  (params[idx++],Alert_Enabled);
   ParamSetBool  (params[idx++],Alert_Popup);
   ParamSetBool  (params[idx++],Alert_Sound);
   ParamSetString(params[idx++],Alert_SoundFile);
   ParamSetBool  (params[idx++],Alert_OnlyAccepted);
   ParamSetBool  (params[idx++],Alert_Long);
   ParamSetBool  (params[idx++],Alert_Short);
   ParamSetBool  (params[idx++],Alert_OnlyInSession);
   ParamSetBool  (params[idx++],Alert_OncePerBar);
   ParamSetInt   (params[idx++],Alert_CooldownSeconds);
   ParamSetString(params[idx++],Alert_Prefix);
   ParamSetInt   (params[idx++],Alert_PointsFormat);
   ParamSetString(params[idx++],Alert_UniqueID);

   ParamSetBool  (params[idx++],Show_Debug);
   ParamSetBool  (params[idx++],ResetStatsOnAttach);

   ParamSetBool  (params[idx++],Dash_Enable);
   ParamSetInt   (params[idx++],Dash_FontSize);
   ParamSetColor (params[idx++],Dash_TextColor);
   ParamSetInt   (params[idx++],Dash_X);
   ParamSetInt   (params[idx++],Dash_Y);
   ParamSetColor (params[idx++],Dash_BgColor);
   ParamSetColor (params[idx++],Dash_BorderColor);
   ParamSetInt   (params[idx++],Dash_Corner);
   ParamSetInt   (params[idx++],Dash_Width);
   ParamSetInt   (params[idx++],Dash_Height);
   ParamSetInt   (params[idx++],MFE_LookaheadBars);
   ParamSetBool  (params[idx++],Session_Enable);
   ParamSetInt   (params[idx++],Session_StartHour);
   ParamSetInt   (params[idx++],Session_StartMinute);
   ParamSetInt   (params[idx++],Session_EndHour);
   ParamSetInt   (params[idx++],Session_EndMinute);
   ParamSetInt   (params[idx++],(int)Session_Mode);

   ParamSetString(params[idx++],Dash_Font);
   ParamSetInt   (params[idx++],Dash_LabelFontSize);
   ParamSetInt   (params[idx++],Dash_ValueFontSize);
   ParamSetInt   (params[idx++],Dash_LabelXOffset);
   ParamSetInt   (params[idx++],Dash_ValueXOffset);
   ParamSetColor (params[idx++],Dash_AccentColor);
   ParamSetColor (params[idx++],Dash_GoodColor);
   ParamSetColor (params[idx++],Dash_BadColor);
   ParamSetColor (params[idx++],Dash_MutedColor);
   ParamSetColor (params[idx++],Dash_BullishColor);
   ParamSetColor (params[idx++],Dash_BearishColor);
   ParamSetColor (params[idx++],Dash_AvgColor);
   ParamSetInt   (params[idx++],Dash_SpacerLines);
   ParamSetInt   (params[idx++],Dash_RowGapPixels);

   return(idx);
}

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   g_isTester = (MQLInfoInteger(MQL_TESTER)==1);

   long fillingFlags = SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE);
   if(fillingFlags==0)
      fillingFlags = SYMBOL_FILLING_FOK;

   if((fillingFlags & SYMBOL_FILLING_RETURN)!=0)
      g_fillingMode = ORDER_FILLING_RETURN;
   else if((fillingFlags & SYMBOL_FILLING_IOC)!=0)
      g_fillingMode = ORDER_FILLING_IOC;
   else
      g_fillingMode = ORDER_FILLING_FOK;

   if(!InitializeIndicator())
      return(INIT_FAILED);

   ResetDailyStats();
   UpdateRiskFlags();
   Log(StringFormat("ST VWAP EA initialized (%s)", g_isTester?"Tester":"Live/Forward"));
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(g_indicatorHandle!=INVALID_HANDLE)
   {
      IndicatorRelease(g_indicatorHandle);
      g_indicatorHandle = INVALID_HANDLE;
   }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
      return;

   if(g_indicatorHandle==INVALID_HANDLE)
      return;

   datetime currentBarTime = iTime(_Symbol,_Period,1);
   if(currentBarTime==0)
      return;

   if(g_lastProcessedBar!=currentBarTime)
   {
      g_lastProcessedBar = currentBarTime;
      CheckDayRollover();
      UpdateRiskFlags();
      ProcessPendingSignals(true);

      int signalDir = GetSignalDirection();
      if(signalDir!=0)
      {
         if(ip_EntryMode==EM_IMMEDIATE)
         {
            ExecuteSignal(signalDir,currentBarTime);
         }
         else
         {
            AddPendingSignal(currentBarTime,signalDir);
         }
      }
   }
   else
   {
      // Even if bar not advanced, process pending signals for custom TF timers
      ProcessPendingSignals(false);
   }
}

//+------------------------------------------------------------------+
//| Trade transaction handler                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
{
   if(trans.type!=TRADE_TRANSACTION_DEAL_ADD)
      return;

   ulong deal = trans.deal;
   if(!HistoryDealSelect(deal))
      return;

   string symbol = HistoryDealGetString(deal,DEAL_SYMBOL);
   long   dealMagic = HistoryDealGetInteger(deal,DEAL_MAGIC);
   if(symbol!=_Symbol || (ulong)dealMagic!=MagicNumber)
      return;

   int entry = (int)HistoryDealGetInteger(deal,DEAL_ENTRY);
   double profit = HistoryDealGetDouble(deal,DEAL_PROFIT);
   profit += HistoryDealGetDouble(deal,DEAL_SWAP);
   profit += HistoryDealGetDouble(deal,DEAL_COMMISSION);

   datetime dealTime = (datetime)HistoryDealGetInteger(deal,DEAL_TIME);

   if(entry==DEAL_ENTRY_IN)
   {
      datetime day = (datetime)StringToTime(TimeToString(dealTime,TIME_DATE));
      if(day!=g_currentDay)
      {
         g_currentDay = day;
         g_dailyTradeCount = 0;
         g_dailyNetProfit = 0.0;
         g_dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
         g_dailyLimitHit = false;
         g_drawdownHit = false;
      }
      g_dailyTradeCount++;
   }
   else if(entry==DEAL_ENTRY_OUT)
   {
      g_dailyNetProfit += profit;
      g_globalNetProfit += profit;
   }

   UpdateRiskFlags();
}

//+------------------------------------------------------------------+
//| Initialize indicator handle                                      |
//+------------------------------------------------------------------+
bool InitializeIndicator()
{
   if(g_indicatorHandle!=INVALID_HANDLE)
      IndicatorRelease(g_indicatorHandle);

   MqlParam params[];
   int total = PrepareIndicatorParams(params);

   ResetLastError();
   g_indicatorHandle = IndicatorCreate(_Symbol,(ENUM_TIMEFRAMES)_Period,IND_CUSTOM,total,params);
   int err = GetLastError();

   if(g_indicatorHandle==INVALID_HANDLE)
   {
      PrintFormat("Failed to create ST_VWAP_Integrated1 indicator. Error: %d (params=%d)",err,total);
      return(false);
   }

   return(true);
}

//+------------------------------------------------------------------+
//| Reset daily stats                                                |
//+------------------------------------------------------------------+
void ResetDailyStats()
{
   datetime now = TimeCurrent();
   g_currentDay = (datetime)StringToTime(TimeToString(now,TIME_DATE));
   g_dailyTradeCount = 0;
   g_dailyNetProfit = 0.0;
   g_dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_dailyLimitHit = false;
   g_drawdownHit = false;
   g_globalLimitHit = false;
   g_globalNetProfit = 0.0;
   ArrayResize(g_pending,0);
}

//+------------------------------------------------------------------+
//| Day rollover check                                               |
//+------------------------------------------------------------------+
void CheckDayRollover()
{
   datetime now = TimeCurrent();
   datetime today = (datetime)StringToTime(TimeToString(now,TIME_DATE));
   if(today!=g_currentDay)
   {
      g_currentDay = today;
      g_dailyTradeCount = 0;
      g_dailyNetProfit = 0.0;
      g_dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      g_dailyLimitHit = false;
      g_drawdownHit = false;
      g_lastEntrySignalTime = 0;
      Log("New trading day detected. Counters reset.");
   }
}

//+------------------------------------------------------------------+
//| Update risk limitation flags                                     |
//+------------------------------------------------------------------+
void UpdateRiskFlags()
{
   g_drawdownHit = false;
   g_dailyLimitHit = false;
   g_globalLimitHit = false;

   if(DRisk_EnableMaxTradesPerDay && DRisk_MaxTradesPerDay>0 && g_dailyTradeCount>=DRisk_MaxTradesPerDay)
      g_dailyLimitHit = true;

   if(DRisk_EnableProfitCap && DRisk_DailyProfitTarget>0 && g_dailyNetProfit>=DRisk_DailyProfitTarget)
      g_dailyLimitHit = true;

   if(DRisk_EnableLossCap && DRisk_DailyLossLimit>0 && (-g_dailyNetProfit)>=DRisk_DailyLossLimit)
      g_dailyLimitHit = true;

   if(SDD_EnableDrawdownProtection && SDD_MaxDrawdownUSD>0)
   {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      if(g_dayStartEquity - equity >= SDD_MaxDrawdownUSD)
         g_drawdownHit = true;
   }

   if(ORisk_EnableGlobalProfitTarget && ORisk_GlobalProfitTarget>0 && g_globalNetProfit>=ORisk_GlobalProfitTarget)
      g_globalLimitHit = true;

   if(ORisk_EnableGlobalLossLimit && ORisk_GlobalLossLimit>0 && (-g_globalNetProfit)>=ORisk_GlobalLossLimit)
      g_globalLimitHit = true;
}

//+------------------------------------------------------------------+
//| Count open positions for symbol/magic                            |
//+------------------------------------------------------------------+
int CountOpenPositions(const int direction)
{
   int total = 0;
   for(int i=PositionsTotal()-1;i>=0;--i)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL)!=_Symbol)
         continue;

      if(PositionGetInteger(POSITION_MAGIC)!=(long)MagicNumber)
         continue;

      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(direction>0 && type!=POSITION_TYPE_BUY)
         continue;
      if(direction<0 && type!=POSITION_TYPE_SELL)
         continue;

      total++;
   }
   return(total);
}

//+------------------------------------------------------------------+
//| Weekday check                                                    |
//+------------------------------------------------------------------+
bool IsWeekdayAllowed(const datetime t)
{
   int day = ExtractDayOfWeek(t);
   switch(day)
   {
      case 0: return ip_TradeSun;
      case 1: return ip_TradeMon;
      case 2: return ip_TradeTue;
      case 3: return ip_TradeWed;
      case 4: return ip_TradeThu;
      case 5: return ip_TradeFri;
      case 6: return ip_TradeSat;
   }
   return(true);
}

//+------------------------------------------------------------------+
//| Time window check                                                |
//+------------------------------------------------------------------+
bool IsWithinGeneralWindow(const datetime t)
{
   if(!ip_UseTimeFilter)
      return(true);

   int begin = ip_BeginHour*60 + ip_BeginMinute;
   int end   = ip_EndHour*60 + ip_EndMinute;
   int minutes = ExtractMinutesOfDay(t);

   if(begin<=end)
      return(minutes>=begin && minutes<=end);
   else
      return(minutes>=begin || minutes<=end);
}

//+------------------------------------------------------------------+
//| Session windows                                                  |
//+------------------------------------------------------------------+
bool IsWithinSessions(const datetime t)
{
   bool anySession = ip_UseSession1 || ip_UseSession2 || ip_UseSession3 || ip_UseSession4;
   if(!anySession)
      return(true);

   int minutes = ExtractMinutesOfDay(t);

   if(ip_UseSession1)
   {
      int start = ip_Session1StartH*60 + ip_Session1StartM;
      int end   = ip_Session1EndH*60 + ip_Session1EndM;
      if(start<=end)
      {
         if(minutes>=start && minutes<=end) return(true);
      }
      else
      {
         if(minutes>=start || minutes<=end) return(true);
      }
   }

   if(ip_UseSession2)
   {
      int start = ip_Session2StartH*60 + ip_Session2StartM;
      int end   = ip_Session2EndH*60 + ip_Session2EndM;
      if(start<=end)
      {
         if(minutes>=start && minutes<=end) return(true);
      }
      else
      {
         if(minutes>=start || minutes<=end) return(true);
      }
   }

   if(ip_UseSession3)
   {
      int start = ip_Session3StartH*60 + ip_Session3StartM;
      int end   = ip_Session3EndH*60 + ip_Session3EndM;
      if(start<=end)
      {
         if(minutes>=start && minutes<=end) return(true);
      }
      else
      {
         if(minutes>=start || minutes<=end) return(true);
      }
   }

   if(ip_UseSession4)
   {
      int start = ip_Session4StartH*60 + ip_Session4StartM;
      int end   = ip_Session4EndH*60 + ip_Session4EndM;
      if(start<=end)
      {
         if(minutes>=start && minutes<=end) return(true);
      }
      else
      {
         if(minutes>=start || minutes<=end) return(true);
      }
   }

   return(false);
}

int ExtractDayOfWeek(const datetime value)
{
   MqlDateTime dt;
   if(TimeToStruct(value,dt))
      return dt.day_of_week;
   return 0;
}

int ExtractMinutesOfDay(const datetime value)
{
   MqlDateTime dt;
   if(TimeToStruct(value,dt))
      return dt.hour*60 + dt.min;
   return 0;
}

//+------------------------------------------------------------------+
//| Validate spread                                                  |
//+------------------------------------------------------------------+
bool IsSpreadValid()
{
   if(ip_MaxSpreadPts<=0)
      return(true);

   long spread = SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
   if(spread==0)
      spread = (long)MathRound((SymbolInfoDouble(_Symbol,SYMBOL_ASK) - SymbolInfoDouble(_Symbol,SYMBOL_BID))/_Point);

   return(spread<=ip_MaxSpreadPts);
}

//+------------------------------------------------------------------+
//| Check entry permissions                                          |
//+------------------------------------------------------------------+
bool CheckEntryPermissions(const int direction)
{
   if(!ip_EnableEntry)
      return(false);

   if(direction>0 && !ip_EnableBuy)
      return(false);

   if(direction<0 && !ip_EnableSell)
      return(false);

   if(g_dailyLimitHit || g_drawdownHit || g_globalLimitHit)
      return(false);

   datetime now = TimeCurrent();
   if(!IsWeekdayAllowed(now))
      return(false);

   if(!IsWithinGeneralWindow(now))
      return(false);

   if(!IsWithinSessions(now))
      return(false);

   if(!IsSpreadValid())
      return(false);

   int openAll = CountOpenPositions(0);
   if(ip_OneTradeAtTime && openAll>0)
      return(false);

   if(ip_MaxOpenTrades>0 && openAll>=ip_MaxOpenTrades)
      return(false);

   if(ip_EntryRepeatType==ERT_WAIT_FOR_CLOSE)
   {
      int sameDir = CountOpenPositions(direction);
      if(sameDir>0)
         return(false);
   }

   return(true);
}

//+------------------------------------------------------------------+
//| Process pending signals                                          |
//+------------------------------------------------------------------+
void ProcessPendingSignals(const bool isNewBar)
{
   if(ArraySize(g_pending)==0)
      return;

   bool changed = false;
   for(int i=0;i<ArraySize(g_pending);)
   {
      PendingSignal ps = g_pending[i];
      bool ready = false;

      if(ps.useCustomTF)
      {
         ready = CustomDelayReady(ps);
      }
      else
      {
         if(isNewBar && ps.barsRemaining>0)
         {
            ps.barsRemaining--;
            g_pending[i].barsRemaining = ps.barsRemaining;
         }
         if(ps.barsRemaining<=0)
            ready = true;
      }

      if(ready)
      {
         if(ExecuteSignal(ps.direction,ps.signalBarTime))
         {
            RemovePendingSignal(i);
            changed = true;
            continue;
         }
         else
         {
            RemovePendingSignal(i);
            changed = true;
            continue;
         }
      }

      i++;
   }

   if(changed)
      UpdateRiskFlags();
}

//+------------------------------------------------------------------+
//| Add signal to queue                                              |
//+------------------------------------------------------------------+
void AddPendingSignal(const datetime barTime,const int direction)
{
   PendingSignal ps;
   ps.signalBarTime = barTime;
   ps.direction = direction;
   ps.barsRemaining = ip_DelayBars;
   ps.useCustomTF = (ip_EntryMode==EM_DELAY_CUSTOM_TF);
   ps.customShiftAtSignal = -1;

   if(ip_EntryMode==EM_DELAY_THIS_TF)
   {
      if(ps.barsRemaining<1)
         ps.barsRemaining = 1;
   }
   else if(ip_EntryMode==EM_DELAY_CUSTOM_TF)
   {
      ps.barsRemaining = (ip_DelayBars<1)?1:ip_DelayBars;
      int shift = iBarShift(_Symbol,ip_DelayTF,barTime,true);
      ps.customShiftAtSignal = shift;
      if(shift==-1)
      {
         Log("Custom timeframe shift unavailable for signal. Skipping.");
         return;
      }
   }

   int sz = ArraySize(g_pending);
   ArrayResize(g_pending,sz+1);
   g_pending[sz] = ps;
   Log(StringFormat("Signal queued dir=%d at %s",direction,TimeToString(barTime,TIME_DATE|TIME_SECONDS)));
}

//+------------------------------------------------------------------+
//| Remove queued signal                                             |
//+------------------------------------------------------------------+
void RemovePendingSignal(const int index)
{
   int sz = ArraySize(g_pending);
   if(index<0 || index>=sz)
      return;

   for(int i=index;i<sz-1;i++)
      g_pending[i] = g_pending[i+1];

   ArrayResize(g_pending,sz-1);
}

//+------------------------------------------------------------------+
//| Custom timeframe delay ready                                     |
//+------------------------------------------------------------------+
bool CustomDelayReady(const PendingSignal &ps)
{
   if(ps.customShiftAtSignal<0)
      return(false);

   int currentShift = iBarShift(_Symbol,ip_DelayTF,TimeCurrent(),true);
   if(currentShift==-1)
      return(false);

   int barsElapsed = ps.customShiftAtSignal - currentShift;
   return(barsElapsed>=ip_DelayBars);
}

//+------------------------------------------------------------------+
//| Execute signal                                                   |
//+------------------------------------------------------------------+
bool ExecuteSignal(const int direction,const datetime signalTime)
{
   if(!CheckEntryPermissions(direction))
      return(false);

   if(ip_EntryRepeatType==ERT_WAIT_FOR_CLOSE && g_lastEntrySignalTime==signalTime)
      return(false);

   double slPoints = RSLTP_Points_SL;
   double tpPoints = RSLTP_Points_TP;
   double volume = CalculateVolume(direction,slPoints,tpPoints);
   if(volume<=0)
   {
      Log("Volume calculation failed. Signal ignored.");
      return(false);
   }

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick))
   {
      Log("Failed to get tick data. Signal ignored.");
      return(false);
   }

   double price = (direction>0)?tick.ask:tick.bid;
   double sl=0.0,tp=0.0;
   ComputeSLTPPrices(direction,price,slPoints,tpPoints,sl,tp);

   string comment = (direction>0)?"ST_VWAP buy":"ST_VWAP sell";
   if(!SendMarketOrder(direction,volume,price,sl,tp,comment))
      return(false);

   g_lastEntrySignalTime = signalTime;
   Log(StringFormat("Trade opened dir=%d lot=%.2f price=%.5f",direction,volume,price));
   return(true);
}

//+------------------------------------------------------------------+
//| Send market order without external trade classes                 |
//+------------------------------------------------------------------+
bool SendMarketOrder(const int direction,const double volume,const double price,const double sl,const double tp,const string comment)
{
   MqlTradeRequest request;
   MqlTradeResult  result;
   ZeroMemory(request);
   ZeroMemory(result);

   request.action      = TRADE_ACTION_DEAL;
   request.symbol      = _Symbol;
   request.volume      = volume;
   request.magic       = MagicNumber;
   request.deviation   = g_maxDeviationPts;
   request.type_filling= g_fillingMode;
   request.comment     = comment;

   if(direction>0)
   {
      request.type  = ORDER_TYPE_BUY;
      request.price = (price>0.0)?price:SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   }
   else
   {
      request.type  = ORDER_TYPE_SELL;
      request.price = (price>0.0)?price:SymbolInfoDouble(_Symbol,SYMBOL_BID);
   }

   if(sl>0.0)
      request.sl = sl;
   if(tp>0.0)
      request.tp = tp;

   if(!OrderSend(request,result))
   {
      PrintFormat("OrderSend failed dir=%d error=%d",direction,GetLastError());
      return(false);
   }

   if(result.retcode!=TRADE_RETCODE_DONE && result.retcode!=TRADE_RETCODE_DONE_PARTIAL)
   {
      PrintFormat("OrderSend rejected dir=%d retcode=%d comment=%s",direction,result.retcode,result.comment);
      return(false);
   }

   return(true);
}

//+------------------------------------------------------------------+
//| Calculate volume                                                 |
//+------------------------------------------------------------------+
double CalculateVolume(const int direction,double &slPoints,double &tpPoints)
{
   double minLot = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double step   = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);

   if(minLot<=0 || step<=0)
      return(0.0);

   double lot = ip_FixedLot;
   if(ip_DynamicLots)
   {
      if(RSLTP_UseMoneyTargets)
      {
         // convert money-based SL/TP to points based on selected lot after calculation
      }

      double riskPct = MathMax(ip_RiskPct,0.0);
      if(riskPct<=0.0)
         lot = minLot;
      else
      {
         double slPts = (RSLTP_UseMoneyTargets)?RSLTP_Points_SL:slPoints;
         if(slPts<=0.0)
            slPts = RSLTP_Points_SL;
         if(slPts<=0.0)
            slPts = 100.0;

         double riskMoney = AccountInfoDouble(ACCOUNT_EQUITY) * (riskPct/100.0);
         double tickValue = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
         double tickSize  = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
         if(tickValue<=0 || tickSize<=0)
            return(0.0);

         double priceDiff = slPts * _Point;
         if(priceDiff<=0)
            priceDiff = step * _Point;

         double moneyPerLot = (priceDiff/tickSize) * tickValue;
         if(moneyPerLot<=0)
            lot = minLot;
         else
            lot = riskMoney / moneyPerLot;
      }
   }

   lot = MathMax(lot,minLot);
   if(maxLot>0)
      lot = MathMin(lot,maxLot);

   int volDigits = DetermineVolumeDigits(step);
   lot = MathFloor(lot/step)*step;
   lot = NormalizeDouble(lot,volDigits);
   lot = MathMax(lot,minLot);

   if(RSLTP_UseMoneyTargets)
   {
      double tickValue = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
      double tickSize  = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
      if(tickValue<=0 || tickSize<=0)
         return(0.0);

      if(RSLTP_Money_SL_Amount>0.0)
      {
         double priceDiff = (RSLTP_Money_SL_Amount/(lot*tickValue))*tickSize;
         slPoints = priceDiff/_Point;
      }
      if(RSLTP_Money_TP_Amount>0.0)
      {
         double priceDiff = (RSLTP_Money_TP_Amount/(lot*tickValue))*tickSize;
         tpPoints = priceDiff/_Point;
      }
   }

   return(lot);
}

//+------------------------------------------------------------------+
//| Compute SL/TP prices                                             |
//+------------------------------------------------------------------+
void ComputeSLTPPrices(const int direction,const double price,const double slPoints,const double tpPoints,double &sl,double &tp)
{
   sl = 0.0;
   tp = 0.0;

   if(slPoints>0.0)
   {
      double slPrice = (direction>0)?(price - slPoints*_Point):(price + slPoints*_Point);
      sl = NormalizeDouble(slPrice,_Digits);
   }

   if(tpPoints>0.0)
   {
      double tpPrice = (direction>0)?(price + tpPoints*_Point):(price - tpPoints*_Point);
      tp = NormalizeDouble(tpPrice,_Digits);
   }
}

//+------------------------------------------------------------------+
//| Obtain latest signal direction                                   |
//+------------------------------------------------------------------+
int GetSignalDirection()
{
   if(BarsCalculated(g_indicatorHandle)<=0)
      return(0);

   double buffer[];
   if(CopyBuffer(g_indicatorHandle,6,1,1,buffer)<=0)
   {
      Print("CopyBuffer failed. Error: ",GetLastError());
      return(0);
   }

   double val = buffer[0];
   if(val>0.5)
      return(1);
   if(val<-0.5)
      return(-1);
   return(0);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
