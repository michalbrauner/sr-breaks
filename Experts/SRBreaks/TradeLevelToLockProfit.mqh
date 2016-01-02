//+------------------------------------------------------------------+
//|                                       TradeLevelToLockProfit.mqh |
//|                                                   Michal Brauner |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Michal Brauner"
#property link      "http://www.mql5.com"
#property version   "1.00"
#property strict

#include "consts.mqh"
#include <Object.mqh>

//
// Trida zapouzdrujici uroven pro uzamceni obchodu
//

class TradeLevelToLockProfit : public CObject
{
   private:
   
      int levelNumber;
      double priceLockAt;
      double newStopLoss;

   public:
   
      void TradeLevelToLockProfit(int levelNumber, double priceLockAt, double newStopLoss)
      {
         this.levelNumber = levelNumber;
         this.priceLockAt = priceLockAt;
         this.newStopLoss = newStopLoss;
      }
      
      double getPriceLockAt()
      {
         return(this.priceLockAt);
      }
      
      double getNewStopLoss()
      {
         return(this.newStopLoss);
      }
      
      int Compare(TradeLevelToLockProfit *node, int mode=0)
      { 
         if (node.levelNumber>this.levelNumber)
         {
            return(1);
         }
         else
         if (node.levelNumber<this.levelNumber)
         {
            return(-1);
         }

         return(0);      
      }
};
