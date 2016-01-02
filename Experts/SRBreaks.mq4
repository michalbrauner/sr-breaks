//+------------------------------------------------------------------+
//|                                              SR_Breaks_1-0-0.mq4 |
//|                                                   Michal Brauner |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Michal Brauner"
#property link      "http://www.mql5.com"
#property version   "1.00"
#property strict

#include "SRBreaks/consts.mqh"
#include "SRBreaks/SRLevel.mqh"
#include "SRBreaks/TradeManagement.mqh"
#include "SRBreaks/TradeLevelToLockProfit.mqh"
#include "SRBreaks/Trade.mqh"

#include <Arrays/ArrayObj.mqh>
#include <MickyTools/OrderSendMarket.mqh>

//
// -------- Konfigurace - externi --------
//

// Koeficient pro urcovani velikosti TakeProfitu
extern double takeProfitKoefLong = 22;
extern double takeProfitKoefShort = 64;

//
// -------- Konfigurace - interni --------
//

double minimumTradeAmount = 0.01;

// DEMO ucty zacinaji 1, ostre zacinaji 2
int expertMagicNumber = 10010142;

// maximalni mozna ztrata v USD
double maxUsdLoss = 30;

// pocet riskovanych procent z uctu
double mmFF_maxLossPercent = 1.5;

// konfigurace pro vypocet urovni
extern int levelMinimumBars = 5;
extern int maxChangeInPips = 20;

   
//
// -------- Pomocne promenne --------
//

TradeManagement *tradeManagement;


//
// -------- Vykonna cast --------
//
int OnInit()
{

   if (!isEnabledSymbol())
   {
      Print("Nepovoleny symbol k obchodovani ('"+Symbol()+"')");
      return(INIT_PARAMETERS_INCORRECT);
   }
   if (IsDemo() && !(expertMagicNumber>=10000000 && expertMagicNumber<=19999999))
   {  
      Print("Spatne expertMagicNumber pro typ uctu (demo)");
      return(INIT_PARAMETERS_INCORRECT);
   }
   if (!IsDemo() && !(expertMagicNumber>=20000000 && expertMagicNumber<=29999999))
   {  
      Print("Spatne expertMagicNumber pro typ uctu (real)");
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   tradeManagement = new TradeManagement(expertMagicNumber);
   
   return(INIT_SUCCEEDED);
}


void OnDeinit(const int reason)
{

}


void OnTick()
{   
   static SRLevel *srLevel_support = new SRLevel();
   static SRLevel *srLevel_resistance = new SRLevel();  
   static SRLevel *srLevel_support_lastDrawn = NULL;
   static SRLevel *srLevel_resistance_lastDrawn = NULL;
         
   // Urcuje sentiment pro dny den - pro support se pricita 1, pro resistenci se odecita 1
   static int SRLevelSentiment = 0;
         
   // kontrola jiz ukoncenych obchodu
   tradeManagement.checkTrades();
      
   if (isNewBar())
   {               
      if (isNewDay())
      {
         SRLevelSentiment = 0;
      }
      
      // rozdil lows dvou predchozich svicek
      double lowDif = priceToPips(MathAbs(Low[1] - Low[2]));
      
      // rozdil highs dvou predchozich svicek
      double highDif = priceToPips(MathAbs(High[1] - High[2]));
      
      
      double stopLevel = MarketInfo(Symbol(), MODE_STOPLEVEL);
      
      double stopLoss = 0; 
      double takeProfit = 0;
      double volume = 0;
                 
      CArrayObj *tradeLockProfitAt = NULL;          
      Trade  *addedTrade = NULL;
      
      //
      // Zpracujeme support
      //
      if (srLevel_support.isInLevel(Low[1]))
      {  
         srLevel_support.increaseLength();
      }
      else
      {
         if (!srLevel_support.isEmpty() && srLevel_support.getLength()>=levelMinimumBars)
         {
            SRLevelSentiment++;
         
            srLevel_support.setEndTime(Time[2]);
            srLevel_support.drawLine(2, SRLevelSentiment);
            
            srLevel_support_lastDrawn = srLevel_support;
                             
            if (tradeManagement.getCountOfTrades()==0 || (SRLevel::areDisjunctive(srLevel_support, srLevel_resistance_lastDrawn) && tradeManagement.selectLastTrade() && OrderType() == OP_SELL))
            {                           
               // Otevreme novy LONG obchod
               if (canEnterATrade(SRLevelSentiment, Close[1], srLevel_support))
               {    
                  if (tradeManagement.isOpenedLastTrade())
                  {
                     // Zavreme naposledy otevreny obchod    
                     tradeManagement.closeLastTrade();
                  }
               
                  //           
                  // Vypocet stopLoss, takeProfit a volume
                  //       
                  stopLoss = Ask - NormalizeDouble(getStopLossSizeLongCurrent()*Point(),Digits);
                  //takeProfit = Ask + NormalizeDouble(getTakeProfitSizeLongCurrent()*Point(),Digits);
                  takeProfit = Ask + NormalizeDouble(getTakeProfitKoefLongCurrent()*(Ask-srLevel_support.levelMin),Digits);
                  //takeProfit = Ask + NormalizeDouble(takeProfitKoefLong*(Ask-srLevel_support.levelMin),Digits);

                  // Spocitame, kde mame locknout obchod                  
                  tradeLockProfitAt = generateTradesLockArray(TRADE_LONG);
                                                    
                  if (stopLoss>0 && Ask-stopLoss < stopLevel*Point)
                  {
                     stopLoss = stopLoss - (stopLevel*Point-(Ask-stopLoss));
                  }
            
                  if (takeProfit>0 && takeProfit-Ask < stopLevel*Point)
                  {
                     takeProfit = takeProfit + (stopLevel*Point-(takeProfit-Ask));
                  }
                  
                  volume = calculatePositionSizeWrapper(stopLoss, maxUsdLoss);
                  
                  //
                  // Otevreni obchodu
                  //
                  RefreshRates();
                  addedTrade = tradeManagement.addTrade(TRADE_LONG, volume, Ask, stopLoss, takeProfit, NULL);
                  
                  if (addedTrade)
                  {
                     addedTrade.setLevelsToLockProfit(tradeLockProfitAt);
                     addedTrade.setLevel(srLevel_support);
                  }
               }        
            }
         }
         
         srLevel_support = new SRLevel(SR_LEVEL_TYPE_SUPPORT, Low[1]-pipsToPrice(maxChangeInPips), Low[1]+pipsToPrice(maxChangeInPips));
         srLevel_support.setStartTime(Time[1]);
      }            
      
      
      //
      // Zpracujeme resistenci
      //
      if (srLevel_resistance.isInLevel(High[1]))
      {  
         srLevel_resistance.increaseLength();
      }
      else
      {
         if (!srLevel_resistance.isEmpty() && srLevel_resistance.getLength()>=levelMinimumBars)
         {
            SRLevelSentiment--;
         
            srLevel_resistance.setEndTime(Time[2]);
            srLevel_resistance.drawLine(2, SRLevelSentiment);            
            
            srLevel_resistance_lastDrawn = srLevel_resistance;
                                      
            if (tradeManagement.getCountOfTrades()==0 || (SRLevel::areDisjunctive(srLevel_resistance, srLevel_support_lastDrawn) && tradeManagement.selectLastTrade() && OrderType() == OP_BUY))
            {                           
               // Otevreme novy SHORT obchod
               if (canEnterATrade(SRLevelSentiment, Close[1], srLevel_resistance))
               {      
                  if (tradeManagement.isOpenedLastTrade())
                  {
                     // Zavreme naposledy otevreny obchod
                     tradeManagement.closeLastTrade();
                  }
               
                  //           
                  // Vypocet stopLoss, takeProfit a volume
                  //               
                  stopLoss = Bid + NormalizeDouble(getStopLossSizeShortCurrent()*Point(),Digits);
                  //takeProfit = Bid - NormalizeDouble(getTakeProfitSizeShortCurrent()*Point(),Digits);
                  takeProfit = Bid - NormalizeDouble(getTakeProfitKoefShortCurrent()*(Ask-srLevel_resistance.levelMin),Digits);
                  //takeProfit = Bid - NormalizeDouble(takeProfitKoefShort*(Ask-srLevel_resistance.levelMin),Digits);
                  
                  // Spocitame, kde mame locknout obchod                  
                  tradeLockProfitAt = generateTradesLockArray(TRADE_SHORT);
                                    
                  if (stopLoss>0 && stopLoss-Bid < stopLevel*Point)
                  {
                     stopLoss = stopLoss + (stopLevel*Point-(stopLoss-Bid));
                  }
            
                  if (takeProfit>0 && Bid-takeProfit < stopLevel*Point)
                  {
                     takeProfit = takeProfit - (stopLevel*Point-(Bid-takeProfit));
                  }
                  
                  volume = calculatePositionSizeWrapper(stopLoss, maxUsdLoss);
                  
                  //
                  // Otevreni obchodu
                  //
                  RefreshRates();
                  addedTrade = tradeManagement.addTrade(TRADE_SHORT, volume, Bid, stopLoss, takeProfit, NULL);
                  
                  if (addedTrade)
                  {
                     addedTrade.setLevelsToLockProfit(tradeLockProfitAt);
                     addedTrade.setLevel(srLevel_resistance);
                  }
               }
            }  
         }
         
         srLevel_resistance = new SRLevel(SR_LEVEL_TYPE_RESISTANCE, High[1]-pipsToPrice(maxChangeInPips), High[1]+pipsToPrice(maxChangeInPips));
         srLevel_resistance.setStartTime(Time[1]);
      }            
      
   }
}

//
// ===============================
// Funkce
// ===============================
//

// Zjisti, jestli se jedna o povoleny symbol k obchodovani
bool isEnabledSymbol()
{
   string symbol = Symbol();
   
   if (symbol=="EURUSD" || symbol=="GBPUSD" || symbol=="EURJPY")
   {
      return(true);
   }
   
   return(false);
}

// Zjisti, jestli muze vstoupit do obchodu
bool canEnterATrade(int sentiment, double priceClose, SRLevel *level)
{
   string symbol = Symbol();
   bool ret = false;
   
   double rsiValue = NormalizeDouble(iRSI(Symbol(), PERIOD_H4, 7, PRICE_WEIGHTED, 0), Digits);
   
   double iEmaHistory = iMA(Symbol(), PERIOD_H1, 40, 0, MODE_EMA, PRICE_WEIGHTED, 28);
   double iEmaCurrent = iMA(Symbol(), PERIOD_H1, 40, 0, MODE_EMA, PRICE_WEIGHTED, 0);
   
   
   if (checkTradingHours())
   {
      if (level.getType()==SR_LEVEL_TYPE_SUPPORT)
      {
         if (symbol=="EURUSD")
         {
            if (sentiment>0 && priceClose<level.levelMax)
            {
               ret = true;
            }
         }
         else
         if (symbol=="GBPUSD" || symbol=="EURJPY")
         {
            if (sentiment>0 && priceClose>level.levelMax)
            {
               ret = true;
            }
         }
         
         // Kontrola RSI
         if (rsiValue>80)
         {
            ret = false;
         }
         
         // Kontrola EMA
         if (iEmaHistory >= iEmaCurrent)
         {
            //ret = false;
         }
         
         
      }
      else
      if (level.getType()==SR_LEVEL_TYPE_RESISTANCE)
      {
         if (symbol=="EURUSD")
         {
            if (sentiment<0 && priceClose>level.levelMin)
            {
               ret = true;
            
            }
         }
         else
         if (symbol=="GBPUSD" || symbol=="EURJPY")
         {
            if (sentiment<0 && priceClose>level.levelMin)
            {
               ret = true;
            }
         }
         
         // Kontrola RSI
         if (rsiValue<20)
         {
            ret = false;
         }
         
         // Kontrola EMA
         if (iEmaHistory <= iEmaCurrent)
         {
            //ret = false;
         }
      }
   }
   
   return(ret);
}

// Vrati pole objektu, pro uzamykani profitu
CArrayObj *generateTradesLockArray(string tradeType)
{
   // Spocitame, kde mame locknout obchod                  
   CArrayObj *tradeLockProfitAt = new CArrayObj();                             
   tradeLockProfitAt.Sort();
   
   int slStepKoefInPipsLong = 50;
   int slStepKoefInPipsShort = 50;
      
   int slStepKoefInPips = 0;
   
   if (tradeType==TRADE_LONG)
   {      
      for (int i=1; i<=10; i++)
      {
         if (i<=5)
         {
            slStepKoefInPips = slStepKoefInPipsLong;
         }
         else
         {
            slStepKoefInPips = slStepKoefInPipsLong + 70;
         }
         tradeLockProfitAt.InsertSort(new TradeLevelToLockProfit(i, Ask + NormalizeDouble(400*i*Point(),Digits), Ask + NormalizeDouble(i*slStepKoefInPips*Point(),Digits)));
      }
   }
   
   if (tradeType==TRADE_SHORT)
   {      
      for (int i=1; i<=10; i++)
      {
         if (i<=5)
         {
            slStepKoefInPips = slStepKoefInPipsShort;
         }
         else
         {
            slStepKoefInPips = slStepKoefInPipsShort + 70;
         }
         tradeLockProfitAt.InsertSort(new TradeLevelToLockProfit(i, Bid - NormalizeDouble(400*i*Point(),Digits), Bid - NormalizeDouble(i*slStepKoefInPips*Point(),Digits)));
      }
   }
   
   return(tradeLockProfitAt);
}


// Zjisti, jestli je jedna o novou svicku
bool isNewBar()
{
   static datetime barTime = 0;
   bool isNewBar = false;
   
   if (barTime == 0 || barTime!=Time[0])
   {
      barTime = Time[0];
      isNewBar = true;
   }
   
   return(isNewBar);
}

// Zjisti, jestli se jedna  novy den
bool isNewDay()
{
   static string dayTime = "";
   bool isNewDay = false;
   
   string tmpDayTime = TimeYear(Time[0]) + "-" + TimeDayOfYear(Time[0]);
   
   if (dayTime == "" || dayTime!=tmpDayTime)
   {
      dayTime =  tmpDayTime;
      isNewDay = true;
   }
   
   return(isNewDay);
}

// Prevod ceny na pipsy
int priceToPips(double price)
{  
   return(price * MathPow(10, MarketInfo(Symbol(), MODE_DIGITS)));
}

// Prevod pipsu na cenu
double pipsToPrice(int pips)
{  
   return(pips / MathPow(10, MarketInfo(Symbol(), MODE_DIGITS)));
}

/*
 * Hlavni funkce pro vypocet obchodovane pozice
 */
double calculatePositionSizeWrapper(double stopLossPips, double maxUsdLoss)
{   
   return (0.03);
   
   if (stopLossPips>0)
   {
      //return(calculatePositionSizeFF(stopLossPips));
      //return(calculatePositionSize(stopLossPips, maxUsdLoss));
   }
   
   return(minimumTradeAmount);
}


/**
 * Podle SL spocita, jako velkou pozici muzeme obchodovat, aby byla
 * zachovana maximalni mozna ztrata v USD
 */
double calculatePositionSize(double stopLossPips, double maxUsdLoss)
{  
   double pipValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   
   double stopLossUsd = 0, stopLossUsdTemp = 0;
   double positionSize = 0, positionSizeTemp = minimumTradeAmount;
   double positionSizeIncrement = 0.01;       
         
   while (true)
   {
      stopLossUsdTemp = NormalizeDouble(stopLossPips * pipValue * positionSizeTemp, 2);
   
      if (stopLossUsdTemp<maxUsdLoss)
      {
         positionSizeTemp += positionSizeIncrement;
         stopLossUsd = stopLossUsdTemp;
         positionSize = positionSizeTemp;
      }
      else
      {
         break;
      }
   }
   
   if (positionSize==0)
   {
      positionSize = minimumTradeAmount;
   }
               
   return(positionSize);
}

double calculatePositionSizeFF(double stopLossPips)
{
   double pipValue = MarketInfo(Symbol(), MODE_TICKVALUE);   
   double currentCapital = AccountBalance();
      
   double maxUsdLoss = NormalizeDouble(currentCapital * (mmFF_maxLossPercent/100),2);

   return( calculatePositionSize(stopLossPips, maxUsdLoss) );    
}

//
// Funkce pro pocitani velikosti stoplossu na zaklade volatility
//

// Long
int getStopLossSizeLongCurrent()
{   
   int stopLossSizeLongKoef = 5;
   int stopLossSizeLongBarsInHistory = 200;   
   
   double avgVolatility = 0;
   double sum = 0;
   int count = 0;
   
   for (int i=1; i<=stopLossSizeLongBarsInHistory; i++)
   {
      sum = sum + (High[i]-Low[i])/Point;
      count = count+1;
   }
   
   avgVolatility = sum / count;
   
   return( MathRound(avgVolatility)*stopLossSizeLongKoef );
}

// Short
int getStopLossSizeShortCurrent()
{      
   int stopLossSizeShortKoef = 2;
   int stopLossSizeShortBarsInHistory = 50;

   double avgVolatility = 0;
   double sum = 0;
   int count = 0;
   
   for (int i=1; i<=stopLossSizeShortBarsInHistory; i++)
   {
      sum = sum + (High[i]-Low[i])/Point;
      count = count+1;
   }
   
   avgVolatility = sum / count;
   
   return( MathRound(avgVolatility)*stopLossSizeShortKoef );
}


//
// Funkce pro pocitani velikosti take profitu na zaklade volatility
//
// Long
int getTakeProfitKoefLongCurrent()
{   
   return(takeProfitKoefLong);
   
   /*
   int takeProfitSizeLongKoef = 30;
   
   double avgVolatility = 0;
   double sum = 0;
   int count = 0;
   
   for (int i=1; i<=200; i++)
   {
      sum = sum + (High[i]-Low[i])/Point;
      count = count+1;
   }
   
   avgVolatility = sum / count;
   
   return( MathRound(avgVolatility)*takeProfitSizeLongKoef );
   */
}

// Short
int getTakeProfitKoefShortCurrent()
{   
   return(takeProfitKoefShort);
   /*
   int takeProfitSizeLongKoef = 30;
   
   double avgVolatility = 0;
   double sum = 0;
   int count = 0;
   
   for (int i=1; i<=200; i++)
   {
      sum = sum + (High[i]-Low[i])/Point;
      count = count+1;
   }
   
   avgVolatility = sum / count;
   
   return( MathRound(avgVolatility)*takeProfitSizeLongKoef );
   */
}


// Vrati prumernou volatilitu
double getAvgVolatility()
{
   double avgVolatility = 0;
   double sum = 0;
   int count = 0;
   
   for (int i=1; i<=200; i++)
   {
      sum = sum + (High[i]-Low[i])/Point;
      count = count+1;
   }
   
   avgVolatility = sum / count;
   
   return(avgVolatility);
}


/**
 * Zkontroluje jestli je povoleny cas k obchodovani
 */
bool checkTradingHours()
{
   datetime tradingHours[1,2]; 
   string dayLocal = TimeYear(TimeCurrent())+"."+TimeMonth(TimeCurrent())+"."+TimeDay(TimeCurrent());
   
   tradingHours[0][0] = StrToTime(dayLocal+" 00:00:00"); tradingHours[0][1] = StrToTime(dayLocal+" 23:59:59");
   
   int i, tradingHoursCount = ArrayRange(tradingHours, 0);
   datetime currentTime = TimeCurrent();
   bool isInTradingHours = false;

   if (tradingHoursCount>0)
   {
      for (i=0; i<tradingHoursCount; i++)
      {  
         if (tradingHours[i][0]>0 && tradingHours[i][1]>0)
         {
            isInTradingHours = tradingHours[i][0]<=currentTime && currentTime<=tradingHours[i][1];     
         }
         
         // Pokud jsou obchodni hodiny, muzeme rovnou vyskocit z cyklu :)
         if (isInTradingHours)
         {
            break;
         }
      }
   }
   
   return(isInTradingHours);
}