//+------------------------------------------------------------------+
//|                                                        Trade.mqh |
//|                                                   Michal Brauner |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Michal Brauner"
#property link      "http://www.mql5.com"
#property version   "1.00"
#property strict

#include "consts.mqh"
#include "TradeLevelToLockProfit.mqh"
#include "SRLevel.mqh"

#include <Arrays/ArrayInt.mqh>
#include <Arrays/ArrayDouble.mqh>
#include <Arrays/ArrayObj.mqh>

//
// This class encapsulates one trade
//

class Trade : public CObject
{
   private:
        
      int orderTicket;
      
      // extra trades added in order to increase position size
      CArrayObj *extraAddedTrades;
      
      // the price where profit will be locked
      CArrayObj *levelsToLockProfit;
      
      // the minimum price during since trade opening time
      double priceMinimum;
      
      // the maximum price during since trade opening time
      double priceMaximum;
      
      int maxSlippage;
      
      // SR level in relation with trade
      SRLevel *level;
      
      // counter - how often is trade in a profit or in a loss
      int totalInLoss;
      int totalInProfit;
      
      // profit values - current and last
      double profitLast;
      double profitCurrent;
      
      int magic;
      
      double avgVolatilityAtStart;
            
      // Processes the trade with ATR value - moving profit target
      bool processTradeByAtrValue()
      {  
         bool result = true;
         
         int atrHistoryOffset = 3;
         int addPipsByAtr = 150;
                
         //
         // should we move take profit because of increasing ATR?
         //   
         double atrCurrent = iATR(Symbol(), 0, 7, 0);
         double atrHistorical = iATR(Symbol(), 0, 7, atrHistoryOffset);
         double newStopLoss = 0, newTakeProfit = 0;
         
         double stopLevel = MarketInfo(Symbol(), MODE_STOPLEVEL)*Point;
         
         
         //
         // Increasing volatility check
         //
         if (atrCurrent>atrHistorical)
         {  
            if (OrderSelect(this.orderTicket,SELECT_BY_TICKET))
            {                             
               if (OrderMagicNumber()==this.magic && OrderProfit()>0)
               {
                  //
                  // If we are in a profit, we move take profit (ATR increases)
                  //                  
                  if (OrderType()==OP_BUY && (OrderTakeProfit()-Bid)<addPipsByAtr*Point )
                  {
                     newTakeProfit = OrderTakeProfit() + addPipsByAtr*Point;
                  
                     if (newTakeProfit>Bid+stopLevel)
                     {
                        result = OrderModify(this.orderTicket, OrderOpenPrice(), OrderStopLoss(), newTakeProfit, OrderExpiration(), DarkViolet);
                     }
                  }
                  else
                  if (OrderType()==OP_SELL && (Ask-OrderTakeProfit())<addPipsByAtr*Point)
                  {
                     newTakeProfit = OrderTakeProfit() - addPipsByAtr*Point;
                  
                     if (newTakeProfit<Bid-stopLevel)
                     {
                        result = OrderModify(this.orderTicket, OrderOpenPrice(), OrderStopLoss(), newTakeProfit, OrderExpiration(), MediumSpringGreen);
                     }
                  }
               }
            }  
         }
         
         return(result);
      }
      
      //
      // Adds an extra LONG trade
      //
      Trade *addExtraLongTrade(double volume, double price, double stopLoss, double takeProfit, string comment)
      {
         Trade *trade = NULL;
         
         ResetLastError();
         int orderTicket = OrderSendMarket(Symbol(), OP_BUY, volume, price, this.maxSlippage, stopLoss, takeProfit, comment, this.magic, 0, clrBlue);
         
         if (orderTicket==-1)
         {
            Print("ERROR - LONG trade couldn't be added: volume="+volume+", price="+price+", stopLoss="+stopLoss+", takeProfit="+takeProfit+", lastError="+GetLastError());
         }
         else
         {
            if (this.extraAddedTrades == NULL)
            {
               this.extraAddedTrades = new CArrayObj();
               this.extraAddedTrades.Sort();
            }
            else
            {
               Trade *t = NULL;
               
               // we'll close all extra trades in order to lock a profit :)
               for (int i=0; i<this.extraAddedTrades.Total(); i++)
               {
                  t = this.extraAddedTrades.At(i);
                  t.closeTrade();
               }
               
            }
            
            
            trade = new Trade(orderTicket, this.maxSlippage, this.magic);
            this.extraAddedTrades.InsertSort(trade);
         }
         
         return(trade);
      }
      
      //
      // Adds an extra SHORT trade
      //
      Trade *addExtraShortTrade(double volume, double price, double stopLoss, double takeProfit, string comment)
      {
         Trade *trade = NULL;
         
         ResetLastError();
         int orderTicket = OrderSendMarket(Symbol(), OP_SELL, volume, price, this.maxSlippage, stopLoss, takeProfit, comment, this.magic, 0, clrRed);
         
         if (orderTicket==-1)
         {
            Print("ERROR - SHORT trade couldn't be added: volume="+volume+", price="+price+", stopLoss="+stopLoss+", takeProfit="+takeProfit+", lastError="+GetLastError());
         }
         else
         {
            if (this.extraAddedTrades == NULL)
            {
               this.extraAddedTrades = new CArrayObj();
               this.extraAddedTrades.Sort();
            }
            else
            {
               Trade *t = NULL;
               
               // we'll close all extra trades in order to lock a profit :)
               for (int i=0; i<this.extraAddedTrades.Total(); i++)
               {
                  t = this.extraAddedTrades.At(i);
                  t.closeTrade();
               }
            }
            
            trade = new Trade(orderTicket, this.maxSlippage, this.magic);
            this.extraAddedTrades.InsertSort(trade);
         }
         
         return(trade);
      }
      
      //
      // We check all extra added trades
      //
      void checkExtraTrades()
      {         
         if (this.extraAddedTrades!=NULL && this.extraAddedTrades.Total()>0)
         {
            Trade *t = NULL;
            bool closed = false;
            
            double stopLevel = MarketInfo(Symbol(), MODE_STOPLEVEL);
            
            for (int i=0; i<this.extraAddedTrades.Total(); i++)
            {            
               t = this.extraAddedTrades.At(i);
               
               // If the trade was closed (by stop loss or manually), we have to remove it from an array
               if (t.isClosed())
               {
                  t.onClose();
                  this.extraAddedTrades.Delete(i);  
               }
            }
         }
      }
      
      //
      // Close all extra added trades
      //
      void closeExtraTrades()
      {
         if (this.extraAddedTrades!=NULL && this.extraAddedTrades.Total()>0)
         {
            Trade *t = NULL;
            bool closed = false;
                                   
            for (int i=this.extraAddedTrades.Total()-1; i>=0; i--)
            {
               ResetLastError();
            
               t = this.extraAddedTrades.At(i);
               
               if (t.isClosed())
               {
                  closed = true;
               }
               else
               {
                  closed = t.closeTrade();
               }
                  
               if (closed)
               {
                  t.onClose();
                  this.extraAddedTrades.Delete(i);
               }
               else
               {
                  GetLastError();
               }   
            }
         }
      }
      
      static bool isNewBar()
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
      
   public:
      
      void Trade(int orderTicket, int maxSlippage, int magic)
      {
         this.orderTicket = orderTicket;
         this.levelsToLockProfit = NULL;
         this.extraAddedTrades = NULL;
         this.priceMinimum = 0;
         this.priceMaximum = 0;
         this.maxSlippage = maxSlippage;
         this.level = NULL;
         this.totalInLoss = 0;
         this.totalInProfit = 0;
         this.profitLast = 0;
         this.profitCurrent = 0;
         this.magic = magic;
         this.avgVolatilityAtStart = getAvgVolatility();
      }
      
      void setLevel(SRLevel *level)
      {
         this.level = level;
      }
      
      void setLevelsToLockProfit(CArrayObj *levelsToLockProfit)
      {
         this.levelsToLockProfit = levelsToLockProfit;
      }
      
      // The function called after trade closes
      // Should by called before removing from an array of trades
      void onClose()
      {
         // Closing all extra trades
         this.closeExtraTrades();
         
         if (OrderSelect(this.orderTicket,SELECT_BY_TICKET))
         {
            string tradeType = OrderType()==OP_BUY ? "LONG" : "SHORT";
            Print("CLOSED - Trace closed ("+tradeType+" ): orderTicket="+this.orderTicket+", priceMinimum="+this.priceMinimum+", priceMaximum="+this.priceMaximum+", percentInProfit="+this.getPercentTimeInProfit()+", avgVolatility="+this.avgVolatilityAtStart,", profit="+OrderProfit());
         }
      }
      
      // Close a trade
      bool closeTrade()
      {
         bool closed = false;
         
         if (!this.isClosed() && OrderSelect(this.orderTicket,SELECT_BY_TICKET))
         {
            if (OrderMagicNumber()==this.magic)
            {
               RefreshRates();
               
               double price = OrderType()==OP_BUY ? Bid : Ask;
               color clr = OrderType()==OP_BUY ? clrBlue : clrRed;
               
               closed = OrderClose(this.orderTicket, OrderLots(), price, this.maxSlippage, clr);
            }
         }
         
         return(closed);
      }
      
      // Check a trade and if neccessary, make an action (eg. move stop loss)
      // Should be called per each tick
      bool checkTrade()
      {
         double newStopLoss = 0, newStopLossExtraTrade = 0;
         double stopLevel = MarketInfo(Symbol(), MODE_STOPLEVEL);
         
         if (OrderSelect(this.orderTicket,SELECT_BY_TICKET))
         {
            if (OrderMagicNumber()==this.magic)
            {
               if (this.isOpened())
               {
                  this.profitLast = this.profitCurrent;
                  this.profitCurrent = OrderProfit();
                  
                  //
                  // Counters update 
                  //
                  if (OrderProfit()>=0)
                  {
                     this.totalInProfit = this.totalInProfit+1;
                  }
                  else
                  {
                     this.totalInLoss = this.totalInLoss+1;
                  }
                  
                  //
                  // priceMinimum and priceMaximum update
                  //
                  if (OrderType()==OP_BUY)
                  {
                     if (this.priceMinimum==0 || Ask<this.priceMinimum)
                     {
                        this.priceMinimum = Ask;
                     }
                     
                     if (this.priceMaximum==0 || Ask>this.priceMaximum)
                     {
                        this.priceMaximum = Ask;
                     }
                     
                  }
                  else
                  if (OrderType()==OP_SELL)
                  {
                     if (this.priceMinimum==0 || Bid<this.priceMinimum)
                     {
                        this.priceMinimum = Bid;
                     }
                     
                     if (this.priceMaximum==0 || Bid>this.priceMaximum)
                     {
                        this.priceMaximum = Bid;
                     }
                  }
                                 
                  if (Trade::isNewBar())
                  {                                                   
                     //
                     // Processing RSI
                     //
                     double rsiValue = NormalizeDouble(iRSI(Symbol(), PERIOD_D1, 7, PRICE_WEIGHTED, 0), Digits);
                     
                     if (OrderType()==OP_BUY && rsiValue>80)
                     {
                        //this.closeTrade();
                     }
                     else
                     if (OrderType()==OP_SELL && rsiValue<20)
                     {
                        //this.closeTrade();
                     }
                     
                     if ((this.totalInLoss / (this.totalInLoss+this.totalInProfit))*100 > 80 && TimeCurrent()-OrderOpenTime()>60*60*12)
                     {
                        //this.closeTrade();
                     }
                                          
                     //
                     // Processing ATR
                     //
                     //this.processTradeByAtrValue();
                     
                     if (!this.isClosed())
                     {
                        //
                        // Processing profit locking
                        //
                        if (this.levelsToLockProfit.Total())
                        {
                           TradeLevelToLockProfit *lockProfit = NULL;
                           
                           for (int i=0; i<this.levelsToLockProfit.Total(); i++)
                           {
                              lockProfit = this.levelsToLockProfit.At(i);
                              
                              if (OrderType()==OP_BUY)
                              {
                                 if (Ask>=lockProfit.getPriceLockAt())
                                 {
                                    newStopLoss = lockProfit.getNewStopLoss();
                                    
                                    if (newStopLoss>0 && Ask-newStopLoss < stopLevel*Point)
                                    {
                                       newStopLoss = newStopLoss - (stopLevel*Point-(Ask-newStopLoss));
                                    }
                                    
                                    newStopLoss = NormalizeDouble(newStopLoss, Digits);
                                        
                                    if (OrderStopLoss()!=newStopLoss)
                                    {                  
                                       if (OrderModify(this.orderTicket, OrderOpenPrice(), newStopLoss, OrderTakeProfit(), OrderExpiration()))
                                       {
                                          if (this.totalInProfit>this.totalInLoss)
                                          {
                                             newStopLossExtraTrade = Ask - 600*Point;
                                             
                                             if (newStopLossExtraTrade<newStopLoss)
                                             {
                                                newStopLossExtraTrade = newStopLoss;
                                             }
                                             
                                             if (newStopLossExtraTrade>0 && Ask-newStopLossExtraTrade < stopLevel*Point)
                                             {
                                                newStopLossExtraTrade = newStopLossExtraTrade - (stopLevel*Point-(Ask-newStopLossExtraTrade));
                                             }
                                             
                                             // We add an extra trade
                                             RefreshRates();
                                             //this.addExtraLongTrade(OrderLots(), Ask, newStopLossExtraTrade, OrderTakeProfit(), "");
                                             
                                             // We remove a lock level
                                             this.levelsToLockProfit.Delete(i);
                                          }
                                       }
                                    }
                                 }
                              }
                              else
                              if (OrderType()==OP_SELL)
                              {
                                 if (Bid<=lockProfit.getPriceLockAt())
                                 {
                                    newStopLoss = lockProfit.getNewStopLoss();
                                    
                                    if (newStopLoss>0 && newStopLoss-Bid < stopLevel*Point)
                                    {
                                       newStopLoss = newStopLoss + (stopLevel*Point-(newStopLoss-Bid));
                                    }
                                    
                                    newStopLoss = NormalizeDouble(newStopLoss, Digits);
                                           
                                    if (newStopLoss!=OrderStopLoss())
                                    {
                                       if (OrderModify(this.orderTicket, OrderOpenPrice(), newStopLoss, OrderTakeProfit(), OrderExpiration()))
                                       {
                                          if (this.totalInProfit>this.totalInLoss)
                                          {
                                             newStopLossExtraTrade = Bid + 600*Point;
                                             
                                             if (newStopLossExtraTrade>newStopLoss)
                                             {
                                                newStopLossExtraTrade = newStopLoss;
                                             }
                                             
                                             if (newStopLossExtraTrade>0 && newStopLossExtraTrade-Bid < stopLevel*Point)
                                             {
                                                newStopLossExtraTrade = newStopLossExtraTrade + (stopLevel*Point-(newStopLossExtraTrade-Bid));
                                             }                                             
                                             
                                             // We add an extra trade
                                             RefreshRates();
                                             //this.addExtraShortTrade(OrderLots(), Bid, newStopLossExtraTrade, OrderTakeProfit(), "");
                                             
                                             // We remove a lock level
                                             this.levelsToLockProfit.Delete(i);
                                          }
                                       }
                                    }
                                 }
                              }
                           }
                        }
                     }
                  }
               }
            }
         }
         
         // Extra trade check
         this.checkExtraTrades();
         
         return(false);
      }
            
      // Returns if trade is open
      bool isOpened()
      {
         if (OrderSelect(this.orderTicket,SELECT_BY_TICKET))
         {
            if (OrderCloseTime()==0 && (OrderType()==OP_SELL || OrderType()==OP_BUY))
            {
               return(true);
            }
         }
         return(false);
      }
      
      // Returns if trade is closed
      bool isClosed()
      {
         if (OrderSelect(this.orderTicket,SELECT_BY_TICKET))
         {
            if (OrderCloseTime()!=0)
            {
               return(true);
            }
         }
         return(false);
      }
      
      int getOrderTicket()
      {
         return(this.orderTicket);
      }
      
      // Returns a percentage of time in profit
      double getPercentTimeInProfit()
      {
         if (this.totalInLoss>0 || this.totalInProfit>0)
         {
            double percent = (double)(this.totalInProfit / ((double)this.totalInProfit + (double)this.totalInLoss)) * 100;
            return(NormalizeDouble(percent,2));
         }
         return(0);
      }
      
      // TODO: Check if this function is in use :)
      virtual int Compare(Trade *node, int mode=0)
      { 
         if (node.orderTicket>this.orderTicket)
         {
            return(1);
         }
         else
         if (node.orderTicket<this.orderTicket)
         {
            return(-1);
         }

         return(0);      
      }
};