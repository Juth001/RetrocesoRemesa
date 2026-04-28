# Extensión: Retroceso de Remesa Registrada (Localización Española - Módulo Cartera)

## Descripción
Permite revertir el proceso de registro de una remesa de cobro o pago en Business Central con localización española. El proceso es el inverso al de "Registrar Remesa":

1. **Valida** que la remesa pueda ser revertida.
2. **Desaplica** los apuntes de cliente/proveedor que fueron cerrados al registrar la remesa.
3. **Invierte** los asientos contables y de banco mediante el mecanismo estándar de BC (`Reversal Entry`).
4. **Actualiza** el estado de los documentos de cartera a `Rejected` (Rechazado).

---

## Ficheros incluidos

| Fichero | Descripción |
|---------|-------------|
| `app.json` | Manifiesto de la extensión |
| `src/RetrocesoRemesaCobro.Codeunit.al` | Lógica principal para remesas de **cobro** |
| `src/RetrocesoRemesaPago.Codeunit.al` | Lógica principal para remesas de **pago** |
| `src/RemesasCobRegistradasPageExt.al` | Acción en la página *Remesas Cobro Registradas* |
| `src/RemesasPagoRegistradasPageExt.al` | Acción en la página *Remesas Pago Registradas* |

---

## Consideraciones importantes antes de compilar

### 1. Nombres de páginas base (Page Extensions)
Verificar los nombres exactos de las páginas en tu versión de BC/Cartera:

```al
// Pueden llamarse de estas formas según la versión:
extends "Posted Bill Groups"         // o "Remesas Cobro Registradas"
extends "Posted Payment Orders"      // o "Remesas Pago Registradas"
```

Para comprobarlo: busca en el Object Explorer de VS Code con AL Language o ejecuta:
```sql
SELECT Name FROM [COMPANY$Object] WHERE Type = 8 AND Name LIKE '%Bill Group%'
```

### 2. Campo "Cust./Vendor Ledger Entry No." en Posted Cartera Doc.
El código asume que este campo apunta al apunte del **libro auxiliar de cliente/proveedor** creado al registrar la remesa. Verifica que en tu versión el campo apunta al apunte de pago/cobro (no a la factura original). Si no existe con ese nombre, puede llamarse:
- `"Ledger Entry No."`
- `"Cust. Ledger Entry No."`

### 3. Enum "Cartera Document Type"
Verifica los valores del enum para `Type` en `Posted Cartera Doc.`:
```al
// Puede ser un Enum o una Option:
"Cartera Document Type"::Receivable  // Cobros
"Cartera Document Type"::Payable     // Pagos

// O directamente como integer si es Option:
DocCarteraRegistrado.Type := 0  // Receivable
DocCarteraRegistrado.Type := 1  // Payable
```

### 4. Remesas con varios asientos bancarios (Descuento, Factoring)
En modalidades de **Gestión de Descuento** o **Factoring**, el registro puede generar más de una transacción bancaria (línea de riesgo + cobro). En ese caso necesitarás iterar sobre múltiples `Transaction No.`:

```al
// Ejemplo para múltiples transacciones:
var
    TransactionNos: List of [Integer];
    TransactionNo: Integer;
begin
    ApunteBanco.SetRange("Bank Account No.", CuentaBancaria);
    ApunteBanco.SetRange("Document No.", NumRemesa);
    ApunteBanco.SetRange(Reversed, false);
    if ApunteBanco.FindSet() then
        repeat
            if not TransactionNos.Contains(ApunteBanco."Transaction No.") then
                TransactionNos.Add(ApunteBanco."Transaction No.");
        until ApunteBanco.Next() = 0;

    foreach TransactionNo in TransactionNos do begin
        AsientoInverso.SetHideDialog(true);
        AsientoInverso.ReverseTransaction(TransactionNo);
    end;
end;
```

### 5. Restricciones del mecanismo estándar de reversión
`Reversal Entry.ReverseTransaction()` **fallará** si:
- Existe algún apunte de cliente/proveedor aún aplicado (por eso se desaplica antes).
- El período contable está cerrado (`Accounting Period`).
- La fecha de registro cae en un período bloqueado.
- El apunte ya fue previamente revertido.

En caso de período cerrado, se puede añadir una fecha alternativa:
```al
AsientoInverso.SetReverseToleranceDate(WorkDate());
```

### 6. Permisos necesarios
El usuario que ejecute el retroceso necesitará permisos de:
- Modificación en `Posted Cartera Doc.`
- Ejecución de `Reversal Entry`
- Modificación en `Cust. Ledger Entry` / `Vendor Ledger Entry`

---

## Flujo de datos (diagrama)

```
ANTES del retroceso:
  Posted Bill Group
    └─ Posted Cartera Doc. (Status: Honored)
         └─ Cust. Ledger Entry (Closed: true, aplicado a factura)
              └─ Bank Account Ledger Entry (Reversed: false)
                   └─ G/L Entry (Reversed: false)

DESPUÉS del retroceso:
  Posted Bill Group  (sin cambios, queda como histórico)
    └─ Posted Cartera Doc. (Status: Rejected)  ← modificado
         └─ Cust. Ledger Entry (Closed: false)  ← desaplicado
              └─ Bank Account Ledger Entry (Reversed: true)  ← invertido
                   └─ G/L Entry (Reversed: true)  ← invertido
                        └─ G/L Entry inverso (nuevos asientos)
```

---

## Notas de auditoría
Los asientos inversos creados por `ReverseTransaction` llevan en el campo `Reversed by Entry No.` la referencia al asiento original, dejando trazabilidad completa del retroceso.

---

## Versión mínima recomendada
- Business Central: **v24** (Runtime 12.0)
- Localización española: **módulo Cartera** instalado
