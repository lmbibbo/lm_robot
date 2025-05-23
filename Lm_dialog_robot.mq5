//+------------------------------------------------------------------+
//|                                              Lm_dialog_robot.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

#include <../IncludePropios/CpanelList.mqh>
#include <Controls\Dialog.mqh>
#include <Controls\Label.mqh>
#include <Controls\Button.mqh>
#include <Controls\CheckBox.mqh>

class CMyDialog : public CAppDialog
{
private:
   CLabel m_labelSymbol;
   CLabel m_labelAsk;
   CLabel m_labelBid;
   CButton m_buttonClose;
   CButton m_buttonMinimize;
   CCheckBox m_checkboxOperar;
   string m_symbol;
   double m_ask, m_bid;

   double m_DPIScale;
   int PanelWidth;
   virtual bool CreateObjects();
   virtual void Destroy();
   bool LabelCreate(CList *list, CLabel &Lbl, int X1, int Y1, int X2, int Y2, string Name, string Text, string Tooltip = "\n")
   
   CPanelList *PersistentList; // PersisntentList can be potentially used for Strategy Tester event tracking in the future.

   // Some of the panel measurement parameters are used by more than one method:
   int first_column_start, normal_label_width, normal_edit_width, second_column_start, element_height, third_column_start, narrow_label_width, v_spacing, multi_tp_column_start,
       multi_tp_label_width, multi_tp_button_start, leverage_edit_width, third_trading_column_start, second_trading_column_start;

protected:
   virtual bool OnEvent(const int id, const long &lparam, const double &dparam, const string &sparam);

public:
   CMyDialog();
   ~CMyDialog();

   bool OperarHabilitado() const;
   virtual bool Create(const long chart, const string name, const int subwin, const int x1, const int y1);
   void UpdatePrices();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CMyDialog::CMyDialog() : m_symbol(Symbol()), m_ask(0), m_bid(0)
{
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CMyDialog::~CMyDialog()
{
   delete PersistentList;
}

//+------------------------------------------------------------------+
//| Creación de la ventana                                           |
//+------------------------------------------------------------------+
bool CMyDialog::Create(const long chart, const string name, const int subwin, const int x1, const int y1)
{

   double screen_dpi = (double)TerminalInfoInteger(TERMINAL_SCREEN_DPI);
   m_DPIScale = screen_dpi / 96.0;

   if ((AccountInfoInteger(ACCOUNT_CURRENCY_DIGITS) > 2) || (_Digits > 5)) // Wide panel required.
      PanelWidth = 500;
   else
      PanelWidth = 350; // Narrow panel (like in MT4).

   int x2 = x1 + (int)MathRound(PanelWidth * m_DPIScale);
   int y2 = y1 + (int)MathRound(400 * m_DPIScale);

   if (!CAppDialog::Create(chart, name, subwin, x1, y1, x2, y2))
      return false;
   if (!CreateObjects())
      return false;

   return true;
}

bool CMyDialog::CreateObjects()
{
   int row_start, h_spacing,
       tab_button_start, tab_button_width, tab_button_spacing, narrow_edit_width, risk_perc_edit_width, narrowest_label_width, risk_lot_edit, wide_edit_width, wide_label_width, swap_last_label_width, swap_type_edit_width, swap_size_edit_width, atr_period_label_width, atr_period_edit_width, quick_risk_button_width, quick_risk_button_offset,
       second_risk_column_start, second_margin_column_start, second_swaps_column_start, third_risk_column_start, third_swaps_column_start, fourth_risk_column_start, fourth_swaps_column_start, max_psc_column_start,
       panel_end, ignore_symbols_button_width;

   // Same for both modes - narrow and wide.
   row_start = (int)MathRound(10 * m_DPIScale);
   element_height = (int)MathRound(20 * m_DPIScale);
   v_spacing = (int)MathRound(4 * m_DPIScale);
   h_spacing = (int)MathRound(5 * m_DPIScale);
   tab_button_start = (int)MathRound(15 * m_DPIScale);
   tab_button_width = (int)MathRound(50 * m_DPIScale);
   normal_label_width = (int)MathRound(108 * m_DPIScale);
   narrow_label_width = (int)MathRound(85 * m_DPIScale);
   narrow_edit_width = (int)MathRound(75 * m_DPIScale);
   narrowest_label_width = (int)MathRound(50 * m_DPIScale);
   leverage_edit_width = (int)MathRound(35 * m_DPIScale);
   wide_edit_width = (int)MathRound(170 * m_DPIScale);
   wide_label_width = (int)MathRound(193 * m_DPIScale);
   swap_type_edit_width = narrow_edit_width * 2 + h_spacing;
   quick_risk_button_width = (int)MathRound(32 * m_DPIScale);
   first_column_start = 2 * h_spacing;
   second_swaps_column_start = first_column_start + narrowest_label_width + h_spacing;
   multi_tp_column_start = first_column_start + normal_label_width;
   multi_tp_label_width = (int)MathRound(70 * m_DPIScale);
   ignore_symbols_button_width = (int)MathRound(95 * m_DPIScale);

   // Wide mode.
   if (PanelWidth > 350) // Wide panel required.
   {
      tab_button_spacing = (int)MathRound(50 * m_DPIScale);
      normal_edit_width = (int)MathRound(125 * m_DPIScale);
      risk_perc_edit_width = (int)MathRound(85 * m_DPIScale);
      swap_last_label_width = (int)MathRound(100 * m_DPIScale);
      swap_size_edit_width = normal_edit_width;
      atr_period_label_width = (int)MathRound(78 * m_DPIScale);
      atr_period_edit_width = (int)MathRound(70 * m_DPIScale);
      quick_risk_button_offset = (int)MathRound(90 * m_DPIScale);
      risk_lot_edit = normal_edit_width;

      second_column_start = first_column_start + (int)MathRound(163 * m_DPIScale);
      second_risk_column_start = first_column_start + (int)MathRound(122 * m_DPIScale);
      second_margin_column_start = first_column_start + (int)MathRound(178 * m_DPIScale);
      second_trading_column_start = second_margin_column_start + h_spacing;

      third_column_start = second_column_start + (int)MathRound(182 * m_DPIScale);
      third_risk_column_start = second_risk_column_start + normal_edit_width + (int)MathRound(8 * m_DPIScale);
      third_swaps_column_start = second_swaps_column_start + normal_edit_width + h_spacing;
      third_trading_column_start = second_trading_column_start + normal_edit_width + (int)MathRound(5 * m_DPIScale);

      fourth_risk_column_start = third_risk_column_start + risk_perc_edit_width + (int)MathRound(8 * m_DPIScale);
      fourth_swaps_column_start = third_swaps_column_start + normal_edit_width + h_spacing;

      max_psc_column_start = second_margin_column_start + leverage_edit_width;

      multi_tp_button_start = second_trading_column_start + (int)MathRound(50 * m_DPIScale);
   }
   else
   {
      tab_button_spacing = (int)MathRound(15 * m_DPIScale);
      normal_edit_width = (int)MathRound(85 * m_DPIScale);
      risk_perc_edit_width = (int)MathRound(65 * m_DPIScale);
      swap_last_label_width = (int)MathRound(80 * m_DPIScale);
      swap_size_edit_width = narrow_edit_width;
      atr_period_label_width = (int)MathRound(72 * m_DPIScale);
      atr_period_edit_width = (int)MathRound(36 * m_DPIScale);
      quick_risk_button_offset = tab_button_width;
      risk_lot_edit = narrowest_label_width;

      second_column_start = first_column_start + (int)MathRound(123 * m_DPIScale);
      second_risk_column_start = first_column_start + (int)MathRound(114 * m_DPIScale);
      second_margin_column_start = first_column_start + (int)MathRound(138 * m_DPIScale);
      second_trading_column_start = second_margin_column_start + h_spacing;

      third_column_start = second_column_start + (int)MathRound(102 * m_DPIScale);
      third_risk_column_start = second_risk_column_start + normal_edit_width + (int)MathRound(4 * m_DPIScale);
      third_swaps_column_start = second_swaps_column_start + narrow_edit_width + h_spacing;
      third_trading_column_start = second_trading_column_start + normal_edit_width + (int)MathRound(5 * m_DPIScale);

      fourth_risk_column_start = third_risk_column_start + risk_perc_edit_width + (int)MathRound(4 * m_DPIScale);
      fourth_swaps_column_start = third_swaps_column_start + narrow_edit_width + h_spacing;

      max_psc_column_start = second_margin_column_start + normal_edit_width + h_spacing;

      multi_tp_button_start = second_trading_column_start + (int)MathRound(11 * m_DPIScale);
   }

   panel_end = third_column_start + narrow_label_width;

   int y = (int)MathRound(8 * m_DPIScale);
   Print("y = ", y);
   PersistentList = new CPanelList;
   
   if (!LabelCreate(PersistentList, m_labelSymbol, first_column_start, y, first_column_start + normal_label_width, y + element_height, "m_LblEntryLevel", TRANSLATION_LABEL_ENTRY + ":"))                                        return false;

   // Crear controles
   m_labelSymbol.Create(m_chart_id, "LabelSymbol", m_subwin, first_column_start, y, first_column_start + normal_label_width, y + element_height);
   m_labelSymbol.Text("Símbolo: " + m_symbol);
   Add(m_labelSymbol);
   ///////// hasta acá
   y = row_start + element_height + 3 * v_spacing;
   Print("y3 = ", y);

   // Configuración de la ventana
   Caption("Monitor de Precios");

   // Crear controles
   m_labelSymbol.Create(m_chart_id, "LabelSymbol", m_subwin, 10, 10, 40, 40);
   m_labelSymbol.Text("Símbolo: " + m_symbol);
   Add(m_labelSymbol);

   m_labelAsk.Create(m_chart_id, "LabelAsk", m_subwin, 10, 30, 40, 40);
   m_labelAsk.Text("Ask: " + DoubleToString(m_ask, _Digits));
   Add(m_labelAsk);

   m_labelBid.Create(m_chart_id, "LabelBid", m_subwin, 200, 30, 40, 40);
   m_labelBid.Text("Bid: " + DoubleToString(m_bid, _Digits));
   Add(m_labelBid);

   m_checkboxOperar.Create(m_chart_id, "CheckOperar", m_subwin, 10, 50, 40, 20);
   m_checkboxOperar.Text("Operar?");
   m_checkboxOperar.Checked(true);
   Add(m_checkboxOperar);

   return true;
}

//+------------------------------------------------------------------+
//| Manejo de eventos                                                |
//+------------------------------------------------------------------+
bool CMyDialog::OnEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   return CAppDialog::OnEvent(id, lparam, dparam, sparam);
}

//+------------------------------------------------------------------+
//| Actualización de precios                                         |
//+------------------------------------------------------------------+
void CMyDialog::UpdatePrices()
{
   m_ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
   m_bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);

   m_labelAsk.Text("Ask: " + DoubleToString(m_ask, _Digits));
   m_labelBid.Text("Bid: " + DoubleToString(m_bid, _Digits));
}

//+------------------------------------------------------------------+
//| Verificar estado del checkbox                                    |
//+------------------------------------------------------------------+
bool CMyDialog::OperarHabilitado() const
{
   return m_checkboxOperar.Checked();
}

void CMyDialog::Destroy()
{
   CDialog::Destroy();
}

//+-------+
//| Label |
//+-------+
bool CMyDialog::LabelCreate(CList *list, CLabel &Lbl, int X1, int Y1, int X2, int Y2, string Name, string Text, string Tooltip = "\n")
{
    if (!Lbl.Create(m_chart_id, m_name + Name, m_subwin, X1, Y1, X2, Y2))       return false;
    if (!Add(Lbl))                                                              return false;
    if (!Lbl.Text(Text))                                                        return false;
   
    return true;
}


CMyDialog myDialog;

int OnInit()
{
   // Crear ventana (tamaño: 300x150 píxeles)
   if (!myDialog.Create(0, "MyDialog", 0, 30, 30))
      return INIT_FAILED;

   myDialog.Run(); // Mostrar ventana
   return INIT_SUCCEEDED;
}

void OnTick()
{
   myDialog.UpdatePrices(); // Actualizar precios
}

void OnDeinit(const int reason)
{
}