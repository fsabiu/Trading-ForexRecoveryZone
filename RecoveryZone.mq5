//+------------------------------------------------------------------+
//|                                                 RecoveryZone.mq5 |
//|                                  Copyright 2022, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "RecoveryZone"
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

#include <Trade\OrderInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\Trade.mqh>

CTrade  trade;

//extern ENUM_TIMEFRAMES timeframe = 5; // Timeframe
input double size_multipler = 1; // Size multiplier
input int slippage = 2;
input int max_trade_orders = 8;
input int tp_pips = 60;
input int reco_pips = 20; 

input int period = 5; // Period (min)
// Trading hours
input int start_hour = 6;
input int end_hour = 16;
input bool stop_if_loss = false;

// Conservative stop loss
input bool conservative_stop = false; // Conservative SL
input bool trailing_stop = false;

double trades_sizes[10] = {0.1, 0.14, 0.1, 0.14, 0.19, 0.25, 0.33, 0.44, 0.59, 0.78};
string markets[5] = {"EURUSD", "EURGBP", "GBPUSD", "EURCHF", "USDCAD"};

// To be instantiated in OnInit()
double account_free_margin = -1;
double account_equity = -1;
double account_equity_prev = -1;
double trade_size_required = -1; // Dictionary needed for multicurrency
//double eurperlot = 3300; // Leverage 1:30, dictionary needed for multicurrency and/or different leverage
double eurperlot = 4000;

// To be updated at each new position opening
int magic_numbers[]; // Array of magic numbers (-1 if free, index if busy)
int magic_numbers_cont; // Counter of busy positions 
int magic_numbers_size; // Size of the array magic_numbers
int magic_numbers_trades[];   // Array of #orders opened for each magic number (to prevent partial closing)
int magic_numbers_trailing[]; // Array of trailing stops. If [i]==1, trailing stop is set
  
int tradesnr = 0;

datetime stop_trading_until;

int OnInit()
  {   
   // Variables
   magic_numbers_cont = 0;
   magic_numbers_size = 0;
   
   // Trade
   trade.SetDeviationInPoints(slippage);
   //trade.SetTypeFilling(ORDER_FILLING_RETURN);
   trade.LogLevel(1);
   trade.SetAsyncMode(true);
   
   // Parameters check
   if (max_trade_orders > 10)
      return(INIT_PARAMETERS_INCORRECT); // Not tested

   // Getting equity
   account_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   account_equity_prev = AccountInfoDouble(ACCOUNT_EQUITY);
   //Print("Account equity: ", account_equity);
   
   // Getting free margin
   account_free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   //Print("Account free margin: ", account_free_margin);
   
   // Set sizes of trading (depends on multiplier)
   setTradesSizes();
   
   // Calculate size needed for a trade (worst scenario: max_trade_orders)
   trade_size_required = getRequiredSize();
   //Print("Size required by a trade: ", trade_size_required);
   
   // Allocate magic_numbers array and initializing elements to -1 
   //Print("Trade size required ", trade_size_required);
   //Print("Eurperlot ", eurperlot);
   //Print("trade_size_required*eurperlot ", trade_size_required*eurperlot);
   
   int sz = MathRound((account_equity)/(trade_size_required*eurperlot))*2.0;
   //Print("Size::::", sz);
   initMagicNumbers(sz, 0);
   
   // Initializing stop trading
   stop_trading_until = TimeCurrent()-(TimeCurrent()%(PERIOD_D1*60));
   
   return(INIT_SUCCEEDED);
}


void OnTick()
  {
      account_equity_prev = account_equity;
      account_equity = AccountInfoDouble(ACCOUNT_EQUITY);
      
      // Check orders every minute
      checkOrders();
      
      // Trade every "period" minutes
      if(int(TimeToString(TimeCurrent(),TIME_MINUTES)) % period == 0) {
         //Print("5 mins");
         //Print(TimeCurrent());
         // Enough margin to open a trade?
         int free_trades = getFreeTrades();
         Print("OnTick(): Free trades: ", free_trades);
         Print("Magic cont: ", magic_numbers_cont);
         //Print("Free trades: ", free_trades, " Is trading session: ", isTradingSession(), " stop_trading_until: ", stop_trading_until);
         if(free_trades>0 && isTradingSession() && TimeCurrent() >= stop_trading_until) { //How many 1st operations can I open? Also will depend on maximal drawdown allowed
            // Look for 1st operation
            int scan = marketScan();
         }
      }
}


int marketScan() {
   int num = MathRand()%10 + 1; // int btw 1 and 10
   if(num == 5) { // => prob 0.1
      string market = "EURUSD";
   
      int magic_number = getFreeMagicNumber();
      trade.SetExpertMagicNumber(magic_number);
      
      num = MathRand()%10 + 1;
      
      //--- object for receiving symbol settings
      CSymbolInfo symbol_info;
      //--- set the name for the appropriate symbol
      symbol_info.Name(_Symbol);
      //--- receive current rates and display
      symbol_info.RefreshRates();
         
         
      if(num<=5) { // Buy with probability 0.5
         if(!trade.Buy(trades_sizes[0], 
            _Symbol, 
            symbol_info.Ask(), 
            symbol_info.Bid() - (tp_pips+reco_pips)*symbol_info.Point()*10,
            symbol_info.Bid() + tp_pips*symbol_info.Point()*10,
            "1")) {
            //--- failure message
            //Print("Buy() method failed. Return code=",trade.ResultRetcode(), ". Code description: ",trade.ResultRetcodeDescription());
         } else {
            //Print("Buy() method executed successfully. Return code=",trade.ResultRetcode()," (",trade.ResultRetcodeDescription(),")");
            tradesnr++;	
            magic_numbers_trades[magic_number] = 1;	
            magic_numbers_trailing[magic_number] = 0;
           }
           
      } else{ // Sell with probability 0.5
                
         if(!trade.Sell(trades_sizes[0], 
            _Symbol, 
            symbol_info.Bid(), 
            symbol_info.Ask() + (tp_pips+reco_pips)*symbol_info.Point()*10,
            symbol_info.Ask() - tp_pips*symbol_info.Point()*10,
            "1")) {
            //--- failure message
            //Print("Buy() method failed. Return code=",trade.ResultRetcode(), ". Code description: ",trade.ResultRetcodeDescription());
         } else {
            //Print("Sell() method executed successfully. Return code=",trade.ResultRetcode()," (",trade.ResultRetcodeDescription(),")");
            tradesnr++;
            magic_numbers_trades[magic_number] = 1;
            magic_numbers_trailing[magic_number] = 0;
           }
      }
   }
   return 0;
}

void checkOrders() {
   
   int opened_orders;
   int pending_orders;
   int total_orders;
   
   datetime first_order_time;
   int first_order_type;
   double first_order_price;
   string first_order_symbol;
   
   for(int magic=0; magic < magic_numbers_size; magic++) {
         
      if(magic_numbers[magic]!= -1){
         
         // Orders with current magic number
         opened_orders = 0;
         pending_orders = 0;
         total_orders = 0;
         
         // First order info
         first_order_time = TimeCurrent();
         first_order_type = -1;
         first_order_price = -1;
         first_order_symbol = "";
         
         // Counting orders
         COrderInfo ord_info;	
         CPositionInfo pos_info;
         
         for (int i = 0; i < OrdersTotal(); i++) {
            if(ord_info.SelectByIndex(i) == false ) {
               //Print("ERROR - Unable to select the order - ",GetLastError());
               break;
            } 
            if(ord_info.Magic() == magic_numbers[magic]){
               pending_orders++;
            }
         }
         
         // Counting positions (opened orders)
         for (int i = 0; i < PositionsTotal(); i++) {
            CPositionInfo pos_info;
            if(pos_info.SelectByIndex(i) == false ) {
               //Print("ERROR - Unable to select the order - ",GetLastError());
               break;
            }
            if(pos_info.Magic() == magic_numbers[magic]){
               opened_orders++;
               
               datetime pos_time = PositionGetInteger(POSITION_TIME);
               
               if(pos_time < first_order_time){
                  first_order_type = PositionGetInteger(POSITION_TYPE);
                  first_order_time = PositionGetInteger(POSITION_TIME);
                  first_order_price = PositionGetDouble(POSITION_PRICE_OPEN);
                  first_order_symbol = PositionGetString(POSITION_SYMBOL);
               }
            }
         }

         
         total_orders = opened_orders + pending_orders;
         //Print("CheckOrders(): Total orders: ", total_orders);
         //Print("CheckOrders(): Open orders: ", opened_orders);
         //Print("CheckOrders():Pending orders: ", pending_orders);
         
         switch(total_orders)
            {
            case 0:
               // Remove Magic Number, TP or SL hit
               //Print("Placed order CLOSED!");
               setFreeMagicNumber(magic);
               // If enabled: if loss, stop trading for today
               if(stop_if_loss == true && account_equity_prev > account_equity) {
                  stopTradingUntilTomorrow();
               }
               break;
            
            default: // total_orders >= 1
               // Checks
               if(pending_orders > 1){
                  //Print("CheckOrders(): Too many pending orders!"); // We should not have more pending orders for a magic number
               }
               
               // TP hit before last pending order triggering
               if(opened_orders==0 && pending_orders == 1){
                  // If it's not the 1st, cancel it
                  cancelOrderIfNotFirst(magic);
                  
                  //Print("CheckOrders(): Closed");
               }
               
               // Partial closing of orders
               if(pending_orders == 0 && opened_orders < max_trade_orders && magic_numbers_trades[magic] > opened_orders){
                  cancelAllOrders(magic);
               }
               
               // Next order: standard case 
               if(pending_orders == 0 && opened_orders >=1 && opened_orders < max_trade_orders && magic_numbers_trades[magic] == opened_orders && magic_numbers_trailing[magic]==0) {
                  //Print("SENDING ORDER WITH LOTS ", trades_sizes[opened_orders]);
                  //Print("CheckOrders(): First order type: ", first_order_type);
                  //Print("CheckOrders(): Open orders: ", opened_orders, ", pending orders: ", pending_orders);
                  int err = sendNextOrder(first_order_symbol, first_order_type, first_order_price, opened_orders, magic);
                  //Print("CheckOrders(): Order nr ", opened_orders+1);
               }
               
               // Conservative stop (just after last position opening)
               if(conservative_stop && pending_orders == 0 && opened_orders == max_trade_orders && magic_numbers_trades[magic] == opened_orders) {
                  setConservativeStopLoss(magic, first_order_type, first_order_price);
               }
               
               // Trailing stop
               //Print("Trailing checks");	
               //Print("opened_orders ", opened_orders);	
               //Print("magic_numbers_trades[magic] ", magic_numbers_trades[magic]);	
               //Print("magic_numbers_trailing[magic] ", magic_numbers_trailing[magic]);
               
               if(trailing_stop && opened_orders==1 && magic_numbers_trades[magic] == opened_orders && magic_numbers_trailing[magic]==0){
                  Print("Checking for trailing stop");
                  int res = setTrailingStop(magic, first_order_type, first_order_price);
               }
               break;
            } 
      }  
   }
}


/*	
Size management functions	
 - setTradesSizes()	
 - getRequiredSize()	
 - getFreeTrades()	
*/
void setTradesSizes(){
   
   for(int i=0; i<ArraySize(trades_sizes); i++) {
      trades_sizes[i] = NormalizeDouble((size_multipler*trades_sizes[i]), 2); // Format x.xx
      //trades_sizes[i] = RoundToDigitsUp((size_multipler*trades_sizes[i]), 2);
   }

   //Print("Using sizes:");
   for(int i=0; i<ArraySize(trades_sizes); i++) {
      //Print(trades_sizes[i]);
   }
   return;
}

// Returns the max total size needed to start a trade (worst scenario)
double getRequiredSize() {

   double required_size = 0;
   
   for (int i = 0; i < max_trade_orders; i++) {
      required_size += trades_sizes[i];
   }
   
   return required_size;
}

// Returns the maximum number of position that can be open with the current equitiy and opened position (which are considered to evolve according to the worst scenario)
// i.e. how many position will keep the margin level above 100 with max_trade_orders per trade
int getFreeTrades(){
   
   int free_trades = 0;
   
   // Worst case for the currently opened trades
   double current_trades = trade_size_required*magic_numbers_cont;
   
   // TODO consider trades with trail stop or SL at breakeven
   double size_required = trade_size_required*eurperlot; // size required by a trade with current size
   double potential_busy_margin = size_required*current_trades;
   
   /*
   //Print("Size required: ", size_required);
   //Print("Trade size required: ", trade_size_required);
   //Print("Eur per lot: ", eurperlot);
   */
   
   // Margin level = (Equity/Used Margin) X 100
   // Margin level if another position is opened (+size_required)
   double potential_margin_level = 101;
   int trades = 1;
   while(potential_margin_level > 100) {
      potential_margin_level = (AccountInfoDouble(ACCOUNT_EQUITY)/(potential_busy_margin + trades*size_required))*100;
      
      if(potential_margin_level > 100) {
         trades++;
         free_trades++;
      }
   }
   
   return free_trades;
}

/*	
Magic number management functions	
 - initMagicNumbers()	
 - getFreeMagicNumber()	
 - setFreeMagicNumber()	
*/

void initMagicNumbers(int new_size, int old_size) {
   magic_numbers_size = new_size;
   
   if(ArrayResize(magic_numbers, magic_numbers_size) < 0) {
      Alert("magic_numbers resizing failed!");
   }
   if(ArrayResize(magic_numbers_trades, magic_numbers_size) < 0) {
      Alert("magic_numbers_trades resizing failed!");
   }
   
   if(ArrayResize(magic_numbers_trailing, magic_numbers_size) < 0) {
      Alert("magic_numbers_trailing resizing failed!");
   }
   
   for(int i = old_size; i < magic_numbers_size; i++){
      magic_numbers[i] = -1;
      magic_numbers_trades[i] = 0;
      magic_numbers_trailing[i] = 0;
   }
}

int getFreeMagicNumber() {
   int magic = -1;
   int i = 0;
   while(i < magic_numbers_size && magic==-1){
      if(magic_numbers[i]==-1) {
         magic = i;                    // Select
         magic_numbers[magic] = magic; // Set to busy
      }
      i++;
   }
   
   if(magic == -1) { // No free magic numbers, double the array size
      initMagicNumbers(magic_numbers_size*2, magic_numbers_size);
      return getFreeMagicNumber();
   }
   
   // Updating counter of current trades
   magic_numbers_cont++;
   
   return magic;
}

void setFreeMagicNumber(int n){
   magic_numbers[n] = -1;
   magic_numbers_trades[n] = 0;
   magic_numbers_trailing[n] = 0;
   
   // Updating counter of current trades
   magic_numbers_cont--; 
   return;
}

/*	
Orders and positions management functions:	
 - cancelOrderIfNotFirst()	
 - cancelAllOrders()	
*/

int cancelOrderIfNotFirst(int magic) {
   MqlTradeRequest request = {};
   MqlTradeResult  result = {};
   
   request.action = TRADE_ACTION_REMOVE;
   
   COrderInfo ord_info;
   
   for(int i=OrdersTotal()-1;i>=0;i--){
      if(ord_info.Select(i) && ord_info.Magic() == magic) {
         if(ord_info.Comment() != "1") {      
            request.order  = ord_info.Ticket();
            ResetLastError();
            if(!OrderSend(request,result)){
               //Print("Fail to delete ticket ", request.order,": Error ",GetLastError(),", retcode = ",result.retcode);
            } else{
               //Print("Order deleted");
            }
         }
      }
   }
   
   return 0;
}

int cancelAllOrders(int magic) {
   MqlTradeRequest request = {};
   MqlTradeResult  result = {};
   
   request.action = TRADE_ACTION_REMOVE;
   
   COrderInfo ord_info;
   
   for(int i=OrdersTotal()-1; i>=0; i--){
      if(ord_info.SelectByIndex(i) && ord_info.Magic() == magic) {
            //int res = OrderDelete(OrderTicket());
            request.order  = ord_info.Ticket();
            ResetLastError();
            if(!OrderSend(request,result)){
               Print("Fail to delete ticket ", request.order,": Error ",GetLastError(),", retcode = ",result.retcode);
            } else{
               Print("Orders deleted");
            }
       }
   }
   
   return 0;
}

/* Further Parameters functions:	
 - isTradingSession()	
 - stopTradingUntilTomorrow()	
 - setTrailingStop()	
 - setConservativeStopLoss()	
*/

bool isTradingSession() {
   bool is_session;
   
   datetime tm=TimeCurrent(); //gets current time in datetime data type
   string str=TimeToString(tm,TIME_MINUTES); //changing the data type to a string
   string current = StringSubstr(str, 0, 2); //selecting the first two characters of the datetime e.g. if it's 5:00:00 then it'll save it as 5, if it's 18 it will save 18.
   int currentTimeInt = StringToInteger(current); //changes the string to an integer

   if(currentTimeInt >= start_hour && end_hour >= currentTimeInt) {
      is_session = true;
   } else {
      is_session = false;
   }
   
   return is_session;
}

void stopTradingUntilTomorrow() {
   datetime today_midnight = TimeCurrent()-(TimeCurrent()%(PERIOD_D1*60));
   stop_trading_until = today_midnight+PERIOD_D1*60; // tomorrow midnight
   //Print("Trading stopped until tomorrow!");
   
   return;
}

int setTrailingStop(int magic, int first_order_type, double first_order_price) {
   double new_stop_loss = 0.0;
   
   MqlTradeRequest request = {};
   MqlTradeResult  result = {};
   
   CPositionInfo pos_info;
   
   CSymbolInfo symbol_info;
   symbol_info.Name(_Symbol);
   
   
   for (int i = PositionsTotal() - 1; i >= 0; i--) {
      if(pos_info.SelectByIndex(i) == false ) {
         //Print("ERROR - Unable to select the order - ",GetLastError());
         break;
      } 
      
      
      if(pos_info.Magic() == magic_numbers[magic] && magic_numbers_trailing[magic] == 0) {
         
         double profit_pips;
         switch(first_order_type) {
            case POSITION_TYPE_BUY:
               profit_pips = (pos_info.PriceCurrent() - pos_info.PriceOpen())/symbol_info.Point();
               break;
            case POSITION_TYPE_SELL:
               profit_pips = (pos_info.PriceOpen() - pos_info.PriceCurrent())/symbol_info.Point();
               break;
         }
         
         double trigger_point = tp_pips/2.0;
         
         switch(first_order_type) {
            case POSITION_TYPE_BUY:
               // First trailing stop
               if(profit_pips > trigger_point) {
                  double step = (tp_pips/10.0);
                  new_stop_loss = pos_info.PriceOpen(); // + step*symbol_info.Point()*10;
                  Print("Comparison true. New stop loss set to: ", new_stop_loss);
               }
               break;
            case POSITION_TYPE_SELL:
               if(profit_pips > trigger_point) {
                  double step = (tp_pips/10.0);
                  new_stop_loss = pos_info.PriceOpen(); // - step*symbol_info.Point()*10;
                  Print("Comparison true. New stop loss set to: ", new_stop_loss);
               }
               break;
         }
   
         // setting stop loss
         if(new_stop_loss!=0.0) {
            Print("Putting trailing stop");
            request.action  = TRADE_ACTION_SLTP; // type of trade operation
            request.type_filling = ORDER_FILLING_FOK;///
            request.position = pos_info.Ticket();   // ticket of the position
            request.symbol = pos_info.Symbol();
            request.sl = new_stop_loss;                // Stop Loss of the position
            request.tp = pos_info.TakeProfit();
            //int res = OrderModify(OrderTicket(),OrderGetDouble(ORDER_PRICE_OPEN), new_stop_loss, OrderTakeProfit(), OrderExpiration(), 0);
            if(!OrderSend(request,result)) {
               PrintFormat("OrderSend error %d",GetLastError());  // if unable to send the request, output the error code
            } else {
               Print("Set trailing stop to new sl: ", new_stop_loss);
               magic_numbers_trailing[magic]++;
            }
            
         }
      }
   }
   return 0;
}

int setConservativeStopLoss(int magic, int first_order_type, double first_order_price){
   MqlTradeRequest request = {};
   MqlTradeResult  result = {};
   
   //--- object for receiving symbol settings
   CSymbolInfo symbol_info;
   //--- set the name for the appropriate symbol
   symbol_info.Name(_Symbol);
   
   double new_stop_loss = 0.0;
   double new_take_profit = 0.0;
   
   switch(first_order_type) {
      case POSITION_TYPE_BUY:
         new_stop_loss = first_order_price - (reco_pips/2)*symbol_info.Point()*10;
         break;
      case POSITION_TYPE_SELL:
         new_stop_loss = first_order_price + (reco_pips/2)*symbol_info.Point()*10;
         break;
   }
   
   CPositionInfo pos_info;
   
   for (int i = PositionsTotal() - 1; i >= 0; i--) {
      if(pos_info.SelectByIndex(i) == false ) {
         //Print("ERROR - Unable to select the order - ",GetLastError());
         break;
      }
      
      if(pos_info.Magic() == magic) {
         request.action  = TRADE_ACTION_SLTP; // type of trade operation
         request.type_filling = ORDER_FILLING_FOK;///
         request.position = pos_info.Ticket();   // ticket of the position
         request.symbol = pos_info.Symbol();
         request.sl = new_stop_loss;                // Stop Loss of the position
         request.tp = pos_info.TakeProfit();
         
         if(!OrderSend(request,result)) {
            PrintFormat("OrderSend error %d",GetLastError());  // if unable to send the request, output the error code
         } else{
            magic_numbers_trailing[magic] = 1;
         }
      }
   }
   
   return 0;
}


int sendNextOrder(string symbol, int first_order_type, double first_order_price, int opened_orders, int magic_number) {

   double new_order_size = trades_sizes[opened_orders];
   int new_order_type = -1;
   double new_order_price = -1;
   double new_order_tp = -1;
   double new_order_sl = -1;
   
   CSymbolInfo symbol_info;
   symbol_info.Name(_Symbol);
   
   //Print("First order type: ", first_order_type);
   switch(first_order_type)
      {
      case POSITION_TYPE_BUY:
            if(opened_orders % 2 == 0) { // Buy
               new_order_type = ORDER_TYPE_BUY_STOP;
               new_order_price = first_order_price;
               new_order_tp = first_order_price + tp_pips*symbol_info.Point()*10;
               new_order_sl = first_order_price - (tp_pips + reco_pips)*symbol_info.Point()*10;
               if(conservative_stop==true){
                  new_order_sl = first_order_price - (reco_pips/2)*symbol_info.Point()*10;
               }
            }else { // Sell
               new_order_type = ORDER_TYPE_SELL_STOP;
               new_order_price = first_order_price - reco_pips*symbol_info.Point()*10;
               new_order_tp = first_order_price - (tp_pips + reco_pips)*symbol_info.Point()*10;
               new_order_sl = first_order_price + tp_pips*symbol_info.Point()*10;
               if(conservative_stop==true){
                  new_order_sl = first_order_price - (reco_pips/2)*symbol_info.Point()*10;
               }
            }
            break;
      case POSITION_TYPE_SELL:
            if(opened_orders % 2 == 0) { // Sell
               new_order_type = ORDER_TYPE_SELL_STOP;
               new_order_price = first_order_price;
               new_order_tp = first_order_price - tp_pips*symbol_info.Point()*10;
               new_order_sl = first_order_price + (tp_pips + reco_pips)*symbol_info.Point()*10;
            } else{
               new_order_type = ORDER_TYPE_BUY_STOP;
               new_order_price = first_order_price + reco_pips*symbol_info.Point()*10;
               new_order_tp = first_order_price + (tp_pips + reco_pips)*symbol_info.Point()*10;
               new_order_sl = first_order_price - tp_pips*symbol_info.Point()*10;
            }
            break;
      }
   
   // Send Order
   MqlTradeRequest request = {};
   MqlTradeResult  result={};
   
   request.type   = (ENUM_ORDER_TYPE)new_order_type;
   request.type_filling = ORDER_FILLING_FOK;///
   request.action = TRADE_ACTION_PENDING;  // definir una orden pendiente
   request.magic  = magic_number;    // ORDER_MAGIC
   request.symbol = _Symbol;         // instrumento
   request.volume = new_order_size;  // volumen d
   request.sl     = new_order_sl;    // Stop Loss 
   request.tp     = new_order_tp;    // Take Profit
   request.price  = new_order_price; // Price
   request.comment = IntegerToString(opened_orders+1);

   ResetLastError();
   
   int err = OrderSend(request,result);
   if(!err){
      Print("Fail to set next order ", request.order,": Error ",GetLastError(),", retcode = ",result.retcode);
         Print("Type: ", request.type);
         Print("Type filling: ", request.type_filling);
         Print("Action: ", request.action);
         Print("Magic: ", request.magic);
         Print("Symbol: ", request.symbol);
         Print("Volume: ", request.volume);
         Print("Stop loss: ", request.sl);
         Print("Take profit: ", request.tp);
         Print("Request price: ", request.price);
         Print("Comment: ", request.comment);
   } else{
         Print("Next request sent.");
         tradesnr++;
         magic_numbers_trades[magic_number] = magic_numbers_trades[magic_number] + 1;
         //Print("sendNextOrder(): #", tradesnr, " Order placed at ", new_order_price, " sl: ", new_order_sl, " tp: ", new_order_tp, " size: ", new_order_size);
         //Print("sendNextOrder(): magic nr: ", magic_number, " opened orders: ", opened_orders);
         //Print("Balance: ", AccountInfoDouble(ACCOUNT_BALANCE));
         //Print("Equity: ", AccountInfoDouble(ACCOUNT_EQUITY));
   }
   return err;
}
