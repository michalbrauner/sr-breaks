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
// This class encapsulates one level
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
      
      // Sets the start time of SR level
      void setStartTime(datetime time)
      {
         this.startTime = time;
      }
      
      // Sets the end time of SR level
      void setEndTime(datetime time)
      {
         this.endTime = time;
      }
      
      
      // Increases the length of level
      void increaseLength()
      {
         this.length++;
      }
      
      // Returns the length of level
      int getLength()
      {
         return(this.length);
      }
      
      // Returns the type of level
      string getType()
      {
         return(this.type);
      }
      
      // Checks if this level is still empty
      bool isEmpty()
      {
         return(this.levelMin==0 && this.levelMax==0 ? true : false);
      }
            
      // Checks if the specified price is in available levels
      bool isInLevel(double price)
      {         
         if (!this.isEmpty() && this.levelMin<price && price<this.levelMax)
         {
            return(true);
         }
         
         return(false);
      }
      
      // Draws a line (SR level)
      bool drawLine(int startIndex, int sentiment)
      {
         SRLevel::SRPoints_support_counter++;
         
         string rectangleIdent = "SRPoint_"+type+"_"+SRLevel::SRPoints_support_counter;
         string sentimentLabel = "SRPointLabel_"+type+"_"+SRLevel::SRPoints_support_counter;
         
         // Calculating an end coordinates of rectangle
         int endIndex = startIndex + this.length - 1;
         
         int pipsToPriceKoef = MathPow(10, MarketInfo(Symbol(), MODE_DIGITS));
                                             
         //
         // Creating a rectangle
         //
         ResetLastError();
         if (!ObjectCreate(0, rectangleIdent, OBJ_RECTANGLE, 0, Time[endIndex], this.levelMin, Time[startIndex], this.levelMax))
         {
            Print("Creating a rectangle failed! Error: "+GetLastError());
            return(false);
         }
         
         if (!ObjectCreate(0, sentimentLabel, OBJ_TEXT, 0, Time[endIndex], this.type==SR_LEVEL_TYPE_SUPPORT ? this.levelMin : this.levelMax))
         {
            Print("Creating a rectangle failed! Error: "+GetLastError());
            return(false);
         }
         
         //
         // Rectangle configuration
         //
         if (this.type==SR_LEVEL_TYPE_SUPPORT)
         {
            // Configuration for support
            ObjectSetInteger(0, rectangleIdent, OBJPROP_COLOR, clrBlue);
            ObjectSetInteger(0, rectangleIdent, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, rectangleIdent, OBJPROP_WIDTH, 1);
         }
         else
         if (this.type==SR_LEVEL_TYPE_RESISTANCE)
         {
            // Configuration for resistance
            ObjectSetInteger(0, rectangleIdent, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, rectangleIdent, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, rectangleIdent, OBJPROP_WIDTH, 1);
         }
         
         //
         // Label configuration
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
      // Checks if levels are disjunctive.
      // Expects non empty levels
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