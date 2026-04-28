codeunit 50101 "Retroceso Remesa Pago ES"
{
    Permissions =
        tabledata "Posted Payment Order" = RMD,
        tabledata "Posted Cartera Doc." = RIMD,
        tabledata "Cartera Doc." = RIMD;

    procedure RetrocederRemesaPago(var RemesaPagoReg: Record "Posted Payment Order")
    var
        TextoConfirmacion: Label 'Se va a retroceder la remesa de pago %1\Banco: %2  |  Importe: %3  |  Fecha: %4\\\· Se invertirá el asiento contable del registro.\· Los movimientos de proveedor serán desaplicados.\· Los documentos volverán a Cartera listos para ser remesados.\¿Desea continuar?', Comment = '%1=No., %2=Banco, %3=Importe, %4=Fecha';
        TextoExito: Label 'La remesa de pago %1 ha sido revertida correctamente.\Los documentos han vuelto a Cartera listos para ser remesados de nuevo.', Comment = '%1=No.';
        NumTransaccion: Integer;
    begin
        ValidarConfiguracionCartera();
        ValidarDocumentosRemesa(RemesaPagoReg."No.", "Cartera Document Type"::Payable);
        NumTransaccion := ObtenerNumTransaccion(RemesaPagoReg."No.", RemesaPagoReg."Bank Account No.");

        if not Confirm(TextoConfirmacion, false,
            RemesaPagoReg."No.",
            RemesaPagoReg."Bank Account No.",
            RemesaPagoReg.Amount,
            RemesaPagoReg."Posting Date")
        then
            Error('');

        DesaplicarProveedoresPorTransaccion(NumTransaccion);
        PostearDiarioInverso(RemesaPagoReg."No.", NumTransaccion);
        ProcesarDocumentosCartera(RemesaPagoReg);

        Message(TextoExito, RemesaPagoReg."No.");
    end;

    local procedure ValidarConfiguracionCartera()
    var
        ConfigCartera: Record "Cartera Setup";
        ErrNoPermitido: Label 'El retroceso de remesas registradas no está habilitado.\Acceda a Configuración de Cartera y marque "Permitir revertir Remesas Registradas".';
    begin
        if not ConfigCartera.Get() then
            Error(ErrNoPermitido);
        if not ConfigCartera."Allow Bill Group Reversal" then
            Error(ErrNoPermitido);
    end;

    local procedure ValidarDocumentosRemesa(NumRemesa: Code[20]; TipoDocumento: Enum "Cartera Document Type")
    var
        RemesaPagoReg: Record "Posted Payment Order";
        DocCarteraPost: Record "Posted Cartera Doc.";
        ListaEfectos: Text;
        ErrEfectos: Label 'No se puede retroceder la remesa de pago %1 porque contiene efectos (no facturas):\%2\Los efectos deben gestionarse mediante la acción "Rechazar".', Comment = '%1=No., %2=Lista';
        ErrImpresa: Label 'No se puede retroceder la remesa de pago %1 porque ha sido impresa (%2 veces).\Anule el efecto impreso antes de retroceder.', Comment = '%1=No., %2=Num.';
    begin
        if RemesaPagoReg.Get(NumRemesa) then
            if RemesaPagoReg."No. Printed" > 0 then
                Error(ErrImpresa, NumRemesa, RemesaPagoReg."No. Printed");

        DocCarteraPost.SetRange("Bill Gr./Pmt. Order No.", NumRemesa);
        DocCarteraPost.SetRange(Type, TipoDocumento);
        if not DocCarteraPost.FindSet() then
            exit;

        repeat
            if DocCarteraPost."Document Type" <> DocCarteraPost."Document Type"::Invoice then
                ListaEfectos += StrSubstNo('· %1 %2 (Cuenta: %3)\',
                    DocCarteraPost."Document Type", DocCarteraPost."Document No.", DocCarteraPost."Account No.");
        until DocCarteraPost.Next() = 0;

        if ListaEfectos <> '' then
            Error(ErrEfectos, NumRemesa, ListaEfectos);
    end;

    local procedure ObtenerNumTransaccion(NumRemesa: Code[20]; CuentaBancaria: Code[20]) NumTransaccion: Integer
    var
        ApunteBanco: Record "Bank Account Ledger Entry";
        ApunteGL: Record "G/L Entry";
        ErrNoEncontrado: Label 'No se encontraron apuntes contables activos para la remesa de pago %1. Es posible que ya haya sido revertida.', Comment = '%1=No.';
    begin
        ApunteBanco.SetRange("Bank Account No.", CuentaBancaria);
        ApunteBanco.SetRange("Document No.", NumRemesa);
        ApunteBanco.SetRange(Reversed, false);
        if ApunteBanco.FindFirst() then
            exit(ApunteBanco."Transaction No.");

        ApunteGL.SetCurrentKey("Document No.", "Posting Date");
        ApunteGL.SetRange("Document No.", NumRemesa);
        ApunteGL.SetRange(Reversed, false);
        if ApunteGL.FindFirst() then
            exit(ApunteGL."Transaction No.");

        Error(ErrNoEncontrado, NumRemesa);
    end;

    local procedure DesaplicarProveedoresPorTransaccion(NumTransaccion: Integer)
    var
        ApunteProveedor: Record "Vendor Ledger Entry";
        DesaplicarApunte: Codeunit "VendEntry-Apply Posted Entries";
    begin
        ApunteProveedor.SetCurrentKey("Transaction No.");
        ApunteProveedor.SetRange("Transaction No.", NumTransaccion);
        if not ApunteProveedor.FindSet() then
            exit;
        repeat
            if not ApunteProveedor.Open then
                DesaplicarApunte.UnApplyVendLedgEntry(ApunteProveedor."Entry No.");
        until ApunteProveedor.Next() = 0;
    end;

    local procedure PostearDiarioInverso(NumRemesa: Code[20]; NumTransaccion: Integer)
    var
        ApunteGL: Record "G/L Entry";
        LineaDiario: Record "Gen. Journal Line";
        PostLinea: Codeunit "Gen. Jnl.-Post Line";
        NombrePlantilla: Code[10];
        NombreLote: Code[10];
        NumLinea: Integer;
        NumDocInverso: Code[20];
        ErrSinApuntes: Label 'No se encontraron apuntes contables para crear el asiento inverso (Transacción %1).', Comment = '%1=Transaction No.';
    begin
        NumDocInverso := CopyStr('RET-' + NumRemesa, 1, MaxStrLen(LineaDiario."Document No."));
        ObtenerPlantillaLote(NombrePlantilla, NombreLote);
        LimpiarLoteTemporal(NombrePlantilla, NombreLote);

        ApunteGL.SetRange("Transaction No.", NumTransaccion);
        ApunteGL.SetRange(Reversed, false);
        if not ApunteGL.FindSet() then
            Error(ErrSinApuntes, NumTransaccion);

        NumLinea := 10000;
        repeat
            LineaDiario.Init();
            LineaDiario.Validate("Journal Template Name", NombrePlantilla);
            LineaDiario.Validate("Journal Batch Name", NombreLote);
            LineaDiario."Line No." := NumLinea;
            LineaDiario.Validate("Posting Date", WorkDate());
            LineaDiario."Document No." := NumDocInverso;
            LineaDiario.Description := CopyStr('Retroceso remesa pago ' + NumRemesa, 1, MaxStrLen(LineaDiario.Description));
            LineaDiario.Validate("Account Type", LineaDiario."Account Type"::"G/L Account");
            LineaDiario.Validate("Account No.", ApunteGL."G/L Account No.");
            LineaDiario.Validate(Amount, -ApunteGL.Amount);
            LineaDiario."Source Code" := ApunteGL."Source Code";
            LineaDiario.Insert(true);
            PostLinea.RunWithCheck(LineaDiario);
            NumLinea += 10000;
        until ApunteGL.Next() = 0;

        LimpiarLoteTemporal(NombrePlantilla, NombreLote);
    end;

    local procedure ProcesarDocumentosCartera(var RemesaPagoReg: Record "Posted Payment Order")
    var
        DocCarteraPost: Record "Posted Cartera Doc.";
        DocCartera: Record "Cartera Doc.";
        UltimoEntryNoRech: Integer;
    begin
        DocCarteraPost.SetRange("Bill Gr./Pmt. Order No.", RemesaPagoReg."No.");
        DocCarteraPost.SetRange(Type, "Cartera Document Type"::Payable);
        if not DocCarteraPost.FindSet() then
            exit;

        repeat
            DocCartera.Init();
            DocCartera.Type := DocCarteraPost.Type; //Tipo
            DocCartera."Entry No." := DocCarteraPost."Entry No."; //Nº Mov (Cartera)
            DocCartera."No." := DocCarteraPost."No."; // Nº (Efecto)
            DocCartera."Posting Date" := DocCarteraPost."Posting Date"; // Fecha Registro
            DocCartera."Document No." := DocCarteraPost."Document No."; // Nº Documento
            DocCartera.Description := DocCarteraPost.Description; //Descripción
            DocCartera."Remaining Amount" := DocCarteraPost."Remaining Amount"; // Importe Pendiente
            DocCartera.Validate("Remaining Amt. (LCY)", DocCartera."Remaining Amt. (LCY)"); // Importe Pendiente (LCY) - para recalcular en caso de que la moneda haya cambiado
            DocCartera."Due Date" := DocCarteraPost."Due Date"; // Fecha vencimiento
            DocCartera."Payment Method Code" := DocCarteraPost."Payment Method Code"; // Cód. forma de pago
            DocCartera."Accepted" := DocCarteraPost."Accepted"; // Aceptado
            DocCartera.Place := DocCarteraPost.Place; // Plaza 
            DocCartera."Collection Agent" := DocCarteraPost."Collection Agent"; // Entidad de cobro
            DocCartera."Bill Gr./Pmt. Order No." := ''; // Nº Remesa (vacío al retroceder)
            DocCartera."Category Code" := DocCarteraPost."Category Code"; // Código Clasificación
            DocCartera."Account No." := DocCarteraPost."Account No."; // Cuenta cliente
            DocCartera."Currency Code" := DocCarteraPost."Currency Code"; // Divisa
            DocCartera."Cust./Vendor Bank Acc. Code" := DocCarteraPost."Cust./Vendor Bank Acc. Code"; // Cód. Banco cliente/proveedor
            DocCartera."Original Amount" := DocCarteraPost."Original Amount"; // Importe inicial
            DocCartera.Validate("Original Amount (LCY)", DocCartera."Original Amount (LCY)"); // Importe inicial (LCY) - para recalcular en caso de que la moneda haya cambiado
            DocCartera."Document Type" := DocCarteraPost."Document Type"; // Tipo de documento
            DocCartera."Global Dimension 1 Code" := DocCarteraPost."Global Dimension 1 Code";
            DocCartera."Global Dimension 2 Code" := DocCarteraPost."Global Dimension 2 Code";
            DocCartera.Adjusted := DocCarteraPost.Adjusted; // Ajustado         
            DocCartera."Adjusted Amount" := DocCarteraPost."Adjusted Amount"; // Importe ajustado
            DocCartera."Remaining Amount" := DocCarteraPost."Remaining Amount";
            DocCartera."Dimension Set ID" := DocCarteraPost."Dimension Set ID"; // Dimension Set ID
            DocCartera.Insert(true);

            CalcularImportesDL(DocCartera);

            // Actualizar situación del movimiento de proveedor → "Cartera"
            ActualizarSituacionVLE(DocCarteraPost."Entry No.");

            // 3. Eliminar de Posted Cartera Doc.
            DocCarteraPost.Delete(true);
        until DocCarteraPost.Next() = 0;

        // -- Eliminar cabecera de Posted Payment Order --
        RemesaPagoReg.Delete(true);
    end;

    local procedure ActualizarSituacionVLE(EntryNo: Integer)
    var
        VendLedgEntry: Record "Vendor Ledger Entry";
    begin
        if not VendLedgEntry.Get(EntryNo) then
            exit;
        VendLedgEntry."Document Situation" := VendLedgEntry."Document Situation"::Cartera;
        VendLedgEntry.Modify(true);
    end;

    local procedure CalcularImportesDL(var DocCartera: Record "Cartera Doc.")
    var
        CurrExchRate: Record "Currency Exchange Rate";
        TipoCambio: Decimal;
    begin
        if DocCartera."Currency Code" = '' then
            DocCartera."Remaining Amt. (LCY)" := DocCartera."Remaining Amount"
        else begin
            TipoCambio := CurrExchRate.ExchangeRate(DocCartera."Posting Date", DocCartera."Currency Code");
            DocCartera."Remaining Amt. (LCY)" :=
                Round(CurrExchRate.ExchangeAmtFCYToLCY(
                    DocCartera."Posting Date",
                    DocCartera."Currency Code",
                    DocCartera."Remaining Amount",
                    TipoCambio));
        end;
        DocCartera.Modify(false);
    end;

    local procedure ObtenerPlantillaLote(var NombrePlantilla: Code[10]; var NombreLote: Code[10])
    var
        PlantillaDiario: Record "Gen. Journal Template";
        LoteDiario: Record "Gen. Journal Batch";
    begin
        NombreLote := 'RETREMESA';
        PlantillaDiario.SetRange(Type, PlantillaDiario.Type::General);
        PlantillaDiario.SetRange(Recurring, false);
        if not PlantillaDiario.FindFirst() then
            Error('No se encontró ninguna plantilla de diario general.');
        NombrePlantilla := PlantillaDiario.Name;

        if not LoteDiario.Get(NombrePlantilla, NombreLote) then begin
            LoteDiario.Init();
            LoteDiario."Journal Template Name" := NombrePlantilla;
            LoteDiario.Name := NombreLote;
            LoteDiario.Description := 'Retroceso Remesas - Uso temporal';
            LoteDiario.Insert(true);
        end;
    end;

    local procedure LimpiarLoteTemporal(NombrePlantilla: Code[10]; NombreLote: Code[10])
    var
        LineaDiario: Record "Gen. Journal Line";
    begin
        LineaDiario.SetRange("Journal Template Name", NombrePlantilla);
        LineaDiario.SetRange("Journal Batch Name", NombreLote);
        LineaDiario.DeleteAll(true);
    end;
}
