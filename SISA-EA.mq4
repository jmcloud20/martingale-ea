//+------------------------------------------------------------------+
//|                                                         SISA.mq4 |
//|                              Joseph M Garcia Copyright July 2021 |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Joseph M Garcia Copyright July 2021"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

extern int TakeProfit = 60;
extern int PipStep = 150;
extern double dynamicMult = .5;
extern int maxTrade = 14;

//+------------------------------------------------------------------+
//| Report Vars                                                      |
//+------------------------------------------------------------------+
extern bool enableComment = false;
extern bool enablePrintJournal = true;
extern int printMonthDebug = 12;
extern int printDayDebug = 31;
extern int printYearDebug = 2021;

//+------------------------------------------------------------------+
//| Global Vars                                                      |
//+------------------------------------------------------------------+
double LotExp = 1.357;
double cutpercent=1;
double lotMult = .00001;

//+------------------------------------------------------------------+
//| Expert BUY vars                                                  |
//+------------------------------------------------------------------+
string BuyEAName="BASILIO-V1";
double BuytargetOpen,BuyStartLot,Buyexponential;
int BuymagicNumber = 59485;

datetime currentTime;
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
      startBuy();    
      startSell();   
      generateReport();
   }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Expert SELL function                                             |
//+------------------------------------------------------------------+

   int startSell(){
      //Initialize start lot.
      StartLot = AccountBalance() * lotMult * dynamicMult;
      
      // Get last lot size.
      // Check for open orders.
      // Check if will execute a SELL trade.
      initialize();   
      
      // Execute only on closing and without open order
      if(currentTime == Time[0] && hasOpenOrder)
         return (0);
         
      currentTime = Time[0];
      
      if(hasOpenOrder){      
         if(isExecute){
            //generateLastOrderDetails();
            // Open Order  
            // Generate lot size.
            openOrder(generateLotSize());         
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
         openOrder();
         // No need to generate report if first order
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
       
       if(lowestEquity==0||AccountEquity()<lowestEquity){
         lowestEquity = AccountEquity();
         equityPercent = (AccountEquity() / AccountBalance())*100;
       }
       
       if(highTrade == 0 || getTotalOrders() > highTrade){
         highTrade = getTotalOrders();
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
         if(OrderMagicNumber() == magicNumber && OrderType() == OP_SELL){
            if(OrderTakeProfit() != tp){
               hasError = OrderModify(OrderTicket(),0, 0, tp, 0,CLR_NONE);
               //Make sure to get the last lot size.
               lastLotSize = OrderLots();
            }
         }
      }
  }
  
  int getTotalOrders(){
      int counter = 0;
      for(int i=0;i<OrdersTotal();i++){
         bool selectHasError = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
         // Only get orders with magic number and BUY trades.
         if(OrderMagicNumber() == magicNumber && OrderType() == OP_SELL){
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
         if(OrderMagicNumber() == magicNumber && OrderType() == OP_SELL){
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
         if(OrderMagicNumber() == magicNumber && OrderType() == OP_SELL){
            double computePrice = OrderLots() * OrderOpenPrice();
            totalLots = totalLots + OrderLots();
            averagePrice = averagePrice + computePrice; 
         }
                 
      }      
      averagePrice = averagePrice / totalLots;
      double tp = NormalizeDouble(averagePrice - (TakeProfit * Point()), Digits);
      
      return tp;
  }   
  
  double generateLotSize(){
  
      if(exponential == 0){
         exponential = getTotalOrders();
      }else{
         exponential = LotExp;
      }
      
      double lotSize = NormalizeDouble(lastLotSize * exponential, 2);
  
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
      BuyStartLot = AccountBalance() * lotMult * dynamicMult; 
      
      // Get last lot size.
      // Check for open orders.
      // Check if will execute a BUY trade.
      Buyinitialize();
      
      // Execute only on closing and without open order
      if(currentTime == Time[0] && BuyhasOpenOrder)
         return (0);             
     
      if(BuyhasOpenOrder){
         if(BuyisExecute){
            //BuygenerateLastOrderDetails();
            // Generate lot size.         
            // Open Order    
            BuyopenOrder(BuygenerateLotSize());            
            // Generate TP.
            double tp = NormalizeDouble(BuygenerateTp(), Digits);
            // Modify Open Trades
            BuymodifyOpenTrades(tp);
         }
         
       }else{
         //reset lot sizing
         Buyexponential = 0;
         //Open first order
         BuyopenOrder();
       }
       
       generateReport();
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
         if(OrderMagicNumber() == BuymagicNumber && OrderType() == OP_BUY){
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
         if(OrderMagicNumber() == BuymagicNumber && OrderType() == OP_BUY){
            if(OrderTakeProfit() != tp){
               bool modifyHasError = OrderModify(OrderTicket(),0, 0, tp, 0,CLR_NONE);
               BuylastLotSize = OrderLots();
            }
         }
      }
  }
  
  int BuygetTotalOrders(){
      int counter = 0;
      for(int i=0;i<OrdersTotal();i++){
         bool selectHasError = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
         // Only get orders with magic number and BUY trades.
         if(OrderMagicNumber() == BuymagicNumber && OrderType() == OP_BUY){
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
         if(OrderMagicNumber() == BuymagicNumber && OrderType() == OP_BUY){
            double computePrice = OrderLots() * OrderOpenPrice();
            totalLots = totalLots + OrderLots();
            averagePrice = averagePrice + computePrice; 
         }
                 
      }
      
      averagePrice = averagePrice / totalLots;
      double tp = NormalizeDouble(averagePrice + (TakeProfit * 0.00001), Digits);
      return tp;
  }   
  
  void BuyopenOrder(double lots){  
      if(Ask<BuytargetOpen && BuygetTotalOrders()< maxTrade){      
         bool sendHasError = OrderSend(Symbol(),OP_BUY, NormalizeDouble(lots, 2), Ask, BuyvSlippage, 0, 0, StringConcatenate(BuyEAName,"-",BuygetTotalOrders()), BuymagicNumber, 0, Blue);
      }
  }
  
  void BuyopenOrder(){
      double tp = Ask + (TakeProfit * Point());
      bool sendHasError = OrderSend(Symbol(), OP_BUY,NormalizeDouble(BuyStartLot, 2), Ask, BuyvSlippage, 0, tp, StringConcatenate(BuyEAName,"-",BuygetTotalOrders()), BuymagicNumber, 0, Blue);
  }