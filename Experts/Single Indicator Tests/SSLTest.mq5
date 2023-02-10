//+------------------------------------------------------------------+
//| Includes                                                         |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>
//+------------------------------------------------------------------+
//| ENUMS                                                            |
//+------------------------------------------------------------------+
enum enTradeSignal
  {
   buy_signal,
   sell_signal,
   no_signal
  };

enum enTradeEntryType
  {
   go_long,
   go_short
  };

//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+
input ENUM_TIMEFRAMES Timeframe = PERIOD_CURRENT; // Timeframe

//+--------------------------Risk Inputs-----------------------------+
input double inpRiskPerTrade = 1.0; // Risk Percent Per Trade
input double inpProfitFactor = 1.5; // Profit factor
input uint inpATRPeriod = 25; // ATR Period
input double inpATRChannelFactor =1.5; // ATR Channel Factor
input ENUM_APPLIED_PRICE inpATRChannelAppPrice = PRICE_TYPICAL; // ATR Channel Applied Price

input ENUM_MA_METHOD inpSSLMAMethod = MODE_SMA;  // SSL MA Method
input int inpSSLPeriod = 10; // SSL Period
//+------------------------------------------------------------------+
//| Handles                                                          |
//+------------------------------------------------------------------+
int ATRChannelHandle;
int SSLHandle;
//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
int barTotal;
ulong posTicket;
bool inTrade = false;

//+------------------------------------------------------------------+
//| Objects                                                          |
//+------------------------------------------------------------------+
CTrade trade;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   barTotal = iBars(_Symbol,Timeframe);
   
   ATRChannelHandle = iCustom(_Symbol,Timeframe,"ATR Channel.ex5",MODE_SMA,1,inpATRPeriod,inpATRChannelFactor,inpATRChannelAppPrice);
   SSLHandle = iCustom(_Symbol,Timeframe,"SSL_Channel_Chart.ex5",inpSSLMAMethod,inpSSLPeriod);
   
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   int barTotalUpdated = iBars(_Symbol,Timeframe);
   
   if (barTotal != barTotalUpdated)
   {
    barTotal = barTotalUpdated;
    
    enTradeSignal tradeSignal = CheckForSignal();
    PositionCheckModify(tradeSignal);
    
    if (inTrade == false)
    {
     if (tradeSignal == buy_signal)
     {
      EnterPosition(go_long);
     }
     if (tradeSignal == sell_signal)
     {
      EnterPosition(go_short);
     }
    }
    
   }
   
  }

//+------------------------------------------------------------------+
//| Trade Signal Function                                            |
//+------------------------------------------------------------------+
enTradeSignal CheckForSignal()
  {
   double SSLBullsValues[];
   CopyBuffer(SSLHandle,1,1,2,SSLBullsValues);
   ArrayReverse(SSLBullsValues);
   
   double SSLBearsValues[];
   CopyBuffer(SSLHandle,0,1,2,SSLBearsValues);
   ArrayReverse(SSLBearsValues);
   
   if ((SSLBullsValues[0] > SSLBearsValues[0]) && (SSLBullsValues[1] < SSLBearsValues[1]))
   {
    return buy_signal;
   }
   if ((SSLBullsValues[0] < SSLBearsValues[0]) && (SSLBullsValues[1] > SSLBearsValues[1]))
   {
    return sell_signal;
   }
   
   return no_signal;
  }

//+------------------------------------------------------------------+
//| Lot Size Calculation Function                                    |
//+------------------------------------------------------------------+
double calcLots(double riskPercentage, double slDistance)
  {
   double tickSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double lotStep = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   
   if (tickSize == 0 || tickValue == 0 || lotStep == 0)
   {
    Print("Lot Size Could not be calculated");
    return 0;
   }
   
   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * riskPercentage / 100;
   double moneyLotStep = (slDistance / tickSize) * tickValue * lotStep;
   
   if (moneyLotStep == 0)
   {
    Print("Lot Size could not be calculated.");
    return 0;
   }
   double lots = MathFloor(riskMoney / moneyLotStep) * lotStep;
   
   return lots;
  }

//+------------------------------------------------------------------+
//| Enter Position Function                                          |
//+------------------------------------------------------------------+
void EnterPosition(enTradeEntryType entryType)
  {
   double ATRChannelUpper[];
   CopyBuffer(ATRChannelHandle,1,1,1,ATRChannelUpper);
   
   double ATRChannelLower[];
   CopyBuffer(ATRChannelHandle,2,1,1,ATRChannelLower);
   
   double askPrice = NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_ASK),_Digits);
   double bidPrice = NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_BID),_Digits);
   
   if (entryType == go_long)
   {
    double stopLossDistance = askPrice - ATRChannelLower[0];
    double takeProfitDistance = stopLossDistance * inpProfitFactor;
    double stopPrice = NormalizeDouble(ATRChannelLower[0],_Digits);
    double profitPrice = NormalizeDouble((askPrice + takeProfitDistance),_Digits);
    double lotSize = calcLots(inpRiskPerTrade,stopLossDistance);
    if (trade.Buy(lotSize,_Symbol,askPrice,stopPrice,profitPrice))
    {
     if (trade.ResultRetcode() == TRADE_RETCODE_DONE)
     {
      posTicket = trade.ResultOrder();
      inTrade = true;
     }
    }
   }
   
   if (entryType == go_short)
   {
    double stopLossDistance = ATRChannelUpper[0] - bidPrice;
    double takeProfitDistance = stopLossDistance * inpProfitFactor;
    double stopPrice = NormalizeDouble(ATRChannelUpper[0],_Digits);
    double profitPrice = NormalizeDouble((bidPrice - takeProfitDistance),_Digits);
    double lotSize = calcLots(inpRiskPerTrade,stopLossDistance);
    if (trade.Sell(lotSize,_Symbol,bidPrice,stopPrice,profitPrice))
    {
     if (trade.ResultRetcode() == TRADE_RETCODE_DONE)
     {
      posTicket = trade.ResultOrder();
      inTrade = true;
     }
    }
   }
   
  }

//+------------------------------------------------------------------+
//| Position Check/Modify function                                   |
//+------------------------------------------------------------------+
void PositionCheckModify(enTradeSignal tradeSignal)
  {
   if (inTrade == true)
   {
    if (PositionSelectByTicket(posTicket))
    {
     
     if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
     {
      if (tradeSignal == sell_signal)
      {
       if (trade.PositionClose(posTicket))
       {
        inTrade = false;
        posTicket = 0;
       }
      }
     }
     
     if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
     {
      if (tradeSignal == buy_signal)
      {
       if (trade.PositionClose(posTicket))
       {
        inTrade = false;
        posTicket = 0;
       }
      }
     }
     
    }
    else
    {
     inTrade = false;
     posTicket = 0;
    }
   }
   
  }

//+------------------------------------------------------------------+
