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
// Trida zapouzdrujici objekt obchodu
//

class Trade : public CObject
{
   private:
        
      int orderTicket;
      
      // obchody, ktere se pridaly kvuli navysovani pozic v prubehu obchodu
      CArrayObj *extraAddedTrades;
      
      // ceny, kde bude dochazet k lockovani obchodu
      CArrayObj *levelsToLockProfit;
      
      // Minimalni cena za dobu trvani obchodu
      double priceMinimum;
      
      // Maximalni cena za dobu trvani obchodu
      double priceMaximum;
      
      int maxSlippage;
      
      // SR uroven, ktera se vztahuje k obchodu
      SRLevel *level;
      
      // Pocitadla, jak casto je obchod v zisku a jak casto ve ztrate
      int totalInLoss;
      int totalInProfit;
      
      // Hodnoty profitu - aktualni a v predchozim ticku
      double profitLast;
      double profitCurrent;
      
      int magic;
      
      double avgVolatilityAtStart;
            
      // Zprocesuje obchod na zaklade hodnoty ATR - posouvani PT
      bool processTradeByAtrValue()
      {  
         bool result = true;
         
         int atrHistoryOffset = 3;
         int addPipsByAtr = 150;
                
         // zkontrolujeme, jestli nemame posunout PT (pokud roste ATR)
            
         double atrCurrent = iATR(Symbol(), 0, 7, 0);
         double atrHistorical = iATR(Symbol(), 0, 7, atrHistoryOffset);
         double newStopLoss = 0, newTakeProfit = 0;
         
         double stopLevel = MarketInfo(Symbol(), MODE_STOPLEVEL)*Point;
         
         
         //
         // Kontrola zvysujici se volatility
         //
         if (atrCurrent>atrHistorical)
         {  
            if (OrderSelect(this.orderTicket,SELECT_BY_TICKET))
            {                             
               if (OrderMagicNumber()==this.magic && OrderProfit()>0)
               {
                  //
                  // Pokud jsme v profitu, natahujeme dale PT (pokud roste ATR)
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
      // Prida extra BUY obchod 
      //
      Trade *addExtraLongTrade(double volume, double price, double stopLoss, double takeProfit, string comment)
      {
         Trade *trade = NULL;
         
         ResetLastError();
         int orderTicket = OrderSendMarket(Symbol(), OP_BUY, volume, price, this.maxSlippage, stopLoss, takeProfit, comment, this.magic, 0, clrBlue);
         
         if (orderTicket==-1)
         {
            Print("ERROR - Nepodarilo se vytvorit extra LONG obchod: volume="+volume+", price="+price+", stopLoss="+stopLoss+", takeProfit="+takeProfit+", lastError="+GetLastError());
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
               
               // uzavreme vsechny ostatni extra obchody pro zamceni zisku :)
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
      // Prida extra SHORT obchod 
      //
      Trade *addExtraShortTrade(double volume, double price, double stopLoss, double takeProfit, string comment)
      {
         Trade *trade = NULL;
         
         ResetLastError();
         int orderTicket = OrderSendMarket(Symbol(), OP_SELL, volume, price, this.maxSlippage, stopLoss, takeProfit, comment, this.magic, 0, clrRed);
         
         if (orderTicket==-1)
         {
            Print("ERROR - Nepodarilo se vytvorit extra SHORT obchod: volume="+volume+", price="+price+", stopLoss="+stopLoss+", takeProfit="+takeProfit+", lastError="+GetLastError());
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
               
               // uzavreme vsechny ostatni extra obchody pro zamceni zisku :)
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
      // Zkontroluje vsechny extra pridane obchody
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
               
               // Pokud se obchod zavrel treba na SL nebo rucne, musime ho vymazat z pole
               if (t.isClosed())
               {
                  t.onClose();
                  this.extraAddedTrades.Delete(i);  
               }
            }
         }
      }
      
      //
      // Uzavre vsechny extra pridane obchody
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
      
      // Funkce volana po uzavreni obchodu
      // Volat tesne pred smazanim z pole obchodu
      void onClose()
      {
         // Uzavreni vsech extra obchodu
         this.closeExtraTrades();
         
         if (OrderSelect(this.orderTicket,SELECT_BY_TICKET))
         {
            string tradeType = OrderType()==OP_BUY ? "LONG" : "SHORT";
            Print("CLOSED - Ukoncen "+tradeType+" obchod: orderTicket="+this.orderTicket+", priceMinimum="+this.priceMinimum+", priceMaximum="+this.priceMaximum+", percentInProfit="+this.getPercentTimeInProfit()+", avgVolatility="+this.avgVolatilityAtStart,", profit="+OrderProfit());
         }
      }
      
      // Uzavre obchod
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
      
      // Zkontroluje obchod a provede pripadne akce (napr. posunuti obchodu apod...)
      // Mela by byt volana pro kazdy tick
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
                  // Aktualizace pocitadel jestli je obchod ve ztrate nebo profitu
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
                  // Zpracovani ukladani minima a maxima
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
                     // Zpracovani a kontrola RSI
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
                     // Kontrola pole ATR
                     //
                     //this.processTradeByAtrValue();
                     
                     if (!this.isClosed())
                     {
                        //
                        // Zpracovani lockovani profitu
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
                                             
                                             
                                             // Pridame extra obchod
                                             RefreshRates();
                                             //this.addExtraLongTrade(OrderLots(), Ask, newStopLossExtraTrade, OrderTakeProfit(), "");
                                             
                                             // Smazeme lock uroven
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
                                             
                                             
                                             // Pridame extra obchod
                                             RefreshRates();
                                             //this.addExtraShortTrade(OrderLots(), Bid, newStopLossExtraTrade, OrderTakeProfit(), "");
                                             
                                             // Smazeme lock uroven
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
         
         // Kontrola extra obchodu
         this.checkExtraTrades();
         
         return(false);
      }
            
      // Vraci, jestli je obchod otevreny
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
      
      // Vraci, jestli je obchod otevreny
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
      
      // Vrati pocet procent z casu, kdy byl obchod v zisku
      double getPercentTimeInProfit()
      {
         if (this.totalInLoss>0 || this.totalInProfit>0)
         {
            double percent = (double)(this.totalInProfit / ((double)this.totalInProfit + (double)this.totalInLoss)) * 100;
            return(NormalizeDouble(percent,2));
         }
         return(0);
      }
      
      // TODO: Otestovat jeste jestli se tato funkce vola :)
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