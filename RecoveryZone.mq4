//+------------------------------------------------------------------+
//|                                                     RecoveryZone |
//|                                      Copyright 2022, CompanyName |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Francesco Sabiu"
#property link "https://github.com/fsabiu/"
#property version "0.1"
#property strict
#property description "RecoveryZone"
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

struct trade
  {
   string  currency;     // currency of the trade
   string  trade_type;    // BUY, SELL
   short   trade_entry;    // Price
   double  trade_tp;    // Price
   double  trade_sl;         // Price
   int MagicNumber;         // Magic Number
  };

extern double first_trade_size = 0.1
extern double size_multipler = 1; // 1 is strongly recommended to reduce losses
extern int slippage = 2;
extern int max_trade_orders = 8;
extern int tp_pips = 2;
extern int reco_pips = 2;
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
trade trades[]; // array of first trades
 /*
e.g.
			trades[0] = {"EURUSD", "BUY", 0.99880, 0.99990, 0.99780, 001},
			trades[1] = {"EURCHF", "BUY", 0.99880, 0.99990, 0.99780, 002}
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

      if(free_trades>0) {
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

// Returns the maximum number of position that can be open with the current equities and open position (which are considered to evolve according to the worst scenario)
string getFreeTrades(){

   int free_trades = 0

   // Worst case for the currently opened trades
   current_trades = trade_size_required*ArraySize(trades);

   potential_busy_margin = trade_size_required*eurperlot*current_trades;

   // Margin level = (Equity/Used Margin) X 100

   // TODO

   return free_trades
}
