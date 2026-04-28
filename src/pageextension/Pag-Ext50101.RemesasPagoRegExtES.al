pageextension 50101 "Remesas Pago Reg. Ext ES" extends "Posted Payment Orders"
{
    actions
    {
        addlast(processing)
        {
            action(RetrocederRemesaPago)
            {
                ApplicationArea = Basic, Suite;
                Caption = 'Retroceder Remesa de Pago';
                ToolTip = 'Revierte el registro de la remesa de pago.';
                Image = ReverseRegister;

                trigger OnAction()
                var
                    RetrocesoRemesaPago: Codeunit "Retroceso Remesa Pago ES";
                begin
                    RetrocesoRemesaPago.RetrocederRemesaPago(Rec);
                    CurrPage.Update(false);
                end;
            }
        }
    }
}
