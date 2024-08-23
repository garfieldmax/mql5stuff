//+------------------------------------------------------------------+
//|                                                   ATR_RelMom_EMA.mq5 |
//|                        Custom indicator for MetaTrader 5         |
//|                                                                  |
//+------------------------------------------------------------------+
#property strict

// Indicator settings
#property indicator_separate_window
#property indicator_plots 4
#property indicator_buffers 4

#property indicator_color1 Blue
#property indicator_label1 "RelMomentum"
#property indicator_width1 2

#property indicator_width2 2
#property indicator_color2 Green

#property indicator_color3 Gray
#property indicator_width3 1
#property indicator_style3 STYLE_DASH

#property indicator_width4 1
#property indicator_label4 "ATR"
#property indicator_color4 Red



// Input parameters
input ENUM_APPLIED_PRICE PriceData  = PRICE_CLOSE;
input int atrLength = 15;          // ATR period
input int priceChangeLength = 1;  // Price change period
input int smoothingPeriod = 3;    // Smoothing period

// Buffers
double RelativeMomentumBuffer[];
double SmoothedRelativeMomentumBuffer[];
double ZeroLineBuffer[];
double ATRBuffer[];
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
// Set indicator buffers
   SetIndexBuffer(0, RelativeMomentumBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, SmoothedRelativeMomentumBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, ZeroLineBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, ATRBuffer, INDICATOR_DATA);

// Set plot properties
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_LINE);
   PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_NONE);
   PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_LINE);
   PlotIndexSetInteger(3, PLOT_DRAW_TYPE, DRAW_LINE);

// Set indicator label
   IndicatorSetString(INDICATOR_SHORTNAME,MQLInfoString(MQL_PROGRAM_NAME)+ "("
                      +(string)atrLength+","+(string)priceChangeLength+","+(string)smoothingPeriod+")" );

// Initialize ZeroLineBuffer
   for (int i = 0; i < ArraySize(ZeroLineBuffer); i++)
      ZeroLineBuffer[i] = 0;



   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
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
   int start;
   int min_rates_total = MathMax(atrLength, priceChangeLength);

// which bar we start from (so we dont calc from first bar all time)
   if(prev_calculated<=min_rates_total)
     {
      start=min_rates_total;
     }
   else
     {
      start=prev_calculated-1;   //current bar
     }


// Calculate ATR
   for (int i = start; i < rates_total  && !IsStopped() ; i++)
     {
      double atr = 0;
      for (int j = 0; j < atrLength; j++)
        {
         double trueRange = MathMax(high[i - j] - low[i - j], MathMax(MathAbs(high[i - j] - close[i - j - 1]), MathAbs(low[i - j] - close[i - j - 1])));
         atr += trueRange;
        }
      atr = atr/atrLength;
      ATRBuffer[i]=atr;

      double highest_high = MathMax(high[i-1], high[i]);
      double lowest_low = MathMin(low[i-1], low[i]);

      double barExt;

      if (highest_high - low[i-1] > high[i-1] - lowest_low)
         barExt = highest_high - low[i-1];  // upward direction
      else
         barExt = high[i-1] - lowest_low;  // downward direction

      RelativeMomentumBuffer[i] = barExt/2;
      // Calculate Relative Momentum
      //if (i >= priceChangeLength)
      //  {
      //   double price, priceprev;
      //   price=getPrice(PriceData,open,close,high,low,i);
      //   priceprev=getPrice(PriceData,open,close,high,low,i-priceChangeLength);
      //   RelativeMomentumBuffer[i] = MathAbs(price-priceprev) ; // just plotting absolute price change
      //  }
      ZeroLineBuffer[i] = 0;
     }

// Apply EMA smoothing
   for (int i = start; i < rates_total; i++)
     {
      if (i == start)
         SmoothedRelativeMomentumBuffer[i] = RelativeMomentumBuffer[i];
      else
         SmoothedRelativeMomentumBuffer[i] = (RelativeMomentumBuffer[i] - SmoothedRelativeMomentumBuffer[i - 1]) * (2.0 / (smoothingPeriod + 1)) + SmoothedRelativeMomentumBuffer[i - 1];
     }



   return(rates_total);
  }
//+------------------------------------------------------------------+
double getPrice(ENUM_APPLIED_PRICE tprice,const double &open[],const double &close[],const double &high[],const double &low[],int i)
  {
   if(i>=0)
      switch(tprice)
        {
         case PRICE_CLOSE:
            return(close[i]);
         case PRICE_OPEN:
            return(open[i]);
         case PRICE_HIGH:
            return(high[i]);
         case PRICE_LOW:
            return(low[i]);
         case PRICE_MEDIAN:
            return((high[i]+low[i])/2.0);
         case PRICE_TYPICAL:
            return((high[i]+low[i]+close[i])/3.0);
         case PRICE_WEIGHTED:
            return((high[i]+low[i]+close[i]+close[i])/4.0);
        }
   return(0);
  }
//+------------------------------------------------------------------+
