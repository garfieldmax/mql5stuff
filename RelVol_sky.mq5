// skynetgen clearer coloration. 2do - integrate stdDev and other signals from TOS
//4. 05 maxvol
//1.02 - 1.26.22 . StdDev implemented
//------------------------------------------------------------------
#property version   "1.02"
//------------------------------------------------------------------
#property indicator_separate_window
#property indicator_buffers 7
#property indicator_plots   5

#property indicator_label1  "Neutral | Bull | Bull BO | Bear | Bear BO | low volume "
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrOrange,clrGray,clrRed,clrGray,clrRed, clrBlack // Neutral, Bull
#property indicator_width1  2

#property indicator_label2  "Average"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDeepSkyBlue
#property indicator_width2  2

#property indicator_label3  "MinVol"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrMediumBlue
#property indicator_width3  2

#property indicator_label4  "MaxVol"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrMediumSeaGreen
#property indicator_width4  2

#property indicator_label5  "Vol Std Dev"
#property indicator_type5   DRAW_COLOR_ARROW
#property indicator_color5  clrCyan, clrViolet,clrOrange,clrBlack,clrNONE
#property indicator_width5  1
//---
enum enMaTypes
   {
   ma_sma,    // Simple moving average
   ma_ema,    // Exponential moving average
   ma_smma,   // Smoothed MA
   ma_lwma    // Linear weighted MA
   };
//---
enum enVolumeType
   {
   vol_ticks, // Use ticks
   vol_volume // Use real volume
   };
//--- input parameters
input enVolumeType inpVolumeType      = vol_ticks; // Volume type to use
input int          inpAveragePeriod   = 50;        // Average period
input int          PeriodMinBars   = 20; //  period to calculate minimum
input int          PeriodMaxBars   = 20; // period to calculate maximum
input enMaTypes    inpAverageMethod   = ma_lwma;    // Average method
input double       inpBreakoutPercent = 10;        // Breakout percentage
input int          StdDevPeriod = 50;        // Standard Deviation Period

input double numDev = 1.0;
input double ExtranumDev = 2.3;
input double MegaDev=4;
input double MinVolDev = -1.3;

//--- buffers
double  val[],valcolor[],average[]; //0-2
double MinVol[]; //3
double MaxVol[];//4
double plotVolStdDev[],plotVolStdDevColor[]; //6-7

//
double VolStdDev[];
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit()
   {

//---- indicator buffers mapping
   SetIndexBuffer(0,val,INDICATOR_DATA);
   SetIndexBuffer(1,valcolor,INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2,average,INDICATOR_DATA);
   
   SetIndexBuffer(3,MinVol,INDICATOR_DATA);
   PlotIndexSetDouble(2,PLOT_EMPTY_VALUE, EMPTY_VALUE); //minvol
   PlotIndexSetInteger(2,PLOT_ARROW,218); // wingdings http://www.alanwood.net/demos/wingdings.html
   
   SetIndexBuffer(4,MaxVol,INDICATOR_DATA);
   PlotIndexSetDouble(3,PLOT_EMPTY_VALUE, EMPTY_VALUE); //maxvol
   PlotIndexSetInteger(3,PLOT_ARROW,217); // wingdings http://www.alanwood.net/demos/wingdings.html
   PlotIndexSetInteger(3,PLOT_ARROW_SHIFT,10);
   
   
   
   SetIndexBuffer(5,plotVolStdDev,INDICATOR_DATA);
   SetIndexBuffer(6,plotVolStdDevColor,INDICATOR_COLOR_INDEX);
   PlotIndexSetDouble(4,PLOT_EMPTY_VALUE, EMPTY_VALUE); //maxvol
   PlotIndexSetInteger(4,PLOT_ARROW,233); // wingdings http://www.alanwood.net/demos/wingdings.html
   PlotIndexSetInteger(4,PLOT_ARROW_SHIFT,0);
//-------   
   string _avgNames[]= {"SMA","EMA","SMMA","LWMA"};
   IndicatorSetString(INDICATOR_SHORTNAME,"RelVol "+_avgNames[inpAverageMethod]+" Avg Period ("+(string)inpAveragePeriod+")");
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
   int min_rates_total=MathMax(inpAveragePeriod,PeriodMinBars);

   if(Bars(_Symbol,_Period)<rates_total  || rates_total<min_rates_total) return(-1);
   
   if(ArrayRange(VolStdDev,0)!=rates_total) ArrayResize(VolStdDev,rates_total);

   
   int i=(int)MathMax(prev_calculated-1,0);
   for(; i<rates_total && !_StopFlag; i++)
      {
      double _volume=double((inpVolumeType==vol_ticks) ? tick_volume[i]: volume[i]);
      double _avg = iCustomMa(inpAverageMethod,_volume,inpAveragePeriod,i,rates_total);
      average[i]  = 100;
      val[i]      = (_avg!=0) ? 100*_volume/_avg : 0;
      valcolor[i]     = 0;
      if(i>0 && close[i] > close[i-1])  valcolor[i] = (_volume > _avg*(1+inpBreakoutPercent*0.01)) ? 2 : 1; // Bull candles
      if(i>0 && close[i] < close[i-1])  valcolor[i] = (_volume > _avg*(1+inpBreakoutPercent*0.01)) ? 4 : 3; // Bear candles

   // calculate vplume maximum and minimums
      MinVol[i]=EMPTY_VALUE;
      MaxVol[i]=EMPTY_VALUE;
      int volmin_index=ArrayMinimum(val, ((i-PeriodMinBars)>0)? (i-PeriodMinBars) : 0, PeriodMinBars+1);
      int volmax_index=ArrayMaximum(val, ((i-PeriodMaxBars)>0)? (i-PeriodMaxBars) : 0, PeriodMaxBars+1);
      if(volmin_index==i)  //>0
         {
         valcolor[volmin_index]=5;
         MinVol[volmin_index]=(average[volmin_index]+val[volmin_index])/2;
         }

      if(volmax_index==i)
         {
         MaxVol[volmax_index]=val[volmax_index];
         }
      //2do just standard deviation is not enough. - see vol adj in TOS
      /*
      def avgvolume = expAverage(volume, avglength);
      def adjvol = if firstbars  then volume/5 else if lastbars then avgvolume[2]  else volume;         
      def rawRelVol = (adjvol - Average(adjvol , RelVollength)) / StDev(adjvol , RelVollength);
      def RelVol =  rawRelVol;
      
      def RelVolSignal= if  Relvol>MEgaDev then 4 
      */
      
      VolStdDev[i]=iDeviation(_volume,StdDevPeriod,false,i,rates_total);
      double relvol=(_volume-_avg)/VolStdDev[i];
      plotVolStdDev[i]=(relvol>numDev || relvol<MinVolDev)? val[i] : EMPTY_VALUE;
      plotVolStdDevColor[i]=(relvol>MegaDev)? 0: (relvol>ExtranumDev)? 1: (relvol>numDev)? 2: (relvol<MinVolDev)? 3 :4 ;
      }//end for

   return(rates_total);
   }

//mladen Deviation
//isSample - sample correction
double workDev[];
double iDeviation(double value, int length, bool isSample, int i, int bars)
   {
   if (ArraySize(workDev)!=bars) ArrayResize(workDev,bars);
   workDev[i] = value;
   double oldMean   = value;
   double newMean   = value;
   double squares   = 0;
   int k;
   for (k=1; k<length && (i-k)>=0; k++)
      {
      newMean  = (workDev[i-k]-oldMean)/(k+1)+oldMean;
      squares += (workDev[i-k]-oldMean)*(workDev[i-k]-newMean);
      oldMean  = newMean;
      }
   return(MathSqrt(squares/MathMax(k-isSample,1)));
   }

//+------------------------------------------------------------------+
//| Custom functions                                                 |
//+------------------------------------------------------------------+
#define _maInstances 1
#define _maWorkBufferx1 1*_maInstances
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double iCustomMa(int mode,double price,double length,int r,int bars,int instanceNo=0)
   {
   switch(mode)
      {
      case ma_sma   :
         return(iSma(price,(int)length,r,bars,instanceNo));
      case ma_ema   :
         return(iEma(price,length,r,bars,instanceNo));
      case ma_smma  :
         return(iSmma(price,(int)length,r,bars,instanceNo));
      case ma_lwma  :
         return(iLwma(price,(int)length,r,bars,instanceNo));
      default       :
         return(price);
      }
   }
double workSma[][_maWorkBufferx1];
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double iSma(double price,int period,int r,int _bars,int instanceNo=0)
   {
   if(ArrayRange(workSma,0)!=_bars) ArrayResize(workSma,_bars);
   workSma[r][instanceNo]=price;
   double avg=price;
   int k=1;
   for(; k<period && (r-k)>=0; k++) avg+=workSma[r-k][instanceNo];
   return(avg/(double)k);
   }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double workEma[][_maWorkBufferx1];
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double iEma(double price,double period,int r,int _bars,int instanceNo=0)
   {
   if(ArrayRange(workEma,0)!=_bars) ArrayResize(workEma,_bars);
   workEma[r][instanceNo]=price;
   if(r>0 && period>1)
      workEma[r][instanceNo]=workEma[r-1][instanceNo]+(2.0/(1.0+period))*(price-workEma[r-1][instanceNo]);
   return(workEma[r][instanceNo]);
   }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double workSmma[][_maWorkBufferx1];
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double iSmma(double price,double period,int r,int _bars,int instanceNo=0)
   {
   if(ArrayRange(workSmma,0)!=_bars) ArrayResize(workSmma,_bars);
   workSmma[r][instanceNo]=price;
   if(r>1 && period>1)
      workSmma[r][instanceNo]=workSmma[r-1][instanceNo]+(price-workSmma[r-1][instanceNo])/period;
   return(workSmma[r][instanceNo]);
   }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double workLwma[][_maWorkBufferx1];
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double iLwma(double price,double period,int r,int _bars,int instanceNo=0)
   {
   if(ArrayRange(workLwma,0)!=_bars) ArrayResize(workLwma,_bars);

   workLwma[r][instanceNo] = price;
   if(period<1) return(price);
   double sumw = period;
   double sum  = period*price;
   for(int k=1; k<period && (r-k)>=0; k++)
      {
      double weight=period-k;
      sumw  += weight;
      sum   += weight*workLwma[r-k][instanceNo];
      }
   return(sum/sumw);
   }
//+------------------------------------------------------------------+
