tableextension 50100 "Cartera Setup Ext ES" extends "Cartera Setup"
{
    fields
    {
        field(50100; "Allow Bill Group Reversal"; Boolean)
        {
            Caption = 'Permitir revertir Remesas Registradas';
            DataClassification = CustomerContent;
        }
    }
}
