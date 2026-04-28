tableextension 50100 "Cartera Setup Ext ES" extends "Cartera Setup"
{
    // ============================================================
    // Extensión de la tabla "Cartera Setup" (Configuración de Cartera)
    // Añade el control de acceso a la funcionalidad de retroceso.
    // ============================================================
    fields
    {
        field(50100; "Allow Bill Group Reversal"; Boolean)
        {
            Caption = 'Permitir revertir Remesas Registradas';
            DataClassification = CustomerContent;
        }
    }
}
