//+-----------------------------------------------------------------------------+
//|                                              Bollinger Squeeze Advanced.mq5 |
//|                                             Copyright © 2023, EarnForex.com |
//| https://www.earnforex.com/metatrader-indicators/Bollinger-Squeeze-Advanced/ |
//+-----------------------------------------------------------------------------+
#property copyright "Copyright © 2023, EarnForex.com"
#property link      "https://www.earnforex.com/metatrader-indicators/Bollinger-Squeeze-Advanced/"
#property version   "1.01"

#property description "Advanced version of the Bollinger Squeeze with alerts."
#property description "BB / Keltner channel squeeze is show with the wide blue bars."
#property description "Trend strength and direction histogram can be based on one of the following indicators:"
#property description "Stochastic, CCI, RSI, MACD, Momentum, Williams % Range, ADX, DeMarker."
#property description "Supports multi-timeframe operation."

#property indicator_separate_window
#property indicator_buffers 5
#property indicator_plots 4
#property indicator_color1 clrGreen, clrIndianRed
#property indicator_type1  DRAW_COLOR_HISTOGRAM
#property indicator_width1 1
#property indicator_label1 "BS Histo Trending"
#property indicator_color2 clrBlue
#property indicator_type2  DRAW_HISTOGRAM
#property indicator_width2 2
#property indicator_label2 "BS Histo Sideways"
#property indicator_type3  DRAW_LINE
#property indicator_color3 clrRed
#property indicator_label3 "MACD MA"
#property indicator_type4  DRAW_LINE
#property indicator_color4 clrGray
#property indicator_label4 "BS Histo Line"

enum enum_trigger_types
{
    Stochastic,
    CCI,
    RSI,
    MACD,
    Momentum,
    Williams, // Williams % Range
    ADX,
    DeMarker
};

enum enum_candle_to_check
{
    Current,
    Previous
};

int    BB_Period = 20;
double BB_Deviation = 2.0;
int    KeltnerPeriod = 20;
double KeltnerFactor = 1.5;

input ENUM_TIMEFRAMES InpTimeframe = PERIOD_CURRENT; // Timeframe
input enum_trigger_types TriggerType = DeMarker;
input int StochasticPeriod = 14;
input int CCIPeriod = 50;
input int RSIPeriod = 14;
input int MACDFastEMAPeriod = 12;
input int MACDSlowEMAPeriod = 26;
input int MACDMACDEMAPeriod = 9;
input int MomentumPeriod = 14;
input int WilliamsPRPeriod = 24;
input int ADXPeriod = 14;
input int DeMarkerPeriod = 13;
input bool AlertOnSidewaysTrending = false;
input bool AlertOnZeroCross = false;
input double AlertAboveLevel = 0; // AlertAboveLevel: If you want alerts above a non-zero level.
input double AlertBelowLevel = 0; // AlertBelowLevel: If you want alerts below a non-zero level.
input bool EnableNativeAlerts = false;
input bool EnableEmailAlerts = false;
input bool EnablePushAlerts = false;
input enum_candle_to_check TriggerCandle = Previous;

double HistoTrending[];
double HistoTrendingColor[];
double HistoSideways[];
double MACD_MA[];
double HistoLine[];

// Internal indicators' buffers:
double Buffer[];
double MACD_Signal_Buffer[];
double ATR_Buffer[];
double StdDev_Buffer[];

// Global variables:
int MaxPeriod = 0;
int Handle, ATR_Handle, StdDev_Handle;

// MTF:
ENUM_TIMEFRAMES Timeframe; // Timeframe of operation
int deltaHighTF = 1; // Difference in candles count from the higher timeframe
int PrevCalculated = 0;

// Alerts:
bool IsTrending;
bool IsSideways;
bool IsHistogramAboveZero;
bool IsHistogramBelowZero;

void OnInit()
{
    SetIndexBuffer(0, HistoTrending, INDICATOR_DATA);
    SetIndexBuffer(1, HistoTrendingColor, INDICATOR_COLOR_INDEX);
    SetIndexBuffer(2, HistoSideways, INDICATOR_DATA);
    SetIndexBuffer(3, MACD_MA, INDICATOR_DATA);
    SetIndexBuffer(4, HistoLine, INDICATOR_DATA);

    PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0);
    PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0);
    PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, 0);
    PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, 0);

    ArraySetAsSeries(HistoTrending, true);
    ArraySetAsSeries(HistoTrendingColor, true);
    ArraySetAsSeries(HistoSideways, true);
    ArraySetAsSeries(MACD_MA, true);
    ArraySetAsSeries(HistoLine, true);

    // Setting values for the higher timeframe:
    Timeframe = InpTimeframe;
    if (InpTimeframe < Period())
    {
        Timeframe = Period();
    }

    switch (TriggerType)
    {
    case Stochastic:
        MaxPeriod = StochasticPeriod;
        Handle = iStochastic(Symbol(), Timeframe, StochasticPeriod, 3, 3, MODE_SMA, STO_CLOSECLOSE);
        IndicatorSetInteger(INDICATOR_LEVELS, 2);
        IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 30);
        IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, -30);
        IndicatorSetString(INDICATOR_SHORTNAME, "Bollinger Squeeze with Stochastic (" + IntegerToString(StochasticPeriod) + ", 3, 3)");
        break;
    case CCI:
        MaxPeriod = CCIPeriod;
        Handle = iCCI(Symbol(), Timeframe, CCIPeriod, PRICE_CLOSE);
        IndicatorSetInteger(INDICATOR_LEVELS, 4);
        IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, -200);
        IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, -100);
        IndicatorSetDouble(INDICATOR_LEVELVALUE, 2, 100);
        IndicatorSetDouble(INDICATOR_LEVELVALUE, 3, 200);
        IndicatorSetString(INDICATOR_SHORTNAME, "Bollinger Squeeze with CCI (" + IntegerToString(CCIPeriod) + ", CLOSE)");
        break;
    case RSI:
        MaxPeriod = RSIPeriod;
        Handle = iRSI(Symbol(), Timeframe, RSIPeriod, PRICE_CLOSE);
        IndicatorSetInteger(INDICATOR_LEVELS, 2);
        IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 20);
        IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, -20);
        IndicatorSetString(INDICATOR_SHORTNAME, "Bollinger Squeeze with RSI (" + IntegerToString(RSIPeriod) + ", CLOSE)");
        break;
    case MACD:
        MaxPeriod = (int)MathMax(MathMax(MACDFastEMAPeriod, MACDSlowEMAPeriod), MACDMACDEMAPeriod);
        Handle = iMACD(Symbol(), Timeframe, 12, 26, 9, PRICE_CLOSE);
        IndicatorSetString(INDICATOR_SHORTNAME, "Bollinger Squeeze with MACD (" + IntegerToString(MACDFastEMAPeriod) + ", " + IntegerToString(MACDSlowEMAPeriod) + ", " + IntegerToString(MACDMACDEMAPeriod) + ", CLOSE)");
        break;
    case Momentum:
        MaxPeriod = MomentumPeriod;
        Handle = iMomentum(Symbol(), Timeframe, MomentumPeriod, PRICE_CLOSE);
        IndicatorSetInteger(INDICATOR_LEVELS, 2);
        IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 1);
        IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, -1);
        IndicatorSetString(INDICATOR_SHORTNAME, "Bollinger Squeeze with Momentum (" + IntegerToString(MomentumPeriod) + ", CLOSE)");
        break;
    case Williams:
        MaxPeriod = WilliamsPRPeriod;
        Handle = iWPR(Symbol(), Timeframe, WilliamsPRPeriod);
        IndicatorSetInteger(INDICATOR_LEVELS, 2);
        IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 30);
        IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, -30);
        IndicatorSetString(INDICATOR_SHORTNAME, "Bollinger Squeeze with Williams% (" + IntegerToString(WilliamsPRPeriod) + ")");
        break;
    case ADX:
        MaxPeriod = ADXPeriod;
        Handle = iADX(Symbol(), Timeframe, ADXPeriod);
        IndicatorSetInteger(INDICATOR_LEVELS, 2);
        IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 15);
        IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, 40);
        IndicatorSetString(INDICATOR_SHORTNAME, "Bollinger Squeeze with ADX (" + IntegerToString(ADXPeriod) + ")");
        break;
    case DeMarker:
        MaxPeriod = DeMarkerPeriod;
        Handle = iDeMarker(Symbol(), Timeframe, DeMarkerPeriod);
        IndicatorSetInteger(INDICATOR_LEVELS, 2);
        IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 0.25);
        IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, -0.25);
        IndicatorSetString(INDICATOR_SHORTNAME, "Bollinger Squeeze with Demarker (" + IntegerToString(DeMarkerPeriod) + ")");
        break;
    }
    
    ATR_Handle = iATR(Symbol(), Timeframe, KeltnerPeriod);
    StdDev_Handle = iStdDev(Symbol(), Timeframe, BB_Period, MODE_SMA, 0, PRICE_CLOSE);

    ArraySetAsSeries(Buffer, true);
    ArraySetAsSeries(MACD_Signal_Buffer, true);
    ArraySetAsSeries(ATR_Buffer, true);
    ArraySetAsSeries(StdDev_Buffer, true);

    MaxPeriod = MathMax(MathMax(MaxPeriod, KeltnerPeriod), BB_Period);

    if (PeriodSeconds(Timeframe) > PeriodSeconds())
    {
        deltaHighTF = PeriodSeconds(Timeframe) / PeriodSeconds();
    }

    ResetGlobalVariables();
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &Time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    ArraySetAsSeries(Time, true);

    int counted_bars = prev_calculated;
    if (counted_bars > 0) counted_bars--;

    PrevCalculated = prev_calculated;

    static int upper_prev_counted = 0; // For MTF.
    int upper_limit, calculated_start;
    if (Timeframe != Period()) // MTF.
    {
        upper_limit = iBars(Symbol(), Timeframe) - upper_prev_counted + 1;
        if (upper_limit >= iBars(Symbol(), Timeframe) - MaxPeriod) upper_limit = iBars(Symbol(), Timeframe) - MaxPeriod - 1;
        if (upper_limit > rates_total - MaxPeriod) upper_limit = rates_total - MaxPeriod; // Buffers cannot hold more than the current period's bars worth of data!
        calculated_start = iBarShift(_Symbol, PERIOD_CURRENT, iTime(Symbol(), Timeframe, upper_limit)); // Current timeframe's bar to start calculations.
    }
    else // Normal operation
    {
        int limit = rates_total - counted_bars;
        if (limit >= rates_total - MaxPeriod) limit = rates_total - MaxPeriod - 1;
        upper_limit = limit;
        calculated_start = limit;
    }
    int copied_Buffer = CopyBuffer(Handle, 0, 0, upper_limit, Buffer);
    if (copied_Buffer <= 0) return 0; // Data not ready yet.
    int copied_MACD = 0;
    if (TriggerType == MACD)
    {
        copied_MACD = CopyBuffer(Handle, 1, 0, upper_limit, MACD_Signal_Buffer);
        if (copied_MACD <= 0) return 0; // Data not ready yet.
    }
    int copied_ATR = CopyBuffer(ATR_Handle, 0, 0, upper_limit, ATR_Buffer);
    if (copied_ATR <= 0) return 0; // Data not ready yet.
    int copied_StdDev = CopyBuffer(StdDev_Handle, 0, 0, upper_limit, StdDev_Buffer);
    if (copied_StdDev <= 0) return 0; // Data not ready yet.
    for (int shift = calculated_start; shift >= 0; shift--)
    {
        int index = iBarShift(_Symbol, Timeframe, Time[shift]);
        if ((index >= copied_Buffer) || (index >= copied_ATR) || (index >= copied_StdDev)) continue; // Cannot go so far back in time.

        double d = 0;
        MACD_MA[shift] = 0;
        switch (TriggerType)
        {
        case Stochastic:
            d = Buffer[index] - 50;
            break;
        case CCI:
            d = Buffer[index];
            break;
        case RSI:
            d = Buffer[index] - 50;
            break;
        case MACD:
            d = Buffer[index];
            if (index >= copied_MACD) continue;
            MACD_MA[shift] = MACD_Signal_Buffer[index];
            break;
        case Momentum:
            d = Buffer[index] - 100;
            break;
        case Williams:
            d = Buffer[index] + 50;
            break;
        case ADX:
            d = Buffer[index];
            break;
        case DeMarker:
            d = Buffer[index] - 0.5;
            break;
        }

        HistoLine[shift] = d;

        double diff = ATR_Buffer[index] * KeltnerFactor;
        double std = StdDev_Buffer[index];
        double bbs = BB_Deviation * std / diff;

        if (bbs < 1)
        {
            if (d > 0)
            {
                HistoSideways[shift] = d;
                HistoTrending[shift] = 0;
            }
            else
            {
                HistoSideways[shift] = d;
                HistoTrending[shift] = 0;
            }
        }
        else
        {
            if (d > 0)
            {
                HistoTrending[shift] = d;
                HistoTrendingColor[shift] = 0;
                HistoSideways[shift] = 0;
            }
            else
            {
                HistoTrending[shift] = d;
                HistoTrendingColor[shift] = 1;
                HistoSideways[shift] = 0;
            }
        }
    }

    DoAlerts();

    upper_prev_counted = iBars(Symbol(), Timeframe);

    return rates_total;
}

void DoAlerts()
{
    if ((!EnableEmailAlerts) && (!EnableNativeAlerts) && (!EnablePushAlerts)) return;

    if (!PrevCalculated)
    {
        RefreshGlobalVariables(); // Refresh global alert variables after attaching indicator.
    }

    string isTrendingMessage = NULL;
    string isSidewaysMessage = NULL;
    string isHistogramAboveZeroMessage = NULL;
    string isHistogramBelowZeroMessage = NULL;

    // Checking for alerts and saving info about it.
    if ((AlertOnSidewaysTrending) &&
            (!IsTrending) &&
            (HasTrending()))
    {
        isTrendingMessage =  "Trending";
        IsTrending = true;
        IsSideways = false;
    }

    if ((AlertOnSidewaysTrending) &&
            (!IsSideways) &&
            (HasSideways()))
    {
        isSidewaysMessage = "Sideways";
        IsSideways = true;
        IsTrending = false;
    }

    if ((AlertOnZeroCross) &&
            (!IsHistogramAboveZero) &&
            (HasHistogramAboveZero()))
    {
        isHistogramAboveZeroMessage = "Histogram Above ";
        if (AlertAboveLevel == 0) isHistogramAboveZeroMessage += "Zero.";
        else isHistogramAboveZeroMessage += DoubleToString(AlertAboveLevel, 2) + ".";
        IsHistogramAboveZero = true;
        IsHistogramBelowZero = false;
    }

    if ((AlertOnZeroCross) &&
            (!IsHistogramBelowZero) &&
            (HasHistogramBelowZero()))
    {
        isHistogramBelowZeroMessage = "Histogram Below ";
        if (AlertBelowLevel == 0) isHistogramBelowZeroMessage += "Zero.";
        else isHistogramBelowZeroMessage += DoubleToString(AlertBelowLevel, 2) + ".";
        IsHistogramBelowZero = true;
        IsHistogramAboveZero = false;
    }

    IssueAlerts(isSidewaysMessage);
    IssueAlerts(isTrendingMessage);
    IssueAlerts(isHistogramAboveZeroMessage);
    IssueAlerts(isHistogramBelowZeroMessage);
}

void ResetGlobalVariables()
{
    IsTrending = false;
    IsSideways = false;
    IsHistogramAboveZero = false;
    IsHistogramBelowZero = false;
}

void RefreshGlobalVariables()
{
    IsTrending = HasTrending();
    IsSideways = HasSideways();
    IsHistogramAboveZero = HasHistogramAboveZero();
    IsHistogramBelowZero = HasHistogramBelowZero();
}

void IssueAlerts(string message)
{
    if (message == NULL) return;

    if (EnableNativeAlerts)
    {
        Alert(message);
    }

    message = "BSA: " + Symbol() + " - " + StringSubstr(EnumToString((ENUM_TIMEFRAMES)Timeframe), 7) + " - " + message + ".";

    if (EnableEmailAlerts)
    {
        SendMail("BSA Alert", message);
    }

    if (EnablePushAlerts)
    {
        SendNotification(message);
    }
}

bool HasTrending()
{
    return (HistoTrending[TriggerCandle * deltaHighTF] != 0);
}

bool HasSideways()
{
    return (HistoSideways[TriggerCandle * deltaHighTF] != 0);
}

bool HasHistogramAboveZero()
{
    return (HistoLine[TriggerCandle * deltaHighTF] > AlertAboveLevel);
}

bool HasHistogramBelowZero()
{
    return (HistoLine[TriggerCandle * deltaHighTF] < AlertBelowLevel);
}
//+------------------------------------------------------------------+