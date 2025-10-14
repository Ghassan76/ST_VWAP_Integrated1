//+------------------------------------------------------------------+
//|                          ST_VWAP_Integrated1.mq5                 |
//|  Integrated SuperTrend + Daily VWAP with filtered trade signals  |
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
input int      MFE_LookaheadBars    = 24;         // bars to look ahead for MFE calc
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

   // performance (rolling)
   double avgMFEBlue;
   double avgMFEWhite;
   double avgMFEAll;
   double lastMFE;
   double avgMAEBlue;
   double avgMAEWhite;
   double avgMAEAll;
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
   // ensure all price arrays and indicator buffers are indexed oldest->newest (non series)
   static bool seriesInit=false;
   if(!seriesInit)
   {
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
   if(rates_total<=ST_ATRPeriod+2) return 0;

   // copy ATR
   if(CopyBuffer(atrHandle,0,0,rates_total,ATRBuf)<=0) return prev_calculated;

   int start = (prev_calculated>0)?prev_calculated-1:ST_ATRPeriod+2;

   // Reset daily VWAP if new calculation
   if(prev_calculated==0){
      // strategy-tester stats reset at start tick
      if(g_isTesting){
         g_btCutoffTime = time[rates_total-1];
         // zero cumulative stats & state
         g_sumMFEBlue=g_sumMFEWhite=0.0;
         g_cntBlue=g_cntWhite=0;
         g_totalFlips=g_accepted=g_rejected=g_bullAccepted=g_bearAccepted=0;
         g_lastAcceptedBar=-1;
         g_lastMFEPoints=0.0;
         g_lastMAEPoints=0.0;
         g_sumMAEBlue=g_sumMAEWhite=0.0; g_seg.dir=0; g_seg.startBar=0; g_seg.entryPrice=0.0; g_seg.maxMFE=0.0; g_seg.age=0;
         g_seg.maxMAE=0.0;
         g_lastFlipTime=0; g_lastTrendDir=0;
         // Suppress historical alert on load
         if(rates_total>=2){
            g_initialLastBar = time[rates_total-2];
            g_lastAlertBar   = g_initialLastBar;
            g_lastAlertTime  = TimeCurrent();
            g_alertsActive   = false;
         }
      } }

   for(int i=start;i<rates_total;i++)
   {
      // skip historical bars that belong to warm-up range in tester
      if(g_isTesting && time[i] <= g_btCutoffTime){ SignalBuf[i]=0; continue; }

      // ---- VWAP cumulative per day using buffers ----
      double volBar = (tick_vol[i]>0) ? (double)tick_vol[i] : ((vol[i]>0)?(double)vol[i]:0.0);
      if(volBar < VWAP_MinVolume) volBar = 0.0;

      double priceVW = VWAPPrice(i,open,high,low,close);
      double tpv      = priceVW * volBar;

      if(i==0)
      {
         VWAP_TPVBuf[i] = tpv;
         VWAP_VolBuf[i] = volBar;
      }
      else
      {
         if(DayAnchor(time[i]) == DayAnchor(time[i-1]))
         {
            VWAP_TPVBuf[i] = VWAP_TPVBuf[i-1] + tpv;
            VWAP_VolBuf[i] = VWAP_VolBuf[i-1] + volBar;
         }
         else
         {
            VWAP_TPVBuf[i] = tpv;
            VWAP_VolBuf[i] = volBar;
         }
      }

      VWAPBuf[i] = (VWAP_VolBuf[i] > 0.0) ? VWAP_TPVBuf[i] / VWAP_VolBuf[i] : priceVW;

      // ---- VWAP Weekly ----
      if(i==0)
      {
         VWAPWeek_TPVBuf[i] = tpv;
         VWAPWeek_VolBuf[i] = volBar;
      }
      else
      {
         if(WeekAnchor(time[i]) == WeekAnchor(time[i-1]))
         {
            VWAPWeek_TPVBuf[i] = VWAPWeek_TPVBuf[i-1] + tpv;
            VWAPWeek_VolBuf[i] = VWAPWeek_VolBuf[i-1] + volBar;
         }
         else
         {
            VWAPWeek_TPVBuf[i] = tpv;
            VWAPWeek_VolBuf[i] = volBar;
         }
      }
      VWAPWeeklyBuf[i] = (VWAPWeek_VolBuf[i] > 0.0) ? VWAPWeek_TPVBuf[i] / VWAPWeek_VolBuf[i] : priceVW;

      // ---- VWAP Monthly ----
      if(i==0)
      {
         VWAPMonth_TPVBuf[i] = tpv;
         VWAPMonth_VolBuf[i] = volBar;
      }
      else
      {
         if(MonthAnchor(time[i]) == MonthAnchor(time[i-1]))
         {
            VWAPMonth_TPVBuf[i] = VWAPMonth_TPVBuf[i-1] + tpv;
            VWAPMonth_VolBuf[i] = VWAPMonth_VolBuf[i-1] + volBar;
         }
         else
         {
            VWAPMonth_TPVBuf[i] = tpv;
            VWAPMonth_VolBuf[i] = volBar;
         }
      }
      VWAPMonthlyBuf[i] = (VWAPMonth_VolBuf[i] > 0.0) ? VWAPMonth_TPVBuf[i] / VWAPMonth_VolBuf[i] : priceVW;

      // ---- AVWAP Session (anchored at fixed time each day) ----
      if(AVWAP_Session_Enable)
      {
         MqlDateTime dt;
         TimeToStruct(time[i],dt);
         int barMin = dt.hour*60 + dt.min;
         int anchorMin = AVWAP_Session_Hour*60 + AVWAP_Session_Min;
         
         bool isAnchorBar = (barMin == anchorMin);
         bool isPastAnchor = (barMin >= anchorMin);
         
         if(i==0)
         {
            AVWAPSess_TPVBuf[i] = tpv;
            AVWAPSess_VolBuf[i] = volBar;
         }
         else
         {
            datetime curDay = DayAnchor(time[i]);
            datetime prevDay = DayAnchor(time[i-1]);
            
            if(curDay != prevDay || isAnchorBar)
            {
               // New day or hit anchor time - reset
               AVWAPSess_TPVBuf[i] = tpv;
               AVWAPSess_VolBuf[i] = volBar;
            }
            else if(isPastAnchor)
            {
               // Same day, past anchor - accumulate
               AVWAPSess_TPVBuf[i] = AVWAPSess_TPVBuf[i-1] + tpv;
               AVWAPSess_VolBuf[i] = AVWAPSess_VolBuf[i-1] + volBar;
            }
            else
            {
               // Before anchor time - no value
               AVWAPSess_TPVBuf[i] = 0;
               AVWAPSess_VolBuf[i] = 0;
            }
         }
         
         AVWAPSessionBuf[i] = (AVWAPSess_VolBuf[i] > 0.0) ? AVWAPSess_TPVBuf[i] / AVWAPSess_VolBuf[i] : EMPTY_VALUE;
      }
      else
      {
         AVWAPSessionBuf[i] = EMPTY_VALUE;
      }

      // ---- SuperTrend core ----
      double base = BasePrice(i,open,high,low,close);
      UpBuf[i]   = base + ST_Multiplier*ATRBuf[i];
      DownBuf[i] = base - ST_Multiplier*ATRBuf[i];

      if(i<=1){ TrendBuf[i]=1; continue; }

      // trend decision versus prior closed bar bands
      double src = BasePrice(i,open,high,low,close);
      if(src > UpBuf[i-1])        TrendBuf[i]= 1;
      else if(src < DownBuf[i-1]) TrendBuf[i]=-1;
      else                              TrendBuf[i]= TrendBuf[i-1];

      // trailing stops
      if(TrendBuf[i]>0 && DownBuf[i]<DownBuf[i-1]) DownBuf[i]=DownBuf[i-1];
      if(TrendBuf[i]<0 && UpBuf[i]>UpBuf[i-1])     UpBuf[i]=UpBuf[i-1];

      // compute SuperTrend plot & colour
      if(TrendBuf[i]>0){ SuperTrendBuf[i]=DownBuf[i]; ST_ColorBuf[i]=0; }
      else              { SuperTrendBuf[i]=UpBuf[i];   ST_ColorBuf[i]=1; }

      // ---- Signal logic (work only on CLOSED candle) ----
      SignalBuf[i]=0;

      int lastClosed = rates_total-2;
      if(i>lastClosed) continue; // skip still-forming candle

      // price source respects ST_Price
      double srcSig = src; // already computed above

      bool flipUp   = (TrendBuf[i]>0 && TrendBuf[i-1]<0);
      bool flipDown = (TrendBuf[i]<0 && TrendBuf[i-1]>0);
      int dir = flipUp ? 1 : (flipDown ? -1 : 0);

      if(dir==0 || time[i]==g_lastFlipTime) { /*nothing*/ }
      else
      {
         // finalise previous segment
         if(g_seg.dir!=0)
         {
            double diff_i = (g_seg.dir==1) ? (high[i]-g_seg.entryPrice) : (g_seg.entryPrice-low[i]);
            if(diff_i > g_seg.maxMFE) g_seg.maxMFE = diff_i;
            if(g_seg.dir==1){ g_sumMFEBlue += g_seg.maxMFE; g_cntBlue++; }
            else            { g_sumMFEWhite+= g_seg.maxMFE; g_cntWhite++; }
            g_lastMFEPoints = g_seg.maxMFE / _Point;
            g_lastMAEPoints = g_seg.maxMAE / _Point;
            if(g_seg.dir==1) g_sumMAEBlue += g_seg.maxMAE; else g_sumMAEWhite += g_seg.maxMAE;
            g_seg.dir = 0;
         }

         // VWAP + session filters
         bool genOK  = ShouldGenerateSignals(time[i]);
         
         // Check each enabled VWAP filter (AND logic)
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
         
         bool accepted = vwapOK && genOK;

         if(accepted) SignalBuf[i]=dir;

         if(Show_Arrows)
         {
            string name = StringFormat("STVWAP_%c_%I64d", dir==1?'U':'D', time[i]);
            if(ObjectFind(0,name)<0)
            {
               int   code = (dir==1)?ArrowCodeUp:ArrowCodeDn;
               color col  = accepted?((dir==1)?BearArrowColor:BullArrowColor):RejectArrowColor;
               ObjectCreate(0,name,OBJ_ARROW,0,time[i],srcSig);
               ObjectSetInteger(0,name,OBJPROP_ARROWCODE,code);
               ObjectSetInteger(0,name,OBJPROP_COLOR,col);
               ObjectSetInteger(0,name,OBJPROP_WIDTH,2);
               ObjectSetInteger(0,name,OBJPROP_BACK,false);
               ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
               ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
            }
         }

         g_lastFlipTime=time[i];
         g_lastTrendDir=dir;

         if(accepted)
         {
            g_totalFlips++; g_accepted++; if(dir==1) g_bullAccepted++; else g_bearAccepted++;
            g_seg.dir=dir; g_seg.startBar=i; g_seg.entryPrice=srcSig; g_seg.maxMFE=0.0; g_seg.age=0; g_seg.maxMAE=0.0;
            g_lastAcceptedBar=i;

            // CALL ALERT ----------------------------------
            TryAlert(dir,time[i],srcSig,VWAPBuf[i],SuperTrendBuf[i],accepted);
            // ---------------------------------------------
         }
         else { g_totalFlips++; g_rejected++; }
      }

      // ---- ongoing segment tracking (after potential flip processing) ----
      if(g_seg.dir!=0)
      {
         double diff = (g_seg.dir==1) ? (high[i]-g_seg.entryPrice) : (g_seg.entryPrice-low[i]);
         if(diff > g_seg.maxMFE) g_seg.maxMFE = diff;
         // keep segment active until next accepted flip; no automatic timeout
      }
      // update MAE alongside MFE when segment active
      if(g_seg.dir!=0)
      {
         double adverse = (g_seg.dir==1) ? (g_seg.entryPrice - low[i]) : (high[i] - g_seg.entryPrice);
         if(adverse > g_seg.maxMAE) g_seg.maxMAE = adverse;
      }
   }

   // Enable alerts only after a NEW bar has closed since attachment
   if(!g_alertsActive && rates_total>=2 && time[rates_total-2]!=g_initialLastBar)
         g_alertsActive = true;

   // hide bar 0 values to avoid repaint (optional)
   SuperTrendBuf[0]=EMPTY_VALUE; 
   VWAPBuf[0]=EMPTY_VALUE; 
   VWAPWeeklyBuf[0]=EMPTY_VALUE; 
   VWAPMonthlyBuf[0]=EMPTY_VALUE; 
   AVWAPSessionBuf[0]=EMPTY_VALUE;
   SignalBuf[0]=0;

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

      ds.avgMFEBlue  = (g_cntBlue>0)  ? (g_sumMFEBlue / g_cntBlue)  / _Point : 0.0;
      ds.avgMFEWhite = (g_cntWhite>0) ? (g_sumMFEWhite/ g_cntWhite) / _Point : 0.0;
      int totCnt     = g_cntBlue + g_cntWhite;
      ds.avgMFEAll   = (totCnt>0)? (g_sumMFEBlue+g_sumMFEWhite)/totCnt/_Point : 0.0;
      ds.lastMFE     = g_lastMFEPoints;

      ds.avgMAEBlue  = (g_cntBlue>0)  ? g_sumMAEBlue  / g_cntBlue  / _Point : 0.0;
      ds.avgMAEWhite = (g_cntWhite>0) ? g_sumMAEWhite / g_cntWhite / _Point : 0.0;
      ds.avgMAEAll   = (totCnt>0)? (g_sumMAEBlue+g_sumMAEWhite)/totCnt/_Point : 0.0;
      ds.lastMAE     = g_lastMAEPoints;

      ds.lastSignalBars = (g_lastAcceptedBar>=0) ? (rates_total-1 - g_lastAcceptedBar) : -1;
      ds.lastSignalTime = (g_lastFlipTime>0) ? TimeToString(g_lastFlipTime,TIME_MINUTES) : "None";
       
      int last = rates_total-1;
      ds.curPrice = close[last];
      ds.curST    = SuperTrendBuf[last];
      ds.curVWAP  = VWAPBuf[last];

      ds.inSession   = IsInSession(time[last]);
      ds.sessionText = StringFormat("%02d:%02d - %02d:%02d",
                          Session_StartHour,Session_StartMinute,
                          Session_EndHour,Session_EndMinute);
      ds.windowStatus= ds.inSession ? "ACTIVE" : "OUT OF WINDOW";

      if(Dash_Enable && ShouldUpdateDashboard(time[last]))
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

   // labels
   string labels[] = {
      // Current state
      "Current Price:", "SuperTrend:", "VWAP:", "Direction:",
      "", // spacer
      // Signal stats
      "Total Flips:", "Accepted:", "Rejected:", "Bullish:", "Bearish:",
      "", // spacer
      // Performance
      "Avg MFE Blue:", "Avg MFE White:", "Avg MFE All:",
      "Last MFE:",
      "Avg MAE Blue:", "Avg MAE White:", "Avg MAE All:", "Last MAE:",
      "Last Signal (bars ago):", "Last Flip Time:",
      "", // spacer
      // Session
      "Session:", "Status:"
   };

   int y = 28;
   int lhBase = MathMax(Dash_LabelFontSize,Dash_ValueFontSize)+4;
   int lh = lhBase + Dash_RowGapPixels;
   int idx=0;
   for(int i=0;i<ArraySize(labels);i++)
   {
      if(labels[i]==""){ y += (lhBase + Dash_RowGapPixels) * Dash_SpacerLines; continue; }

      string L = DASH_OBJ_LBL+IntegerToString(idx);
      string V = DASH_OBJ_VAL+IntegerToString(idx);

      if(ObjectFind(0,L)<0)
      {
         ObjectCreate(0,L,OBJ_LABEL,0,0,0);
         ObjectSetString (0,L,OBJPROP_TEXT,labels[i]);
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
      y += lh; idx++;
   }

   g_dashCreated=true;
}

void UpdateDashboard(const DashStats &ds)
{
   if(!g_dashCreated) return;

   // direction text + color
   string dirTxt = (g_lastTrendDir==1) ? "BULLISH" : (g_lastTrendDir==-1 ? "BEARISH" : "NO SIGNAL");
   color bullColor = Dash_BullishColor;
   color bearColor = Dash_BearishColor;
   color  dirClr = (g_lastTrendDir==1) ? bullColor : (g_lastTrendDir==-1 ? bearColor : Dash_MutedColor);

   string values[] = {
      // current
      DoubleToString(ds.curPrice,_Digits),
      (ds.curST==0.0 || ds.curST==EMPTY_VALUE) ? "N/A" : DoubleToString(ds.curST,_Digits),
      (ds.curVWAP==0.0|| ds.curVWAP==EMPTY_VALUE) ? "N/A" : DoubleToString(ds.curVWAP,_Digits),
      dirTxt,
      // stats
      IntegerToString(ds.totalSignals),
      IntegerToString(ds.acceptedSignals),
      IntegerToString(ds.rejectedSignals),
      IntegerToString(ds.bullishSignals),
      IntegerToString(ds.bearishSignals),
      // perf
      DoubleToString(ds.avgMFEBlue,1),
      DoubleToString(ds.avgMFEWhite,1),
      DoubleToString(ds.avgMFEAll,1),
      DoubleToString(ds.lastMFE,1),
      DoubleToString(ds.avgMAEBlue,1),
      DoubleToString(ds.avgMAEWhite,1),
      DoubleToString(ds.avgMAEAll,1),
      DoubleToString(ds.lastMAE,1),
      IntegerToString(ds.lastSignalBars),
      ds.lastSignalTime,
      // session
      ds.sessionText,
      ds.windowStatus
   };

   color vcol[] = {
      // current
      Dash_AccentColor,
      Dash_AccentColor,
      Dash_AccentColor,
      dirClr,
      // stats counts (meta good/bad)
      clrWhite,
      Dash_GoodColor,
      Dash_BadColor,
      Dash_GoodColor,
      Dash_BadColor,
      // perf MFE
      bullColor,
      bearColor,
      Dash_AvgColor,
      Dash_AvgColor,
      // perf MAE
      bullColor,
      bearColor,
      Dash_AvgColor,
      Dash_AvgColor,
      // recency
      Dash_AccentColor,
      clrWhite,
      // session
      clrWhite,
      (ds.inSession?Dash_GoodColor:Dash_MutedColor)
   };

   for(int i=0;i<ArraySize(values);i++)
   {
      string V = DASH_OBJ_VAL+IntegerToString(i);
      ObjectSetString (0,V,OBJPROP_TEXT,values[i]);
      ObjectSetInteger(0,V,OBJPROP_COLOR,vcol[i]);
   }

   // Panel size (keep user size if set)
   ObjectSetInteger(0,DASH_OBJ_BG,OBJPROP_XSIZE,Dash_Width);
   ObjectSetInteger(0,DASH_OBJ_BG,OBJPROP_YSIZE,Dash_Height);

   ChartRedraw();
}

void RemoveDashboard()
{
   ObjectDelete(0,DASH_OBJ_BG);
   ObjectDelete(0,DASH_OBJ_TTL);
   for(int i=0;i<30;i++)
   {
      ObjectDelete(0, DASH_OBJ_LBL+IntegerToString(i));
      ObjectDelete(0, DASH_OBJ_VAL+IntegerToString(i));
   }
   g_dashCreated=false;
}
