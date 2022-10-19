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

extern ENUM_TIMEFRAMES timeframe = 5; // Timeframe
extern double first_trade_size = 0.1;
extern double size_multipler = 1; // 1 is strongly recommended to reduce losses
extern int slippage = 2;
extern int max_trade_orders = 8;
extern int tp_pips = 60;
extern int reco_pips = 20;

double trades_sizes[10] = {0.1, 0.14, 0.1, 0.14, 0.19, 0.25, 0.33, 0.44, 0.59, 0.78};
string markets[5] = {"EURUSD", "EURGBP", "GBPUSD", "EURCHF", "USDCAD"};

// To be instantiated in OnInit()
double account_free_margin = -1;
double account_equity = -1;
double trade_size_required = -1; // Dictionary needed for multicurrency
double eurperlot = 3300; // Leverage 1:30, dictionary needed for multicurrency and/or different leverage

// To be updated at each new position opening
int magic_numbers[];
int magic_numbers_cont;
int magic_numbers_size;
  

int OnInit()
  {

   // If broker/market allows increments of 0.1 lots, update the nor_lot variable
   if(MarketInfo(Symbol(),MODE_LOTSTEP)!=0.1) {
      Alert("Increments of 0.1 lots not allowed!");
   }
   
   // Variables
   magic_numbers_cont = 0;
   magic_numbers_size = 0;
   
   // Parameters check
   if (max_trade_orders > 10)
      return(INIT_PARAMETERS_INCORRECT); // Not tested

   // Getting equity
   account_equity = AccountEquity();
   Print("Account equity = ", account_equity);
   
   // Getting free margin
   account_free_margin = AccountFreeMargin();
   Print("Account free margin = ", account_free_margin);
   
   // Calculate size needed for a trade (worst scenario: max_trade_orders)
   trade_size_required = getRequiredSize();
   
   // Allocate magic_numbers array and initializing elements to -1 
   initMagicNumbers(MathRound((account_equity/trade_size_required)*2), 0);
   
   return(INIT_SUCCEEDED);
}

void initMagicNumbers(int new_size, int old_size) {
   magic_numbers_size = new_size;
   
   if(ArrayResize(magic_numbers, magic_numbers_size)< 0) {
      Alert("Array resizing failed!");
   }
   
   for(int i = old_size; i < magic_numbers_size; i++){
      magic_numbers[i] = -1;
   }
}


void OnTick()
  {

      // Check orders
      checkOrders();
      
      // Enough margin to open a trade?
      int free_trades = getFreeTrades();
      
      if(free_trades>0) { //How many 1st operations can I open? Also depends on maximal drawdown allowed
         // Look for 1st operation
         int scan = marketScan();
         
         if(scan!=0) {
            Print("Error", scan);
         }
      }
     
}


int marketScan() {
   string market = "EURUSD";
   
   int type = OP_BUY;
   int magic_number = getFreeMagicNumber();
   
   // https://docs.mql4.com/trading/ordersend
   int err = OrderSend("EURUSD", 
             OP_BUY, 
             trades_sizes[0], 
             Ask, 
             2, 
             Bid-(tp_pips+reco_pips)*Point, 
             Bid+tp_pips*Point,
             "1",   // we also have "expiration" parameter
             magic_number);
   
   
   // Error checking
   
   switch(err)                             // Overcomable errors
     {
      case 129:Alert("Invalid price. Retrying..");
         RefreshRates();                     // Update data
      case 135:Alert("The price has changed. Retrying..");
         RefreshRates();                     // Update data
      case 146:Alert("Trading subsystem is busy. Retrying..");
         Sleep(500);                         // Simple solution
         RefreshRates();                     // Update data
     }
   switch(err)                             // Critical errors
     {
      case 2 : Alert("Common error.");
         break;                              // Exit 'switch'
      case 5 : Alert("Outdated version of the client terminal.");
         break;                              // Exit 'switch'
      case 64: Alert("The account is blocked.");
         break;                              // Exit 'switch'
      case 133:Alert("Trading fobidden");
         break;                              // Exit 'switch'
      default: Alert("Occurred error ",err);// Other alternatives   
     }
   
   return err;
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
                  if(OrderOpenTime() < first_order_time) { // Saving info of 1st order
                     first_order_type = OrderType();
                     first_order_time = OrderOpenTime();
                     first_order_price = OrderOpenPrice();
                     first_order_symbol = OrderSymbol();
                  }
               }
            }
         }
         
         total_orders = opened_orders + pending_orders;
         
         switch(total_orders)
            {
            case 0:
               // Remove Magic Number, TP or SL hit
               removeMagicNumber(magic);
               break;
            
            default: // total_orders > 1
               // Checks
               if(pending_orders > 1){
                  Alert("Too many pending orders!"); // We should not have more pending orders for a magic number
                  break;
               }
               
               // is there a pending order?
               if(pending_orders == 1){
                  Print("Wait...");
               }
               
               if(pending_orders == 0 && opened_orders < max_trade_orders) {
                  int err = sendNextOrder(first_order_symbol, first_order_type, first_order_price, opened_orders, magic);
               }
               break;
            } 
      }  
   }
}


int sendNextOrder(string symbol, int first_order_type, double first_order_price, int opened_orders, int magic_number) {

   double new_order_size = trades_sizes[opened_orders];
   int new_order_type = -1;
   double new_order_price = -1;
   double new_order_tp = -1;
   double new_order_sl = -1;
   
   switch(first_order_type)
      {
      case OP_BUY:
            if(opened_orders % 2 == 0) { // Buy
               new_order_type = OP_BUYSTOP;
               new_order_price = first_order_price;
               new_order_tp = first_order_price + tp_pips*Point;
               new_order_sl = first_order_price - (tp_pips + reco_pips)*Point;
            }else { // Sell
               new_order_type = OP_SELLSTOP;
               new_order_price = first_order_price - reco_pips*Point;
               new_order_tp = first_order_price - (tp_pips + reco_pips)*Point;
               new_order_sl = first_order_price + tp_pips*Point;
            }
            break;
      case OP_SELL:
            if(opened_orders % 2 == 0) { // Sell
               new_order_type = OP_SELLSTOP;
               new_order_price = first_order_price;
               new_order_tp = first_order_price - tp_pips*Point;
               new_order_sl = first_order_price + (tp_pips + reco_pips)*Point;
            }else{
               new_order_type = OP_BUYSTOP;
               new_order_price = first_order_price - reco_pips*Point;
               new_order_tp = first_order_price + (tp_pips + reco_pips)*Point;
               new_order_sl = first_order_price - tp_pips*Point;
            }
            break;
      }
   
   // Send Order
   int err = OrderSend(symbol, // symbol
             new_order_type,  // cmd
             new_order_size,  // volume
             new_order_price, // price
             slippage,        // slippage
             new_order_sl,    // stoploss
             new_order_tp,    // takeprofit
             IntegerToString(opened_orders+1), //comment, Cardinality of the order
             magic_number);   //magic
    
   // Error checking
   switch(err)                             // Overcomable errors
     {
      case 129:Alert("Invalid price. Retrying..");
         RefreshRates();                     // Update data
      case 135:Alert("The price has changed. Retrying..");
         RefreshRates();                     // Update data
      case 146:Alert("Trading subsystem is busy. Retrying..");
         Sleep(500);                         // Simple solution
         RefreshRates();                     // Update data
     }
   switch(err)                             // Critical errors
     {
      case 2 : Alert("Common error.");
         break;                              // Exit 'switch'
      case 5 : Alert("Outdated version of the client terminal.");
         break;                              // Exit 'switch'
      case 64: Alert("The account is blocked.");
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
      if(magic_numbers[i]==-1)
         magic = i;                    // Select
         magic_numbers[magic] = magic; // Set to busy
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

   int required_size = 0;
   
   for (int i = 0; i<=max_trade_orders; i++) {
      required_size += trades_sizes[i];
   }
   
   return required_size;
}

// Returns the maximum number of position that can be open with the current equitiy and opened position (which are considered to evolve according to the worst scenario)
// i.e. how many position will keep the margin level above 100 with max_trade_orders per trade
int getFreeTrades(){
   
   int free_trades = 0;
   
   // Worst case for the currently opened trades
   double current_trades = trade_size_required*ArraySize(magic_numbers);
   
   // TODO consider trades with trail stop or SL at breakeven
   double size_required = trade_size_required*eurperlot; // size required by a trade with current size
   double potential_busy_margin = size_required*current_trades;
   
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