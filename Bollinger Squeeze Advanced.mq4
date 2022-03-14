//+-----------------------------------------------------------------------------+
//|                                              Bollinger Squeeze Advanced.mq4 |
//|                                             Copyright © 2022, EarnForex.com |
//| https://www.earnforex.com/metatrader-indicators/Bollinger-Squeeze-Advanced/ |
//+-----------------------------------------------------------------------------+
#property copyright "Copyright © 2022, EarnForex.com"
#property link      "https://www.earnforex.com/metatrader-indicators/Bollinger-Squeeze-Advanced/"
#property version   "1.00"
#property strict

#property description "Advanced version of the Bollinger Squeeze with alerts."
#property description "BB / Keltner channel squeeze is show with the wide blue bars."
#property description "Trend strength and direction histogram can be based on one of the following indicators:"
#property description "Stochastic, CCI, RSI, MACD, Momentum, Williams % Range, ADX, DeMarker."

#property indicator_separate_window
#property indicator_buffers 6
#property indicator_color1 clrGreen
#property indicator_type1  DRAW_HISTOGRAM
#property indicator_width1 1
#property indicator_label1 "BS Histo Trending"
#property indicator_color2 clrIndianRed
#property indicator_type2  DRAW_HISTOGRAM
#property indicator_width2 1
#property indicator_label2 "BS Histo Trending"
#property indicator_color3 clrBlue
#property indicator_type3  DRAW_HISTOGRAM
#property indicator_width3 2
#property indicator_label3 "BS Histo Sideways"
#property indicator_color4 clrBlue
#property indicator_type4  DRAW_HISTOGRAM
#property indicator_width4 2
#property indicator_label4 "BS Histo Sideways"
#property indicator_color5 clrRed
#property indicator_label5 "MACD MA"
#property indicator_color6 clrGray
#property indicator_label6 "BS Histo Line"

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

double UpperHistoTrending[];
double LowerHistoTrending[];
double UpperHistoSideways[];
double LowerHistoSideways[];
double MACD_MA[];
double HistoLine[];

// Global variables:
datetime LastAlertTimeSidewaysTrending = D'01.01.1970';
int LastAlertDirectionSidewaysTrending = 0;
datetime LastAlertTimeZeroCross = D'01.01.1970';
int LastAlertDirectionZeroCross = 0;
int MaxPeriod = 0;

void OnInit()
{
    SetIndexBuffer(0, UpperHistoTrending);
    SetIndexEmptyValue(0, 0);

    SetIndexBuffer(1, LowerHistoTrending);
    SetIndexEmptyValue(1, 0);

    SetIndexBuffer(2, UpperHistoSideways);
    SetIndexEmptyValue(2, 0);

    SetIndexBuffer(3, LowerHistoSideways);
    SetIndexEmptyValue(3, 0);

    SetIndexBuffer(4, MACD_MA);

    SetIndexBuffer(5, HistoLine);

    switch (TriggerType)
    {
    case Stochastic:
        MaxPeriod = StochasticPeriod;
        SetLevelValue(1, 30);
        SetLevelValue(2, -30);
        IndicatorShortName("Bollinger Squeeze with Stochastic (" + IntegerToString(StochasticPeriod) + ", 3, 3)");
        break;
    case CCI:
        MaxPeriod = CCIPeriod;
        SetLevelValue(1, -200);
        SetLevelValue(2, -100);
        SetLevelValue(3, 100);
        SetLevelValue(4, 200);
        IndicatorShortName("Bollinger Squeeze with CCI (" + IntegerToString(CCIPeriod) + ", CLOSE)");
        break;
    case RSI:
        MaxPeriod = RSIPeriod;
        SetLevelValue(1, 20);
        SetLevelValue(2, -20);
        IndicatorShortName("Bollinger Squeeze with RSI (" + IntegerToString(RSIPeriod) + ", CLOSE)");
        break;
    case MACD:
        MaxPeriod = (int)MathMax(MathMax(MACDFastEMAPeriod, MACDSlowEMAPeriod), MACDMACDEMAPeriod);
        IndicatorShortName("Bollinger Squeeze with MACD (" + IntegerToString(MACDFastEMAPeriod) + ", " + IntegerToString(MACDSlowEMAPeriod) + ", " + IntegerToString(MACDMACDEMAPeriod) + ", CLOSE)");
        break;
    case Momentum:
        MaxPeriod = MomentumPeriod;
        SetLevelValue(1, 1);
        SetLevelValue(2, -1);
        IndicatorShortName("Bollinger Squeeze with Momentum (" + IntegerToString(MomentumPeriod) + ", CLOSE)");
        break;
    case Williams:
        MaxPeriod = WilliamsPRPeriod;
        SetLevelValue(1, 30);
        SetLevelValue(2, -30);
        IndicatorShortName("Bollinger Squeeze with Williams% (" + IntegerToString(WilliamsPRPeriod) + ")");
        break;
    case ADX:
        MaxPeriod = ADXPeriod;
        SetLevelValue(1, 15);
        SetLevelValue(2, 40);
        IndicatorShortName("Bollinger Squeeze with ADX (" + IntegerToString(ADXPeriod) + ")");
        break;
    case DeMarker:
        MaxPeriod = DeMarkerPeriod;
        SetLevelValue(1, 0.25);
        SetLevelValue(2, -0.25);
        IndicatorShortName("Bollinger Squeeze with Demarker (" + IntegerToString(DeMarkerPeriod) + ")");
        break;
    }
    
    MaxPeriod = MathMax(MathMax(MaxPeriod, KeltnerPeriod), BB_Period);
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    int counted_bars = IndicatorCounted();
    if (counted_bars > 0) counted_bars--;
    int limit = Bars - counted_bars;
    if (limit >= Bars - MaxPeriod) limit = Bars - MaxPeriod - 1;

    for (int shift = limit - 1; shift >= 0; shift--)
    {
        double d = 0;
        switch (TriggerType)
        {
        case Stochastic:
            d = iStochastic(Symbol(), Period(), StochasticPeriod, 3, 3, MODE_SMA, 0, MODE_MAIN, shift) - 50;
            break;
        case CCI:
            d = iCCI(Symbol(), Period(), CCIPeriod, PRICE_CLOSE, shift);
            break;
        case RSI:
            d = iRSI(Symbol(), Period(), RSIPeriod, PRICE_CLOSE, shift) - 50;
            break;
        case MACD:
            d = iMACD(Symbol(), Period(), 12, 26, 9, PRICE_CLOSE, MODE_MAIN, shift);
            MACD_MA[shift] = iMACD(Symbol(), Period(), MACDFastEMAPeriod, MACDSlowEMAPeriod, MACDMACDEMAPeriod, PRICE_CLOSE, MODE_SIGNAL, shift);
            break;
        case Momentum:
            d = iMomentum(Symbol(), Period(), MomentumPeriod, PRICE_CLOSE, shift) - 100;
            break;
        case Williams:
            d = iWPR(Symbol(), Period(), WilliamsPRPeriod, shift) + 50;
            break;
        case ADX:
            d = iADX(Symbol(), Period(), ADXPeriod, PRICE_CLOSE, MODE_MAIN, shift);
            break;
        case DeMarker:
            d = iDeMarker(Symbol(), Period(), DeMarkerPeriod, shift) - 0.5;
            break;
        }

        HistoLine[shift] = d;

        double diff = iATR(Symbol(), Period(), KeltnerPeriod, shift) * KeltnerFactor;
        double std = iStdDev(Symbol(), Period(), BB_Period, MODE_SMA, 0, PRICE_CLOSE, shift);
        double bbs = BB_Deviation * std / diff;

        if (bbs < 1)
        {
            if (d > 0)
            {
                UpperHistoSideways[shift] = d;
                UpperHistoTrending[shift] = 0;
                LowerHistoTrending[shift] = 0;
                LowerHistoSideways[shift] = 0;
            }
            else
            {
                LowerHistoSideways[shift] = d;
                LowerHistoTrending[shift] = 0;
                UpperHistoTrending[shift] = 0;
                UpperHistoSideways[shift] = 0;
            }
        }
        else
        {
            if (d > 0)
            {
                UpperHistoTrending[shift] = d;
                UpperHistoSideways[shift] = 0;
                LowerHistoTrending[shift] = 0;
                LowerHistoSideways[shift] = 0;
            }
            else
            {
                LowerHistoTrending[shift] = d;
                LowerHistoSideways[shift] = 0;
                UpperHistoTrending[shift] = 0;
                UpperHistoSideways[shift] = 0;
            }
        }
    }

    if ((AlertOnSidewaysTrending) && (((TriggerCandle > 0) && (Time[0] > LastAlertTimeSidewaysTrending)) || (TriggerCandle == 0)))
    {
        string Text;
        // Trending Alert
        if (((UpperHistoTrending[TriggerCandle] > 0) || (LowerHistoTrending[TriggerCandle] < 0)) && (LastAlertDirectionSidewaysTrending != 1))
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
        if (((UpperHistoSideways[TriggerCandle] > 0) || (LowerHistoSideways[TriggerCandle])) && (LastAlertDirectionSidewaysTrending != -1))
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