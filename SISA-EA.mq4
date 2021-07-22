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
//| Global Vars                                                      |
//+------------------------------------------------------------------+
extern int printMonthDebug = 12;
extern int printDayDebug = 31;

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
void start()
  {
//---
   startBuy();    
   startSell();
   
   if(Month() == printMonthDebug && Day() == printDayDebug){
      Print("Lowest Margin: "+DoubleToString(lowestMargin,2));
      Print("Lowest Equity: "+DoubleToString(lowestEquity*.01,2)+" ("+DoubleToString(equityPercent,2)+"%)");
      Print("Account Balance: "+DoubleToString(AccountBalance()*.01,2));
   }
   
   Comment(
    "-------------------------------------------------"+
    "\nLowest Margin: "+DoubleToString(lowestMargin,2)+
    "\nLowest Equity: "+DoubleToString(lowestEquity*.01,2)+" ("+DoubleToString(equityPercent,2)+"%)"+
    "\nAccount Balance: "+DoubleToString(AccountBalance()*.01,2)+
    "\nCovered Pips: "+(IntegerToString(highTrade*PipStep))+
    "\nHighest Trade: "+IntegerToString(highTrade)+
    "\n-------------------------------------------------");
   
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Expert SELL function                                             |
//+------------------------------------------------------------------+

int startSell(){
   //Initialize start lot.
   StartLot = AccountBalance() * lotMult * dynamicMult;
   
   // Execute only on closing and without open order
   if(currentTime == Time[0] && hasOpenOrder())
      return (0);
      
   currentTime = Time[0];
   
   bool hasOpenOrder = initialize();
     
   // There is an existing order.
   if(hasOpenOrder){
      // Get last order details. ( Open Price, Lot Size )      
      generateLastOrderDetails();
      // Check distance between open position price and pip step.
      // Check if valid signal.
      if(isExecute()){
         // Open Order  
         // Generate lot size.
         openOrder(generateLotSize());         
         // Generate TP.
         double tp = NormalizeDouble(generateTp(), Digits);
         // Modify Open Trades
         modifyOpenTrades(tp);
      }
      
    }else{
      //reset lot sizing
      exponential = 0;
      //Open first order
      openOrder();
    }
    
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
    return(0);
}

   void modifyOpenTrades(double tp){      
      bool hasError=false;
      for(int i=0;i<OrdersTotal();i++){
         bool selectHasError = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
         // Only get orders with magic number and BUY trades.
         if(OrderMagicNumber() == magicNumber && OrderType() == OP_SELL){
            hasError = OrderModify(OrderTicket(),0, 0, tp, 0,CLR_NONE);
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
         if(OrderMagicNumber() == magicNumber && OrderType() == OP_SELL){
            counter++;
         }
      }
   return counter;
  }
  
   bool initialize(){
      bool hasOpenOrder = false;
      for(int i=0;i<OrdersTotal();i++){
         bool selectHasError = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
         // Only get orders with magic number and BUY trades.
         if(OrderMagicNumber() == magicNumber && OrderType() == OP_SELL){
            // Last lot size
            lastLotSize = OrderLots();
            // Has open order
            hasOpenOrder = true;
         }
      }
      return hasOpenOrder;
  }
  
  // TODO: For Deprecation
  void generateLastOrderDetails(){
      for(int i=0;i<OrdersTotal();i++){
         bool selectHasError = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
         // Only get orders with magic number and BUY trades.
         if(OrderMagicNumber() == magicNumber && OrderType() == OP_SELL){
            lastLotSize = OrderLots();
         }
      } 
  }
  
 
  
  //TODO: For deprecation
  bool hasOpenOrder(){
      for(int i=0;i<OrdersTotal();i++){
         bool selectHasError = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
         // Only get orders with magic number and BUY trades.
         if(OrderMagicNumber() == magicNumber && OrderType() == OP_SELL){
            return true;
         }
      }
      return false;
  }
  
  bool isExecute(){  
      bool result=false;
      for(int i=0;i<OrdersTotal();i++){
         bool selectHasError = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);         
         if(OrderMagicNumber() == magicNumber && OrderType() == OP_SELL){
            // Only get orders with magic number and BUY trades.
            targetOpen = OrderOpenPrice() + (PipStep * Point()); 
            double step = PipStep * Point();
            if(Bid >= targetOpen){
               result = true;
            }
         }
      }
      return result;
  
  }
  
  
  double generateLotSize(){
      if(exponential == 0){
         exponential = 1;
      }else{
         exponential = LotExp;
      }
      
      double lotSize = NormalizeDouble(lastLotSize * exponential, 2);
  
      return lotSize;
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
  
  void cutloss(){
  
      //Initialize initial balance.
      initialBalance = AccountBalance();
      
      
      double balanceThreshold = initialBalance * cutpercent;
      double computedThreshold = AccountBalance() - balanceThreshold;
      //Equity has reached the threshold level.
      if(AccountEquity() <= computedThreshold){ 
         // Close all positions.
         do{
            for(int i=0;i<=getTotalOrders();i++){
               bool selectHasError = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
               // Only get orders with magic number and BUY trades.
               if(OrderMagicNumber() == magicNumber && OrderType() == OP_SELL){
                  bool closeHasError =OrderClose(OrderTicket(), OrderLots(), Ask, vSlippage, Violet);
               }
            }
         }while(getTotalOrders() != 0);
         //Reinitialize initial balance.
         initialBalance=AccountBalance();
      }   
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
      
      // Execute only on closing and without open order
      if(currentTime == Time[0] && BuyhasOpenOrder())
         return (0);
     
      if(BuyhasOpenOrder()){
         // Get last order details. ( Open Price, Lot Size )      
         BuygenerateLastOrderDetails();
         // Check distance between open position price and pip step.
         if(BuyisExecute()){
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
       
       double Buymargin = AccountEquity() / AccountMargin () * 100;
       
       if(lowestMargin == 0 || Buymargin < lowestMargin){
         lowestMargin = Buymargin;
       }
       
       if(lowestEquity==0||AccountEquity()<lowestEquity){
         lowestEquity = AccountEquity();
         equityPercent = (AccountEquity() / AccountBalance())*100;
       }
       
       if(highTrade == 0 || BuygetTotalOrders() > highTrade){
         highTrade = BuygetTotalOrders();
       }
       
       return(0);
   }

   void BuymodifyOpenTrades(double tp){
      for(int i=0;i<OrdersTotal();i++){
         bool selectHasError =OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
         // Only get orders with magic number and BUY trades.
         if(OrderMagicNumber() == BuymagicNumber && OrderType() == OP_BUY){
            bool modifyHasError = OrderModify(OrderTicket(),0, 0, tp, 0,CLR_NONE);
            BuylastLotSize = OrderLots();
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
  
  void BuygenerateLastOrderDetails(){
      for(int i=0;i<OrdersTotal();i++){
         bool selectHasError = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
         // Only get orders with magic number and BUY trades.
         if(OrderMagicNumber() == BuymagicNumber && OrderType() == OP_BUY){
            BuylastLotSize = OrderLots();
         }
      } 
  }
  
  bool BuyhasOpenOrder(){
      for(int i=0;i<OrdersTotal();i++){
         bool selectHasError = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
         // Only get orders with magic number and BUY trades.
         if(OrderMagicNumber() == BuymagicNumber && OrderType() == OP_BUY){
            return true;
         }
      }
      return false;
  }
  
  bool BuyisExecute(){  
      bool result=false;
      for(int i=0;i<OrdersTotal();i++){
         bool selectHasError = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);         
         if(OrderMagicNumber() == BuymagicNumber && OrderType() == OP_BUY){
            // Only get orders with magic number and BUY trades.
            BuytargetOpen = OrderOpenPrice() - (PipStep * 0.00001); 
            double step = PipStep * .00001;
            if(Ask <= BuytargetOpen){
               result = true;
            }
         }
      }
      return result;
  
  }
  
  
  double BuygenerateLotSize(){
      if(Buyexponential == 0){
         Buyexponential = 1;
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
  
  // Feature for percentage of capital cutloss.
  void Buycutloss(){
  
      //Initialize initial balance.
      BuyinitialBalance = AccountBalance();
      
      
      double balanceThreshold = BuyinitialBalance * cutpercent;
      double computedThreshold = AccountBalance() - balanceThreshold;
      //Equity has reached the threshold level.
      if(AccountEquity() <= computedThreshold){     
         
         // Close all positions.
         do{
            for(int i=0;i<=BuygetTotalOrders();i++){
               bool selectHasError = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
               // Only get orders with magic number and BUY trades.
               if(OrderMagicNumber() == BuymagicNumber && OrderType() == OP_BUY){
                  bool closeHasError = OrderClose(OrderTicket(), OrderLots(), Bid, BuyvSlippage, Violet);
               }
            }
         }while(BuygetTotalOrders() != 0);
         //Reinitialize initial balance.
         BuyinitialBalance=AccountBalance();
      }   
  }
  
  void BuyopenOrder(double lots){  
      if(Ask<BuytargetOpen && BuygetTotalOrders()< maxTrade){      
         bool sendHasError = OrderSend(Symbol(),OP_BUY, NormalizeDouble(lots, 2), Ask, BuyvSlippage, 0, 0, StringConcatenate(BuyEAName,"-",BuygetTotalOrders()), BuymagicNumber, 0, Blue);
      }
  }
  
  void BuyopenOrder(){
      double tp = Ask + (TakeProfit * 0.00001);
      bool sendHasError = OrderSend(Symbol(), OP_BUY,NormalizeDouble(BuyStartLot, 2), Ask, BuyvSlippage, 0, tp, StringConcatenate(BuyEAName,"-",BuygetTotalOrders()), BuymagicNumber, 0, Blue);
  }