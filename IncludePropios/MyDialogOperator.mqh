//+------------------------------------------------------------------+
//| Class SymbolInfoDialog                                           |
//| Creates a dialog box with symbol info                            |
//+------------------------------------------------------------------+
#include <Controls\Defines.mqh>
#include <Controls\Dialog.mqh>
#include <Controls\Label.mqh>
#include <Controls\Button.mqh>
#include <Controls\Edit.mqh>
#include <Controls\CheckBox.mqh>

class MyDialog : public CAppDialog
{
private:

//    CLabel line1, line2, line3;
    CLabel m_lblSymbolName;
    bool estado; // Variable para almacenar el estado del botón
    CLabel m_estado;
    CButton m_btnEstadoAction;        // Nuevo botón central
    
    bool automaticClose; // Variable para almacenar el automaticClose del botón
    CLabel m_AutomaticClose;
    CButton m_btnAutomaticClose;        // Nuevo botón automaticClose
    
    bool openSameDirection; // Variable para almacenar el OpenSameDirection del botón
    CLabel m_OpenSameDirection;
    CButton m_btnOpenSameDirection;        // Nuevo botón OpenSameDirection

// Constants for layout
#define MARGIN_LEFT 10
#define MARGIN_TOP 10
#define LABEL_WIDTH 60
#define EDIT_WIDTH 80
#define ROW_HEIGHT 25
#define COLUMN_GAP 50
#define BUTTON_WIDTH 80         // Ancho del botón
#define BUTTON_HEIGHT 25        // Alto del botón
#define BUTTON_MARGIN_BOTTOM 35 // Margen inferior
#define CHECKBOX_WIDTH 250       // Ancho del botón
#define CHECKBOX_HEIGHT 25      // Alto del botón

public:
    MyDialog(void);
    ~MyDialog(void);

    void UpdateValues(const string symbol);

    virtual bool Create(const long chart, const string name, const int subwin,
                        const int x1, const int y1, const int x2, const int y2);

    void OnButtonActionEstadoClicked(void);
    void OnButtonActionAutomaticCloseClicked(void);
    void OnButtonActionOpenSameDirectionClicked(void);
    virtual bool OnEvent(const int id, const long &lparam, const double &dparam, const string &sparam);
    void OnClickButtonClose(void);
    virtual bool IsMinimized() { return m_minimized; }
    void SetEstado(const bool new_estado); // Método para establecer el estado
    bool GetEstado(void) const;            // Método para obtener el estado
    void SetAutomaticClose(const bool new_AutomaticClose);
    bool GetAutomaticClose(void) const;
    void SetOpenSameDirection(const bool new_OpenSameDirection);
    bool GetOpenSameDirection(void) const;

protected:
    bool CreateControls(void);
    bool CreateActionButton(CButton &button, string name, string text, int x, int y);
    bool CreateEdit(CEdit &edit, string name, int x, int y, bool read_only = true);
    bool CreateLabel(CLabel &label, string name, string text, int x, int y);
    bool CreateCheckBox(CCheckBox &checkBox, string name, string text, int x, int y);
    bool DrawHorizontalLine(CLabel &label, int x);

};

//+------------------------------------------------------------------+
//| Event Handling                                                   |
//+------------------------------------------------------------------+
// Event Map

EVENT_MAP_BEGIN(MyDialog)
ON_EVENT(ON_CLICK, m_btnEstadoAction, OnButtonActionEstadoClicked)
ON_EVENT(ON_CLICK, m_btnAutomaticClose, OnButtonActionAutomaticCloseClicked)
ON_EVENT(ON_CLICK, m_btnOpenSameDirection, OnButtonActionOpenSameDirectionClicked)
EVENT_MAP_END(CAppDialog)

/*
bool MyDialog::OnEvent(const int id,const long& lparam,const double& dparam,const string& sparam) {
   if(id==(ON_CLICK+CHARTEVENT_CUSTOM) && lparam==m_btnEstadoAction.Id()) {
   OnButtonActionClicked(); return(true);
   }
//if(id==(ON_CLICK+CHARTEVENT_CUSTOM) && lparam==m_bmpbutton2.Id()) { OnClickBmpButton2(); return(true); }
return(CAppDialog::OnEvent(id,lparam,dparam,sparam)); }
*/

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
MyDialog::MyDialog(void)
{
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
MyDialog::~MyDialog(void)
{
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Set the value of 'estado'                                        |
//+------------------------------------------------------------------+
void MyDialog::SetEstado(const bool new_estado)
{
    estado = new_estado;
    m_estado.Text("Estado: " + (estado ? "Activado" : "Desactivado"));
    m_btnEstadoAction.Text((estado ? "Desactivar" : "Activar"));
}

//+------------------------------------------------------------------+
//| Get the value of 'estado'                                        |
//+------------------------------------------------------------------+
bool MyDialog::GetEstado(void) const
{
    return estado;
}
//+------------------------------------------------------------------+
//| Set the value of 'CheckAutomaticClose'                                        |
//+------------------------------------------------------------------+
void MyDialog::SetAutomaticClose(const bool new_AutomaticClose)
{
    automaticClose = new_AutomaticClose;
    m_AutomaticClose.Text("AutomaticClose: "+ (automaticClose ? "Activado" : "Desactivado")); 
    m_btnAutomaticClose.Text((automaticClose ? "Desactivar" : "Activar"));
}


//+------------------------------------------------------------------+
//| Get the value of 'CheckAutomaticClose'                                        |
//+------------------------------------------------------------------+
bool MyDialog::GetAutomaticClose(void) const
{
    return automaticClose; // Devuelve el estado del checkbox
}
//+------------------------------------------------------------------+
//| Set the value of 'CheckAutomaticClose'                                        |
//+------------------------------------------------------------------+
void MyDialog::SetOpenSameDirection(const bool new_OpenSameDirection)
{
   openSameDirection = new_OpenSameDirection;
   m_OpenSameDirection.Text("OpenSameDir: "+ (openSameDirection ? "Activado" : "Desactivado"));
   m_btnOpenSameDirection.Text((openSameDirection ? "Desactivar" : "Activar"));
}

//+------------------------------------------------------------------+
//| Get the value of 'CheckAutomaticClose'                                        |
//+------------------------------------------------------------------+
bool MyDialog::GetOpenSameDirection(void) const
{
    return openSameDirection; // Devuelve el estado del checkbox OpenSameDirection
}
//+------------------------------------------------------------------+
//| Event handler for Minimize                                 |
//+------------------------------------------------------------------+
/*void MyDialog::Minimize(void)
{
    CAppDialog::Minimize();
        sets.IsPanelMinimized = true;
        if (remember_left != -1)
        {
            Move(remember_left, remember_top);
            m_min_rect.Move(remember_left, remember_top);
        }
    IniFileSave();
}
    */
//+------------------------------------------------------------------+
//| Create dialog                                                    |
//+------------------------------------------------------------------+
bool MyDialog::Create(const long chart, const string name, const int subwin,
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
bool MyDialog::CreateControls(void)
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

    // Second row - Estado - Action Button
    current_y += ROW_HEIGHT + 5;
    if (!CreateLabel(m_estado, "Estado", "Estado:", column1_x, current_y))
        return false;

    if (!CreateActionButton(m_btnEstadoAction, "btnEstadoAction", "btnEstadoAction", column2_x, current_y))
        return false;

    // Third row
    current_y += ROW_HEIGHT + 5;
/*    if (!DrawHorizontalLine(line2, current_y-5))
        return false;
    current_y += ROW_HEIGHT + 5;
  */  
    if (!CreateLabel(m_AutomaticClose, "AutomaticClose", "AutomaticClose:", column1_x, current_y))
        return false;

    if (!CreateActionButton(m_btnAutomaticClose, "btnAutomaticClose", "btnAutomaticClose", column2_x, current_y))
        return false;

    // Fourth row
    current_y += ROW_HEIGHT + 5;
/*    if (!DrawHorizontalLine(line3, current_y-5))
        return false;
    current_y += ROW_HEIGHT + 5;
  */  
    if (!CreateLabel(m_OpenSameDirection, "OpenSameDirection", "OpenSameDirection:", column1_x, current_y))
        return false;

    if (!CreateActionButton(m_btnOpenSameDirection, "btnOpenSameDirection", "btnOpenSameDirection", column2_x, current_y))
        return false;

    m_lblSymbolName.Text("Symbol: " + Symbol());
    m_estado.Text("Estado: " + (estado ? "Activado" : "Desactivado"));
    m_btnEstadoAction.Text((estado ? "Desactivar" : "Activar"));

    m_AutomaticClose.Text("AutomaticClose: "+ (automaticClose ? "Activado" : "Desactivado"));
    m_btnAutomaticClose.Text((automaticClose ? "Desactivar" : "Activar"));

    m_OpenSameDirection.Text("OpenSameDir: "+ (openSameDirection ? "Activado" : "Desactivado"));
    m_btnOpenSameDirection.Text((openSameDirection ? "Desactivar" : "Activar"));
    return true;
}

//+------------------------------------------------------------------+
//| Update values in dialog                                          |
//+------------------------------------------------------------------+
void MyDialog::UpdateValues(const string symbol)
{
    m_estado.Text("Estado: " + (estado ? "Activado" : "Desactivado"));
    m_btnEstadoAction.Text((estado ? "Desactivar" : "Activar"));

    m_AutomaticClose.Text("AutomaticClose: "+ (automaticClose ? "Activado" : "Desactivado"));
    m_btnAutomaticClose.Text((automaticClose ? "Activar" : "Desactivar"));

    m_OpenSameDirection.Text("OpenSameDir: "+ (openSameDirection ? "Activado" : "Desactivado"));
    m_btnOpenSameDirection.Text((openSameDirection ? "Activar" : "Desactivar"));
}

void MyDialog::OnClickButtonClose(void)
{
    // Ocultar el diálogo
    Hide();

    // Llama al método de la clase padre
    CAppDialog::OnClickButtonClose();
}

//+------------------------------------------------------------------+
//| Create check box                                                 |
//+------------------------------------------------------------------+
bool MyDialog::CreateCheckBox(CCheckBox &checkBox, string name, string text, int x, int y)
{
    if (!checkBox.Create(m_chart_id, name, m_subwin, x, y, x + CHECKBOX_WIDTH, y + CHECKBOX_HEIGHT))
        return false;

    checkBox.Text(text);
    if(!checkBox.Color(clrBlue))
      return(false);

    Add(checkBox);

    return true;
}

//+------------------------------------------------------------------+
//| Create action button                                             |
//+------------------------------------------------------------------+
bool MyDialog::CreateActionButton(CButton &button, string name, string text, int x, int y)
{
    // Calcular posición centrada horizontalmente
    if (!button.Create(m_chart_id, name, m_subwin, x, y, x + BUTTON_WIDTH, y + BUTTON_HEIGHT))
        return false;

    button.Text(text); // Texto del botón
    button.FontSize(10);
    button.ColorBackground(clrBeige);
    button.Color(clrBlack);
    Add(button);

    return true;
}

//+------------------------------------------------------------------+
//| Crea un label con configuración estándar                         |
//+------------------------------------------------------------------+
bool MyDialog::CreateLabel(CLabel &label, string name, string text, int x, int y)
{
    if (!label.Create(m_chart_id, name, m_subwin, x, y, x + LABEL_WIDTH, y + ROW_HEIGHT))
        return false;

    label.Text(text);
    label.Color(clrBlack); // Color de texto negro
    label.FontSize(9);     // Tamaño de fuente
    Add(label);

    return true;
}

bool MyDialog::DrawHorizontalLine(CLabel &label, int x)
{
//    if (!label.Create(m_chart_id, "DividerLine", m_subwin, 5, x, this.Width()-5 , x+2))
    if (!label.Create(m_chart_id, "DividerLine", m_subwin, 15, x, 200 , x+25))
        return false;

    label.ColorBackground(clrBlue); // Color de texto negro
    Add(label);

    return true;
}

//+------------------------------------------------------------------+
//| Crea un edit box con configuración estándar                      |
//+------------------------------------------------------------------+
/*bool MyDialog::CreateEdit(CEdit &edit, string name, int x, int y, bool read_only = true)
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
*/

void MyDialog::OnButtonActionEstadoClicked()
{
    SetEstado(!GetEstado());
}

void MyDialog::OnButtonActionAutomaticCloseClicked()
{
    SetAutomaticClose(!GetAutomaticClose());
}

void MyDialog::OnButtonActionOpenSameDirectionClicked()
{
   SetOpenSameDirection(!GetOpenSameDirection());
}
