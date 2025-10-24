//+------------------------------------------------------------------+
//|                          ST_VWAP_Integrated1.mq5                 |
//|  Integrated SuperTrend + Daily VWAP with filtered trade signals  |
//+------------------------------------------------------------------+
//|  VERSION: 1.1 EA-Ready                                           |
//|  DATE: 2025-10-18                                                |
//|                                                                  |
//|  EA INTEGRATION CONTRACT                                         |
//|  ─────────────────────────────────────────────────────────────  |
//|                                                                  |
//|  Signal Buffer Index: 6 (SignalBuf)                              |
//|  Buffer Type: INDICATOR_CALCULATIONS (DRAW_NONE)                 |
//|                                                                  |
//|  Signal Values:                                                  |
//|    +1  = BUY signal (bullish SuperTrend flip, filters passed)    |
//|    -1  = SELL signal (bearish SuperTrend flip, filters passed)   |
//|     0  = No signal (no flip, or filters rejected the flip)       |
//|                                                                  |
//|  Signal Rules:                                                   |
//|    • Signals are written ONLY on CLOSED bars (never bar[0])      |
//|    • Once written, signal values NEVER change (non-repainting)   |
//|    • Decision uses only completed data up to bar[i-1]            |
//|    • Warm-up period: ST_ATRPeriod + 2 bars minimum              |
//|    • Strategy Tester: stats reset at test start date            |
//|                                                                  |
//|  Filter Logic (all enabled filters use AND logic):               |
//|    • VWAP_FilterDaily: price vs Daily VWAP                       |
//|    • VWAP_FilterWeekly: price vs Weekly VWAP                     |
//|    • VWAP_FilterMonthly: price vs Monthly VWAP                   |
//|    • AVWAP_Session_Filter: price vs Session AVWAP                |
//|    • Session_Enable + Session_Mode: time-based gating            |
//|                                                                  |
//|  VWAP Anchor Definitions:                                        |
//|    • Daily: midnight (00:00) each day                            |
//|    • Weekly: Sunday midnight (00:00)                             |
//|    • Monthly: first day of month at midnight (00:00)             |
//|    • Session AVWAP: user-defined hour:minute (AVWAP_Session_*)   |
//|                                                                  |
//|  Inputs Affecting Signals (NEVER change order/type/meaning):     |
//|    • ST_ATRPeriod, ST_Multiplier, ST_Price                       |
//|    • VWAP_PriceMethod, VWAP_MinVolume                            |
//|    • VWAP_FilterDaily, VWAP_FilterWeekly, VWAP_FilterMonthly    |
//|    • AVWAP_Session_Enable, AVWAP_Session_Hour/Min/_Filter       |
//|    • Session_Enable, Session_Start*/End*, Session_Mode           |
//|                                                                  |
//|  Visual-Only Inputs (do NOT affect signal buffer):               |
//|    • Show_VWAP_Line, VWAP_ShowWeekly, VWAP_ShowMonthly          |
//|    • Show_Arrows, Arrow colors/codes, ST_Filling                 |
//|    • Alert_*, Dash_*, All dashboard/session display settings     |
//|                                                                  |
//|  EA Usage Example:                                               |
//|    double signal[];                                              |
//|    ArraySetAsSeries(signal, true);                               |
//|    CopyBuffer(handle, 6, 1, 1, signal); // index 6 = SignalBuf   |
//|    if(signal[0] == 1.0)  { /* BUY */  }                          |
//|    if(signal[0] == -1.0) { /* SELL */ }                          |
//|                                                                  |
//|  Performance & Stability:                                        |
//|    • All buffers use numeric values (no NaN/INF)                 |
//|    • Plot buffers use EMPTY_VALUE when data not ready            |
//|    • Signal buffer uses 0 when data not ready (never EMPTY_VALUE)|
//|    • Deterministic VWAP calculations (same input = same output)  |
//|    • Efficient cumulative TPV/Volume tracking                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property strict
#property indicator_chart_window
#property indicator_plots   6
#property indicator_buffers 19

//--- Plot 1 : SuperTrend colour-line
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrGreen, clrRed
#property indicator_width1  2
#property indicator_label1  "SuperTrend"

//--- Plot 2 : VWAP daily line
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrYellow
#property indicator_width2  2
#property indicator_label2  "VWAP Daily"

//--- Plot 3 : VWAP Weekly line
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrBlue
#property indicator_width3  2
#property indicator_style3  STYLE_DASH
#property indicator_label3  "VWAP Weekly"

//--- Plot 4 : VWAP Monthly line
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrGreen
#property indicator_width4  2
#property indicator_style4  STYLE_DASH
#property indicator_label4  "VWAP Monthly"

//--- Plot 5 : AVWAP Session line
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrMagenta
#property indicator_width5  2
#property indicator_style5  STYLE_DOT
#property indicator_label5  "AVWAP Session"

//--- Plot 6 : Invisible signal buffer (not drawn)
#property indicator_type6   DRAW_NONE
#property indicator_label6  "Signal"

//==================================================================
// INPUTS
//==================================================================
input group "=== SuperTrend Settings ==="
input int      ST_ATRPeriod        = 10;
input double   ST_Multiplier       = 3.0;
input ENUM_APPLIED_PRICE ST_Price  = PRICE_MEDIAN;
input bool     ST_Filling          = false;

input group "=== VWAP Settings ==="
input ENUM_APPLIED_PRICE VWAP_PriceMethod = PRICE_TYPICAL;
input double   VWAP_MinVolume      = 1.0;
input bool     VWAP_ShowWeekly      = true;
input bool     VWAP_ShowMonthly     = true;
input bool     VWAP_FilterDaily     = true;   // use Daily VWAP for signal filtering
input bool     VWAP_FilterWeekly    = false;  // use Weekly VWAP for signal filtering
input bool     VWAP_FilterMonthly   = false;  // use Monthly VWAP for signal filtering

input group "=== Anchored VWAP (Session) ==="
input bool     AVWAP_Session_Enable = false;
input int      AVWAP_Session_Hour   = 9;
input int      AVWAP_Session_Min    = 30;
input color    AVWAP_Session_Color  = clrMagenta;
input bool     AVWAP_Session_Filter = false;  // use session AVWAP for signal filtering

input group "=== Visuals ==="
input bool     Show_VWAP_Line      = true;
input bool     Show_Arrows         = true;
input color    BullArrowColor      = clrWhite;    // bullish valid
input color    BearArrowColor      = clrBlue;     // bearish valid
input color    RejectArrowColor    = clrGray;     // filtered
input int      ArrowCodeUp         = 233;
input int      ArrowCodeDn         = 234;

// INSERT NEW ALERT INPUTS GROUP ---------------------------
input group "=== Alerts ==="
input bool   Alert_Enabled         = true;
input bool   Alert_Popup           = true;
input bool   Alert_Sound           = true;
input string Alert_SoundFile       = "alert.wav";
input bool   Alert_OnlyAccepted    = true;
input bool   Alert_Long            = true;
input bool   Alert_Short           = true;
input bool   Alert_OnlyInSession   = false;
input bool   Alert_OncePerBar      = true;
input int    Alert_CooldownSeconds = 10;
input string Alert_Prefix          = "ST·VWAP";
input int    Alert_PointsFormat    = 1;
input string Alert_UniqueID        = "";
// ---------------------------------------------------------

input group "=== Misc ==="
input bool     Show_Debug          = false;
input bool     ResetStatsOnAttach  = true;       // clear cumulative stats when indicator attaches

input group "=== Dashboard & Session & Stats ==="
input bool     Dash_Enable          = true;
input int      Dash_FontSize        = 11;
input color    Dash_TextColor       = clrWhite;
input int      Dash_X               = 10;
input int      Dash_Y               = 20;
input color    Dash_BgColor         = clrBlack;
input color    Dash_BorderColor     = clrDimGray;
input int      Dash_Corner          = 0; // 0=UL 1=UR 2=LL 3=LR
input int      Dash_Width           = 380;
input int      Dash_Height          = 200;

// Performance aggregation display mode
enum PerfAggMode
{
   PERF_AVG = 0,     // Show averages only
   PERF_MED = 1,     // Show medians only
   PERF_BOTH = 2     // Show both average and median
};
input PerfAggMode  Dash_PerfAggMode = PERF_AVG;   // Performance Aggregation: Avg / Med / Both

input bool     Session_Enable       = false;
input int      Session_StartHour    = 0;
input int      Session_StartMinute  = 0;
input int      Session_EndHour      = 23;
input int      Session_EndMinute    = 59;

// Session Mode (like first code)
enum SessionMode
{
   SESSION_DASH_ONLY = 0,
   SESSION_SIGNALS_ONLY = 1,
   SESSION_BOTH = 2
};
input SessionMode Session_Mode = SESSION_SIGNALS_ONLY;

// Dashboard layout (like first code)
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
input color    Dash_BullishColor    = clrBlue;   // matches bullish arrow by default
input color    Dash_BearishColor    = clrWhite;  // matches bearish arrow by default
input color    Dash_AvgColor        = clrOrange;  // color for "All" averages
input int      Dash_SpacerLines     = 1; // number of line-heights to skip for blank spacer rows
input int      Dash_RowGapPixels    = 2; // extra pixels added between every dashboard row

//==================================================================
// BUFFERS
//==================================================================
// visible
double SuperTrendBuf[];
double ST_ColorBuf[];
double VWAPBuf[];
double VWAPWeeklyBuf[];
double VWAPMonthlyBuf[];
double AVWAPSessionBuf[];
// calculations
double ATRBuf[];
double UpBuf[];
double DownBuf[];
double TrendBuf[];
// signal buffer for EA (1 / -1 / 0) -> NOT drawn
double SignalBuf[];
// cum TPV & Volume for VWAP per-day/week/month
double VWAP_TPVBuf[];
double VWAP_VolBuf[];
double VWAPWeek_TPVBuf[];
double VWAPWeek_VolBuf[];
double VWAPMonth_TPVBuf[];
double VWAPMonth_VolBuf[];
double AVWAPSess_TPVBuf[];
double AVWAPSess_VolBuf[];

// handles
int atrHandle = INVALID_HANDLE;

// remember last flip bar so we don't draw duplicate arrows
datetime g_lastFlipTime = 0;

// (globals removed – VWAP is now calculated per-bar purely inside OnCalculate)

// remember last trend direction to avoid duplicate arrows
int    g_lastTrendDir = 0; // 1 or -1 of last arrow issued

// alert gating (disable during first historical pass)
bool   g_alertsActive = false;

// ADD ALERT STATE -----------------------------------------
datetime  g_lastAlertTime = 0;   // TimeCurrent() of last alert
datetime  g_lastAlertBar  = 0;   // time[i] of last alerted bar
datetime  g_initialLastBar  = 0;   // bar when indicator attached (for startup suppression)
// ---------------------------------------------------------

// === CUMULATIVE STATISTICS =====================================
// lifetime MFE sums & counts
double g_sumMFEBlue  = 0.0;
double g_sumMFEWhite = 0.0;
int    g_cntBlue     = 0;
int    g_cntWhite    = 0;

// lifetime MAE sums (drawdown)
double g_sumMAEBlue  = 0.0;
double g_sumMAEWhite = 0.0;

// individual MFE/MAE values for median calculation
double g_mfeBlueVals[];
double g_mfeWhiteVals[];
double g_maeBlueVals[];
double g_maeWhiteVals[];

// lifetime flip counters
int    g_totalFlips   = 0;
int    g_accepted     = 0;
int    g_rejected     = 0;
int    g_bullAccepted = 0;
int    g_bearAccepted = 0;

// track index of last accepted bar for "bars ago" metric
int    g_lastAcceptedBar = -1;

// stores max favourable excursion (points) of the *previous* accepted signal
double g_lastMFEPoints = 0.0;
double g_lastMAEPoints = 0.0;
// === BACKTEST SUPPORT ============================================
// when running in strategy tester we want statistics to start at the
// user-defined "Start" date (i.e. ignore prior history that MT5 loads
// for indicator warm-up). We detect tester mode and remember the last
// bar time available on the very first tick then zero all counters.
bool     g_isTesting    = false;
datetime g_btCutoffTime = 0;  // bars with time <= this are ignored for arrows / stats

// active segment for ongoing MFE measurement
struct ActiveSegment
{
   int    dir;        // 1 = blue (bullish), -1 = white (bearish)
   int    startBar;   // bar index where segment started
   double entryPrice; // entry price (close of flip bar)
   double maxMFE;     // max favourable excursion in points
   int    age;        // bars since start
   double maxMAE;     // max adverse excursion in points
};
ActiveSegment g_seg = {0,0,0.0,0.0,0.0,0};

// --- DASHBOARD helpers/globals ------------------------------------
#define DASH_OBJ_BG   "STVWAP_DASH_BG"
#define DASH_OBJ_TTL  "STVWAP_DASH_TITLE"
#define DASH_OBJ_LBL  "STVWAP_DASH_LABEL_"
#define DASH_OBJ_VAL  "STVWAP_DASH_VALUE_"

bool g_dashCreated=false;

// dashboard data container
struct DashStats{
   // counts
   int    totalSignals;
   int    bullishSignals;
   int    bearishSignals;
   int    acceptedSignals;
   int    rejectedSignals;

   // performance - averages
   double avgMFEBlue;
   double avgMFEWhite;
   double avgMFEAll;
   double avgMAEBlue;
   double avgMAEWhite;
   double avgMAEAll;
   
   // performance - medians
   double medMFEBlue;
   double medMFEWhite;
   double medMFEAll;
   double medMAEBlue;
   double medMAEWhite;
   double medMAEAll;
   
   // last values
   double lastMFE;
   double lastMAE;

   // recency
   int    lastSignalBars;  // bars since last accepted signal
   string lastSignalTime;  // timestamp of last flip (accepted/rejected)

   // now values
   double curPrice;
   double curST;
   double curVWAP;

   // session
   bool   inSession;
   string sessionText;
   string windowStatus;    // ACTIVE / OUT OF WINDOW
};

// create/refresh/remove dashboard
void CreateDashboard();
void UpdateDashboard(const DashStats &ds);
void RemoveDashboard();

// helper - session rules like first code
bool IsInSession(datetime t);
bool ShouldGenerateSignals(datetime t);
bool ShouldUpdateDashboard(datetime t);

// ADD ALERT FORWARD DECLARATIONS --------------------------
string FormatAlert(int dir,double price,double vwap,double st,datetime barTime);
void   TryAlert(int dir,datetime barTime,double price,double vwap,double st,bool accepted);
// ---------------------------------------------------------

//==================================================================
// STATS (includes accepted/rejected & last flip time)
//==================================================================
struct StatsStruct{
   int    cntBlue;
   int    cntWhite;
   int    cntGray;
   double avgMFEBlue;
   double avgMFEWhite;
   double avgMFEAll;      // <<< NEW
   int    lastSignalBars; // bars since last accepted (SignalBuf!=0)

   int    totalFlips;
   int    accepted;
   int    rejected;
   int    bullAccepted;
   int    bearAccepted;
   string lastFlipTime;  // last flip (any)
};

//==================================================================
// MEDIAN CALCULATION HELPER
//==================================================================
double CalculateMedian(const double &arr[])
{
   int n = ArraySize(arr);
   if(n == 0) return 0.0;
   
   // Create a copy and sort it
   double sorted[];
   ArrayResize(sorted, n);
   ArrayCopy(sorted, arr);
   ArraySort(sorted);
   
   // Calculate median
   if(n % 2 == 1)
   {
      // Odd count: middle element
      return sorted[n / 2];
   }
   else
   {
      // Even count: average of two middle elements
      return (sorted[n / 2 - 1] + sorted[n / 2]) / 2.0;
   }
}

//==================================================================
// SESSION HELPERS
//==================================================================
// Check if datetime belongs to user session  (works for same-day & overnight)
bool IsInSession(datetime t)
{
   if(!Session_Enable) return(true);
   MqlDateTime dt; TimeToStruct(t,dt);
   int minutes = dt.hour*60+dt.min;
   int start   = Session_StartHour*60+Session_StartMinute;
   int endt    = Session_EndHour*60+Session_EndMinute;
   if(start<=endt) // same day window
      return(minutes>=start && minutes<endt);
   else            // window crosses midnight
      return(minutes>=start || minutes<endt);
}

// session gating (mirrors first code semantics)
bool ShouldGenerateSignals(datetime t)
{
   if(!Session_Enable) return true;
   bool inWin = IsInSession(t);
   return (Session_Mode==SESSION_DASH_ONLY) ||
          ((Session_Mode==SESSION_SIGNALS_ONLY) && inWin) ||
          ((Session_Mode==SESSION_BOTH) && inWin);
}
bool ShouldUpdateDashboard(datetime t)
{
   if(!Session_Enable) return true;
   bool inWin = IsInSession(t);
   return (Session_Mode==SESSION_SIGNALS_ONLY) ||
          ((Session_Mode==SESSION_DASH_ONLY) && inWin) ||
          ((Session_Mode==SESSION_BOTH) && inWin);
}

// ADD ALERT IMPLEMENTATIONS ===============================
string FormatAlert(int dir,double price,double vwap,double st,datetime barTime)
{
   string side = (dir==1 ? "LONG" : "SHORT");
   string symTf = StringFormat("%s %s", _Symbol, EnumToString((ENUM_TIMEFRAMES)_Period));
   string suffix = (StringLen(Alert_UniqueID)>0) ? Alert_UniqueID : "";
   string msg = StringFormat("%s%s  %s  %s @ %s ┃ VWAP:%s ┃ ST:%s ┃ %s",
                     Alert_Prefix,
                     suffix,
                     symTf,
                     side,
                     DoubleToString(price,Alert_PointsFormat),
                     DoubleToString(vwap,Alert_PointsFormat),
                     DoubleToString(st,Alert_PointsFormat),
                     TimeToString(barTime,TIME_MINUTES));
   return msg;
}

void TryAlert(int dir,datetime barTime,double price,double vwap,double st,bool accepted)
{
   // tester safety
   if(g_isTesting && barTime<=g_btCutoffTime) return;

   if(!g_alertsActive) return; // skip during initial history load

   if(!Alert_Enabled) return;
   if(Alert_OnlyAccepted && !accepted) return;
   if(dir==1 && !Alert_Long) return;
   if(dir==-1 && !Alert_Short) return;
   if(Alert_OnlyInSession && !IsInSession(barTime)) return;
   if(Alert_OncePerBar && barTime==g_lastAlertBar) return;
   if(TimeCurrent()-g_lastAlertTime < Alert_CooldownSeconds) return;

   string msg = FormatAlert(dir,price,vwap,st,barTime);

   if(Alert_Popup) Alert(msg);
   if(Alert_Sound) PlaySound(Alert_SoundFile);
   Print(msg);

   g_lastAlertTime = TimeCurrent();
   g_lastAlertBar  = barTime;
}
// =========================================================

//==================================================================
// INIT
//==================================================================
int OnInit()
{
   // validate
   if(ST_ATRPeriod < 1 || ST_Multiplier <= 0) return(INIT_PARAMETERS_INCORRECT);

   // ATR handle
   atrHandle = iATR(_Symbol,_Period,ST_ATRPeriod);
   if(atrHandle == INVALID_HANDLE) return(INIT_FAILED);

   // detect strategy tester
   g_isTesting = (bool)MQLInfoInteger(MQL_TESTER);

   // map buffers
   SetIndexBuffer(0,SuperTrendBuf, INDICATOR_DATA);
   SetIndexBuffer(1,ST_ColorBuf,   INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2,VWAPBuf,       INDICATOR_DATA);
   SetIndexBuffer(3,VWAPWeeklyBuf, INDICATOR_DATA);
   SetIndexBuffer(4,VWAPMonthlyBuf,INDICATOR_DATA);
   SetIndexBuffer(5,AVWAPSessionBuf,INDICATOR_DATA);
   SetIndexBuffer(6,SignalBuf,     INDICATOR_CALCULATIONS);
   SetIndexBuffer(7,ATRBuf,        INDICATOR_CALCULATIONS);
   SetIndexBuffer(8,UpBuf,         INDICATOR_CALCULATIONS);
   SetIndexBuffer(9,DownBuf,       INDICATOR_CALCULATIONS);
   SetIndexBuffer(10,TrendBuf,      INDICATOR_CALCULATIONS);
   SetIndexBuffer(11,VWAP_TPVBuf,    INDICATOR_CALCULATIONS);
   SetIndexBuffer(12,VWAP_VolBuf,    INDICATOR_CALCULATIONS);
   SetIndexBuffer(13,VWAPWeek_TPVBuf,INDICATOR_CALCULATIONS);
   SetIndexBuffer(14,VWAPWeek_VolBuf,INDICATOR_CALCULATIONS);
   SetIndexBuffer(15,VWAPMonth_TPVBuf,INDICATOR_CALCULATIONS);
   SetIndexBuffer(16,VWAPMonth_VolBuf,INDICATOR_CALCULATIONS);
   SetIndexBuffer(17,AVWAPSess_TPVBuf,INDICATOR_CALCULATIONS);
   SetIndexBuffer(18,AVWAPSess_VolBuf,INDICATOR_CALCULATIONS);

   PlotIndexSetInteger(2,PLOT_DRAW_TYPE, Show_VWAP_Line ? DRAW_LINE : DRAW_NONE);
   PlotIndexSetInteger(3,PLOT_DRAW_TYPE, VWAP_ShowWeekly ? DRAW_LINE : DRAW_NONE);
   PlotIndexSetInteger(4,PLOT_DRAW_TYPE, VWAP_ShowMonthly ? DRAW_LINE : DRAW_NONE);
   PlotIndexSetInteger(5,PLOT_DRAW_TYPE, AVWAP_Session_Enable ? DRAW_LINE : DRAW_NONE);
   PlotIndexSetInteger(5,PLOT_LINE_COLOR,0,AVWAP_Session_Color);
   IndicatorSetInteger(INDICATOR_DIGITS,_Digits);

   g_dashCreated=false;

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int r)
{
   if(atrHandle!=INVALID_HANDLE) IndicatorRelease(atrHandle);
   RemoveDashboard();
}

//==================================================================
// PRICE helpers
//==================================================================
inline double BasePrice(int i,const double& o[],const double& h[],const double& l[],const double& c[])
{
   switch(ST_Price)
   {
      case PRICE_OPEN:     return o[i];
      case PRICE_HIGH:     return h[i];
      case PRICE_LOW:      return l[i];
      case PRICE_CLOSE:    return c[i];
      case PRICE_MEDIAN:   return (h[i]+l[i])*0.5;
      case PRICE_TYPICAL:  return (h[i]+l[i]+c[i])/3.0;
      case PRICE_WEIGHTED: return (h[i]+l[i]+2.0*c[i])/4.0;
      default:             return c[i];
   }
}
inline double VWAPPrice(int i,const double& o[],const double& h[],const double& l[],const double& c[])
{
   switch(VWAP_PriceMethod)
   {
      case PRICE_OPEN:     return o[i];
      case PRICE_HIGH:     return h[i];
      case PRICE_LOW:      return l[i];
      case PRICE_CLOSE:    return c[i];
      case PRICE_MEDIAN:   return (h[i]+l[i])*0.5;
      case PRICE_TYPICAL:  return (h[i]+l[i]+c[i])/3.0;
      case PRICE_WEIGHTED: return (h[i]+l[i]+2.0*c[i])/4.0;
      default:             return c[i];
   }
}
inline datetime DayAnchor(datetime t){MqlDateTime dt; TimeToStruct(t,dt); dt.hour=dt.min=dt.sec=0; return StructToTime(dt);} 

inline datetime WeekAnchor(datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t,dt);
   dt.hour=dt.min=dt.sec=0;
   datetime dayStart = StructToTime(dt);
   // Roll back to Sunday (day_of_week==0)
   while(dt.day_of_week!=0)
   {
      dayStart -= 86400;
      TimeToStruct(dayStart,dt);
   }
   return dayStart;
}

inline datetime MonthAnchor(datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t,dt);
   dt.day=1;
   dt.hour=dt.min=dt.sec=0;
   return StructToTime(dt);
}

//==================================================================
// MAIN CALCULATION
//==================================================================
int OnCalculate(const int rates_total,const int prev_calculated,const datetime &time[],const double &open[],const double &high[],const double &low[],const double &close[],const long &tick_vol[],const long &vol[],const int &spread[])
{
   // ═══════════════════════════════════════════════════════════════
   // SERIES INDEXING (MT5 Standard): bar[0]=newest, bar[n]=oldest
   // ═══════════════════════════════════════════════════════════════
   // Keep input arrays in MT5's native series order for correct data access
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(tick_vol, true);
   ArraySetAsSeries(vol, true);
   ArraySetAsSeries(spread, true);
   
   static bool seriesInit=false;
   if(!seriesInit)
   {
      // Set all indicator buffers to NON-SERIES (forward indexing)
      ArraySetAsSeries(ATRBuf,false);
      ArraySetAsSeries(UpBuf,false);
      ArraySetAsSeries(DownBuf,false);
      ArraySetAsSeries(TrendBuf,false);
      ArraySetAsSeries(SuperTrendBuf,false);
      ArraySetAsSeries(ST_ColorBuf,false);
      ArraySetAsSeries(VWAPBuf,false);
      ArraySetAsSeries(VWAPWeeklyBuf,false);
      ArraySetAsSeries(VWAPMonthlyBuf,false);
      ArraySetAsSeries(VWAP_TPVBuf,false);
      ArraySetAsSeries(VWAP_VolBuf,false);
      ArraySetAsSeries(VWAPWeek_TPVBuf,false);
      ArraySetAsSeries(VWAPWeek_VolBuf,false);
      ArraySetAsSeries(VWAPMonth_TPVBuf,false);
      ArraySetAsSeries(VWAPMonth_VolBuf,false);
      ArraySetAsSeries(AVWAPSessionBuf,false);
      ArraySetAsSeries(AVWAPSess_TPVBuf,false);
      ArraySetAsSeries(AVWAPSess_VolBuf,false);
      ArraySetAsSeries(SignalBuf,false);

      seriesInit=true;
   }
   
   // ═══════════════════════════════════════════════════════════════
   // WARM-UP PERIOD: Ensure sufficient data for ATR calculation
   // ═══════════════════════════════════════════════════════════════
   if(rates_total<=ST_ATRPeriod+2) return 0;

   // Copy ATR values from indicator to buffer
   // CopyBuffer returns series-ordered data, but we need forward order to match our loop
   // Solution: Copy to temporary array, then manually reverse into ATRBuf
   double tempATR[];
   ArraySetAsSeries(tempATR, true); // Receive in series order from iATR
   if(CopyBuffer(atrHandle,0,0,rates_total,tempATR)<=0) return prev_calculated;
   
   // Manually copy in reverse order to align with forward-indexed buffers
   for(int i=0; i<rates_total; i++)
   {
      ATRBuf[i] = tempATR[rates_total-1-i]; // Forward[i] = Series[rates_total-1-i]
   }

   // ═══════════════════════════════════════════════════════════════
   // DETERMINE START BAR (efficient recalculation using prev_calculated)
   // ═══════════════════════════════════════════════════════════════
   // On first run: start after warm-up period (ST_ATRPeriod+2)
   // On updates: recalculate last bar for corrections
   int start = (prev_calculated>0) ? prev_calculated-1 : ST_ATRPeriod+2;

   // ═══════════════════════════════════════════════════════════════
   // STRATEGY TESTER INITIALIZATION
   // ═══════════════════════════════════════════════════════════════
   // On first calculation (prev_calculated==0), reset all statistics
   // In Strategy Tester: ignore warm-up bars before test start date
   if(prev_calculated==0){
      if(g_isTesting){
         // Remember the current bar time at indicator attach (tester start)
         // All bars with time <= this are part of warm-up and excluded from stats/arrows
         // Series indexing: time[0] = newest bar (test start point)
         g_btCutoffTime = time[0];
         
         // Reset all cumulative statistics and state variables
         g_sumMFEBlue=g_sumMFEWhite=0.0;
         g_cntBlue=g_cntWhite=0;
         g_totalFlips=g_accepted=g_rejected=g_bullAccepted=g_bearAccepted=0;
         g_lastAcceptedBar=-1;
         g_lastMFEPoints=0.0;
         g_lastMAEPoints=0.0;
         g_sumMAEBlue=g_sumMAEWhite=0.0;
         ArrayResize(g_mfeBlueVals, 0);
         ArrayResize(g_mfeWhiteVals, 0);
         ArrayResize(g_maeBlueVals, 0);
         ArrayResize(g_maeWhiteVals, 0); 
         g_seg.dir=0; g_seg.startBar=0; g_seg.entryPrice=0.0; g_seg.maxMFE=0.0; g_seg.age=0;
         g_seg.maxMAE=0.0;
         g_lastFlipTime=0; g_lastTrendDir=0;
         
         // Suppress alerts during initial historical load
         // Series indexing: time[1] = last closed bar
         if(rates_total>=2){
            g_initialLastBar = time[1];
            g_lastAlertBar   = g_initialLastBar;
            g_lastAlertTime  = TimeCurrent();
            g_alertsActive   = false;
         }
      } }

   // ═══════════════════════════════════════════════════════════════
   // MAIN CALCULATION LOOP (Forward: oldest→newest)
   // ═══════════════════════════════════════════════════════════════
   // Hybrid indexing: Input arrays are SERIES, buffers are FORWARD
   // Loop forward through time (i=0 is oldest), but access input arrays with series index
   #define BAR(i) (rates_total - 1 - (i))  // Convert forward index to series index
   
   for(int i=start; i<rates_total; i++)
   {
      // Skip warm-up bars in Strategy Tester (before test start date)
      if(g_isTesting && time[BAR(i)] <= g_btCutoffTime){ SignalBuf[i]=0; continue; }

      // ═══════════════════════════════════════════════════════════════
      // VWAP CALCULATIONS (Daily, Weekly, Monthly, Session)
      // ═══════════════════════════════════════════════════════════════
      // DETERMINISTIC: Same inputs always produce same outputs regardless
      // of tick model or calculation order. Uses cumulative TPV/Volume.
      
      // Volume normalization (use tick_volume or real volume, enforce minimum)
      double volBar = (tick_vol[BAR(i)]>0) ? (double)tick_vol[BAR(i)] : ((vol[BAR(i)]>0)?(double)vol[BAR(i)]:0.0);
      if(volBar < VWAP_MinVolume) volBar = 0.0;

      // Price for VWAP calculation (user-configurable via VWAP_PriceMethod)
      double priceVW = VWAPPrice(BAR(i),open,high,low,close);
      double tpv      = priceVW * volBar;  // Typical Price × Volume

      // ─────────────────────────────────────────────────────────────
      // Daily VWAP: Reset at midnight (00:00) each day
      // Forward indexing: i-1 = previous bar, i = current bar
      // ─────────────────────────────────────────────────────────────
      if(i==0)
      {
         // First bar: initialize cumulative sums
         VWAP_TPVBuf[i] = tpv;
         VWAP_VolBuf[i] = volBar;
      }
      else
      {
         if(DayAnchor(time[BAR(i)]) == DayAnchor(time[BAR(i-1)]))
         {
            // Same day: accumulate TPV and Volume from previous bar
            VWAP_TPVBuf[i] = VWAP_TPVBuf[i-1] + tpv;
            VWAP_VolBuf[i] = VWAP_VolBuf[i-1] + volBar;
         }
         else
         {
            // New day detected: reset cumulative sums (anchor at midnight)
            VWAP_TPVBuf[i] = tpv;
            VWAP_VolBuf[i] = volBar;
         }
      }

      // Calculate Daily VWAP = cumulative TPV / cumulative Volume
      VWAPBuf[i] = (VWAP_VolBuf[i] > 0.0) ? VWAP_TPVBuf[i] / VWAP_VolBuf[i] : priceVW;

      // ─────────────────────────────────────────────────────────────
      // Weekly VWAP: Reset on Sunday midnight (00:00)
      // Forward indexing: i-1 = previous bar, i = current bar
      // ─────────────────────────────────────────────────────────────
      if(i==0)
      {
         VWAPWeek_TPVBuf[i] = tpv;
         VWAPWeek_VolBuf[i] = volBar;
      }
      else
      {
         if(WeekAnchor(time[BAR(i)]) == WeekAnchor(time[BAR(i-1)]))
         {
            // Same week: accumulate from previous bar
            VWAPWeek_TPVBuf[i] = VWAPWeek_TPVBuf[i-1] + tpv;
            VWAPWeek_VolBuf[i] = VWAPWeek_VolBuf[i-1] + volBar;
         }
         else
         {
            // New week: reset (anchor at Sunday 00:00)
            VWAPWeek_TPVBuf[i] = tpv;
            VWAPWeek_VolBuf[i] = volBar;
         }
      }
      VWAPWeeklyBuf[i] = (VWAPWeek_VolBuf[i] > 0.0) ? VWAPWeek_TPVBuf[i] / VWAPWeek_VolBuf[i] : priceVW;

      // ─────────────────────────────────────────────────────────────
      // Monthly VWAP: Reset on 1st day of month at midnight (00:00)
      // Forward indexing: i-1 = previous bar, i = current bar
      // ─────────────────────────────────────────────────────────────
      if(i==0)
      {
         VWAPMonth_TPVBuf[i] = tpv;
         VWAPMonth_VolBuf[i] = volBar;
      }
      else
      {
         if(MonthAnchor(time[BAR(i)]) == MonthAnchor(time[BAR(i-1)]))
         {
            // Same month: accumulate from previous bar
            VWAPMonth_TPVBuf[i] = VWAPMonth_TPVBuf[i-1] + tpv;
            VWAPMonth_VolBuf[i] = VWAPMonth_VolBuf[i-1] + volBar;
         }
         else
         {
            // New month: reset (anchor at 1st of month 00:00)
            VWAPMonth_TPVBuf[i] = tpv;
            VWAPMonth_VolBuf[i] = volBar;
         }
      }
      VWAPMonthlyBuf[i] = (VWAPMonth_VolBuf[i] > 0.0) ? VWAPMonth_TPVBuf[i] / VWAPMonth_VolBuf[i] : priceVW;

      // ─────────────────────────────────────────────────────────────
      // Session AVWAP: Anchored at user-defined time each day
      // Forward indexing: i-1 = previous bar, i = current bar
      // ─────────────────────────────────────────────────────────────
      // Resets daily at AVWAP_Session_Hour:AVWAP_Session_Min
      // Before anchor time: shows EMPTY_VALUE (not ready)
      if(AVWAP_Session_Enable)
      {
         MqlDateTime dt;
         TimeToStruct(time[BAR(i)],dt);
         int barMin = dt.hour*60 + dt.min;
         int anchorMin = AVWAP_Session_Hour*60 + AVWAP_Session_Min;
         
         bool isAnchorBar = (barMin == anchorMin);
         bool isPastAnchor = (barMin >= anchorMin);
         
         if(i==0)
         {
            // First bar: initialize
            AVWAPSess_TPVBuf[i] = isPastAnchor ? tpv : 0;
            AVWAPSess_VolBuf[i] = isPastAnchor ? volBar : 0;
         }
         else
         {
            datetime curDay = DayAnchor(time[BAR(i)]);
            datetime prevDay = DayAnchor(time[BAR(i-1)]);
            
            if(curDay != prevDay || isAnchorBar)
            {
               // New day or exact anchor time reached: reset cumulative sums
               AVWAPSess_TPVBuf[i] = tpv;
               AVWAPSess_VolBuf[i] = volBar;
            }
            else if(isPastAnchor)
            {
               // Same day, after anchor time: accumulate from previous bar
               AVWAPSess_TPVBuf[i] = AVWAPSess_TPVBuf[i-1] + tpv;
               AVWAPSess_VolBuf[i] = AVWAPSess_VolBuf[i-1] + volBar;
            }
            else
            {
               // Before anchor time today: no value yet (not active)
               AVWAPSess_TPVBuf[i] = 0;
               AVWAPSess_VolBuf[i] = 0;
            }
         }
         
         // Calculate session AVWAP or EMPTY_VALUE if not ready
         AVWAPSessionBuf[i] = (AVWAPSess_VolBuf[i] > 0.0) ? AVWAPSess_TPVBuf[i] / AVWAPSess_VolBuf[i] : EMPTY_VALUE;
      }
      else
      {
         // Session AVWAP disabled: always EMPTY_VALUE
         AVWAPSessionBuf[i] = EMPTY_VALUE;
      }

      // ═══════════════════════════════════════════════════════════════
      // SUPERTREND CALCULATION (core indicator logic)
      // Forward indexing: i-1 = previous bar, i = current bar
      // ═══════════════════════════════════════════════════════════════
      double base = BasePrice(BAR(i),open,high,low,close);
      UpBuf[i]   = base + ST_Multiplier*ATRBuf[i];   // Upper band
      DownBuf[i] = base - ST_Multiplier*ATRBuf[i];   // Lower band

      // Warm-up: need at least 2 bars for trend comparison
      if(i<=1){ TrendBuf[i]=1; continue; }

      // ─────────────────────────────────────────────────────────────
      // Trend direction decision (uses only prior CLOSED bar data)
      // Forward indexing: i-1 = previous bar
      // ─────────────────────────────────────────────────────────────
      double src = base;  // Already calculated above
      if(src > UpBuf[i-1])        TrendBuf[i]= 1;   // bullish
      else if(src < DownBuf[i-1]) TrendBuf[i]=-1;   // bearish
      else                        TrendBuf[i]= TrendBuf[i-1];  // maintain

      // ─────────────────────────────────────────────────────────────
      // Trailing stop adjustment (prevent bands from moving against trend)
      // Forward indexing: i-1 = previous bar
      // ─────────────────────────────────────────────────────────────
      if(TrendBuf[i]>0 && DownBuf[i]<DownBuf[i-1]) DownBuf[i]=DownBuf[i-1];
      if(TrendBuf[i]<0 && UpBuf[i]>UpBuf[i-1])     UpBuf[i]=UpBuf[i-1];

      // ─────────────────────────────────────────────────────────────
      // Plot values (visual output: line and color)
      // ─────────────────────────────────────────────────────────────
      if(TrendBuf[i]>0){ SuperTrendBuf[i]=DownBuf[i]; ST_ColorBuf[i]=0; } // green
      else              { SuperTrendBuf[i]=UpBuf[i];   ST_ColorBuf[i]=1; } // red

      // ╔═══════════════════════════════════════════════════════════════╗
      // ║  EA-READY SIGNAL LOGIC (NON-REPAINTING, CLOSED BARS ONLY)    ║
      // ║  Forward indexing: i = current bar position                  ║
      // ╚═══════════════════════════════════════════════════════════════╝
      // Initialize signal to 0 (no signal) for every bar
      SignalBuf[i]=0;

      // CRITICAL: Only process CLOSED bars
      // In forward indexing, bar[rates_total-1] is current/forming bar
      int lastClosed = rates_total-2;
      if(i > lastClosed) continue; // Skip still-forming bar

      // Price source for signal decision (already computed above via ST_Price setting)
      double srcSig = src;

      // Detect SuperTrend direction flip
      // Forward indexing: compare current bar[i] vs previous bar[i-1]
      // This uses only completed data (bar i-1 is fully closed)
      bool flipUp   = (TrendBuf[i]>0 && TrendBuf[i-1]<0);  // bullish flip
      bool flipDown = (TrendBuf[i]<0 && TrendBuf[i-1]>0);  // bearish flip
      int dir = flipUp ? 1 : (flipDown ? -1 : 0);

      if(dir==0 || time[BAR(i)]==g_lastFlipTime) { /*nothing*/ }
      else
      {
         // finalise previous segment
         if(g_seg.dir!=0)
         {
            double diff_i = (g_seg.dir==1) ? (high[BAR(i)]-g_seg.entryPrice) : (g_seg.entryPrice-low[BAR(i)]);
            if(diff_i > g_seg.maxMFE) g_seg.maxMFE = diff_i;
            
            double mfePoints = g_seg.maxMFE / _Point;
            double maePoints = g_seg.maxMAE / _Point;
            
            // Store in sums (for average calculation)
            if(g_seg.dir==1)
            {
               g_sumMFEBlue += g_seg.maxMFE;
               g_sumMAEBlue += g_seg.maxMAE;
               g_cntBlue++;
               
               // Store individual values (for median calculation)
               int n = ArraySize(g_mfeBlueVals);
               ArrayResize(g_mfeBlueVals, n+1);
               g_mfeBlueVals[n] = mfePoints;
               n = ArraySize(g_maeBlueVals);
               ArrayResize(g_maeBlueVals, n+1);
               g_maeBlueVals[n] = maePoints;
            }
            else
            {
               g_sumMFEWhite += g_seg.maxMFE;
               g_sumMAEWhite += g_seg.maxMAE;
               g_cntWhite++;
               
               // Store individual values (for median calculation)
               int n = ArraySize(g_mfeWhiteVals);
               ArrayResize(g_mfeWhiteVals, n+1);
               g_mfeWhiteVals[n] = mfePoints;
               n = ArraySize(g_maeWhiteVals);
               ArrayResize(g_maeWhiteVals, n+1);
               g_maeWhiteVals[n] = maePoints;
            }
            
            g_lastMFEPoints = mfePoints;
            g_lastMAEPoints = maePoints;
            g_seg.dir = 0;
         }

         // ═══════════════════════════════════════════════════════════════
         // FILTER APPLICATION (ALL enabled filters use AND logic)
         // ═══════════════════════════════════════════════════════════════
         
         // Session-based gating (time window filter)
         bool genOK  = ShouldGenerateSignals(time[BAR(i)]);
         
         // VWAP position filters: ALL enabled filters must pass (AND logic)
         // BUY requires price > VWAP, SELL requires price < VWAP
         bool vwapOK = true;
         
         if(VWAP_FilterDaily)
         {
            double vwapD = VWAPBuf[i];
            bool okD = (dir==1)?(srcSig>vwapD):(srcSig<vwapD);
            vwapOK = vwapOK && okD;
         }
         
         if(VWAP_FilterWeekly)
         {
            double vwapW = VWAPWeeklyBuf[i];
            bool okW = (dir==1)?(srcSig>vwapW):(srcSig<vwapW);
            vwapOK = vwapOK && okW;
         }
         
         if(VWAP_FilterMonthly)
         {
            double vwapM = VWAPMonthlyBuf[i];
            bool okM = (dir==1)?(srcSig>vwapM):(srcSig<vwapM);
            vwapOK = vwapOK && okM;
         }
         
         if(AVWAP_Session_Filter && AVWAPSessionBuf[i]!=EMPTY_VALUE)
         {
            double avwapS = AVWAPSessionBuf[i];
            bool okS = (dir==1)?(srcSig>avwapS):(srcSig<avwapS);
            vwapOK = vwapOK && okS;
         }
         
         // Final decision: flip must pass ALL enabled filters
         bool accepted = vwapOK && genOK;

         // ═══════════════════════════════════════════════════════════════
         // WRITE SIGNAL TO BUFFER (EA-CONSUMABLE OUTPUT)
         // ═══════════════════════════════════════════════════════════════
         // If accepted: write +1 (buy) or -1 (sell)
         // If rejected: signal stays 0 (already initialized above)
         // This value will NEVER change for this bar once written
         if(accepted) SignalBuf[i]=dir;

         // ═══════════════════════════════════════════════════════════════
         // VISUAL ARROWS (display only, does NOT affect signal buffer)
         // ═══════════════════════════════════════════════════════════════
         if(Show_Arrows)
         {
            string name = StringFormat("STVWAP_%c_%I64d", dir==1?'U':'D', time[BAR(i)]);
            if(ObjectFind(0,name)<0)
            {
               int   code = (dir==1)?ArrowCodeUp:ArrowCodeDn;
               // Arrow color indicates accepted (white/blue) vs rejected (gray)
               color col  = accepted?((dir==1)?BearArrowColor:BullArrowColor):RejectArrowColor;
               ObjectCreate(0,name,OBJ_ARROW,0,time[BAR(i)],srcSig);
               ObjectSetInteger(0,name,OBJPROP_ARROWCODE,code);
               ObjectSetInteger(0,name,OBJPROP_COLOR,col);
               ObjectSetInteger(0,name,OBJPROP_WIDTH,2);
               ObjectSetInteger(0,name,OBJPROP_BACK,false);
               ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
               ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
            }
         }

         // ═══════════════════════════════════════════════════════════════
         // STATE TRACKING & STATISTICS (does NOT affect signal buffer)
         // ═══════════════════════════════════════════════════════════════
         g_lastFlipTime=time[BAR(i)];
         g_lastTrendDir=dir;

         if(accepted)
         {
            // Update counters for dashboard display
            g_totalFlips++; g_accepted++; if(dir==1) g_bullAccepted++; else g_bearAccepted++;
            
            // Start new MFE/MAE tracking segment
            g_seg.dir=dir; g_seg.startBar=i; g_seg.entryPrice=srcSig; 
            g_seg.maxMFE=0.0; g_seg.age=0; g_seg.maxMAE=0.0;
            g_lastAcceptedBar=i;

            // ═══════════════════════════════════════════════════════════════
            // ALERTS (visual/audio feedback, does NOT affect signal buffer)
            // ═══════════════════════════════════════════════════════════════
            TryAlert(dir,time[BAR(i)],srcSig,VWAPBuf[i],SuperTrendBuf[i],accepted);
         }
         else { g_totalFlips++; g_rejected++; }
      }

      // ═══════════════════════════════════════════════════════════════
      // MFE/MAE TRACKING (ongoing segment, dashboard only)
      // ═══════════════════════════════════════════════════════════════
      if(g_seg.dir!=0)
      {
         // Maximum Favourable Excursion (best price movement in trade direction)
         double diff = (g_seg.dir==1) ? (high[BAR(i)]-g_seg.entryPrice) : (g_seg.entryPrice-low[BAR(i)]);
         if(diff > g_seg.maxMFE) g_seg.maxMFE = diff;
         
         // Maximum Adverse Excursion (worst price movement against trade)
         double adverse = (g_seg.dir==1) ? (g_seg.entryPrice - low[BAR(i)]) : (high[BAR(i)] - g_seg.entryPrice);
         if(adverse > g_seg.maxMAE) g_seg.maxMAE = adverse;
      }
   }
   
   #undef BAR  // Clean up macro

   // Enable alerts only after a NEW bar has closed since attachment
   // Series indexing: time[1] = last closed bar
   if(!g_alertsActive && rates_total>=2 && time[1]!=g_initialLastBar)
         g_alertsActive = true;

   // ╔═══════════════════════════════════════════════════════════════╗
   // ║  CURRENT BAR HANDLING - EA NON-REPAINTING GUARANTEE           ║
   // ╚═══════════════════════════════════════════════════════════════╝
   // Forward indexing: bar[rates_total-1] is forming/current bar
   // Signal buffer: already set to 0 above (skipped by lastClosed check)
   // Visual buffers: keep current bar drawn (shows live ST/VWAP values)
   // EA reads closed bar at rates_total-2, never the forming bar

   // ---- stats & dashboard (on bar close) ----
   static int lastBars=-1;
   if(rates_total!=lastBars)
   {
      DashStats ds;
      ds.totalSignals    = g_totalFlips;
      ds.bullishSignals  = g_bullAccepted;
      ds.bearishSignals  = g_bearAccepted;
      ds.acceptedSignals = g_accepted;
      ds.rejectedSignals = g_rejected;

      // Calculate averages
      ds.avgMFEBlue  = (g_cntBlue>0)  ? (g_sumMFEBlue / g_cntBlue)  / _Point : 0.0;
      ds.avgMFEWhite = (g_cntWhite>0) ? (g_sumMFEWhite/ g_cntWhite) / _Point : 0.0;
      int totCnt     = g_cntBlue + g_cntWhite;
      ds.avgMFEAll   = (totCnt>0)? (g_sumMFEBlue+g_sumMFEWhite)/totCnt/_Point : 0.0;
      
      ds.avgMAEBlue  = (g_cntBlue>0)  ? g_sumMAEBlue  / g_cntBlue  / _Point : 0.0;
      ds.avgMAEWhite = (g_cntWhite>0) ? g_sumMAEWhite / g_cntWhite / _Point : 0.0;
      ds.avgMAEAll   = (totCnt>0)? (g_sumMAEBlue+g_sumMAEWhite)/totCnt/_Point : 0.0;
      
      // Calculate medians
      ds.medMFEBlue  = CalculateMedian(g_mfeBlueVals);
      ds.medMFEWhite = CalculateMedian(g_mfeWhiteVals);
      ds.medMAEBlue  = CalculateMedian(g_maeBlueVals);
      ds.medMAEWhite = CalculateMedian(g_maeWhiteVals);
      
      // Calculate "All" medians from merged samples
      double allMFE[], allMAE[];
      ArrayResize(allMFE, ArraySize(g_mfeBlueVals) + ArraySize(g_mfeWhiteVals));
      ArrayResize(allMAE, ArraySize(g_maeBlueVals) + ArraySize(g_maeWhiteVals));
      ArrayCopy(allMFE, g_mfeBlueVals, 0, 0, WHOLE_ARRAY);
      ArrayCopy(allMFE, g_mfeWhiteVals, ArraySize(g_mfeBlueVals), 0, WHOLE_ARRAY);
      ArrayCopy(allMAE, g_maeBlueVals, 0, 0, WHOLE_ARRAY);
      ArrayCopy(allMAE, g_maeWhiteVals, ArraySize(g_maeBlueVals), 0, WHOLE_ARRAY);
      ds.medMFEAll = CalculateMedian(allMFE);
      ds.medMAEAll = CalculateMedian(allMAE);
      
      // Last values
      ds.lastMFE     = g_lastMFEPoints;
      ds.lastMAE     = g_lastMAEPoints;

      ds.lastSignalBars = (g_lastAcceptedBar>=0) ? (rates_total-1 - g_lastAcceptedBar) : -1;
      ds.lastSignalTime = (g_lastFlipTime>0) ? TimeToString(g_lastFlipTime,TIME_MINUTES) : "None";
       
      // Series indexing: time[0]/close[0] = current bar (newest)
      // Forward buffer indexing: buf[rates_total-1] = current bar
      int last = rates_total-1;
      ds.curPrice = close[0];
      ds.curST    = SuperTrendBuf[last];
      ds.curVWAP  = VWAPBuf[last];

      ds.inSession   = IsInSession(time[0]);
      ds.sessionText = StringFormat("%02d:%02d - %02d:%02d",
                          Session_StartHour,Session_StartMinute,
                          Session_EndHour,Session_EndMinute);
      ds.windowStatus= ds.inSession ? "ACTIVE" : "OUT OF WINDOW";

      if(Dash_Enable && ShouldUpdateDashboard(time[0]))
      {
         CreateDashboard();
         UpdateDashboard(ds);
      }
      else if(Dash_Enable && Session_Enable && Session_Mode!=SESSION_SIGNALS_ONLY)
      {
         // show idle dashboard with muted colors
         CreateDashboard();
         UpdateDashboard(ds);
      }
      else
      {
         RemoveDashboard();
      }

      lastBars=rates_total;
   }

   return rates_total;
}

//==================================================================
// DASHBOARD UI (panel + title + 2 columns)
//==================================================================
void CreateDashboard()
{
   if(g_dashCreated) return;

   // panel
   if(ObjectFind(0,DASH_OBJ_BG)<0)
   {
      ObjectCreate(0,DASH_OBJ_BG,OBJ_RECTANGLE_LABEL,0,0,0);
      ObjectSetInteger(0,DASH_OBJ_BG,OBJPROP_CORNER,Dash_Corner);
      ObjectSetInteger(0,DASH_OBJ_BG,OBJPROP_XDISTANCE,Dash_X);
      ObjectSetInteger(0,DASH_OBJ_BG,OBJPROP_YDISTANCE,Dash_Y);
      ObjectSetInteger(0,DASH_OBJ_BG,OBJPROP_XSIZE,Dash_Width);
      ObjectSetInteger(0,DASH_OBJ_BG,OBJPROP_YSIZE,Dash_Height);
      ObjectSetInteger(0,DASH_OBJ_BG,OBJPROP_BGCOLOR,Dash_BgColor);
      ObjectSetInteger(0,DASH_OBJ_BG,OBJPROP_BORDER_COLOR,Dash_BorderColor);
      ObjectSetInteger(0,DASH_OBJ_BG,OBJPROP_BORDER_TYPE,BORDER_FLAT);
      ObjectSetInteger(0,DASH_OBJ_BG,OBJPROP_BACK,false);
      ObjectSetInteger(0,DASH_OBJ_BG,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,DASH_OBJ_BG,OBJPROP_HIDDEN,true);
   }

   // title
   if(ObjectFind(0,DASH_OBJ_TTL)<0)
   {
      ObjectCreate(0,DASH_OBJ_TTL,OBJ_LABEL,0,0,0);
      ObjectSetString (0,DASH_OBJ_TTL,OBJPROP_TEXT,"SuperTrend · VWAP — Dashboard");
      ObjectSetString (0,DASH_OBJ_TTL,OBJPROP_FONT,Dash_Font);
      ObjectSetInteger(0,DASH_OBJ_TTL,OBJPROP_FONTSIZE,MathMax(Dash_LabelFontSize,Dash_ValueFontSize)+2);
      ObjectSetInteger(0,DASH_OBJ_TTL,OBJPROP_COLOR,Dash_AccentColor);
      ObjectSetInteger(0,DASH_OBJ_TTL,OBJPROP_CORNER,Dash_Corner);
      ObjectSetInteger(0,DASH_OBJ_TTL,OBJPROP_XDISTANCE,Dash_X + Dash_LabelXOffset);
      ObjectSetInteger(0,DASH_OBJ_TTL,OBJPROP_YDISTANCE,Dash_Y + 6);
      ObjectSetInteger(0,DASH_OBJ_TTL,OBJPROP_BACK,false);
      ObjectSetInteger(0,DASH_OBJ_TTL,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,DASH_OBJ_TTL,OBJPROP_HIDDEN,true);
   }

   // Create maximum number of label/value pairs needed (for "Both" mode)
   // We'll create 50 pairs to be safe (more than enough for any mode)
   int y = 28;
   int lhBase = MathMax(Dash_LabelFontSize,Dash_ValueFontSize)+4;
   int lh = lhBase + Dash_RowGapPixels;
   
   for(int idx=0; idx<50; idx++)
   {
      string L = DASH_OBJ_LBL+IntegerToString(idx);
      string V = DASH_OBJ_VAL+IntegerToString(idx);

      if(ObjectFind(0,L)<0)
      {
         ObjectCreate(0,L,OBJ_LABEL,0,0,0);
         ObjectSetString (0,L,OBJPROP_TEXT,"");
         ObjectSetString (0,L,OBJPROP_FONT,Dash_Font);
         ObjectSetInteger(0,L,OBJPROP_FONTSIZE,Dash_LabelFontSize);
         ObjectSetInteger(0,L,OBJPROP_COLOR,Dash_TextColor);
         ObjectSetInteger(0,L,OBJPROP_CORNER,Dash_Corner);
         ObjectSetInteger(0,L,OBJPROP_XDISTANCE,Dash_X + Dash_LabelXOffset);
         ObjectSetInteger(0,L,OBJPROP_YDISTANCE,Dash_Y + y);
         ObjectSetInteger(0,L,OBJPROP_BACK,false);
         ObjectSetInteger(0,L,OBJPROP_SELECTABLE,false);
         ObjectSetInteger(0,L,OBJPROP_HIDDEN,true);
      }
      if(ObjectFind(0,V)<0)
      {
         ObjectCreate(0,V,OBJ_LABEL,0,0,0);
         ObjectSetString (0,V,OBJPROP_TEXT,"");
         ObjectSetString (0,V,OBJPROP_FONT,Dash_Font);
         ObjectSetInteger(0,V,OBJPROP_FONTSIZE,Dash_ValueFontSize);
         ObjectSetInteger(0,V,OBJPROP_COLOR,clrWhite);
         ObjectSetInteger(0,V,OBJPROP_CORNER,Dash_Corner);
         ObjectSetInteger(0,V,OBJPROP_XDISTANCE,Dash_X + Dash_ValueXOffset);
         ObjectSetInteger(0,V,OBJPROP_YDISTANCE,Dash_Y + y);
         ObjectSetInteger(0,V,OBJPROP_BACK,false);
         ObjectSetInteger(0,V,OBJPROP_SELECTABLE,false);
         ObjectSetInteger(0,V,OBJPROP_HIDDEN,true);
      }
   }

   g_dashCreated=true;
}

void UpdateDashboard(const DashStats &ds)
{
   if(!g_dashCreated) return;

   // Clear all labels first
   for(int i=0; i<50; i++)
   {
      string L = DASH_OBJ_LBL+IntegerToString(i);
      string V = DASH_OBJ_VAL+IntegerToString(i);
      ObjectSetString(0,L,OBJPROP_TEXT,"");
      ObjectSetString(0,V,OBJPROP_TEXT,"");
   }

   // direction text + color
   string dirTxt = (g_lastTrendDir==1) ? "BULLISH" : (g_lastTrendDir==-1 ? "BEARISH" : "NO SIGNAL");
   color bullColor = Dash_BullishColor;
   color bearColor = Dash_BearishColor;
   color  dirClr = (g_lastTrendDir==1) ? bullColor : (g_lastTrendDir==-1 ? bearColor : Dash_MutedColor);

   // Build dashboard content based on display mode
   int y = 28;
   int lhBase = MathMax(Dash_LabelFontSize,Dash_ValueFontSize)+4;
   int lh = lhBase + Dash_RowGapPixels;
   int idx = 0;

   // Helper macros to add rows and spacers
   #define ADD_ROW(label, value, valueColor) \
      do { \
         string L = DASH_OBJ_LBL+IntegerToString(idx); \
         string V = DASH_OBJ_VAL+IntegerToString(idx); \
         ObjectSetString(0,L,OBJPROP_TEXT,label); \
         ObjectSetInteger(0,L,OBJPROP_YDISTANCE,Dash_Y + y); \
         ObjectSetString(0,V,OBJPROP_TEXT,value); \
         ObjectSetInteger(0,V,OBJPROP_COLOR,valueColor); \
         ObjectSetInteger(0,V,OBJPROP_YDISTANCE,Dash_Y + y); \
         y += lh; idx++; \
      } while(0)
   
   #define ADD_SPACER \
      y += (lhBase + Dash_RowGapPixels) * Dash_SpacerLines

   // === Current State ===
   ADD_ROW("Current Price:", DoubleToString(ds.curPrice,_Digits), Dash_AccentColor);
   ADD_ROW("SuperTrend:", (ds.curST==0.0 || ds.curST==EMPTY_VALUE) ? "N/A" : DoubleToString(ds.curST,_Digits), Dash_AccentColor);
   ADD_ROW("VWAP:", (ds.curVWAP==0.0|| ds.curVWAP==EMPTY_VALUE) ? "N/A" : DoubleToString(ds.curVWAP,_Digits), Dash_AccentColor);
   ADD_ROW("Direction:", dirTxt, dirClr);
   ADD_SPACER;

   // === Signal Stats ===
   ADD_ROW("Total Flips:", IntegerToString(ds.totalSignals), clrWhite);
   ADD_ROW("Accepted:", IntegerToString(ds.acceptedSignals), Dash_GoodColor);
   ADD_ROW("Rejected:", IntegerToString(ds.rejectedSignals), Dash_BadColor);
   ADD_ROW("Bullish:", IntegerToString(ds.bullishSignals), Dash_GoodColor);
   ADD_ROW("Bearish:", IntegerToString(ds.bearishSignals), Dash_BadColor);
   ADD_SPACER;

   // === Performance Section (mode-dependent) ===
   if(Dash_PerfAggMode == PERF_AVG)
   {
      // Average only
      ADD_ROW("Avg MFE Blue:", DoubleToString(ds.avgMFEBlue,1), bullColor);
      ADD_ROW("Avg MFE White:", DoubleToString(ds.avgMFEWhite,1), bearColor);
      ADD_ROW("Avg MFE All:", DoubleToString(ds.avgMFEAll,1), Dash_AvgColor);
      ADD_ROW("Avg MAE Blue:", DoubleToString(ds.avgMAEBlue,1), bullColor);
      ADD_ROW("Avg MAE White:", DoubleToString(ds.avgMAEWhite,1), bearColor);
      ADD_ROW("Avg MAE All:", DoubleToString(ds.avgMAEAll,1), Dash_AvgColor);
   }
   else if(Dash_PerfAggMode == PERF_MED)
   {
      // Median only
      ADD_ROW("Med MFE Blue:", DoubleToString(ds.medMFEBlue,1), bullColor);
      ADD_ROW("Med MFE White:", DoubleToString(ds.medMFEWhite,1), bearColor);
      ADD_ROW("Med MFE All:", DoubleToString(ds.medMFEAll,1), Dash_AvgColor);
      ADD_ROW("Med MAE Blue:", DoubleToString(ds.medMAEBlue,1), bullColor);
      ADD_ROW("Med MAE White:", DoubleToString(ds.medMAEWhite,1), bearColor);
      ADD_ROW("Med MAE All:", DoubleToString(ds.medMAEAll,1), Dash_AvgColor);
   }
   else if(Dash_PerfAggMode == PERF_BOTH)
   {
      // Both Average and Median
      ADD_ROW("— Performance (Average) —", "", Dash_AccentColor);
      ADD_ROW("Avg MFE Blue:", DoubleToString(ds.avgMFEBlue,1), bullColor);
      ADD_ROW("Avg MFE White:", DoubleToString(ds.avgMFEWhite,1), bearColor);
      ADD_ROW("Avg MFE All:", DoubleToString(ds.avgMFEAll,1), Dash_AvgColor);
      ADD_ROW("Avg MAE Blue:", DoubleToString(ds.avgMAEBlue,1), bullColor);
      ADD_ROW("Avg MAE White:", DoubleToString(ds.avgMAEWhite,1), bearColor);
      ADD_ROW("Avg MAE All:", DoubleToString(ds.avgMAEAll,1), Dash_AvgColor);
      ADD_SPACER;
      ADD_ROW("— Performance (Median) —", "", Dash_AccentColor);
      ADD_ROW("Med MFE Blue:", DoubleToString(ds.medMFEBlue,1), bullColor);
      ADD_ROW("Med MFE White:", DoubleToString(ds.medMFEWhite,1), bearColor);
      ADD_ROW("Med MFE All:", DoubleToString(ds.medMFEAll,1), Dash_AvgColor);
      ADD_ROW("Med MAE Blue:", DoubleToString(ds.medMAEBlue,1), bullColor);
      ADD_ROW("Med MAE White:", DoubleToString(ds.medMAEWhite,1), bearColor);
      ADD_ROW("Med MAE All:", DoubleToString(ds.medMAEAll,1), Dash_AvgColor);
   }

   // === Last MFE/MAE (always shown once) ===
   ADD_ROW("Last MFE:", DoubleToString(ds.lastMFE,1), Dash_AvgColor);
   ADD_ROW("Last MAE:", DoubleToString(ds.lastMAE,1), Dash_AvgColor);
   
   // === Recency ===
   ADD_ROW("Last Signal (bars ago):", IntegerToString(ds.lastSignalBars), Dash_AccentColor);
   ADD_ROW("Last Flip Time:", ds.lastSignalTime, clrWhite);
   ADD_SPACER;

   // === Session ===
   ADD_ROW("Session:", ds.sessionText, clrWhite);
   ADD_ROW("Status:", ds.windowStatus, (ds.inSession?Dash_GoodColor:Dash_MutedColor));

   #undef ADD_ROW
   #undef ADD_SPACER

   // Panel size (keep user size if set)
   ObjectSetInteger(0,DASH_OBJ_BG,OBJPROP_XSIZE,Dash_Width);
   ObjectSetInteger(0,DASH_OBJ_BG,OBJPROP_YSIZE,Dash_Height);

   ChartRedraw();
}

void RemoveDashboard()
{
   ObjectDelete(0,DASH_OBJ_BG);
   ObjectDelete(0,DASH_OBJ_TTL);
   for(int i=0;i<50;i++)
   {
      ObjectDelete(0, DASH_OBJ_LBL+IntegerToString(i));
      ObjectDelete(0, DASH_OBJ_VAL+IntegerToString(i));
   }
   g_dashCreated=false;
}
