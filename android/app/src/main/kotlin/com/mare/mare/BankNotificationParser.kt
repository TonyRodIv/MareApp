package com.mare.mare

import java.text.Normalizer
import java.util.Locale

data class ParsedBankExpense(
    val name: String,
    val cents: Int,
    val bankName: String,
    val packageName: String,
)

object BankNotificationParser {
    private val bankPackages = mapOf(
        "com.nu.production" to "Nubank",
        "com.itau" to "Itaú",
        "com.itau.pers" to "Itaú",
        "com.itau.emp" to "Itaú",
        "br.com.itau.uniclass" to "Itaú",
        "com.itau.personnalite" to "Itaú",
        "br.com.intermedium" to "Inter",
        "com.bradesco" to "Bradesco",
        "com.bradesco.prime" to "Bradesco",
        "com.santander.app" to "Santander",
        "com.santander.way" to "Santander",
        "br.com.bb.android" to "Banco do Brasil",
        "br.com.gabba.Caixa" to "Caixa",
        "br.gov.caixa.tem" to "Caixa",
        "com.c6bank.app" to "C6 Bank",
        "com.picpay" to "PicPay",
        "com.mercadopago.wallet" to "Mercado Pago",
        "br.com.uol.ps.myaccount" to "PagBank",
        "com.btg.pactual.digital" to "BTG",
        "br.com.xp.carteira" to "XP",
        "br.com.neon" to "Neon",
        "br.com.bradesco.next" to "Next",
        "br.com.willbank" to "Will Bank",
        "br.com.sicredi.app" to "Sicredi",
        "br.com.sicoob.sisbr" to "Sicoob",
        "com.recargapay" to "RecargaPay",
    )

    private val blockedKeywords = listOf(
        "pix recebido",
        "voce recebeu",
        "recebeu um pix",
        "recebeu uma transferencia",
        "transferencia recebida",
        "deposito recebido",
        "compra negada",
        "compra recusada",
        "transacao negada",
        "nao aprovada",
        "fatura fechada",
        "fatura disponivel",
        "pagamento da fatura",
        "fatura paga",
        "estorno",
        "reembolso",
        "cashback",
        "rendeu",
        "codigo de verificacao",
        "token",
        "limite disponivel",
        "aumento de limite",
    )

    private val allowedKeywords = listOf(
        "compra aprovada",
        "compra no credito",
        "compra no debito",
        "compra realizada",
        "compra de r",
        "voce gastou",
        "pix enviado",
        "transferencia enviada",
        "transferencia realizada",
        "voce transferiu",
        "pagamento efetuado",
        "pagamento aprovado",
        "pagamento realizado",
        "pagou",
        "debito automatico",
        "cobrado",
        "assinatura",
    )

    private val amountRegex = Regex("""R\$\s*([\d.]+,\d{2}|\d+(?:[.,]\d{2})?)""")
    private val merchantRegex = Regex(
        """(?i)(?:\bem|\bno|\bna|\bpara)\s+([A-Za-z0-9À-ÿ][A-Za-z0-9À-ÿ\s&*._-]{1,36}?)(?:\s+(?:no|na|com|em|via|as|às|por|valor|cartao|cartão|credito|crédito|debito|débito|\d{2}/\d{2})|[.,;!?\n]|$)"""
    )

    fun isSupportedBank(packageName: String): Boolean = bankPackages.containsKey(packageName)

    fun bankNameFor(packageName: String): String? = bankPackages[packageName]

    fun parse(packageName: String, title: String, text: String): ParsedBankExpense? {
        val bankName = bankPackages[packageName] ?: return null
        val fullRaw = "$title\n$text".trim()
        if (fullRaw.isEmpty()) return null
        val folded = fold(fullRaw)

        if (blockedKeywords.any { folded.contains(it) }) return null
        if (!allowedKeywords.any { folded.contains(it) }) return null

        val cents = extractCents(fullRaw) ?: return null
        if (cents <= 0 || cents > 100_000_000) return null

        val merchant = extractMerchant(fullRaw, bankName)
        return ParsedBankExpense(
            name = merchant,
            cents = cents,
            bankName = bankName,
            packageName = packageName,
        )
    }

    private fun extractCents(raw: String): Int? {
        val m = amountRegex.find(raw) ?: return null
        var num = m.groupValues[1].trim()
        num = if (num.contains(',') && num.contains('.')) {
            num.replace(".", "").replace(',', '.')
        } else if (num.contains(',')) {
            num.replace(',', '.')
        } else {
            num
        }
        val d = num.toDoubleOrNull() ?: return null
        return kotlin.math.round(d * 100.0).toInt()
    }

    private fun extractMerchant(raw: String, fallbackBank: String): String {
        val m = merchantRegex.find(raw)
        val candidate = m?.groupValues?.getOrNull(1)?.trim()
            ?.replace(Regex("""\s+"""), " ")
            ?.trimEnd('-', '*', '.', ' ')
        if (!candidate.isNullOrBlank() && candidate.length >= 2) {
            return candidate.take(36)
        }
        return "Gasto $fallbackBank"
    }

    private fun fold(input: String): String {
        val norm = Normalizer.normalize(input, Normalizer.Form.NFD)
        return norm.replace(Regex("""\p{Mn}+"""), "").lowercase(Locale.ROOT)
    }
}
