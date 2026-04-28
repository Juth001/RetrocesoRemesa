permissionset 50100 "Retroceso Remesa ES"
{
    Assignable = true;
    Caption = 'Retroceso Remesas Registradas ES';

    Permissions =
        tabledata "Posted Bill Group" = RMD,
        tabledata "Posted Payment Order" = RMD,
        tabledata "Posted Cartera Doc." = RIMD,   // Delete necesario para mover a Cartera Doc.
        tabledata "Cartera Doc." = RIMD,
        tabledata "Cust. Ledger Entry" = RM,
        tabledata "Detailed Cust. Ledg. Entry" = RIMD,
        tabledata "Vendor Ledger Entry" = RM,
        tabledata "Detailed Vendor Ledg. Entry" = RIMD,
        tabledata "Gen. Journal Template" = RIM,
        tabledata "Gen. Journal Batch" = RIMD,
        tabledata "Gen. Journal Line" = RIMD,
        tabledata "G/L Entry" = R,
        tabledata "Bank Account Ledger Entry" = R,
        tabledata "Cartera Setup" = R,
        codeunit "CustEntry-Apply Posted Entries" = X,
        codeunit "VendEntry-Apply Posted Entries" = X,
        codeunit "Gen. Jnl.-Post Line" = X;
}
