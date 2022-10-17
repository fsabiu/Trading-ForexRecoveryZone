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

class trade {
 public:
   string  currency;        // currency of the trade
   string  trade_type;      // BUY, SELL
   short   trade_entry;     // Price
   double  trade_tp;        // Price
   double  trade_sl;        // Price
   int MagicNumber;         // Magic Number
   int n_order;             // Number of order wrt trade (1 <= n_order <= max_trade_orders)
   //--- Default constructor
   trade(void);
   //--- Parametric constructor
   trade(string cur, string  t_type, short   t_entry, double  t_tp, double  t_sl, int MNum, int n_ord);      
  };
//+------------------------------------------------------------------+
//| Parametric constructor                                           |
//+------------------------------------------------------------------+
trade::trade(string cur, string t_type, short t_entry, double t_tp, double t_sl, int MNum, int n_ord) {
   string  currency = cur;        // currency of the trade
   string  trade_type = t_type;      // BUY, SELL
   short   trade_entry = t_entry;     // Price
   double  trade_tp = t_tp;        // Price
   double  trade_sl = t_sl;        // Price
   int MagicNumber = MNum;         // Magic Number
   int n_order = n_ord;             // Number of order wrt trade (1 <= n_order <= max_trade_orders)
}
 
extern ENUM_TIMEFRAMES timeframe = 5; // Timeframe
extern double first_trade_size = 0.1
extern double size_multipler = 1; // 1 is strongly recommended to reduce losses
extern int slippage = 2;
extern int max_trade_orders = 8;
extern int tp_pips = 60;
extern int reco_pips = 20;
extern string markets[5] = {"EURUSD", "EURGBP", "GBPUSD", "EURCHF", "USDCAD"};
extern double trades_sizes[10] = {0.1, 0.14, 0.1, 0.14, 0.19, 0.25, 0.33, 0.44, 0.59, 0.78};


// To be instantiated in OnInit()
double account_margin = -1;
double account_equity = -1;
double trade_size_required = -1; // Dictionary needed for multicurrency
double eurperlot = 3300; // Leverage 1:30, dictionary needed for multicurrency and/or different leverage


// To be updated at each new position opening
int free_trades; // How many trades can I start with the current margin?
int busy_magic_numbers[];
trade trades[]; // array of arrays of trades
 /*
e.g. 
			trades[0] = [{"EURUSD", "BUY", 0.99880, 0.99990, 0.99780, 001, 1}, 
			             {"EURUSD", "SELL", 0.99880, 0.99990, 0.99780, 001, 2}, 
			             ...
			            ]
			trades[1] = {"EURCHF", "BUY", 0.99880, 0.99990, 0.99780, 002, 1}
*/

  
//////////////////////////////////////////////////////////////
int OnInit()
  {

   // If broker/market allows increments of 0.1 lots, update the nor_lot variable
   if(MarketInfo(Symbol(),MODE_LOTSTEP)==0.1) nor_lot=1;

   // Parameters check
   if (max_trade_orders > 10)
      return(INIT_PARAMETERS_INCORRECT);

   // Getting equity
   Print("Account equity = ",AccountEquity());
   
   // Getting free margin
   Print("Account free margin = ",AccountFreeMargin());
   
   // Calculate size needed for a trade (worst scenario: max_trade_orders)
   trade_size_required = getRequiredSize();
   
   return(INIT_SUCCEEDED);
}
////////////////////////////////////

void OnTick()
  {

      // Check orders
      checkOrders();
      
      // Enough margin to open a trade?
      free_trades = getFreeTrades();
      
      if(free_trades>0) { //How many 1st operations can I open? Also depends on maximal drawdown
         // Look for 1st operation
         market, op_type, tp, sl, magic_nr = marketScan()
      }
      
      /*
      // Look for 1st operation
        market, op_type, tp, sl, magic_nr = marketScan()
      
        # If opportunities and enough margin
        if (marginFlag="GREEN" and market!=NULL) {
        	int err = opentrade(market, op_type, tp, sl, magic_nr)
      	if(err!=0) {
      		print("Error opening tradeision")
      	}
      
      	int err = setRecoOrders(market, op_type, tp, sl, magic_nr)
      	if(err!=0) {
      		print("Error setting recovery orders")
      	}
        }
      
        else{
        	if(market==NULL)
        		print("No opportunities")
        	if(marginFlag=="RED")
        		print("No enough margin")
        }
            */
        }


trade marketScan() {
   string market = "EURUSD";
   
   
   string type = OP_BUY;
   int magic_number = getFreeMagicNumber();
   
   // open at sell
   double price;
   double tp;
   double sl;
   
   //OrderSend(Symbol(),OP_BUY,0.1,Ask,2,Bid-15*Point,Bid+15*Point);
   OrderSend("EURUSD", OP_BUY, trades_sizes[0], Ask, 2, Bid-(tp_pips+reco_pips)*Point, Bid+tp_pips*Point);
   
   // Error checking
   int Error=GetLastError();                 // Failed :(
   switch(Error)                             // Overcomable errors
     {
      case 129:Alert("Invalid price. Retrying..");
         RefreshRates();                     // Update data
         continue;                           // At the next iteration
      case 135:Alert("The price has changed. Retrying..");
         RefreshRates();                     // Update data
         continue;                           // At the next iteration
      case 146:Alert("Trading subsystem is busy. Retrying..");
         Sleep(500);                         // Simple solution
         RefreshRates();                     // Update data
         continue;                           // At the next iteration
     }
   switch(Error)                             // Critical errors
     {
      case 2 : Alert("Common error.");
         break;                              // Exit 'switch'
      case 5 : Alert("Outdated version of the client terminal.");
         break;                              // Exit 'switch'
      case 64: Alert("The account is blocked.");
         break;                              // Exit 'switch'
      case 133:Alert("Trading fobidden");
         break;                              // Exit 'switch'
      default: Alert("Occurred error ",Error);// Other alternatives   
     }
   break;                                    // Exit cycle
   }
   
   // Fetch order and fill trades structure
      // set tp
      // set sl;
      
      // set next trade
      // add struct to trades
   
}

void checkOrders() {
   // Close pending orders if TP or SL have been hit
   
   /*
   for trade in trades:
		if(trade.OP_MagicNumber is not in in myOpentrades)
			remove trade from trade
	*/
	
	
	// Trailing stop
	// Trail the SL if only 1st trade is opened and 
	
	/*
	for trade in trades:
		if(only 1st trade is opened)
			if(currentPrice > buy + (TP/2) pips):
				cancell all orders
				SL = currentPrice - (TP/2) pips
				TP = TP + (TP/2)
   */
}

// Returns the max total size needed to start a trade (worst scenario)
double getRequiredSize() {

   required_size = 0;
   
   for (int i = 0; i<=max_trade_orders; i++) {
      total_size += trades_sizes[i];
   }
   
   return required_size;
}

// Returns the maximum number of position that can be open with the current equitiy and opened position (which are considered to evolve according to the worst scenario)
// i.e. how many position will keep the margin level above 100 with max_trade_orders per trade
int getFreeTrades(){
   
   int free_trades = 0
   
   // Worst case for the currently opened trades
   current_trades = trade_size_required*ArraySize(trades);
   
   // TODO consider trades with trail stop or SL at breakeven
   size_required = trade_size_required*eurperlot; // size required by a trade with current size
   potential_busy_margin = size_required*current_trades;
   
   // Margin level = (Equity/Used Margin) X 100
   // Margin level if another position is opened (+size_required)
   potential_margin_level = 101;
   trades = 1;
   while(potential_margin_level > 100) {
      potential_margin_level = (AccountEquity()/(potential_busy_margin + i*size_required))*100;
      
      if(potential_margin_level > 100) {
         i++;
         free_trades++;
      }
   }
   
   return free_trades;
}