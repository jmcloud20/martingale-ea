//+------------------------------------------------------------------+
//|                                                         SISA.mq4 |
//|                              Joseph M Garcia Copyright July 2021 |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Joseph M Garcia Copyright July 2021"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

input string mainSettings="";

extern int TakeProfit = 60;
extern int PipStep = 150;
extern double dynamicMult = .5;
extern int maxTrade = 14;

double previousDayHigh = 0;
double previousDayLow = 0;


input string tpSettings="";

extern int fifty=5;
extern int twentyFive=8;
extern int breakEven=10;


//+------------------------------------------------------------------+
//| Extend initial lot                                               |
//+------------------------------------------------------------------+
bool isInitialSellLimit=false;
int initSellLimit = 0;

bool isInitialBuyLimit=false;
int initBuyLimit = 0;
int initLimit = 1;

//+------------------------------------------------------------------+
//| Switch BUY / SELL                                                |
//+------------------------------------------------------------------+
input string disableSettings="";
extern bool disableBuy = false;
extern bool disableSell = false;


//+------------------------------------------------------------------+
//| Report Vars                                                      |
//+------------------------------------------------------------------+
extern bool enableComment = false;
bool enablePrintJournal = true;
int printMonthDebug = 12;
int printDayDebug = 31;
int printYearDebug = 2021;

//+------------------------------------------------------------------+
//| Global Vars                                                      |
//+------------------------------------------------------------------+
double LotExp = 1.357;
double cutpercent=1;
//double lotMult = .00001;
double lotMult = Point();

//+------------------------------------------------------------------+
//| Expert BUY vars                                                  |
//+------------------------------------------------------------------+
string BuyEAName="BASILIO-V1";
double BuytargetOpen,BuyStartLot,Buyexponential;
int BuymagicNumber = 59485;

datetime currentTime, BuycurrentTime;
double BuylastLotSize = 0.0;

int BuyvSlippage;

// New vars for optimization
bool BuyhasOpenOrder = false, BuyisExecute = false;

//+------------------------------------------------------------------+
//| Cutloss capital feature.                                         |
//+------------------------------------------------------------------+
double BuyinitialBalance, initialBalance;

//+------------------------------------------------------------------+
//| Expert SELL  vars                                                |
//+------------------------------------------------------------------+

string EAName="CRISPIN-V1";
double targetOpen, lowestMargin,lowestEquity,equityPercent,StartLot,exponential;
int magicNumber = 59484;
double lastLotSize = 0.0;

int vSlippage, highTrade;

// New vars for optimization
bool hasOpenOrder = false, isExecute = false;

// Expert init function
int init()
  {
   ObjectsDeleteAll();
   return(0);
  }

// Expert deinit function
int deinit()
  {
   return(0);
  }  
     
   //+------------------------------------------------------------------+
   //| Expert start function                                             |
   //+------------------------------------------------------------------+
   void start(){         
   
      previousDayHigh = iHigh(NULL, PERIOD_D1, 1);
      previousDayLow = iLow(NULL, PERIOD_D1, 1);
      double currentPrice = Close[0];
      
      if(!disableBuy){
         //Buyinitialize();
         //if(currentPrice > previousDayHigh || BuyhasOpenOrder){
            //closeSellTrades();
            startBuy();    
         //}
      }
      if(!disableSell){
         //initialize();
         //if(currentPrice < previousDayLow || hasOpenOrder){
            //closeBuyTrades();
            startSell();   
         //}
      }
      //generateReport();
   }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Expert SELL function                                             |
//+------------------------------------------------------------------+

   int startSell(){
      //Initialize start lot.
      double sellMult = Month() <= 3 || Month() >= 11 || Month() == 7 ? dynamicMult / 2 : dynamicMult;
      StartLot = AccountBalance() * lotMult * sellMult;
      
      // Get last lot size.
      // Check for open orders.
      // Check if will execute a SELL trade.
      initialize();   
      
      // Execute only on closing and without open order
      if(currentTime == Time[0] && hasOpenOrder)
         return (0);
         
      currentTime = Time[0];
      
      
      // Reset the initial sell limit if there are no open order; regular process should proceed;
      if(!hasOpenOrder){
         isInitialSellLimit = false;    
         initSellLimit = 0;  
      }
      
      if(hasOpenOrder){      
         if(isExecute){
            //generateLastOrderDetails();
            // Open Order  
            
            if(isInitialSellLimit){
               // Generate lot size.
               openOrder(generateLotSize()); 
            }else{
               openOrder();
               initSellLimit++;
               if(initSellLimit == initLimit){
                  isInitialSellLimit = true;
               }
            }
            // Generate TP.
            double tp = NormalizeDouble(generateTp(), Digits);
            // Modify Open Trades
            modifyOpenTrades(tp);
         }else{
            // If did not execute a trade, no need to generate report.
            return 0;
         }
         
       }else{
         //reset lot sizing
         exponential = 0;
         //Open first order
         //if(previousDayLow > Ask){
            openOrder();
            //modifyOpenTrades();
          //}
         // No need to generate report if first order.
         return 0;
       }
       
       return(0);
   }
   
   void generateReport(){
      // For debug printing report.
       double margin = AccountEquity() / AccountMargin () * 100;
       
       if(lowestMargin == 0 || margin < lowestMargin){
         lowestMargin = margin;
       }
       
       double initialEquityPercent = (AccountEquity() / AccountBalance())*100;
       
       if(lowestEquity==0||initialEquityPercent<equityPercent){
         lowestEquity = AccountEquity();
         equityPercent = initialEquityPercent;
       }
       
       if(highTrade == 0 || getTotalOrders() > highTrade || BuygetTotalOrders() > highTrade){
         if(getTotalOrders() > highTrade){
            highTrade = getTotalOrders();
         }else if (BuygetTotalOrders() > highTrade){
            highTrade = BuygetTotalOrders();
         }else if (highTrade == 0){
            highTrade = getTotalOrders();
         }
         
       }
       
       //Print in journal
       if(enablePrintJournal && Month() == printMonthDebug && Day() == printDayDebug && Year() == printYearDebug){
          Print("Lowest Margin: "+DoubleToString(lowestMargin,2));
          Print("Lowest Equity: "+DoubleToString(lowestEquity*.01,2)+" ("+DoubleToString(equityPercent,2)+"%)");
          Print("Account Balance: "+DoubleToString(AccountBalance()*.01,2));
       }
       
       if(enableComment){
          Comment(
             "-------------------------------------------------"+
             "\nLowest Margin: "+DoubleToString(lowestMargin,2)+
             "\nLowest Equity: "+DoubleToString(lowestEquity*.01,2)+" ("+DoubleToString(equityPercent,2)+"%)"+
             "\nAccount Balance: "+DoubleToString(AccountBalance()*.01,2)+
             "\nCovered Pips: "+(IntegerToString(highTrade*PipStep))+
             "\nHighest Trade: "+IntegerToString(highTrade)+
             "\n-------------------------------------------------");
        }
   }

   void modifyOpenTrades(double tp){      
      bool hasError=false;
      for(int i=0;i<OrdersTotal();i++){
         bool selectHasError = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
         // Only get orders with magic number and BUY trades.
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == magicNumber && OrderType() == OP_SELL){
            if(OrderTakeProfit() != tp){
               //hasError = OrderModify(OrderTicket(),0, previousDayLow > Ask ? previousDayLow : 0, tp, 0,CLR_NONE);
               hasError = OrderModify(OrderTicket(),0, 0, tp, 0,CLR_NONE);
               //Make sure to get the last lot size.
               lastLotSize = OrderLots();
            }
         }
      }
  }
  
  void modifyOpenTrades(){      
      bool hasError=false;
      for(int i=0;i<OrdersTotal();i++){
         bool selectHasError = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
         // Only get orders with magic number and BUY trades.
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == magicNumber && OrderType() == OP_SELL){
               hasError = OrderModify(OrderTicket(),0, previousDayLow > Ask ? previousDayLow : 0, OrderTakeProfit(), 0,CLR_NONE);
               //Make sure to get the last lot size.
               lastLotSize = OrderLots();
            
         }
      }
  }
  
  int getTotalOrders(){
      int counter = 0;
      for(int i=0;i<OrdersTotal();i++){
         bool selectHasError = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
         // Only get orders with magic number and BUY trades.
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == magicNumber && OrderType() == OP_SELL){
            counter++;
         }
      }
   return counter;
  }
  
  /**
  * Get last lot size.
  * Check for open orders.
  * Check if will execute a SELL trade.
  * Generate TP
  */
  void initialize(){
      hasOpenOrder = false;
      isExecute = false;
      
      for(int i=0;i<OrdersTotal();i++){
         bool selectHasError = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
         // Only get orders with magic number and SELL trades.
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == magicNumber && OrderType() == OP_SELL){
            // Last lot size
            lastLotSize = OrderLots();
            // Has open order
            hasOpenOrder = true;
            // Execute a trade.
            // Get the target price to open a trade.
            targetOpen = OrderOpenPrice() + (PipStep * Point()); 
            if(Bid >= targetOpen){
               isExecute = true;
            }         
         }
      }
  }
  
  double generateTp(){
  
      double averagePrice = 0;
      double totalLots = 0;
      //get all Orders
      for(int i=0;i<OrdersTotal();i++){
         bool selectHasError = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
         // Only get orders with magic number and BUY trades.
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == magicNumber && OrderType() == OP_SELL){
            double computePrice = OrderLots() * OrderOpenPrice();
            totalLots = totalLots + OrderLots();
            averagePrice = averagePrice + computePrice; 
         }
                 
      }      
      averagePrice = averagePrice / totalLots;
      int totalOrders = getTotalOrders();
      int sellTP=0;
      if(totalOrders>fifty){
         sellTP = TakeProfit / 2;
      }else if(totalOrders>twentyFive){
         sellTP = TakeProfit / 4;
      }else if(totalOrders>breakEven){
         sellTP = 0;
      }else{
         sellTP = TakeProfit;
      }
      double tp = NormalizeDouble(averagePrice - (sellTP * Point()), Digits);
      
      return tp;
  }   
  
  double generateLotSize(){
  
      if(exponential == 0){
         exponential = getTotalOrders();
      }else{
         exponential = LotExp;
      }
      
      double lotSize = 0;
      lotSize = NormalizeDouble(lastLotSize * exponential, 2);
      
      return lotSize;
  }
  
  void openOrder(double lots){  
      if(Bid>targetOpen && getTotalOrders()< maxTrade){   
         bool sendHasError = OrderSend(
            Symbol(),
            OP_SELL, 
            NormalizeDouble(lots, 2), 
            Bid, 
            vSlippage, 
            0, 
            0, 
            StringConcatenate(EAName,"-",IntegerToString(getTotalOrders())), 
            magicNumber, 
            0, 
            Red);
      }
  }
  
  void openOrder(){
      double tp = Bid - (TakeProfit * Point());
      if(StartLot < .01){
         StartLot = .01;
      }
      
      bool sendHasError = OrderSend(
               Symbol(), 
               OP_SELL,
               NormalizeDouble(StartLot, 2), 
               Bid, 
               vSlippage, 
               0, 
               tp, 
               StringConcatenate(EAName,"-",IntegerToString(getTotalOrders())), 
               magicNumber, 0, Red); 
  }

//+------------------------------------------------------------------+
//| Expert BUY function                                             |
//+------------------------------------------------------------------+
   int startBuy(){
      //Initialize start lot.
      double buyMult = Month() <= 3 || Month() >= 11  || Month() == 7 ? dynamicMult / 2 : dynamicMult ;
      BuyStartLot = AccountBalance() * lotMult * buyMult; 
      
      // Get last lot size.
      // Check for open orders.
      // Check if will execute a BUY trade.
      Buyinitialize();
      
      // Execute only on closing and without open order
      if(BuycurrentTime == Time[0] && BuyhasOpenOrder)
         return (0);             
         
      BuycurrentTime = Time[0];
      
       // Reset the initial buy limit if there are no open order; regular process should proceed;
      if(!BuyhasOpenOrder){
         isInitialBuyLimit = false;    
         initBuyLimit = 0;  
      }
     
      if(BuyhasOpenOrder){
         if(BuyisExecute){
            //BuygenerateLastOrderDetails();
            // Generate lot size.         
            if(isInitialBuyLimit){
               // Open Order   
               BuyopenOrder(BuygenerateLotSize());    
            }else{
               BuyopenOrder();
               initBuyLimit++;
               if(initBuyLimit == initLimit){
                  isInitialBuyLimit = true;
               }
            }        
            // Generate TP.
            double tp = NormalizeDouble(BuygenerateTp(), Digits);
            // Modify Open Trades
            BuymodifyOpenTrades(tp);
         }
         
       }else{
         //reset lot sizing
         Buyexponential = 0;
         //Open first order
         //if(previousDayHigh < Bid){
            BuyopenOrder();
            //BuymodifyOpenTrades();
         //}
         
       }
       return(0);
   }
   
   /**
  * Get last lot size.
  * Check for open orders.
  * Check if will execute a BUY trade.
  * Generate TP
  */
  void Buyinitialize(){
      BuyhasOpenOrder = false;
      BuyisExecute = false;
      
      for(int i=0;i<OrdersTotal();i++){
         bool selectHasError = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
         // Only get orders with magic number and SELL trades.
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == BuymagicNumber && OrderType() == OP_BUY){
            // Last lot size
            BuylastLotSize = OrderLots();
            // Has open order
            BuyhasOpenOrder = true;
            // Execute a trade.
            // Get the target price to open a trade.
            BuytargetOpen = OrderOpenPrice() - (PipStep * Point()); 
            if(Ask <= BuytargetOpen){
               BuyisExecute = true;
            }       
         }
      }
  }

   void BuymodifyOpenTrades(double tp){
      for(int i=0;i<OrdersTotal();i++){
         bool selectHasError =OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
         // Only get orders with magic number and BUY trades.
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == BuymagicNumber && OrderType() == OP_BUY){
            if(OrderTakeProfit() != tp){
               //bool modifyHasError = OrderModify(OrderTicket(),0, previousDayHigh < Bid ? previousDayHigh : 0, tp, 0,CLR_NONE);
               bool modifyHasError = OrderModify(OrderTicket(),0, 0, tp, 0,CLR_NONE);
               BuylastLotSize = OrderLots();
            }
         }
      }
  }
  
  void BuymodifyOpenTrades(){
      for(int i=0;i<OrdersTotal();i++){
         bool selectHasError =OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
         // Only get orders with magic number and BUY trades.
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == BuymagicNumber && OrderType() == OP_BUY){
               bool modifyHasError = OrderModify(OrderTicket(),0, previousDayHigh < Bid ? previousDayHigh : 0, OrderTakeProfit(), 0,CLR_NONE);
               BuylastLotSize = OrderLots();
         }
      }
  }
  
  
  int BuygetTotalOrders(){
      int counter = 0;
      for(int i=0;i<OrdersTotal();i++){
         bool selectHasError = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
         // Only get orders with magic number and BUY trades.
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == BuymagicNumber && OrderType() == OP_BUY){
            counter++;
         }
      }
      return counter;
  }
   
  
  double BuygenerateLotSize(){
      if(Buyexponential == 0){
         Buyexponential = BuygetTotalOrders();
      }else{
         Buyexponential = LotExp;
      }
      
      double lotSize = NormalizeDouble(BuylastLotSize * Buyexponential, 2);
  
      return lotSize;
  }
  
  double BuygenerateTp(){
  
      double averagePrice =0;
      double totalLots=0;
      //get all Orders
      for(int i=0;i<OrdersTotal();i++){
         bool selectHasError = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
         // Only get orders with magic number and BUY trades.
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == BuymagicNumber && OrderType() == OP_BUY){
            double computePrice = OrderLots() * OrderOpenPrice();
            totalLots = totalLots + OrderLots();
            averagePrice = averagePrice + computePrice; 
         }
                 
      }
      
      averagePrice = averagePrice / totalLots;
      int buyTP=0;
      int totalOrders = BuygetTotalOrders();
      if(totalOrders>fifty){
         buyTP = TakeProfit / 2;
      }else if(totalOrders>twentyFive){
         buyTP = TakeProfit / 4;
      }else if(totalOrders>breakEven){
         buyTP = 0;
      }else{
         buyTP = TakeProfit;
      }
      
      double tp = NormalizeDouble(averagePrice + (buyTP * Point()), Digits);
      return tp;
  }   
  
  void BuyopenOrder(double lots){  
      if(Ask<BuytargetOpen && BuygetTotalOrders()< maxTrade){      
         bool sendHasError = OrderSend(Symbol(),OP_BUY, NormalizeDouble(lots, 2), Ask, BuyvSlippage, 0, 0, StringConcatenate(BuyEAName,"-",BuygetTotalOrders()), BuymagicNumber, 0, Blue);
      }
  }
  
  void BuyopenOrder(){
      double tp = Ask + (TakeProfit * Point());      
      if(BuyStartLot < .01){
         BuyStartLot = .01;
      }
      bool sendHasError = OrderSend(Symbol(), OP_BUY,NormalizeDouble(BuyStartLot, 2), Ask, BuyvSlippage, 0, tp, StringConcatenate(BuyEAName,"-",BuygetTotalOrders()), BuymagicNumber, 0, Blue);
  }
