#include <Trade/PositionInfo.mqh>

class MiPosition {
private:
    ENUM_POSITION_TYPE type;
    long time;
    ulong ticket;
    double price;
    double volume;
    double stop_loss;
    double take_profit;
    string symbol;
    int digits;
    long magic;

public:
    // Constructor vacío
    MiPosition() : type(POSITION_TYPE_BUY), time(0), price(0.0), volume(0.0), stop_loss(0.0), take_profit(0.0), symbol(""), digits(0), magic(0) {}

    // Método para inicializar la posición desde un ticket
    bool LoadFromTicket(ulong aticket) {
        if (!PositionSelectByTicket(aticket)) {
            Print("Error: No se pudo seleccionar la posición con ticket ", aticket);
            return false;
        }
        ticket = aticket;
        type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        time = PositionGetInteger(POSITION_TIME_MSC);
        price = PositionGetDouble(POSITION_PRICE_OPEN);
        volume = PositionGetDouble(POSITION_VOLUME);
        stop_loss = PositionGetDouble(POSITION_SL);
        take_profit = PositionGetDouble(POSITION_TP);
        symbol = PositionGetString(POSITION_SYMBOL);
        digits = (int) SymbolInfoInteger(symbol, SYMBOL_DIGITS);
        magic = PositionGetInteger(POSITION_MAGIC);
        return true;
    }

    // Métodos getter
    ENUM_POSITION_TYPE GetType() const { return type; }
    long GetTime() const { return time; }
    ulong GetTicket() const { return ticket; }
    double GetPrice() const { return price; }
    double GetVolume() const { return volume; }
    double GetStopLoss() const { return stop_loss; }
    double GetTakeProfit() const { return take_profit; }
    string GetSymbol() const { return symbol; }
    int GetDigits() const { return digits; }
    long GetMagic() const { return magic; }
    bool IsOk(string Symb, long mag ) {
      return ((Symb==symbol) && (mag == magic));
    }
    
     // Método para convertir la posición a string
   string toString() const {
        return StringFormat("Symbol: %s, Type: %d, Time: %d, Price: %.6f, Volume: %.2f, SL: %.6f, TP: %.6f, Digits: %d, Magic: %d", symbol, type, time, price, volume, stop_loss, take_profit, digits, magic);
    }
};
