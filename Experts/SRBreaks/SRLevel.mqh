//+------------------------------------------------------------------+
//|                                                      SRLevel.mqh |
//|                                                   Michal Brauner |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Michal Brauner"
#property link      "http://www.mql5.com"
#property version   "1.00"
#property strict

#include "consts.mqh"

//
// Trida pro jednotlive urovne
//
class SRLevel
{
   private:
   
      string type;
      
      int length;
      
      double entryPoint;
      
      datetime startTime;
      datetime endTime;
  
      static int SRPoints_support_counter;
      static int SRPoints_resistance_counter;
       
   public:
      
      double levelMin;
      double levelMax;
        
      SRLevel(string type, double levelMin, double levelMax)
      {
         this.type = type;
         this.levelMin = levelMin;
         this.levelMax = levelMax;  
         this.length = 1;
         
         this.entryPoint = 0;
         
         this.startTime = 0;
         this.endTime = 0;
      };
      SRLevel()
      {
         this.length = 0;
      };
      
      // Nastavi pocatecni cas SR urovne
      void setStartTime(datetime time)
      {
         this.startTime = time;
      }
      
      // Nastavi koncovy cas SR urovne
      void setEndTime(datetime time)
      {
         this.endTime = time;
      }
      
      
      // Zvysi delku urovne
      void increaseLength()
      {
         this.length++;
      }
      
      //vrati delku urovne
      int getLength()
      {
         return(this.length);
      }
      
      //vrati typ urovne
      string getType()
      {
         return(this.type);
      }
      
      // otestuje, jestli se jedna o zatim nenaplnenou uroven
      bool isEmpty()
      {
         return(this.levelMin==0 && this.levelMax==0 ? true : false);
      }
            
      // Otestuje, jestli je zadana cena v povolenych urovnich
      bool isInLevel(double price)
      {         
         if (!this.isEmpty() && this.levelMin<price && price<this.levelMax)
         {
            return(true);
         }
         
         return(false);
      }
      
      // Vykresli znazorneni SR urovne
      bool drawLine(int startIndex, int sentiment)
      {
         SRLevel::SRPoints_support_counter++;
         
         string rectangleIdent = "SRPoint_"+type+"_"+SRLevel::SRPoints_support_counter;
         string sentimentLabel = "SRPointLabel_"+type+"_"+SRLevel::SRPoints_support_counter;
         
         // Spocitame koncove souradnice obdelniku
         int endIndex = startIndex + this.length - 1;
         
         int pipsToPriceKoef = MathPow(10, MarketInfo(Symbol(), MODE_DIGITS));
                                             
         //
         // Vytvoreni obdelniku
         //
         ResetLastError();
         if (!ObjectCreate(0, rectangleIdent, OBJ_RECTANGLE, 0, Time[endIndex], this.levelMin, Time[startIndex], this.levelMax))
         {
            Print("Nepodarilo se vytvorit obdelnik! Chyba: "+GetLastError());
            return(false);
         }
         
         if (!ObjectCreate(0, sentimentLabel, OBJ_TEXT, 0, Time[endIndex], this.type==SR_LEVEL_TYPE_SUPPORT ? this.levelMin : this.levelMax))
         {
            Print("Nepodarilo se vytvorit obdelnik! Chyba: "+GetLastError());
            return(false);
         }
         
         //
         // Konfigurace obdelniku
         //
         if (this.type==SR_LEVEL_TYPE_SUPPORT)
         {
            // Konfigurace pro support
            ObjectSetInteger(0, rectangleIdent, OBJPROP_COLOR, clrBlue);
            ObjectSetInteger(0, rectangleIdent, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, rectangleIdent, OBJPROP_WIDTH, 1);
         }
         else
         if (this.type==SR_LEVEL_TYPE_RESISTANCE)
         {
            // Konfigurace pro resistanci
            ObjectSetInteger(0, rectangleIdent, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, rectangleIdent, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, rectangleIdent, OBJPROP_WIDTH, 1);
         }
         
         //
         // Konfigurace popisku
         //
         ObjectSetString(0, sentimentLabel,OBJPROP_TEXT, "Sentiment = "+sentiment);
         ObjectSetString(0, sentimentLabel,OBJPROP_FONT, "Arial");
         ObjectSetInteger(0, sentimentLabel, OBJPROP_FONTSIZE, 10);
         ObjectSetDouble(0, sentimentLabel, OBJPROP_ANGLE, 90);
         ObjectSetInteger(0, sentimentLabel, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, sentimentLabel, OBJPROP_SELECTED, false);
         ObjectSetInteger(0, sentimentLabel, OBJPROP_HIDDEN, true);
         ObjectSetInteger(0, sentimentLabel, OBJPROP_COLOR, clrYellow);
         
         if (this.type==SR_LEVEL_TYPE_SUPPORT)
         {
            ObjectSetInteger(0, sentimentLabel, OBJPROP_ANCHOR, ANCHOR_RIGHT);
         }
         else
         if (this.type==SR_LEVEL_TYPE_RESISTANCE)
         {
            ObjectSetInteger(0, sentimentLabel, OBJPROP_ANCHOR, ANCHOR_LEFT);
         }
         
         return(true);
      } 
      
      //
      // Vraci informaci o tom, jestli jsou urovne disjunktivni
      // Ocekava non-empty urovne
      //
      static bool areDisjunctive(SRLevel *level1, SRLevel *level2)
      {
         if (level1.endTime<level2.startTime || level1.startTime>level2.endTime)
         {
            return(true);
         }
         
         return(false);
      }
   
};

int SRLevel::SRPoints_support_counter = 0;
int SRLevel::SRPoints_resistance_counter = 0;