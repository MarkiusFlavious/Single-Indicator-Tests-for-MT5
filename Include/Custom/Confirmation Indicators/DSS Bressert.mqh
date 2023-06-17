/* ===========================================================================================================================
   | Includes                                                                                                                |
   =========================================================================================================================== */

#include <Custom/ConfirmationIndicator.mqh>

/* ===========================================================================================================================
   |                                                                                                                         |
   | Class: DSS Bressert                                                                                                     |
   | -------------------                                                                                                     |
   =========================================================================================================================== */

class DSSBressert : public TwoLineCrossIndicator {

public:
   // Inputs:
   uint DSS_EMA_Period;
   uint DSS_Stoch_Period;
   int DSS_Shift;
   
   // Functions:
                           DSSBressert(void);
   void                    Initialize(void) override;
};

/* ===========================================================================================================================
   | Constructor                                                                                                             |
   =========================================================================================================================== */

DSSBressert::DSSBressert(void) {
   Fast_Line_Buffer = 0;
   Slow_Line_Buffer = 1;
}

/* ===========================================================================================================================
   | Initialization Function                                                                                                 |
   =========================================================================================================================== */

void DSSBressert::Initialize(void) override {
   Handle = iCustom(Pair,Timeframe,"dssbressert.ex5",DSS_EMA_Period,DSS_Stoch_Period,DSS_Shift);
}
