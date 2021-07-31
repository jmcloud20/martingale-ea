//+------------------------------------------------------------------+
//|                                                         SISA.mq4 |
//|                              Joseph M Garcia Copyright July 2021 |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Joseph M Garcia Copyright July 2021"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Expert vars                                                      |
//+------------------------------------------------------------------+
string EAName="ICHI-V1";
int magicNumber = 1209383;

// Lot Multiplier
extern double lotMult = .00001;
extern double dynamicMult = 1.0;

datetime currentTime;

 //Initialize start lot.
 double Lot;
   
 //ichi moku parameters
 int Tenkan = 9;
 int Kijun = 26;
 int Senkou = 52;
   
 //indicator settings
 double TenkanSen= iIchimoku(NULL,PERIOD_CURRENT,Tenkan,Kijun,Senkou,MODE_TENKANSEN,0);
 double KijunSen = iIchimoku(NULL,PERIOD_CURRENT,Tenkan,Kijun,Senkou,MODE_KIJUNSEN,0);
 double SenkouSpanA = iIchimoku(NULL, 0, Tenkan, Kijun, Senkou, MODE_SENKOUSPANA, 1);
 double SenkouSpanB = iIchimoku(NULL, 0, Tenkan, Kijun, Senkou, MODE_SENKOUSPANB, 1); 
  
 double KumoTop= MathMax(SenkouSpanA, SenkouSpanB);
 double KumoBottom = MathMin (SenkouSpanA, SenkouSpanB);
 
 // Expert init function
int init()
  {
   ObjectsDeleteAll();
   return(0);
  }

//+------------------------------------------------------------------+
//| Expert start function                                            |
//+------------------------------------------------------------------+
void start(){   

   Lot = AccountBalance() * lotMult * dynamicMult;
   
   TenkanSen= iIchimoku(NULL,PERIOD_CURRENT,Tenkan,Kijun,Senkou,MODE_TENKANSEN,0);
   KijunSen = iIchimoku(NULL,PERIOD_CURRENT,Tenkan,Kijun,Senkou,MODE_KIJUNSEN,0);
   SenkouSpanA = iIchimoku(NULL, 0, Tenkan, Kijun, Senkou, MODE_SENKOUSPANA, 1);
   SenkouSpanB = iIchimoku(NULL, 0, Tenkan, Kijun, Senkou, MODE_SENKOUSPANB, 1); 
  
   KumoTop= MathMax(SenkouSpanA, SenkouSpanB);
   KumoBottom = MathMin (SenkouSpanA, SenkouSpanB);
   
   // Execute only on closing and without open order
   if(currentTime == Time[0])
      return;
         
   currentTime = Time[0];
   
   
   buy();
   sell();
   
}

void buy(){
   //Entry for cloud breakout
   if(Close[1]>KumoTop && TenkanSen > KijunSen && buyGetTotalOrders() == 0){
      // Open Order
      bool sendHasError = OrderSend(Symbol(), OP_BUY, NormalizeDouble(Lot, 2), Ask, 0, 0, 0, EAName, magicNumber, 0, Blue); 
   }
   //Exit
   if(Close[1] < KijunSen && buyGetTotalOrders() > 0){
      closeAllBuyOrders();
   }
}


void modifyOpenTrades(double targetPrice, double cl, int orderType){
   for(int i=0;i<OrdersTotal();i++){
      bool selectHasErr = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      // Only get orders with magic number and BUY trades.
      if(OrderMagicNumber() == magicNumber && OrderType() == orderType){
         bool modHasErr = OrderModify(OrderTicket(),0, cl, targetPrice, 0,CLR_NONE);
       }
    }
}

void sell(){
   //Entry for cloud breakdown
   if(Close[1] < KumoBottom && TenkanSen < KijunSen && sellGetTotalOrders() == 0){
      bool sendHasError = OrderSend(Symbol(), OP_SELL, NormalizeDouble(Lot, 2), Bid, 0, 0, 0, EAName, magicNumber, 0, Red);
   }
   
   //Exit
   if(Close[1] > KijunSen && sellGetTotalOrders() > 0){
      closeAllSellOrders();
   }
}

int buyGetTotalOrders(){
   int counter = 0;
   for(int i=0;i<OrdersTotal();i++){
      bool selectHasError = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      // Only get orders with magic number and BUY trades.
      if(OrderMagicNumber() == magicNumber && OrderType() == OP_BUY){
         counter++;
       }
    }
    return counter;
}

int sellGetTotalOrders(){
   int counter = 0;
   for(int i=0;i<OrdersTotal();i++){
      bool selectHasError = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      // Only get orders with magic number and SELL trades.
      if(OrderMagicNumber() == magicNumber && OrderType() == OP_SELL){
         counter++;
       }
    }
    return counter;
}

void closeAllBuyOrders(){
   // Close all positions.
   do{
      for(int i=0;i<=buyGetTotalOrders();i++){
         bool selectHasError = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
         if(OrderMagicNumber() == magicNumber && OrderType() == OP_BUY){
            bool closeHasError = OrderClose(OrderTicket(), OrderLots(), Bid, 0, Violet);
         }
      }
    }while(buyGetTotalOrders() != 0);
}

void closeAllSellOrders(){
   // Close all positions.
   do{
      for(int i=0;i<=sellGetTotalOrders();i++){
         bool selectHasError = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
         if(OrderMagicNumber() == magicNumber && OrderType() == OP_SELL){
            bool closeHasError = OrderClose(OrderTicket(), OrderLots(), Ask, 0, Violet);
         }
      }
    }while(sellGetTotalOrders() != 0);
}
