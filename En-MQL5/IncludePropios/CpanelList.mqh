#include <Arrays\List.mqh>

class CPanelList : public CList
{
    public:
        void DeleteListElementByName(const string name);
        void MoveListElementByName(const string name, const int index);
        void CreateListElementByName(CObject &obj, const string name);
        void SetHiddenByName(const string name, const bool hidden);
};