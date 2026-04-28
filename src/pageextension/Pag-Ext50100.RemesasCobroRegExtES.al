pageextension 50100 "Remesas Cobro Reg. Ext ES" extends "Posted Bill Groups"
{
    actions
    {
        addlast(processing)
        {
            action(RetrocederRemesaCobro)
            {
                ApplicationArea = Basic, Suite;
                Caption = 'Retroceder Remesa';
                ToolTip = 'Revierte el registro de la remesa: invierte el asiento contable, desaplica movimientos de cliente y devuelve los documentos a una nueva remesa abierta.';
                Image = ReverseRegister;

                trigger OnAction()
                var
                    RetrocesoRemesaCobro: Codeunit "Retroceso Remesa Cobro ES";
                begin
                    RetrocesoRemesaCobro.RetrocederRemesaCobro(Rec);
                    CurrPage.Update(false);
                end;
            }
        }
    }
}
