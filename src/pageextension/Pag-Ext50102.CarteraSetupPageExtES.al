pageextension 50102 "Cartera Setup Page Ext ES" extends "Cartera Setup"
{
    layout
    {
        addlast(content)
        {
            group(GrupoRetroceso)
            {
                Caption = 'Retroceso de Remesas';

                field("Allow Bill Group Reversal"; Rec."Allow Bill Group Reversal")
                {
                    ApplicationArea = Basic, Suite;
                    Caption = 'Permitir revertir Remesas Registradas';
                    ToolTip = 'Activa la acción "Retroceder Remesa" en las páginas de Remesas Registradas (cobro y pago). Al revertir una remesa, se crea el asiento contable inverso, se desaplican los movimientos de cliente/proveedor y la remesa vuelve a aparecer en la lista de remesas pendientes con sus documentos.';
                }
            }
        }
    }
}
