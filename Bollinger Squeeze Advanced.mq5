//+-----------------------------------------------------------------------------+
//|                                              Bollinger Squeeze Advanced.mq5 |
//|                                             Copyright © 2022, EarnForex.com |
//| https://www.earnforex.com/metatrader-indicators/Bollinger-Squeeze-Advanced/ |
//+-----------------------------------------------------------------------------+
#property copyright "Copyright © 2022, EarnForex.com"
#property link      "https://www.earnforex.com/metatrader-indicators/Bollinger-Squeeze-Advanced/"
#property version   "1.00"

#property description "Advanced version of the Bollinger Squeeze with alerts."
#property description "BB / Keltner channel squeeze is show with the wide blue bars."
#property description "Trend strength and direction histogram can be based on one of the following indicators:"
#property description "Stochastic, CCI, RSI, MACD, Momentum, Williams % Range, ADX, DeMarker."

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
datetime LastAlertTimeSidewaysTrending = D'01.01.1970';
int LastAlertDirectionSidewaysTrending = 0;
datetime LastAlertTimeZeroCross = D'01.01.1970';
int LastAlertDirectionZeroCross = 0;
int MaxPeriod = 0;
int Handle, ATR_Handle, StdDev_Handle;

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

    switch (TriggerType)
    {
    case Stochastic:
        MaxPeriod = StochasticPeriod;
        Handle = iStochastic(Symbol(), Period(), StochasticPeriod, 3, 3, MODE_SMA, STO_CLOSECLOSE);
        IndicatorSetInteger(INDICATOR_LEVELS, 2);
        IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 30);
        IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, -30);
        IndicatorSetString(INDICATOR_SHORTNAME, "Bollinger Squeeze with Stochastic (" + IntegerToString(StochasticPeriod) + ", 3, 3)");
        break;
    case CCI:
        MaxPeriod = CCIPeriod;
        Handle = iCCI(Symbol(), Period(), CCIPeriod, PRICE_CLOSE);
        IndicatorSetInteger(INDICATOR_LEVELS, 4);
        IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, -200);
        IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, -100);
        IndicatorSetDouble(INDICATOR_LEVELVALUE, 2, 100);
        IndicatorSetDouble(INDICATOR_LEVELVALUE, 3, 200);
        IndicatorSetString(INDICATOR_SHORTNAME, "Bollinger Squeeze with CCI (" + IntegerToString(CCIPeriod) + ", CLOSE)");
        break;
    case RSI:
        MaxPeriod = RSIPeriod;
        Handle = iRSI(Symbol(), Period(), RSIPeriod, PRICE_CLOSE);
        IndicatorSetInteger(INDICATOR_LEVELS, 2);
        IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 20);
        IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, -20);
        IndicatorSetString(INDICATOR_SHORTNAME, "Bollinger Squeeze with RSI (" + IntegerToString(RSIPeriod) + ", CLOSE)");
        break;
    case MACD:
        MaxPeriod = (int)MathMax(MathMax(MACDFastEMAPeriod, MACDSlowEMAPeriod), MACDMACDEMAPeriod);
        Handle = iMACD(Symbol(), Period(), 12, 26, 9, PRICE_CLOSE);
        IndicatorSetString(INDICATOR_SHORTNAME, "Bollinger Squeeze with MACD (" + IntegerToString(MACDFastEMAPeriod) + ", " + IntegerToString(MACDSlowEMAPeriod) + ", " + IntegerToString(MACDMACDEMAPeriod) + ", CLOSE)");
        break;
    case Momentum:
        MaxPeriod = MomentumPeriod;
        Handle = iMomentum(Symbol(), Period(), MomentumPeriod, PRICE_CLOSE);
        IndicatorSetInteger(INDICATOR_LEVELS, 2);
        IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 1);
        IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, -1);
        IndicatorSetString(INDICATOR_SHORTNAME, "Bollinger Squeeze with Momentum (" + IntegerToString(MomentumPeriod) + ", CLOSE)");
        break;
    case Williams:
        MaxPeriod = WilliamsPRPeriod;
        Handle = iWPR(Symbol(), Period(), WilliamsPRPeriod);
        IndicatorSetInteger(INDICATOR_LEVELS, 2);
        IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 30);
        IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, -30);
        IndicatorSetString(INDICATOR_SHORTNAME, "Bollinger Squeeze with Williams% (" + IntegerToString(WilliamsPRPeriod) + ")");
        break;
    case ADX:
        MaxPeriod = ADXPeriod;
        Handle = iADX(Symbol(), Period(), ADXPeriod);
        IndicatorSetInteger(INDICATOR_LEVELS, 2);
        IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 15);
        IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, 40);
        IndicatorSetString(INDICATOR_SHORTNAME, "Bollinger Squeeze with ADX (" + IntegerToString(ADXPeriod) + ")");
        break;
    case DeMarker:
        MaxPeriod = DeMarkerPeriod;
        Handle = iDeMarker(Symbol(), Period(), DeMarkerPeriod);
        IndicatorSetInteger(INDICATOR_LEVELS, 2);
        IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 0.25);
        IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, -0.25);
        IndicatorSetString(INDICATOR_SHORTNAME, "Bollinger Squeeze with Demarker (" + IntegerToString(DeMarkerPeriod) + ")");
        break;
    }
    
    ATR_Handle = iATR(Symbol(), Period(), KeltnerPeriod);
    StdDev_Handle = iStdDev(Symbol(), Period(), BB_Period, MODE_SMA, 0, PRICE_CLOSE);

    ArraySetAsSeries(Buffer, true);
    ArraySetAsSeries(MACD_Signal_Buffer, true);
    ArraySetAsSeries(ATR_Buffer, true);
    ArraySetAsSeries(StdDev_Buffer, true);

    MaxPeriod = MathMax(MathMax(MaxPeriod, KeltnerPeriod), BB_Period);
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
    int limit = rates_total - counted_bars;
    if (limit >= rates_total - MaxPeriod) limit = rates_total - MaxPeriod - 1;

    if (CopyBuffer(Handle, 0, 0, limit, Buffer) != limit) return 0; // Data not ready yet.
    if (TriggerType == MACD)
    {
        if (CopyBuffer(Handle, 1, 0, limit, MACD_Signal_Buffer) != limit) return 0; // Data not ready yet.
    }
    if (CopyBuffer(ATR_Handle, 0, 0, limit, ATR_Buffer) != limit) return 0; // Data not ready yet.
    if (CopyBuffer(StdDev_Handle, 0, 0, limit, StdDev_Buffer) != limit) return 0; // Data not ready yet.

    for (int shift = limit - 1; shift >= 0; shift--)
    {
        double d = 0;
        MACD_MA[shift] = 0;
        switch (TriggerType)
        {
        case Stochastic:
            d = Buffer[shift] - 50;
            break;
        case CCI:
            d = Buffer[shift];
            break;
        case RSI:
            d = Buffer[shift] - 50;
            break;
        case MACD:
            d = Buffer[shift];
            MACD_MA[shift] = MACD_Signal_Buffer[shift];
            break;
        case Momentum:
            d = Buffer[shift] - 100;
            break;
        case Williams:
            d = Buffer[shift] + 50;
            break;
        case ADX:
            d = Buffer[shift];
            break;
        case DeMarker:
            d = Buffer[shift] - 0.5;
            break;
        }

        HistoLine[shift] = d;

        double diff = ATR_Buffer[shift] * KeltnerFactor;
        double std = StdDev_Buffer[shift];
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

    if ((AlertOnSidewaysTrending) && (((TriggerCandle > 0) && (Time[0] > LastAlertTimeSidewaysTrending)) || (TriggerCandle == 0)))
    {
        string Text;
        // Trending Alert
        if ((HistoTrending[TriggerCandle] != 0) && (LastAlertDirectionSidewaysTrending != 1))
        {
            if (LastAlertDirectionSidewaysTrending != 0) // Skip actual alerts if it is the first run after attachment.
            {
                Text = "BSA: " + Symbol() + " - " + StringSubstr(EnumToString((ENUM_TIMEFRAMES)Period()), 7) + " - Trending.";
                if (EnableNativeAlerts) Alert(Text);
                if (EnableEmailAlerts) SendMail("BSA Alert", Text);
                if (EnablePushAlerts) SendNotification(Text);
            }
            LastAlertTimeSidewaysTrending = Time[0];
            LastAlertDirectionSidewaysTrending = 1;
        }
        // Sideways Alert
        if ((HistoSideways[TriggerCandle] != 0) && (LastAlertDirectionSidewaysTrending != -1))
        {
            if (LastAlertDirectionSidewaysTrending != 0) // Skip actual alerts if it is the first run after attachment.
            {
                Text = "BSA: " + Symbol() + " - " + StringSubstr(EnumToString((ENUM_TIMEFRAMES)Period()), 7) + " - Sideways.";
                if (EnableNativeAlerts) Alert(Text);
                if (EnableEmailAlerts) SendMail("BB Squeeze Alert", Text);
                if (EnablePushAlerts) SendNotification(Text);
            }
            LastAlertTimeSidewaysTrending = Time[0];
            LastAlertDirectionSidewaysTrending = -1;
        }
    }

    if ((AlertOnZeroCross) && (((TriggerCandle > 0) && (Time[0] > LastAlertTimeZeroCross)) || (TriggerCandle == 0)))
    {
        string Text;
        // Zero Cross Alert
        if ((HistoLine[TriggerCandle] > 0) && (LastAlertDirectionZeroCross != 1))
        {
            if (LastAlertDirectionZeroCross != 0) // Skip actual alerts if it is the first run after attachment.
            {
                Text = "BSA: " + Symbol() + " - " + StringSubstr(EnumToString((ENUM_TIMEFRAMES)Period()), 7) + " - Histogram Above Zero.";
                if (EnableNativeAlerts) Alert(Text);
                if (EnableEmailAlerts) SendMail("BSA Alert", Text);
                if (EnablePushAlerts) SendNotification(Text);
            }
            LastAlertTimeZeroCross = Time[0];
            LastAlertDirectionZeroCross = 1;
        }
        // Zero Cross Alert
        if ((HistoLine[TriggerCandle] < 0) && (LastAlertDirectionZeroCross != -1))
        {
            if (LastAlertDirectionZeroCross != 0) // Skip actual alerts if it is the first run after attachment.
            {
                Text = "BSA: " + Symbol() + " - " + StringSubstr(EnumToString((ENUM_TIMEFRAMES)Period()), 7) + " - Histogram Below Zero.";
                if (EnableNativeAlerts) Alert(Text);
                if (EnableEmailAlerts) SendMail("BB Squeeze Alert", Text);
                if (EnablePushAlerts) SendNotification(Text);
            }
            LastAlertTimeZeroCross = Time[0];
            LastAlertDirectionZeroCross = -1;
        }
    }

    return rates_total;
}
//+------------------------------------------------------------------+