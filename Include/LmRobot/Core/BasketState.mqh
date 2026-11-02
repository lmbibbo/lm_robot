//+------------------------------------------------------------------+
//|                                                  BasketState.mqh |
//|                                              lm_robot (MQL5)    |
//+------------------------------------------------------------------+
#ifndef LMROBOT_CORE_BASKETSTATE_MQH
#define LMROBOT_CORE_BASKETSTATE_MQH

//+------------------------------------------------------------------+
//| Direccion y ciclo de vida de una canasta.                        |
//+------------------------------------------------------------------+
enum ENUM_BASKET_DIRECTION
  {
   BASKET_DIRECTION_NONE = 0,
   BASKET_DIRECTION_BUY  = 1,
   BASKET_DIRECTION_SELL = 2
  };

enum ENUM_BASKET_LIFECYCLE
  {
   BASKET_LIFECYCLE_FLAT   = 0,
   BASKET_LIFECYCLE_OPEN   = 1,
   BASKET_LIFECYCLE_CLOSED = 2
  };

//+------------------------------------------------------------------+
//| Posicion cruda tal como la entrega el broker.                    |
//+------------------------------------------------------------------+
struct BasketPosition
  {
   ulong               ticket;
   long                magic;
   string              symbol;
   ENUM_POSITION_TYPE  type;
   double              volume;
   double              openPrice;
   datetime            openTime;
   double              profit;
   double              swap;
   double              commission;
  };

//+------------------------------------------------------------------+
//| Estado agregado de la canasta.                                   |
//+------------------------------------------------------------------+
struct BasketState
  {
   string                  symbol;
   long                    magic;
   int                     count;
   ENUM_BASKET_DIRECTION   direction;
   double                  volume;
   double                  averagePrice;
   double                  lastOpenPrice;
   datetime                lastOpenTime;
   double                  pnl;
   bool                    mixedDirections;
   bool                    valid;
  };

//+------------------------------------------------------------------+
//| Deja el estado en canasta vacia.                                 |
//+------------------------------------------------------------------+
void LmResetBasket(BasketState &basket, const string symbol, const long magic)
  {
   basket.symbol          = symbol;
   basket.magic           = magic;
   basket.count           = 0;
   basket.direction       = BASKET_DIRECTION_NONE;
   basket.volume          = 0.0;
   basket.averagePrice    = 0.0;
   basket.lastOpenPrice   = 0.0;
   basket.lastOpenTime    = 0;
   basket.pnl             = 0.0;
   basket.mixedDirections = false;
   basket.valid           = false;
  }

//+------------------------------------------------------------------+
//| Agrega posiciones filtrando por simbolo y magic.                 |
//| El promedio es ponderado por volumen y el PnL incluye comision.  |
//+------------------------------------------------------------------+
bool LmAggregateBasket(const string symbol, const long magic,
                       const BasketPosition &positions[],
                       BasketState &basket)
  {
   LmResetBasket(basket, symbol, magic);

   double weightedPrice = 0.0;
   datetime lastTime    = 0;
   ulong lastTicket     = 0;
   int total            = ArraySize(positions);

   for(int i = 0; i < total; i++)
     {
      if(positions[i].magic != magic || positions[i].symbol != symbol)
         continue;

      if(positions[i].volume <= 0.0 || positions[i].openPrice <= 0.0)
         continue;

      ENUM_BASKET_DIRECTION positionDirection =
         (positions[i].type == POSITION_TYPE_BUY ? BASKET_DIRECTION_BUY : BASKET_DIRECTION_SELL);

      if(basket.count == 0)
         basket.direction = positionDirection;
      else if(basket.direction != positionDirection)
         basket.mixedDirections = true;

      basket.count++;
      basket.volume += positions[i].volume;
      weightedPrice += positions[i].openPrice * positions[i].volume;
      basket.pnl += positions[i].profit + positions[i].swap + positions[i].commission;

      //--- La ultima orden es la de apertura mas reciente; el ticket desempata.
      if(positions[i].openTime > lastTime ||
         (positions[i].openTime == lastTime && positions[i].ticket > lastTicket))
        {
         lastTime          = positions[i].openTime;
         lastTicket        = positions[i].ticket;
         basket.lastOpenPrice = positions[i].openPrice;
         basket.lastOpenTime  = positions[i].openTime;
        }
     }

   if(basket.volume > 0.0)
      basket.averagePrice = weightedPrice / basket.volume;

   basket.valid = !basket.mixedDirections;
   return(basket.valid);
  }

//+------------------------------------------------------------------+
//| Distancia en pips desde la ultima orden en la direccion que      |
//| agrava la canasta. Negativa si el precio se movio a favor.       |
//+------------------------------------------------------------------+
double LmGridDistancePips(const BasketState &basket,
                          const double currentPrice,
                          const double pipSize)
  {
   if(basket.count <= 0 || basket.lastOpenPrice <= 0.0 ||
      currentPrice <= 0.0 || pipSize <= 0.0)
      return(-1.0);

   if(basket.direction == BASKET_DIRECTION_BUY)
      return((basket.lastOpenPrice - currentPrice) / pipSize);

   if(basket.direction == BASKET_DIRECTION_SELL)
      return((currentPrice - basket.lastOpenPrice) / pipSize);

   return(-1.0);
  }

//+------------------------------------------------------------------+
//| Habilita un paso de grid cuando se alcanza la distancia.         |
//+------------------------------------------------------------------+
bool LmGridStepReached(const BasketState &basket,
                       const double currentPrice,
                       const double gridStepPips,
                       const double pipSize)
  {
   if(gridStepPips <= 0.0)
      return(false);

   double distance = LmGridDistancePips(basket, currentPrice, pipSize);
   return(distance + 1e-9 >= gridStepPips);
  }

//+------------------------------------------------------------------+
//| Ciclo de vida persistente entre ticks.                           |
//+------------------------------------------------------------------+
class CBasketTracker
  {
private:
   ENUM_BASKET_LIFECYCLE   m_state;
   ENUM_BASKET_DIRECTION   m_direction;
   int                     m_stepCount;
   bool                    m_wasOpen;

public:
   CBasketTracker()
     {
      Reset();
     }

   void Reset()
     {
      m_state     = BASKET_LIFECYCLE_FLAT;
      m_direction = BASKET_DIRECTION_NONE;
      m_stepCount = 0;
      m_wasOpen   = false;
     }

   //--- Actualiza el ciclo de vida a partir del scan del tick.
   void Update(const BasketState &basket)
     {
      if(basket.count > 0)
        {
         m_state     = BASKET_LIFECYCLE_OPEN;
         m_direction = basket.direction;
         m_stepCount = basket.count - 1; //--- el primer lote no es un paso de grid
         m_wasOpen   = true;
         return;
        }

      m_direction = BASKET_DIRECTION_NONE;
      m_stepCount = 0;

      if(m_wasOpen)
        {
         //--- La canasta se cerro en este tick: un solo tick en CLOSED.
         m_state   = BASKET_LIFECYCLE_CLOSED;
         m_wasOpen = false;
         return;
        }

      m_state = BASKET_LIFECYCLE_FLAT;
     }

   ENUM_BASKET_LIFECYCLE State()      { return(m_state); }
   ENUM_BASKET_DIRECTION Direction()  { return(m_direction); }
   int                   StepCount()  { return(m_stepCount); }
   bool                  IsOpen()     { return(m_state == BASKET_LIFECYCLE_OPEN); }
   bool                  JustClosed() { return(m_state == BASKET_LIFECYCLE_CLOSED); }

   //--- Sin posiciones se permite la primera orden (plano o recien cerrado).
   bool CanOpenFirst() { return(m_state != BASKET_LIFECYCLE_OPEN); }

   //--- Con posiciones abiertas solo se permiten pasos en la misma direccion.
   bool AllowsDirection(const ENUM_BASKET_DIRECTION direction)
     {
      if(m_state != BASKET_LIFECYCLE_OPEN)
         return(true);

      return(m_direction == direction);
     }
  };

//+------------------------------------------------------------------+
//| Comision acumulada de una posicion desde su historial de deals.  |
//+------------------------------------------------------------------+
double LmPositionCommission(const ulong positionId)
  {
   if(positionId == 0 || !HistorySelectByPosition(positionId))
      return(0.0);

   double commission = 0.0;
   int total = HistoryDealsTotal();

   for(int i = 0; i < total; i++)
     {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0)
         continue;

      commission += HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
     }

   return(commission);
  }

//+------------------------------------------------------------------+
//| Recolecta las posiciones reales del simbolo y magic indicados.   |
//+------------------------------------------------------------------+
int LmCollectBasketPositions(const string symbol, const long magic,
                             BasketPosition &positions[])
  {
   ArrayResize(positions, 0);

   int total = PositionsTotal();
   int used  = 0;

   for(int i = 0; i < total; i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;

      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ArrayResize(positions, used + 1);
      positions[used].ticket     = ticket;
      positions[used].magic      = magic;
      positions[used].symbol     = symbol;
      positions[used].type       = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      positions[used].volume     = PositionGetDouble(POSITION_VOLUME);
      positions[used].openPrice  = PositionGetDouble(POSITION_PRICE_OPEN);
      positions[used].openTime   = (datetime)PositionGetInteger(POSITION_TIME);
      positions[used].profit     = PositionGetDouble(POSITION_PROFIT);
      positions[used].swap       = PositionGetDouble(POSITION_SWAP);
      positions[used].commission = LmPositionCommission((ulong)PositionGetInteger(POSITION_IDENTIFIER));
      used++;
     }

   return(used);
  }

//+------------------------------------------------------------------+
//| Scan de las posiciones reales del simbolo y magic indicados.     |
//+------------------------------------------------------------------+
class CBasketScanner
  {
private:
   string m_symbol;

public:
   CBasketScanner(const string symbol = "")
     {
      m_symbol = (symbol == "" ? _Symbol : symbol);
     }

   void SetSymbol(const string symbol) { m_symbol = symbol; }

   bool Scan(const long magic, BasketState &basket)
     {
      BasketPosition positions[];
      LmCollectBasketPositions(m_symbol, magic, positions);
      return(LmAggregateBasket(m_symbol, magic, positions, basket));
     }
  };

#endif // LMROBOT_CORE_BASKETSTATE_MQH
