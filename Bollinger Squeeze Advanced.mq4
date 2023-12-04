//+-----------------------------------------------------------------------------+
//|                                              Bollinger Squeeze Advanced.mq4 |
//|                                             Copyright © 2023, EarnForex.com |
//| https://www.earnforex.com/metatrader-indicators/Bollinger-Squeeze-Advanced/ |
//+-----------------------------------------------------------------------------+
#property copyright "Copyright © 2023, EarnForex.com"
#property link      "https://www.earnforex.com/metatrader-indicators/Bollinger-Squeeze-Advanced/"
#property version   "1.01"
#property strict

#property description "Advanced version of the Bollinger Squeeze with alerts."
#property description "BB / Keltner channel squeeze is show with the wide blue bars."
#property description "Trend strength and direction histogram can be based on one of the following indicators:"
#property description "Stochastic, CCI, RSI, MACD, Momentum, Williams % Range, ADX, DeMarker."
#property description "Supports multi-timeframe operation."

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

double UpperHistoTrending[];
double LowerHistoTrending[];
double UpperHistoSideways[];
double LowerHistoSideways[];
double MACD_MA[];
double HistoLine[];

// Global variables:
int MaxPeriod = 0;

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

    // Setting values for the higher timeframe:
    Timeframe = InpTimeframe;
    if (InpTimeframe < Period())
    {
        Timeframe = (ENUM_TIMEFRAMES)Period();
    }

    if (Timeframe > Period())
    {
        deltaHighTF = Timeframe / Period();
    }
    
    ResetGlobalVariables();
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

    PrevCalculated = prev_calculated;

    int limit = Bars - counted_bars + deltaHighTF;
    if (limit >= Bars - MaxPeriod) limit = Bars - MaxPeriod - 1;

    for (int shift = limit - 1; shift >= 0; shift--)
    {
        int index = iBarShift(_Symbol, Timeframe, iTime(_Symbol, PERIOD_CURRENT, shift));
        double d = 0;
        switch (TriggerType)
        {
        case Stochastic:
            d = iStochastic(Symbol(), Timeframe, StochasticPeriod, 3, 3, MODE_SMA, 0, MODE_MAIN, index) - 50;
            break;
        case CCI:
            d = iCCI(Symbol(), Timeframe, CCIPeriod, PRICE_CLOSE, index);
            break;
        case RSI:
            d = iRSI(Symbol(), Timeframe, RSIPeriod, PRICE_CLOSE, index) - 50;
            break;
        case MACD:
            d = iMACD(Symbol(), Timeframe, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, index);
            MACD_MA[shift] = iMACD(Symbol(), Timeframe, MACDFastEMAPeriod, MACDSlowEMAPeriod, MACDMACDEMAPeriod, PRICE_CLOSE, MODE_SIGNAL, index);
            break;
        case Momentum:
            d = iMomentum(Symbol(), Timeframe, MomentumPeriod, PRICE_CLOSE, index) - 100;
            break;
        case Williams:
            d = iWPR(Symbol(), Timeframe, WilliamsPRPeriod, index) + 50;
            break;
        case ADX:
            d = iADX(Symbol(), Timeframe, ADXPeriod, PRICE_CLOSE, MODE_MAIN, index);
            break;
        case DeMarker:
            d = iDeMarker(Symbol(), Timeframe, DeMarkerPeriod, index) - 0.5;
            break;
        }

        HistoLine[shift] = d;

        double diff = iATR(Symbol(), Timeframe, KeltnerPeriod, index) * KeltnerFactor;
        double std = iStdDev(Symbol(), Timeframe, BB_Period, MODE_SMA, 0, PRICE_CLOSE, index);
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
    
    DoAlerts();

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
        isTrendingMessage = "BSA: " + Symbol() + " - " + StringSubstr(EnumToString((ENUM_TIMEFRAMES)Timeframe), 7) + " - Trending.";;
        IsTrending = true;
        IsSideways = false;
    }

    if ((AlertOnSidewaysTrending) &&
            (!IsSideways) &&
            (HasSideways()))
    {
        isSidewaysMessage = "BSA: " + Symbol() + " - " + StringSubstr(EnumToString((ENUM_TIMEFRAMES)Timeframe), 7) + " - Sideways.";;
        IsSideways = true;
        IsTrending = false;
    }

    if ((AlertOnZeroCross) &&
            (!IsHistogramAboveZero) &&
            (HasHistogramAboveZero()))
    {
        isHistogramAboveZeroMessage = "BSA: " + Symbol() + " - " + StringSubstr(EnumToString((ENUM_TIMEFRAMES)Timeframe), 7) + " - Histogram Above ";
        if (AlertAboveLevel == 0) isHistogramAboveZeroMessage += "Zero.";
        else isHistogramAboveZeroMessage += DoubleToString(AlertAboveLevel, 2) + ".";
        IsHistogramAboveZero = true;
        IsHistogramBelowZero = false;
    }

    if ((AlertOnZeroCross) &&
            (!IsHistogramBelowZero) &&
            (HasHistogramBelowZero()))
    {
        isHistogramBelowZeroMessage = "BSA: " + Symbol() + " - " + StringSubstr(EnumToString((ENUM_TIMEFRAMES)Timeframe), 7) + " - Histogram Below ";
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
    return ((UpperHistoTrending[TriggerCandle * deltaHighTF] > 0) || (LowerHistoTrending[TriggerCandle * deltaHighTF] < 0));
}

bool HasSideways()
{
    return ((UpperHistoSideways[TriggerCandle * deltaHighTF] > 0) || (LowerHistoSideways[TriggerCandle * deltaHighTF] < 0));
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