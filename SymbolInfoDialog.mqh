//+------------------------------------------------------------------+
//| Class SymbolInfoDialog                                           |
//| Creates a dialog box with symbol info                            |
//+------------------------------------------------------------------+
#include <Controls\Defines.mqh>
#include <Controls\Dialog.mqh>
#include <Controls\Label.mqh>
#include <Controls\Edit.mqh>
#include <Controls\Button.mqh>

class CSymbolInfoDialog : public CAppDialog
{
private:
    CLabel m_lblSymbolName;
    CLabel m_lblAsk;
    CLabel m_lblBid;
    CEdit m_edtSymbolName;
    CEdit m_edtAsk;
    CEdit m_edtBid;
    CButton m_btnAction; // Nuevo botón central

// Constants for layout
#define MARGIN_LEFT 10
#define MARGIN_TOP 10
#define LABEL_WIDTH 60
#define EDIT_WIDTH 80
#define ROW_HEIGHT 20
#define COLUMN_GAP 10
#define BUTTON_WIDTH 80         // Ancho del botón
#define BUTTON_HEIGHT 25        // Alto del botón
#define BUTTON_MARGIN_BOTTOM 35 // Margen inferior

public:
    CSymbolInfoDialog(void);
    ~CSymbolInfoDialog(void);

    void UpdateValues(const string symbol, const double ask, const double bid);

    virtual bool Create(const long chart, const string name, const int subwin,
                        const int x1, const int y1, const int x2, const int y2);

    void OnButtonActionClicked(void);
    virtual bool OnEvent(const int id, const long &lparam, const double &dparam, const string &sparam);
    void OnClickButtonClose(void);

protected:
    virtual void Minimize(void);
    virtual bool     IsMinimized() {return m_minimized;}
    bool CreateControls(void);
    bool CreateActionButton(void);
    bool CreateEdit(CEdit &edit, string name, int x, int y, bool read_only = true);
    bool CreateLabel(CLabel &label, string name, string text, int x, int y);
    void SetValues(const string symbol, const double ask, const double bid);
};

//+------------------------------------------------------------------+
//| Event Handling                                                   |
//+------------------------------------------------------------------+
EVENT_MAP_BEGIN(CSymbolInfoDialog)
//ON_EVENT(ON_CLICK, m_btnMinimize, Minimize)
//ON_EVENT(ON_CLICK, m_btnClose, OnClickButtonClose)  
ON_EVENT(ON_CLICK, m_btnAction, OnClickButtonClose)
//ON_EVENT(ON_CLICK, m_btnAction, OnButtonActionClicked)
EVENT_MAP_END(CAppDialog)

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSymbolInfoDialog::CSymbolInfoDialog(void)
{
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CSymbolInfoDialog::~CSymbolInfoDialog(void)
{
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CSymbolInfoDialog::Minimize(void)
{
    CAppDialog::Minimize();
/*    sets.IsPanelMinimized = true;
    if (remember_left != -1)
    {
        Move(remember_left, remember_top);
        m_min_rect.Move(remember_left, remember_top);
    }*/
    IniFileSave();
}


//+------------------------------------------------------------------+
//| Create dialog                                                    |
//+------------------------------------------------------------------+
bool CSymbolInfoDialog::Create(const long chart, const string name, const int subwin,
                               const int x1, const int y1, const int x2, const int y2)
{
    if (!CAppDialog::Create(chart, name, subwin, x1, y1, x2, y2))
        return false;

    if (!CreateControls())
        return false;

    return true;
}

//+------------------------------------------------------------------+
//| Create controls                                                  |
//+------------------------------------------------------------------+
bool CSymbolInfoDialog::CreateControls(void)
{
    // Calculate positions relative to dialog size
    int width = Width();
    int height = Height();

    int column1_x = MARGIN_LEFT;
    int column2_x = width / 2 + COLUMN_GAP;

    // First row - Symbol Name
    int current_y = MARGIN_TOP;

    if (!CreateLabel(m_lblSymbolName, "lblSymbolName", "Symbol:", column1_x, current_y))
        return false;

    if (!CreateEdit(m_edtSymbolName, "edtSymbolName", column2_x, current_y))
        return false;

    // Second row - Ask
    current_y += ROW_HEIGHT + 5;

    if (!CreateLabel(m_lblAsk, "lblAsk", "Ask:", column1_x, current_y))
        return false;

    if (!CreateEdit(m_edtAsk, "edtAsk", column2_x, current_y))
        return false;

    // Third row - Bid
    current_y += ROW_HEIGHT + 5;

    if (!CreateLabel(m_lblBid, "lblBid", "Bid:", column1_x, current_y))
        return false;

    if (!CreateEdit(m_edtBid, "edtBid", column2_x, current_y))
        return false;

    if (!CreateActionButton())
        return false;

    return true;
}

//+------------------------------------------------------------------+
//| Update values in dialog                                          |
//+------------------------------------------------------------------+
void CSymbolInfoDialog::UpdateValues(const string symbol, const double ask, const double bid)
{
    m_edtSymbolName.Text(symbol);
    m_edtAsk.Text(DoubleToString(ask, _Digits));
    m_edtBid.Text(DoubleToString(bid, _Digits));
}

void CSymbolInfoDialog::OnClickButtonClose(void)
{
    // Ocultar el diálogo
    Hide();

    // Llama al método de la clase padre
    CAppDialog::OnClickButtonClose();
}

//+------------------------------------------------------------------+
//| Create action button                                             |
//+------------------------------------------------------------------+
bool CSymbolInfoDialog::CreateActionButton()
{
    // Calcular posición centrada horizontalmente
    int button_x = (Width() - BUTTON_WIDTH) / 2;
    int button_y = Height() - BUTTON_HEIGHT - BUTTON_MARGIN_BOTTOM;

    if (!m_btnAction.Create(m_chart_id, "btnAction", m_subwin,
                            button_x, button_y,
                            button_x + BUTTON_WIDTH, button_y + BUTTON_HEIGHT))
        return false;

    m_btnAction.Text("Cerrar"); // Texto del botón
    m_btnAction.FontSize(10);
    m_btnAction.ColorBackground(clrBeige);
    m_btnAction.Color(clrBlack);
    Add(m_btnAction);

    return true;
}

//+------------------------------------------------------------------+
//| Crea un label con configuración estándar                         |
//+------------------------------------------------------------------+
bool CSymbolInfoDialog::CreateLabel(CLabel &label, string name, string text, int x, int y)
{
    if (!label.Create(m_chart_id, name, m_subwin, x, y, x + LABEL_WIDTH, y + ROW_HEIGHT))
        return false;

    label.Text(text);
    label.Color(clrBlack); // Color de texto negro
    label.FontSize(9);     // Tamaño de fuente
    Add(label);

    return true;
}

//+------------------------------------------------------------------+
//| Crea un edit box con configuración estándar                      |
//+------------------------------------------------------------------+
bool CSymbolInfoDialog::CreateEdit(CEdit &edit, string name, int x, int y, bool read_only = true)
{
    if (!edit.Create(m_chart_id, name, m_subwin, x, y, x + EDIT_WIDTH, y + ROW_HEIGHT))
        return false;

    edit.ReadOnly(read_only);
    edit.ColorBackground(clrWhiteSmoke); // Fondo claro
    edit.Color(clrBlack);                // Texto negro
    edit.FontSize(9);                    // Tamaño de fuente
    // edit.BorderColor(clrSilver);         // Borde plateado
    // edit.ShowBorder(true);
    Add(edit);

    return true;
}

void CSymbolInfoDialog::OnButtonActionClicked()
{
    // 1. Confirmar con el usuario
    if (MessageBox("¿Desea ejecutar esta operación?", "Confirmación", MB_YESNO | MB_ICONQUESTION) != IDYES)
        return;

    OnClickButtonClose();
}