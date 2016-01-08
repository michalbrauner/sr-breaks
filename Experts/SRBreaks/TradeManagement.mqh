//+------------------------------------------------------------------+
//|                                              TradeManagement.mqh |
//|                                                   Michal Brauner |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Michal Brauner"
#property link      "http://www.mql5.com"
#property strict

#include "consts.mqh"
#include "Trade.mqh"

#include <Arrays/ArrayObj.mqh>
#include <MickyTools/OrderSendMarket.mqh>


//
// The class for trade management
//

class TradeManagement
{
   private:
      // The array of opened trades
      CArrayObj *trades;
            
      int magic;
      
      int maxSlippage;
      
      //
      // Opens a new long trade
      //
      Trade *addLongTrade(double volume, double price, double stopLoss, double takeProfit, string comment)
      {
         Trade *trade = NULL;
         
         ResetLastError();
         int orderTicket = OrderSendMarket(Symbol(), OP_BUY, volume, price, this.maxSlippage, stopLoss, takeProfit, comment, this.magic, 0, clrBlue);
         
         if (orderTicket==-1)
         {
            Print("ERROR - LONG trade couldn't be opened: volume="+volume+", price="+price+", stopLoss="+stopLoss+", takeProfit="+takeProfit+", lastError="+GetLastError());
         }
         else
         {
            trade = new Trade(orderTicket, this.maxSlippage, this.magic);
            this.trades.InsertSort(trade);
         }
         
         return(trade);
      }
      
      
      //
      // Opens a new short trade
      //
      Trade *addShortTrade(double volume, double price, double stopLoss, double takeProfit, string comment)
      {
         Trade *trade = NULL;
         
         ResetLastError();
         int orderTicket = OrderSendMarket(Symbol(), OP_SELL, volume, price, this.maxSlippage, stopLoss, takeProfit, comment, this.magic, 0, clrRed);
         
         if (orderTicket==-1)
         {
            Print("ERROR - SHORT trade couldn't be opened: volume="+volume+", price="+price+", stopLoss="+stopLoss+", takeProfit="+takeProfit+", lastError="+GetLastError());
         }
         else
         {
            trade = new Trade(orderTicket, this.maxSlippage, this.magic);
            this.trades.InsertSort(trade);
         }
         
         return(trade);
      }
      
      //
      // Returns a trade position by orderTicket
      //
      int searchTradePositionByOrderTicket(int orderTicket)
      {         
         if (this.trades.Total()>0)
         {
            for (int i=0; i<this.trades.Total(); i++)
            {
               Trade *t = this.trades.At(i);
               
               if (t.getOrderTicket()==orderTicket)
               {
                  return(i);
               }
            }
         }
         
         return(-1);         
      }
      
      //
      // Closes the trade
      //
      bool closeTrade(int orderTicketToClose)
      {
         bool closed = false;
      
         int tradePosition = this.searchTradePositionByOrderTicket(orderTicketToClose);
         Trade *trade = NULL;
         
         int orderTicket = -1;
         
         if (tradePosition>=0)
         {
            trade = this.trades.At(tradePosition);
            
            if (trade!=NULL)
            {
               orderTicket = trade.getOrderTicket();
               
               ResetLastError();
               if (OrderSelect(orderTicket,SELECT_BY_TICKET))
               {
                  closed = trade.closeTrade();
                  
                  if (closed)
                  {
                     trade.onClose();
                     this.trades.Delete(tradePosition);
                  }
                  else
                  {
                     GetLastError();
                  }
               }
               else
               {
                  GetLastError();
               }
            }
         }
         
         return(closed);
      }
      
      //
      // Select a trade by an index
      //
      bool selectTrade(int index)
      {
         int orderTicket = this.getOrderTicket(index);
         
         if (orderTicket!=-1)
         {
            return(OrderSelect(orderTicket,SELECT_BY_TICKET));
         }
         
         return false;
      }
      
      //
      // Returns last ticket that was added
      //
      int getLastOrderTicket()
      {
         if (this.trades.Total()>0)
         {
            return(this.getOrderTicket(this.trades.Total()-1));
         }
         return(-1);
      }
      
      //
      // Returns the ticket number with given index
      //
      int getOrderTicket(int index)
      {
         Trade *trade = NULL;
         
         if (this.trades.Total()>=index+1)
         {
            trade = this.trades.At(index);
            return(trade.getOrderTicket());
         }
         return(-1);
      }
                  
   public:
   
      void TradeManagement(int magic)
      {
         this.magic = magic;
         this.maxSlippage = 30;
         
         this.trades = new CArrayObj();
         this.trades.Sort();
      }
      
      //
      // Open a new trade
      //
      Trade *addTrade(string tradeType, double volume, double price, double stopLoss, double takeProfit, string comment)
      {
         Trade *trade = NULL;
         
         if (tradeType==TRADE_LONG)
         {
            trade = this.addLongTrade(volume, price, stopLoss, takeProfit, comment);
         }
         else
         if (tradeType==TRADE_SHORT)
         {
            trade = this.addShortTrade(volume, price, stopLoss, takeProfit, comment);
         }
         
         return(trade);
      }
            
      //
      // Close trade that was opened last
      //
      bool closeLastTrade()
      {
         int lastOrderTicket = this.getLastOrderTicket();
         
         if (lastOrderTicket!=-1)
         {
            return(this.closeTrade(lastOrderTicket));
         }
         
         return false;
      }
      
      //
      // Check if the last opened trade is still opened
      //
      bool isOpenedLastTrade()
      {
         if (this.selectLastTrade())
         {
            if ((OrderType()==OP_BUY || OrderType()==OP_SELL) && OrderCloseTime()==0)
            {
               return(true);
            }
         }
         
         return(false);
      }
            
      //
      // Select the trade that was added last
      //
      bool selectLastTrade()
      {
         if (this.trades.Total()>0)
         {
            return(this.selectTrade(this.trades.Total()-1));
         }
         
         return false;
      }
      
      //
      // Returns the number of opened trades
      //
      int getCountOfTrades()
      {
         return(this.trades.Total());
      }  
      
      //
      // Find already closed trades that were closed at stop loss or take profit price
      // Should be called per each tick
      //
      void checkTrades()
      {
         if (this.trades.Total()>0)
         {
            for (int i=0; i<this.trades.Total(); i++)
            {
               if (this.selectTrade(i))
               {
                  Trade *t = this.trades.At(i);
                  
                  if (t.isClosed())
                  {
                     // If the trade is closed, we have to remove it
                     t.onClose();
                     this.trades.Delete(i);
                  }
                  else
                  if (t.isOpened())
                  {
                     // If the trade is opened, we check it and make an action if neccessary
                     t.checkTrade();
                  }
                  
               }
            }
         }
      }
};