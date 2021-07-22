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
double BuymagicNumber = 59485, BuytargetOpen,BuyStartLot,Buyexponential;

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
double magicNumber = 59484, targetOpen, lowestMargin,lowestEquity,equityPercent,StartLot,exponential;

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
      Print("Lowest Margin: "+NormalizeDouble(lowestMargin,2));
      Print("Lowest Equity: "+NormalizeDouble(lowestEquity*.01,2)+" ("+NormalizeDouble(equityPercent,2)+"%)");
      Print("Account Balance: "+NormalizeDouble(AccountBalance()*.01,2));
   }
   
   Comment(
    "-------------------------------------------------"+
    "\nLowest Margin: "+NormalizeDouble(lowestMargin,2)+
    "\nLowest Equity: "+NormalizeDouble(lowestEquity*.01,2)+" ("+NormalizeDouble(equityPercent,2)+"%)"+
    "\nAccount Balance: "+NormalizeDouble(AccountBalance()*.01,2)+
    "\nCovered Pips: "+(highTrade*PipStep)+
    "\nHighest Trade: "+highTrade+
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
     
   // There is an existing order.
   if(hasOpenOrder()){
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
      for(int i=0;i<OrdersTotal();i++){
         OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
         // Only get orders with magic number and BUY trades.
         if(OrderMagicNumber() == magicNumber && OrderType() == OP_SELL){
            OrderModify(OrderTicket(),OrderOpenPrice(), OrderStopLoss(), tp, 0,CLR_NONE);
            lastLotSize = OrderLots();
         }
      }
  }
  
  int getTotalOrders(){
      int counter = 0;
      for(int i=0;i<OrdersTotal();i++){
         OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
         // Only get orders with magic number and BUY trades.
         if(OrderMagicNumber() == magicNumber && OrderType() == OP_SELL){
            counter++;
         }
      }
   return counter;
  }
  
  void generateLastOrderDetails(){
      for(int i=0;i<OrdersTotal();i++){
         OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
         // Only get orders with magic number and BUY trades.
         if(OrderMagicNumber() == magicNumber && OrderType() == OP_SELL){
            lastLotSize = OrderLots();
         }
      } 
  }
  
  bool hasOpenOrder(){
      for(int i=0;i<OrdersTotal();i++){
         OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
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
         OrderSelect(i, SELECT_BY_POS, MODE_TRADES);         
         if(OrderMagicNumber() == magicNumber && OrderType() == OP_SELL){
            // Only get orders with magic number and BUY trades.
            targetOpen = OrderOpenPrice() + (PipStep * 0.00001); 
            double step = PipStep * .00001;
            if(Bid >= targetOpen){
               Print("Open Order Price: "+OrderOpenPrice());
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
  
      double averagePrice;
      double totalLots;
      //get all Orders
      for(int i=0;i<OrdersTotal();i++){
         OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
         // Only get orders with magic number and BUY trades.
         if(OrderMagicNumber() == magicNumber && OrderType() == OP_SELL){
            double computePrice = OrderLots() * OrderOpenPrice();
            totalLots = totalLots + OrderLots();
            averagePrice = averagePrice + computePrice; 
         }
                 
      }      
      averagePrice = averagePrice / totalLots;
      double tp = NormalizeDouble(averagePrice - (TakeProfit * 0.00001), Digits);
      Print("Generate TP: "+ tp);
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
               OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
               // Only get orders with magic number and BUY trades.
               //Print("Ticket: "+OrderTicket());
               //Print("Order Magic: "+OrderMagicNumber());
               //Print("Order Type: "+OrderType());
               if(OrderMagicNumber() == magicNumber && OrderType() == OP_SELL){
                  OrderClose(OrderTicket(), OrderLots(), Ask, vSlippage, Violet);
               }
            }
         }while(getTotalOrders() != 0);
         //Print("New Account Balance: "+NormalizeDouble(AccountBalance(),2));
         //Print("---------------------------------");
         //Reinitialize initial balance.
         initialBalance=AccountBalance();
      }   
  }
  
  void openOrder(double lots){  
      //Print("Target Open: "+ targetOpen);
      //Print("Bid before order: "+Bid);
      if(Bid>targetOpen && getTotalOrders()< maxTrade){      
         OrderSend(Symbol(),OP_SELL, NormalizeDouble(lots, 2), Bid, vSlippage, 0, 0, EAName+"-"+getTotalOrders(), magicNumber, 0, Red);
      }
  }
  
  void openOrder(){
      double tp = Bid - (TakeProfit * 0.00001);
      OrderSend(Symbol(), OP_SELL,NormalizeDouble(StartLot, 2), Bid, vSlippage, 0, tp, EAName+"-"+getTotalOrders(), magicNumber, 0, Red);
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
         //Print("Has Open Order: "+BuyhasOpenOrder());
         // Get last order details. ( Open Price, Lot Size )      
         BuygenerateLastOrderDetails();
         // Check distance between open position price and pip step.
         // Generate lot size.
         // Generate TP.
         // Open Order      
         if(BuyisExecute()){
            BuyopenOrder(BuygenerateLotSize());
            // Modify Open Trades
            double tp = NormalizeDouble(BuygenerateTp(), Digits);
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
         OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
         // Only get orders with magic number and BUY trades.
         if(OrderMagicNumber() == BuymagicNumber && OrderType() == OP_BUY){
            OrderModify(OrderTicket(),OrderOpenPrice(), OrderStopLoss(), tp, 0,CLR_NONE);
            BuylastLotSize = OrderLots();
         }
      }
  }
  
  int BuygetTotalOrders(){
      int counter = 0;
      for(int i=0;i<OrdersTotal();i++){
         OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
         // Only get orders with magic number and BUY trades.
         if(OrderMagicNumber() == BuymagicNumber && OrderType() == OP_BUY){
            counter++;
         }
      }
      return counter;
  }
  
  void BuygenerateLastOrderDetails(){
      for(int i=0;i<OrdersTotal();i++){
         OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
         // Only get orders with magic number and BUY trades.
         if(OrderMagicNumber() == BuymagicNumber && OrderType() == OP_BUY){
            BuylastLotSize = OrderLots();
         }
      } 
      //Print("Generate last order details.");
      //Print("Last Lot Size: "+BuylastLotSize);
  }
  
  bool BuyhasOpenOrder(){
      for(int i=0;i<OrdersTotal();i++){
         OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
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
         OrderSelect(i, SELECT_BY_POS, MODE_TRADES);         
         if(OrderMagicNumber() == BuymagicNumber && OrderType() == OP_BUY){
            // Only get orders with magic number and BUY trades.
            BuytargetOpen = OrderOpenPrice() - (PipStep * 0.00001); 
            double step = PipStep * .00001;
            //Print("Ticket: "+OrderTicket());
            //Print("Order Magic: "+OrderMagicNumber());
            //Print("Order Type: "+OrderType());
            if(Ask <= BuytargetOpen){
               //Print("Open Order Price: "+OrderOpenPrice());
               result = true;
            }
         }
      }
      //Print("Execute BUY: "+result);
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
  
      double averagePrice;
      double totalLots;
      //get all Orders
      for(int i=0;i<OrdersTotal();i++){
         OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
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
               OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
               // Only get orders with magic number and BUY trades.
               //Print("Ticket: "+OrderTicket());
               //Print("Order Magic: "+OrderMagicNumber());
               //Print("Order Type: "+OrderType());
               if(OrderMagicNumber() == BuymagicNumber && OrderType() == OP_BUY){
                  OrderClose(OrderTicket(), OrderLots(), Bid, BuyvSlippage, Violet);
               }
            }
         }while(BuygetTotalOrders() != 0);
         //Reinitialize initial balance.
         BuyinitialBalance=AccountBalance();
      }   
  }
  
  void BuyopenOrder(double lots){  
      //Print("Target Open: "+ BuytargetOpen);
      //Print("Bid before order: "+Ask);
      if(Ask<BuytargetOpen && BuygetTotalOrders()< maxTrade){      
         OrderSend(Symbol(),OP_BUY, NormalizeDouble(lots, 2), Ask, BuyvSlippage, 0, 0, BuyEAName+"-"+BuygetTotalOrders(), BuymagicNumber, 0, Blue);
      }
  }
  
  void BuyopenOrder(){
      double tp = Ask + (TakeProfit * 0.00001);
      OrderSend(Symbol(), OP_BUY,NormalizeDouble(BuyStartLot, 2), Ask, BuyvSlippage, 0, tp, BuyEAName+"-"+BuygetTotalOrders(), BuymagicNumber, 0, Blue);
  }