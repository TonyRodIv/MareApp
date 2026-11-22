/// Marcas conhecidas: nome digitado no gasto → domínio, usado para buscar o logo
/// no serviço de favicons do Google (sem chave de API). Marcas que não estão
/// aqui continuam com o ícone da categoria.
const _brandDomains = <String, String>{
  'netflix': 'netflix.com',
  'spotify': 'spotify.com',
  'disney': 'disneyplus.com',
  'hbo': 'max.com',
  'max': 'max.com',
  'prime video': 'primevideo.com',
  'prime': 'primevideo.com',
  'youtube': 'youtube.com',
  'icloud': 'apple.com',
  'apple': 'apple.com',
  'chatgpt': 'openai.com',
  'openai': 'openai.com',
  'claude': 'claude.ai',
  'globoplay': 'globoplay.globo.com',
  'deezer': 'deezer.com',
  'uber': 'uber.com',
  '99': '99app.com',
  'ifood': 'ifood.com.br',
  'rappi': 'rappi.com.br',
  'amazon': 'amazon.com.br',
  'shopee': 'shopee.com.br',
  'mercado livre': 'mercadolivre.com.br',
  'shein': 'shein.com',
  'nubank': 'nubank.com.br',
  'inter': 'bancointer.com.br',
  'itaú': 'itau.com.br',
  'itau': 'itau.com.br',
  'bradesco': 'bradesco.com.br',
  'santander': 'santander.com.br',
  'steam': 'steampowered.com',
  'playstation': 'playstation.com',
  'xbox': 'xbox.com',
  'nintendo': 'nintendo.com',
  'switch': 'nintendo.com',
  'mario': 'nintendo.com',
  'vivo': 'vivo.com.br',
  'claro': 'claro.com.br',
  'tim': 'tim.com.br',
  'smartfit': 'smartfit.com.br',
  'drogasil': 'drogasil.com.br',
  'carrefour': 'carrefour.com.br',
  'magalu': 'magazineluiza.com.br',
  'americanas': 'americanas.com.br',
  'google': 'google.com',
  'microsoft': 'microsoft.com',
  'adobe': 'adobe.com',
  'canva': 'canva.com',
  'notion': 'notion.so',
  'github': 'github.com',
  'figma': 'figma.com',
};

/// Domínio da marca citada em [name], ou null. Casa por palavra inteira, então
/// "Uber pra casa" acha uber.com, mas "super" não acha nada.
String? brandDomainFor(String name) {
  final n = name.toLowerCase();
  String? best;
  var bestLen = 0;
  for (final e in _brandDomains.entries) {
    if (e.key.length <= bestLen) continue;
    if (RegExp(
      '(^|[^a-zà-ú0-9])${RegExp.escape(e.key)}(\$|[^a-zà-ú0-9])',
    ).hasMatch(n)) {
      best = e.value;
      bestLen = e.key.length;
    }
  }
  return best;
}

/// Logo 128px do domínio (favicon em alta resolução).
String brandLogoUrl(String domain) =>
    'https://www.google.com/s2/favicons?domain=$domain&sz=128';
