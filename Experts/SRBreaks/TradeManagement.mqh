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
// Trida pro spravu obchodu
//

class TradeManagement
{
   private:
      // Pole otevrenych obchodu
      CArrayObj *trades;
            
      int magic;
      
      int maxSlippage;
      
      //
      // Otevre novy obchod do Longu
      //
      Trade *addLongTrade(double volume, double price, double stopLoss, double takeProfit, string comment)
      {
         Trade *trade = NULL;
         
         ResetLastError();
         int orderTicket = OrderSendMarket(Symbol(), OP_BUY, volume, price, this.maxSlippage, stopLoss, takeProfit, comment, this.magic, 0, clrBlue);
         
         if (orderTicket==-1)
         {
            Print("ERROR - Nepodarilo se vytvorit LONG obchod: volume="+volume+", price="+price+", stopLoss="+stopLoss+", takeProfit="+takeProfit+", lastError="+GetLastError());
         }
         else
         {
            trade = new Trade(orderTicket, this.maxSlippage, this.magic);
            this.trades.InsertSort(trade);
         }
         
         return(trade);
      }
      
      
      //
      // Otevre novy obchod do Shortu
      //
      Trade *addShortTrade(double volume, double price, double stopLoss, double takeProfit, string comment)
      {
         Trade *trade = NULL;
         
         ResetLastError();
         int orderTicket = OrderSendMarket(Symbol(), OP_SELL, volume, price, this.maxSlippage, stopLoss, takeProfit, comment, this.magic, 0, clrRed);
         
         if (orderTicket==-1)
         {
            Print("ERROR - Nepodarilo se vytvorit SHORT obchod: volume="+volume+", price="+price+", stopLoss="+stopLoss+", takeProfit="+takeProfit+", lastError="+GetLastError());
         }
         else
         {
            trade = new Trade(orderTicket, this.maxSlippage, this.magic);
            this.trades.InsertSort(trade);
         }
         
         return(trade);
      }
      
      //
      // Vrati pozici obchodu podle orderTicket
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
      // Zavre dany obchod
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
      // Vybere obchod, ktery ma dany index
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
      // Vrati posledni pridany ticket
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
      // Vrati cislo ticketu, ktery ma dany indedx
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
      // Otevre novy obchod
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
      // Zavre naposledy otevreny obchod
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
      // Zjisti, jestli je posledni obchod jeste otevreny
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
      // Vybere naposledy vlozeny obchod
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
      // Vrati pocet otevrenych obchodu
      //
      int getCountOfTrades()
      {
         return(this.trades.Total());
      }  
      
      //
      // Najde jiz uzavrene obchody a to takove, ktere skoncili na SL nebo PT
      // Mela by byt volana pro kazdy tick
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
                     // Pokud se jedna uz o uzavreny obchod, musime ho smazat
                     t.onClose();
                     this.trades.Delete(i);
                  }
                  else
                  if (t.isOpened())
                  {
                     // Pokud se jedna o otevreny obchod, zkontrolujeme ho a provedeme potrebne akce
                     t.checkTrade();
                  }
                  
               }
            }
         }
      }
};