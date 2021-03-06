//+------------------------------------------------------------------+
//|                                                         MOMO.mq4 |
//|                            Copyright April 2021, Joseph M Garcia |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright   "April 2021, Joseph M. Garcia"
#property description "BASILIO-V1"


extern double LotExp = 1.357;
extern int TakeProfit = 60;
extern int PipStep = 150;
extern double dynamicMult = .5;
extern int maxTrade = 17;
extern double cutpercent=.5;
extern double lotMult = .00001;

string EAName="BASILIO-V1";
double magicNumber = 59485, targetOpen, lowestMargin,lowestEquity,equityPercent,StartLot,exponential,initialBalance;
datetime currentTime;

double lastLotSize = 0.0;
int lastLotSizeCounter = 0;

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

// Expert start function
void start()
  {  
   
   //Initialize start lot.
   StartLot = AccountBalance() * lotMult * dynamicMult;
   
   // Execute only on closing and without open order
   if(currentTime == Time[0] && hasOpenOrder())
      return (0);
      
   currentTime = Time[0];
  
   if(hasOpenOrder()){
      Print("Has Open Order: "+hasOpenOrder());
      // Get last order details. ( Open Price, Lot Size )      
      generateLastOrderDetails();
      // Check distance between open position price and pip step.
      // Generate lot size.
      // Generate TP.
      // Open Order      
      if(isExecute()){
         openOrder(generateLotSize());
         // Modify Open Trades
         double tp = NormalizeDouble(generateTp(), Digits);
         modifyOpenTrades(tp);
      }
      
    }else{
      //reset lot sizing
      exponential = 0;
      //Open first order
      openOrder();
    }
    
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
   
    Comment(
    "-------------------------------------------------"+
    "\nLowest Margin: "+NormalizeDouble(lowestMargin,2)+
    "\nLowest Equity: "+NormalizeDouble(lowestEquity*.01,2)+" ("+NormalizeDouble(equityPercent,2)+"%)"+
    "\nAccount Balance: "+NormalizeDouble(AccountBalance()*.01,2)+
    "\nCovered Pips: "+(highTrade*PipStep)+
    "\nHighest Trade: "+highTrade+
    "\n-------------------------------------------------");

  }
  
  void modifyOpenTrades(double tp){
      for(int i=0;i<OrdersTotal();i++){
         OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
         // Only get orders with magic number and BUY trades.
         if(OrderMagicNumber() == magicNumber && OrderType() == OP_BUY){
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
         if(OrderMagicNumber() == magicNumber && OrderType() == OP_BUY){
            counter++;
         }
      }
      return counter;
  }
  
  void generateLastOrderDetails(){
      for(int i=0;i<OrdersTotal();i++){
         OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
         // Only get orders with magic number and BUY trades.
         if(OrderMagicNumber() == magicNumber && OrderType() == OP_BUY){
            lastLotSize = OrderLots();
         }
      } 
      Print("Generate last order details.");
      Print("Last Lot Size: "+lastLotSize);
  }
  
  void cutFirstPosition(){
      int firstOrderTicket;
      double highestPrice = 0, lot;
      
      for(int i=0;i<OrdersTotal();i++){
         OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
         // Only get orders with magic number and BUY trades.
         if(OrderMagicNumber() == magicNumber && OrderType() == OP_BUY){
            if(highestPrice == 0 || highestPrice < OrderOpenPrice()){
               highestPrice = OrderOpenPrice();
               firstOrderTicket = OrderTicket();
               lot = OrderLots();
            }
         }
      } 
      
      Print("Order Ticket: "+firstOrderTicket);
      Print("Lot: "+lot);
      Print("Highest Price: "+highestPrice);
      
      OrderClose(firstOrderTicket, lot, Bid, vSlippage, Red);
  }
  
  bool hasOpenOrder(){
      for(int i=0;i<OrdersTotal();i++){
         OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
         // Only get orders with magic number and BUY trades.
         if(OrderMagicNumber() == magicNumber && OrderType() == OP_BUY){
            return true;
         }
      }
      return false;
  }
  
  bool isExecute(){  
      bool result=false;
      for(int i=0;i<OrdersTotal();i++){
         OrderSelect(i, SELECT_BY_POS, MODE_TRADES);         
         if(OrderMagicNumber() == magicNumber && OrderType() == OP_BUY){
            // Only get orders with magic number and BUY trades.
            targetOpen = OrderOpenPrice() - (PipStep * 0.00001); 
            double step = PipStep * .00001;
            Print("Ticket: "+OrderTicket());
            Print("Order Magic: "+OrderMagicNumber());
            Print("Order Type: "+OrderType());
            if(Ask <= targetOpen){
               Print("Open Order Price: "+OrderOpenPrice());
               result = true;
            }
         }
      }
      Print("Execute BUY: "+result);
      return result;
  
  }
  
  
  double generateLotSize(){
      if(exponential == 0){
         exponential = 1;
      }else{
         exponential = LotExp;
      }
      
      double lotSize = NormalizeDouble(lastLotSize * exponential, 2);
  
      Print("Generate lot size: "+ lotSize);
      return lotSize;
  }
  
  double generateTp(){
  
      double averagePrice;
      double totalLots;
      //get all Orders
      for(int i=0;i<OrdersTotal();i++){
         OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
         // Only get orders with magic number and BUY trades.
         if(OrderMagicNumber() == magicNumber && OrderType() == OP_BUY){
            double computePrice = OrderLots() * OrderOpenPrice();
            totalLots = totalLots + OrderLots();
            averagePrice = averagePrice + computePrice; 
         }
                 
      }
      Print("Average Price: "+averagePrice);
      Print("Total Lots: "+totalLots);
      
      averagePrice = averagePrice / totalLots;
      double tp = NormalizeDouble(averagePrice + (TakeProfit * 0.00001), Digits);
      Print("Generate TP: "+ tp);
      return tp;
  }   
  
  void openOrder(double lots){  
      Print("Target Open: "+ targetOpen);
      Print("Bid before order: "+Ask);
      if(Ask<targetOpen && getTotalOrders()< maxTrade){      
         OrderSend(Symbol(),OP_BUY, NormalizeDouble(lots, 2), Ask, vSlippage, 0, 0, EAName+"-"+getTotalOrders(), magicNumber, 0, Blue);
      }
  }
  
  void openOrder(){
      double tp = Ask + (TakeProfit * 0.00001);
      OrderSend(Symbol(), OP_BUY,NormalizeDouble(StartLot, 2), Ask, vSlippage, 0, tp, EAName+"-"+getTotalOrders(), magicNumber, 0, Blue);
      //reset last lot size counter
      lastLotSizeCounter = 0;
  }
  