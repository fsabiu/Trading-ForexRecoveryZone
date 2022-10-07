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

struct trade
  {
   string  currency;        // currency of the trade
   string  trade_type;      // BUY, SELL
   short   trade_entry;     // Price
   double  trade_tp;        // Price
   double  trade_sl;        // Price
   int MagicNumber;         // Magic Number
   int n_order;             // Number of order wrt trade (1 <= n_order <= max_trade_orders)           
  };
 
extern ENUM_TIMEFRAMES timeframe = 5; // Timeframe
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
      
      if(free_trades>0) { //How many 1st operations can I open?
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
   
   return free_trades;
}



//////////////////////////////

char Sig_f()
  {
   CountOpenedPositions_f();

   if(Orders_Total==0) // First order
     {
      double rsi=iRSI(Symbol(),0,RSI_period,PRICE_CLOSE,0);
      if(rsi>=RSI_sell_zone) return(-1); // sell
      if(rsi<=RSI_buy_zone) return(1);   // buy
     }
   else // Next orders
     {

      // If we've reached the max nr of orders, do nothing 
      if(Max_orders>0 && Orders_Total>=Max_orders) return(0);

      // Else, fetch the last order 
      // (OrderSelect() function copies order data into program environment and all further calls: https://docs.mql4.com/trading/orderselect)

      Select_last_order_f();
      
      // if last order is BUY
      if(OrderType()==OP_BUY)
        {

         // calculate new distance
         double dist=start_distance*point*MathPow(distance_multiplier,Orders_Total-1);

         // check if distance > max allowed distance
         if(max_distance>0 && dist>max_distance*point) dist=max_distance*point;
         if(min_distance>0 && dist<min_distance*point) dist=min_distance*point;

         // if BUY price <= last order price - dist, return -1 = SELL
         if(Bid<=OrderOpenPrice()-dist) return(-1);
        }

      // if last order is SELL
      if(OrderType()==OP_SELL)
        {

         // calculate new distance
         double dist=start_distance*point*MathPow(distance_multiplier,Orders_Total-1);

         // check if distance > max allowed distance
         if(max_distance>0 && dist>max_distance*point) dist=max_distance*point;
         if(min_distance>0 && dist<min_distance*point) dist=min_distance*point;

         // if SELL price >= last order price + dist, return 1 = BUY
         if(Ask>=OrderOpenPrice()+dist) return(1);
        }
     }//end else


   return(0);
  }
///////////////////////////////////////////////////////////////////////////////////////////////

void open_f()
  {
///////////// LOT /////////////////
   double Lotss=Lot;
   CountOpenedPositions_f();
   Lotss=Lot*MathPow(Lot_multiplier,Orders_Total);
//user limit
   if(max_lot>0 && Lotss>max_lot) Lotss=max_lot;
   if(min_lot>0 && Lotss<min_lot) Lotss=min_lot;
//broker limit
   double Min_Lot =MarketInfo(Symbol(),MODE_MINLOT);
   double Max_Lot =MarketInfo(Symbol(),MODE_MAXLOT);
   if(Lotss<Min_Lot) Lotss=Min_Lot;
   if(Lotss>Max_Lot) Lotss=Max_Lot;

//chek free margin
   if(MarketInfo(Symbol(),MODE_MARGINREQUIRED)*Lotss>AccountFreeMargin()) {Alert("Not enouth money to open order "+string(Lotss)+" lots!");return;}



///////////// MAIN /////////////  
   int ticket_op=-1;
   for(int j_op = 0; j_op < 64; j_op++)
     {
      while(IsTradeContextBusy()) Sleep(200);
      RefreshRates();

      if(Sig_p>0) ticket_op=OrderSend(Symbol(),OP_BUY,NormalizeDouble(Lotss,nor_lot),Ask,Slippage,0,0,comment,Magic,0,clrNONE);
      if(Sig_p<0) ticket_op=OrderSend(Symbol(),OP_SELL,NormalizeDouble(Lotss,nor_lot),Bid,Slippage,0,0,comment,Magic,0,clrNONE);

      if(ticket_op>-1)break;
     }


  }
////////////////////////////////////////////////////////////////////////////////////
void CountOpenedPositions_f()
  {
   buys=0;
   sells=0;
   Orders_Total=0;

   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(OrderSelect(i,SELECT_BY_POS))
        {
         if(OrderMagicNumber()==Magic) // only counts positions opened by the EA
           {
            if(OrderSymbol()==Symbol()) // only counts positions for the current current chart symbol
              {
               if(OrderType()==OP_BUY)      buys++;
               if(OrderType()==OP_SELL)     sells++;
              }
           }
        }
     }

   Orders_Total=buys+sells;
  }
////////////////////////////////////////////////////////////////////
void Select_last_order_f()
  {
   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(OrderSelect(i,SELECT_BY_POS))
        {
         if(OrderMagicNumber()==Magic)
           {
            if(OrderSymbol()==Symbol())
              {
               break;
              }
           }
        }
     }

  }
/////////////////////////////////////////////////////////////////////////////////// 
double Profit_f()
  {
   double prof=0;

   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(OrderSelect(i,SELECT_BY_POS))
        {
         if(OrderMagicNumber()==Magic)
           {
            if(OrderSymbol()==Symbol())
              {
               prof+=OrderProfit()+OrderSwap()+OrderCommission();
              }
           }
        }
     }

   return(prof);
  }
////////////////////////////////////////////////////////////////////////////////
void Close_all_f()
  {
   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(OrderSelect(i,SELECT_BY_POS))
        {
         if(OrderMagicNumber()==Magic)
           {
            if(OrderSymbol()==Symbol())
              {
               bool ticket_ex=false;
               for(int j_ex=0;j_ex<64; j_ex++)
                 {
                  while(IsTradeContextBusy()) Sleep(200);
                  RefreshRates();

                  if(OrderType()==OP_BUY) ticket_ex=OrderClose(OrderTicket(),OrderLots(),Bid,Slippage,clrYellow);
                  else
                     if(OrderType()==OP_SELL) ticket_ex=OrderClose(OrderTicket(),OrderLots(),Ask,Slippage,clrYellow);
                  else
                     if(OrderType()==OP_SELLSTOP || OrderType()==OP_BUYSTOP || OrderType()==OP_SELLLIMIT || OrderType()==OP_BUYLIMIT) ticket_ex=OrderDelete(OrderTicket(),clrBrown);
                  else
                     break;
                  if(ticket_ex==true)break;
                 }
              }
           }
        }
     }

  } 
//+------------------------------------------------------------------+


