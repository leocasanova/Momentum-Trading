//+------------------------------------------------------------------+
//|                                                    Momentum1.mq4 |
//|                                     Copyright 2020, Leo Casanova |
//|                                  www.linkedin.com/in/leocasanova |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, Leo Casanova"
#property link      "www.linkedin.com/in/leocasanova"
#property version   "1.00"
#property strict

extern int     StartHour            = 0; 
extern int     TakeProfit           = 100;
extern int     StopLoss             = 100;
extern double  Lots                 = 0.1;
extern int     Slippage             = 5;
extern int     Magic                = 777777;
extern bool    ECNExecution         = false;
extern bool    TrailingStopLoss     = true;
extern int     TrailValue           = 10;
extern bool    AutoAdjustTo5Digits  = true;
extern int     MACD_FastPeriod      = 12;
extern int     MACD_SlowPeriod      = 26;
extern int     MACD_SignalPeriod    = 9;

double MyPoint;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

int OnInit()
{
   if(Period() != PERIOD_D1) // check timeframe
   {
      Alert("The Momentum EA is currently set for the wrong timeframe. Please change it to daily period.");
      return(INIT_FAILED);
   }
   
   SetMyPoint(); // set point value depending on the number of digits for the broker quotes 
   
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
   static datetime dt; 
   static int ticket = 0; 
   int positions=CountEAPositions(); // number of positions opened by this EA
   
   if(Hour() == StartHour) // check the hour we set to start our daily trades
   {
      if(dt!=iTime(Symbol(),Period(),0)) // check if first tick of the new candle on selected timeframe
      {
         dt=iTime(Symbol(),Period(),0);    // overwrite old with new value
         
         // retrieve values of MACD
         double macd = iMACD(Symbol(), Period(), MACD_FastPeriod, MACD_SlowPeriod, MACD_SignalPeriod, PRICE_OPEN, MODE_MAIN, 0); 
         double macdShiftOne = iMACD(Symbol(), Period(), MACD_FastPeriod, MACD_SlowPeriod, MACD_SignalPeriod, PRICE_OPEN, MODE_MAIN, 1);
         double macdShiftTwo = iMACD(Symbol(), Period(), MACD_FastPeriod, MACD_SlowPeriod, MACD_SignalPeriod, PRICE_OPEN, MODE_MAIN, 2);

         // set bullish and bearish signals conditions
         bool macdBull = macd > macdShiftOne && macdShiftOne > macdShiftTwo;
         bool macdBear = macd < macdShiftOne && macdShiftOne < macdShiftTwo;

         if(positions < 1) // only one position at a time
         {
            if(macdBull)
            {  
               // send BUY order if bullish signal
               MarketOrderSend(Symbol(), OP_BUY, Lots, ND(Ask), Slippage*int(MyPoint/Point()), ND(Bid-StopLoss*MyPoint), ND(Bid+TakeProfit*MyPoint), "Set by Daily Momentum EA", Magic, clrBlue);
            }
            else if(macdBear)
            {
               //send SELL order if bearish signal
               MarketOrderSend(Symbol(), OP_SELL, Lots, ND(Bid), Slippage*int(MyPoint/Point()), ND(Ask+StopLoss*MyPoint), ND(Ask-TakeProfit*MyPoint), "Set by Daily Momentum EA", Magic, clrRed);
            }
         }
         else // a position is currently open
         {
            bool order = OrderSelect(ticket, SELECT_BY_TICKET);
         
            if(OrderType() == OP_BUY) // if the position is a BUY order
            {
               if(macdBear) // if the market conditions changed and we now have a bearish signal
               {  
                  order = OrderClose(ticket, OrderLots(), OrderClosePrice(), Slippage*int(MyPoint/Point()), clrBlue); // close the order

                  if(!order) // if order was not closed
                  {
                     Alert("OrderClose error: ", GetLastError());
                  }
                  else // if it was correctly closed
                  {  
                     // open a SELL order
                     MarketOrderSend(Symbol(), OP_SELL, Lots, ND(Bid), Slippage*int(MyPoint/Point()), ND(Ask+StopLoss*MyPoint), ND(Ask-TakeProfit*MyPoint), "Set by Daily Momentum EA", Magic, clrRed);
                  }  
               }
            }
            else if(OrderType() == OP_SELL) // if the position is a SELL order
            {
               if(macdBull) // if the market conditions changed and we now have a bullish signal
               {
                  order = OrderClose(ticket, OrderLots(), OrderClosePrice(), Slippage*int(MyPoint/Point()), clrRed); // close the order

                  if(!order) // if order was not closed
                  {
                     Alert("OrderClose error: ", GetLastError());
                  }
                  else // if it was correctly closed
                  {
                     // open a BUY order
                     MarketOrderSend(Symbol(), OP_BUY, Lots, ND(Ask), Slippage*int(MyPoint/Point()), ND(Bid-StopLoss*MyPoint), ND(Bid+TakeProfit*MyPoint), "Set by Daily Momentum EA", Magic, clrBlue);
                  }  
               }
            }
         }
      }
   }
   else // it is not the hour we have set to start our daily trades
   {
      if(TrailingStopLoss == true)
      {
         if(ticket > 0) // existing current position
         {
            TrailingStop(ticket); // adjust trailing stop loss with the changes in ticker
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Expert auxiliary functions                                       |
//+------------------------------------------------------------------+

// counts the number of open positions of this EA
int CountEAPositions()
{
   int positions = 0;
   
   for(int trade = OrdersTotal() - 1; trade >= 0; trade--)
   {
      if(!OrderSelect(trade, SELECT_BY_POS, MODE_TRADES))
      {
         continue;
      }
      if(OrderSymbol() == Symbol())
      {
         if((OrderType() == OP_BUY || OrderType() == OP_SELL) && OrderMagicNumber() == Magic)
         {
            positions++;
         }
      }
   }
   return positions;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

// modifies the trailing stop loss of the order
void TrailingStop(int ticket)
{
   bool order = OrderSelect(ticket, SELECT_BY_TICKET);

   if(order == true)
   {
      if(OrderType() == OP_BUY)
      {
         if(Bid - OrderStopLoss() > TrailValue*MyPoint)
         {
            order = OrderModify(OrderTicket(), OrderOpenPrice(), ND(Bid - TrailValue*MyPoint), OrderTakeProfit(), 0);
            
            if(order)
            {
               Alert("Trailing stop loss for order #" + string(ticket) + " modified successfully.");
            }
            else
            {
               Alert("Trailing stop loss OrderModify error: ", GetLastError());
            }
         }
      }

      if(OrderType() == OP_SELL)
      {
         if(OrderStopLoss() - Ask > TrailValue*MyPoint)
         {
            order = OrderModify(OrderTicket(), OrderOpenPrice(), ND(Ask + TrailValue*MyPoint), OrderTakeProfit(), 0);
            
            if(order)
            {
               Alert("Trailing stop loss for order #" + string(ticket) + " modified successfully.");
            }
            else
            {
               Alert("Trailing stop loss OrderModify error: ", GetLastError());
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

// handles errors when an order is sent via the MarketOrderSend function
bool SendOrderError(int ticket, int cmd)
{
   bool error = false;
   
   string command = "BUY";
   
   if(cmd == OP_SELL)
   {
      command = "SELL";
   }
   
   bool orderSelected = OrderSelect(ticket, SELECT_BY_TICKET);
   
   if(orderSelected)
   {
      Alert(command + " order #" + string(ticket) + " executed succesfully.");
   }
   else
   {
      Alert("Error sending " + command + " order: ", GetLastError());
      error = true;
   }
   return error;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

// sends a market order depending on if the ECN execution mode is activated
void MarketOrderSend(string symbol, int cmd, double volume, double price, int slippage, double stoploss, double takeprofit, string comment, int magic, color arrow)
{
   int ticket;
   bool error;

   if(ECNExecution == false)
   {
      ticket = OrderSend(symbol, cmd, volume, price, slippage, stoploss, takeprofit, comment, magic, 0, arrow);
      
      error = SendOrderError(ticket, cmd);  
   }
   else
   {
      ticket = OrderSend(symbol, cmd, volume, price, slippage, 0, 0, comment, magic, 0, arrow);
      
      error = SendOrderError(ticket, cmd); 
      
      if(!error)
      {
         bool orderModified = OrderModify(ticket, OrderOpenPrice(), stoploss, takeprofit, 0);

         if(orderModified)
         {
            Alert("Order #" + string(ticket) + " modified successfully.");
         }
         else
         { 
            Alert("Order #" + string(ticket) + "has no stoploss and takeprofit. OrderModify error: ", GetLastError());
         }
      }
   }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

// sets point value depending on the number of digits for the broker quotes 
void SetMyPoint()
{
   MyPoint = Point();
   
   if(AutoAdjustTo5Digits == true && (Digits() == 3 || Digits() == 5))
   {
      Alert("Digits: ", Digits(), ". Broker quotes given in 5 digits mode. Values of SL, TP and slippage will be multiplied by 10");
      MyPoint = Point()*10;
   }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

// rounds floating point number to a specified accuracy
double ND(double val)
{
   return(NormalizeDouble(val, Digits()));
}
