//+------------------------------------------------------------------+
//|                                                     RecoveryZone |
//|                                      Copyright 2022, CompanyName |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "FG"
#property link ""
#property version "0.1"
#property strict
#property description "RecoveryZone"
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//extern ENUM_TIMEFRAMES timeframe = 5; // Timeframe
extern double first_trade_size = 0.1;
extern double size_multipler = 1; // Size multiplier
extern int slippage = 2;
extern int max_trade_orders = 8;
extern int tp_pips = 60;
extern int reco_pips = 20; 

extern int period = 5; // Period (min)
// Trading hours
extern int start_hour = 6;
extern int end_hour = 16;

// Conservative stop loss
extern bool conservative_stop = false; // Conservative SL
extern bool trailing_stop = false;

double trades_sizes[10] = {0.1, 0.14, 0.1, 0.14, 0.19, 0.25, 0.33, 0.44, 0.59, 0.78};
string markets[5] = {"EURUSD", "EURGBP", "GBPUSD", "EURCHF", "USDCAD"};

// To be instantiated in OnInit()
double account_free_margin = -1;
double account_equity = -1;
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

int OnInit()
  {   
   // Variables
   magic_numbers_cont = 0;
   magic_numbers_size = 0;
   
   // Parameters check
   if (max_trade_orders > 10)
      return(INIT_PARAMETERS_INCORRECT); // Not tested

   // Getting equity
   account_equity = AccountEquity();
   Print("Account equity: ", account_equity);
   
   // Getting free margin
   account_free_margin = AccountFreeMargin();
   Print("Account free margin: ", account_free_margin);
   
   // Calculate size needed for a trade (worst scenario: max_trade_orders)
   trade_size_required = getRequiredSize();
   Print("Size required by a trade: ", trade_size_required);
   
   // Allocate magic_numbers array and initializing elements to -1 
   Print("Trade size required ", trade_size_required);
   Print("Eurperlot ", eurperlot);
   Print("trade_size_required*eurperlot ", trade_size_required*eurperlot);
   
   int sz = MathRound((account_equity)/(trade_size_required*eurperlot))*2.0;
   Print("Size::::", sz);
   initMagicNumbers(sz, 0);
   
   return(INIT_SUCCEEDED);
}

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


void OnTick()
  {

      // Check orders every minute
      checkOrders();
      
      // Trade every "period" minutes
      if(Minute() % period == 0) {
         Print("5 mins");
         Print(TimeCurrent());
         // Enough margin to open a trade?
         int free_trades = getFreeTrades();
         Print("OnTick(): Free trades: ", free_trades);
         
         if(free_trades>0 && isTradingSession() ) { //How many 1st operations can I open? Also will depend on maximal drawdown allowed
            // Look for 1st operation
            int scan = marketScan();
         }
      }
}


int marketScan() {
   int num = MathRand()%10 + 1; // int btw 1 and 10
   if(num == 5) { // => prob 0.1
      string market = "EURUSD";
   
      int type = OP_BUY;
      int magic_number = getFreeMagicNumber();
      
      // https://docs.mql4.com/trading/ordersend
      int res = OrderSend(Symbol(), 
                OP_BUY, 
                trades_sizes[0], 
                Ask, 
                2, 
                Bid-(tp_pips+reco_pips)*Point*10, 
                Bid+tp_pips*Point*10,
                "1",   // we also have "expiration" parameter
                magic_number);
      
      
      // Error checking
      int err = GetLastError();
      switch(err)                             // Overcomable errors
        {
        case 0:
            tradesnr++;
            magic_numbers_trades[magic_number] = 1;
            magic_numbers_trailing[magic_number] = 0;
            break;
         case 129:Alert("marketScan(): Invalid price. Retrying..");
            RefreshRates();                     // Update data
         case 135:Alert("marketScan(): The price has changed. Retrying..");
            RefreshRates();                     // Update data
         case 146:Alert("marketScan(): Trading subsystem is busy. Retrying..");
            Sleep(500);                         // Simple solution
            RefreshRates();                     // Update data
            
         case 2 : Alert("marketScan(): Common error.");
            break;                              // Exit 'switch'
         case 5 : Alert("marketScan(): Outdated version of the client terminal.");
            break;                              // Exit 'switch'
         case 64: Alert("marketScan(): The account is blocked.");
            break;                              // Exit 'switch'
         case 133:Alert("marketScan(): Trading fobidden");
            break;                              // Exit 'switch'
         default: Alert("marketScan(): Occurred error ",err);// Other alternatives   
        }
      
      return err;
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
         
         // Counting opened and pending orders for this magic_number
         for (int i = 0; i < OrdersTotal(); i++) {
            if( OrderSelect( i, SELECT_BY_POS, MODE_TRADES ) == false ) {
               Print("ERROR - Unable to select the order - ",GetLastError());
               break;
            } 
            
            if(OrderMagicNumber() == magic_numbers[magic]){
               if(OrderType() != OP_BUY && OrderType() != OP_SELL) { // if order is not opened yet
                  pending_orders++;
               } else {
                  opened_orders++;
                  Print("OrderOpenTime: ", OrderOpenTime());
                  Print("FirstOrderTime: ", first_order_time);
                  if(OrderOpenTime() <= first_order_time) { // Saving info of 1st order
                     first_order_type = OrderType();
                     first_order_time = OrderOpenTime();
                     first_order_price = OrderOpenPrice();
                     first_order_symbol = OrderSymbol();
                     Print("CheckOrders(): First order type found: ", first_order_type);
                  }
               }
            }
         }
         
         total_orders = opened_orders + pending_orders;
         Print("CheckOrders(): Total orders: ", total_orders);
         Print("CheckOrders(): Open orders: ", opened_orders);
         Print("CheckOrders():Pending orders: ", pending_orders);
         
         switch(total_orders)
            {
            case 0:
               // Remove Magic Number, TP or SL hit
               Print("Placed order CLOSED!");
               removeMagicNumber(magic);
               break;
            
            default: // total_orders >= 1
               // Checks
               if(pending_orders > 1){
                  Alert("CheckOrders(): Too many pending orders!"); // We should not have more pending orders for a magic number
               }
               
               // TP hit before last pending order triggering
               if(opened_orders==0 && pending_orders == 1){
                  // If it's not the 1st, cancel it
                  cancelOrderIfNotFirst(magic);
                  
                  Print("CheckOrders(): Closed");
               }
               
               // Partial closing of orders
               if(pending_orders == 0 && opened_orders < max_trade_orders && magic_numbers_trades[magic] > opened_orders){
                  cancelAllOrders(magic);
               }
               
               // Next order: standard case 
               if(pending_orders == 0 && opened_orders < max_trade_orders && magic_numbers_trades[magic] == opened_orders && magic_numbers_trailing[magic]==0) {
                  Print("SENDING ORDER WITH LOTS ", trades_sizes[opened_orders]);
                  Print("CheckOrders(): First order type: ", first_order_type);
                  Print("CheckOrders(): Open orders: ", opened_orders, ", pending orders: ", pending_orders);
                  int err = sendNextOrder(first_order_symbol, first_order_type, first_order_price, opened_orders, magic);
                  Print("CheckOrders(): Order nr ", opened_orders+1);
               }
               
               // Conservative stop (just after last position opening)
               if(conservative_stop && pending_orders == 0 && opened_orders == max_trade_orders && magic_numbers_trades[magic] == opened_orders) {
                  setConservativeStopLoss(magic, first_order_type, first_order_price);
               }
               
               // Trailing stop
               if(opened_orders==1 && magic_numbers_trades[magic] == opened_orders && magic_numbers_trailing[magic]==0){
                  Print("Checking for trailing stop");
                  int res = setTrailingStop(magic, first_order_type, first_order_price);
               }
               break;
            } 
      }  
   }
}

int setTrailingStop(int magic, int first_order_type, double first_order_price) {
   double new_stop_loss = 0.0;
   
   for(int i=OrdersTotal()-1;i>=0;i--){
      if((OrderSelect(i,SELECT_BY_POS,MODE_TRADES))&&(OrderMagicNumber()==magic)) {
      
         // Getting profit in pips
         double profitPips = OrderProfit() - OrderSwap() - OrderCommission(); // To be checked
         Print("Profit pips: ", profitPips, " openprice: ", OrderOpenPrice(), " orderprofit: ", OrderProfit());
         
         switch(first_order_type) {
            case OP_BUY:
               // First trailing stop
               if(magic_numbers_trailing[OrderMagicNumber()]==0 && profitPips > tp_pips/3) {
                  new_stop_loss = OrderOpenPrice() + (reco_pips/6)*Point*10;
               }
               
               break;
            case OP_SELL:
               if(magic_numbers_trailing[OrderMagicNumber()]==0 && profitPips > tp_pips/3) {
                  new_stop_loss = OrderOpenPrice() - (reco_pips/6)*Point*10;
               }
               break;
         }
         
         if(new_stop_loss!=0.0) {
            int res = OrderModify(OrderTicket(),OrderOpenPrice(), new_stop_loss, OrderTakeProfit(), OrderExpiration(), 0);
            Print("Set trailing stop to new sl: ", new_stop_loss);
            magic_numbers_trailing[magic]++;
         }
      }
   }
   return 0;
}

int setConservativeStopLoss(int magic, int first_order_type, double first_order_price){
   double new_stop_loss = 0.0;
   
   switch(first_order_type) {
      case OP_BUY:
         new_stop_loss = first_order_price - (reco_pips/2)*Point*10;
         break;
      case OP_SELL:
         new_stop_loss = first_order_price + (reco_pips/2)*Point*10;
         break;
   }
   
   for(int i=OrdersTotal()-1;i>=0;i--){
      if((OrderSelect(i,SELECT_BY_POS,MODE_TRADES))&&(OrderMagicNumber()==magic)) {
         int res = OrderModify(OrderTicket(),OrderOpenPrice(), new_stop_loss, OrderTakeProfit(), OrderExpiration(), 0);
      }
   }
   
   return 0;
}
int cancelAllOrders(int magic) {

   for(int i=OrdersTotal()-1;i>=0;i--){
      if((OrderSelect(i,SELECT_BY_POS,MODE_TRADES))&&(OrderMagicNumber()==magic)) {
            int res = OrderDelete(OrderTicket());
      }
   }
   
   return 0;
}

int cancelOrderIfNotFirst(int magic) {

   for(int i=OrdersTotal()-1;i>=0;i--){
      if((OrderSelect(i,SELECT_BY_POS,MODE_TRADES))&&(OrderMagicNumber()==magic)) {
         if(OrderComment()!="1"){
            OrderDelete(OrderTicket());
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
   
   Print("First order type: ", first_order_type);
   switch(first_order_type)
      {
      case OP_BUY:
            if(opened_orders % 2 == 0) { // Buy
               new_order_type = OP_BUYSTOP;
               new_order_price = first_order_price;
               new_order_tp = first_order_price + tp_pips*Point*10;
               new_order_sl = first_order_price - (tp_pips + reco_pips)*Point*10;
               if(conservative_stop==true){
                  new_order_sl = first_order_price - (reco_pips/2)*Point*10;
               }
            }else { // Sell
               new_order_type = OP_SELLSTOP;
               new_order_price = first_order_price - reco_pips*Point*10;
               new_order_tp = first_order_price - (tp_pips + reco_pips)*Point*10;
               new_order_sl = first_order_price + tp_pips*Point*10;
               if(conservative_stop==true){
                  new_order_sl = first_order_price - (reco_pips/2)*Point*10;
               }
            }
            break;
      case OP_SELL:
            if(opened_orders % 2 == 0) { // Sell
               new_order_type = OP_SELLSTOP;
               new_order_price = first_order_price;
               new_order_tp = first_order_price - tp_pips*Point*10;
               new_order_sl = first_order_price + (tp_pips + reco_pips)*Point*10;
               if(conservative_stop==true){
                  new_order_sl = first_order_price + (reco_pips/2)*Point*10;
               }
            }else{
               new_order_type = OP_BUYSTOP;
               new_order_price = first_order_price - reco_pips*Point*10;
               new_order_tp = first_order_price + (tp_pips + reco_pips)*Point*10;
               new_order_sl = first_order_price - tp_pips*Point*10;
               if(conservative_stop==true){
                  new_order_sl = first_order_price + (reco_pips/2)*Point*10;
               }
            }
            break;
      }
   
   // Send Order
   int res = OrderSend(Symbol(), // symbol
             new_order_type,  // cmd
             new_order_size,  // volume
             new_order_price, // price
             slippage,        // slippage
             new_order_sl,    // stoploss
             new_order_tp,    // takeprofit
             IntegerToString(opened_orders+1), //comment, Cardinality of the order
             magic_number);   //magic
    
   // Error checking
   int err = GetLastError();
   switch(err)                             // Overcomable errors
     {
      case 0:
         tradesnr++;
         magic_numbers_trades[magic_number] = magic_numbers_trades[magic_number] + 1;
         Print("sendNextOrder(): #", tradesnr, " Order placed at ", new_order_price, " sl: ", new_order_sl, " tp: ", new_order_tp, " size: ", new_order_size);
         Print("sendNextOrder(): magic nr: ", magic_number, " opened orders: ", opened_orders);
         Print("Balance: ", AccountBalance());
         Print("Equity: ", AccountEquity());
         break;
      case 129:Alert("sendNextOrder(): Invalid price. Retrying..");
         RefreshRates();                     // Update data
      case 135:Alert("sendNextOrder(): The price has changed. Retrying..");
         RefreshRates();                     // Update data
      case 146:Alert("sendNextOrder(): Trading subsystem is busy. Retrying..");
         Sleep(500);                         // Simple solution
         RefreshRates();                     // Update data
      case 2 : Alert("sendNextOrder(): Common error.");
         break;                              // Exit 'switch'
      case 5 : Alert("sendNextOrder(): Outdated version of the client terminal.");
         break;                              // Exit 'switch'
      case 64: Alert("sendNextOrder(): The account is blocked.");
         break;                              // Exit 'switch'
      case 133:Alert("Trading fobidden");
         break;                              // Exit 'switch'
      default: Alert("Occurred error ",err);// Other alternatives   
     }
   
   return err;
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
      magic = getFreeMagicNumber();
   }
   
   // Updating counter of current trades
   magic_numbers_cont++;
   
   return magic;
}

void removeMagicNumber(int n){
   magic_numbers[n] = -1;
   magic_numbers_trades[n] = 0;
   magic_numbers_trailing[n] = 0;
   
   // Updating counter of current trades
   magic_numbers_cont--; 
   return;
}

/*
int oppositeOp(int op) {
   if(op==OP_BUY || op==OP_BUYLIMIT || op==OP_BUYSTOP) return OP_SELLSTOP;
   if(op==OP_SELL || op==OP_SELLLIMIT || op==OP_SELLSTOP) return OP_BUYSTOP;   
}
*/

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
   Print("Size required: ", size_required);
   Print("Trade size required: ", trade_size_required);
   Print("Eur per lot: ", eurperlot);
   */
   
   // Margin level = (Equity/Used Margin) X 100
   // Margin level if another position is opened (+size_required)
   double potential_margin_level = 101;
   int trades = 1;
   while(potential_margin_level > 100) {
      potential_margin_level = (AccountEquity()/(potential_busy_margin + trades*size_required))*100;
      
      if(potential_margin_level > 100) {
         trades++;
         free_trades++;
      }
   }
   
   return free_trades;
}

bool isTradingSession()
{
    if (start_hour < end_hour)
    {
        if (Hour() >= start_hour && Hour() <= end_hour)
            return (true);
        return (false);
    }
    if (start_hour > end_hour)
    {
        if (Hour() >= start_hour && Hour() <= end_hour)
            return (true);
        if (Hour() <= end_hour)
            return (true);
        return (false);
    }
    if (Hour() == start_hour)
        return (true);
    return (false);
}