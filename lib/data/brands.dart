import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Especificação de uma marca conhecida: domínio para buscar o favicon em alta
/// resolução (Google S2 Favicons, gratuito e sem chave de API), cor de fundo
/// opcional para o círculo do logo, cor tema oficial da marca, categoria sugerida
/// e ajuste de escala no círculo ([inset]: margem percentual interna, 0 = sangria
/// total para ícones que já possuem fundo sólido; > 0 para glifos que precisam de
/// respiro para não serem cortados pela máscara circular).
class BrandSpec {
  final String domain;
  final Color bg;
  final String? categoryId;
  final Color? accent;
  final double inset;
  const BrandSpec(
    this.domain, {
    this.bg = const Color(0xFFFFFFFF),
    this.categoryId,
    this.accent,
    this.inset = 0.08,
  });
}

/// Remove acentos e normaliza para minúsculas ("Itaú" == "itau").
String foldText(String input) {
  final lower = input.toLowerCase();
  const from = 'àáâãäåçèéêëìíîïñòóôõöùúûüýÿ';
  const to = 'aaaaaaceeeeiiiinooooouuuuyy';
  final sb = StringBuffer();
  for (var i = 0; i < lower.length; i++) {
    final ch = lower[i];
    final idx = from.indexOf(ch);
    sb.write(idx >= 0 ? to[idx] : ch);
  }
  return sb.toString();
}

const _nintendo = BrandSpec(
  'nintendo.com',
  bg: Color(0xFFE60012),
  categoryId: 'jogos',
);
const _playstation = BrandSpec(
  'playstation.com',
  bg: Color(0xFFFFFFFF),
  categoryId: 'jogos',
  inset: 0.10,
);
const _xbox = BrandSpec(
  'xbox.com',
  bg: Color(0xFF107C10),
  categoryId: 'jogos',
);
const _appleTech = BrandSpec(
  'apple.com',
  categoryId: 'tecnologia',
  accent: Color(0xFFA1A1AA),
  inset: 0.14,
);

/// Marcas conhecidas (BR + globais) e jogos exclusivos por plataforma.
const _brandSpecs = <String, BrandSpec>{
  // Streaming, música & assinaturas
  'netflix': BrandSpec(
    'netflix.com',
    bg: Color(0xFF000000),
    categoryId: 'assinaturas',
    accent: Color(0xFFE50914),
    inset: 0.13,
  ),
  'spotify': BrandSpec(
    'spotify.com',
    bg: Color(0xFF000000),
    categoryId: 'assinaturas',
    accent: Color(0xFF1DB954),
    inset: 0.10,
  ),
  'disney': BrandSpec(
    'disneyplus.com',
    bg: Color(0xFF0B1C3D),
    categoryId: 'assinaturas',
    accent: Color(0xFF1E5BFF),
    inset: 0.06,
  ),
  'disney+': BrandSpec(
    'disneyplus.com',
    bg: Color(0xFF0B1C3D),
    categoryId: 'assinaturas',
    accent: Color(0xFF1E5BFF),
    inset: 0.06,
  ),
  'hbo': BrandSpec(
    'max.com',
    bg: Color(0xFF002BE7),
    categoryId: 'assinaturas',
    accent: Color(0xFF3B66FF),
    inset: 0.06,
  ),
  'max': BrandSpec(
    'max.com',
    bg: Color(0xFF002BE7),
    categoryId: 'assinaturas',
    accent: Color(0xFF3B66FF),
    inset: 0.06,
  ),
  'prime video': BrandSpec(
    'primevideo.com',
    bg: Color(0xFF00050D),
    categoryId: 'assinaturas',
    accent: Color(0xFF00A8E1),
    inset: 0.06,
  ),
  'amazon prime': BrandSpec(
    'primevideo.com',
    bg: Color(0xFF00050D),
    categoryId: 'assinaturas',
    accent: Color(0xFF00A8E1),
    inset: 0.06,
  ),
  'prime': BrandSpec(
    'primevideo.com',
    bg: Color(0xFF00050D),
    categoryId: 'assinaturas',
    accent: Color(0xFF00A8E1),
    inset: 0.06,
  ),
  'youtube': BrandSpec(
    'youtube.com',
    categoryId: 'assinaturas',
    accent: Color(0xFFFF0033),
    inset: 0.14,
  ),
  'youtube premium': BrandSpec(
    'youtube.com',
    categoryId: 'assinaturas',
    accent: Color(0xFFFF0033),
    inset: 0.14,
  ),
  'youtube music': BrandSpec(
    'music.youtube.com',
    categoryId: 'assinaturas',
    accent: Color(0xFFFF0033),
    inset: 0.12,
  ),
  'globoplay': BrandSpec(
    'globoplay.globo.com',
    bg: Color(0xFFFB0234),
    categoryId: 'assinaturas',
    accent: Color(0xFFFB0234),
    inset: 0.0,
  ),
  'deezer': BrandSpec(
    'deezer.com',
    bg: Color(0xFF121212),
    categoryId: 'assinaturas',
    accent: Color(0xFFA238FF),
  ),
  'apple music': BrandSpec(
    'music.apple.com',
    bg: Color(0xFFFA243C),
    categoryId: 'assinaturas',
    accent: Color(0xFFFA243C),
    inset: 0.0,
  ),
  'apple tv': BrandSpec(
    'tv.apple.com',
    bg: Color(0xFF000000),
    categoryId: 'assinaturas',
    accent: Color(0xFF8E8E93),
  ),
  'apple one': BrandSpec(
    'apple.com',
    categoryId: 'assinaturas',
    accent: Color(0xFFA1A1AA),
    inset: 0.14,
  ),
  'applecare': BrandSpec(
    'apple.com',
    categoryId: 'assinaturas',
    accent: Color(0xFFFA243C),
    inset: 0.14,
  ),
  'crunchyroll': BrandSpec(
    'crunchyroll.com',
    bg: Color(0xFFF47521),
    categoryId: 'assinaturas',
    accent: Color(0xFFF47521),
    inset: 0.0,
  ),
  'paramount': BrandSpec(
    'paramountplus.com',
    bg: Color(0xFF0064FF),
    categoryId: 'assinaturas',
    accent: Color(0xFF0064FF),
    inset: 0.0,
  ),
  'star+': BrandSpec(
    'disneyplus.com',
    bg: Color(0xFF0B1C3D),
    categoryId: 'assinaturas',
    accent: Color(0xFFFF4D00),
  ),
  'twitch': BrandSpec(
    'twitch.tv',
    bg: Color(0xFF9146FF),
    categoryId: 'lazer',
    accent: Color(0xFF9146FF),
    inset: 0.12,
  ),
  'audible': BrandSpec(
    'audible.com',
    categoryId: 'assinaturas',
    accent: Color(0xFFFF9900),
  ),
  'kindle': BrandSpec('amazon.com.br', categoryId: 'educacao', inset: 0.12),
  'cinemark': BrandSpec(
    'cinemark.com.br',
    bg: Color(0xFFB5121B),
    categoryId: 'lazer',
    inset: 0.0,
  ),
  'ingresso': BrandSpec('ingresso.com', categoryId: 'lazer'),

  // IA, nuvem, Apple & produtividade
  'icloud': BrandSpec(
    'apple.com',
    categoryId: 'assinaturas',
    accent: Color(0xFF3699FF),
    inset: 0.14,
  ),
  'icloud+': BrandSpec(
    'apple.com',
    categoryId: 'assinaturas',
    accent: Color(0xFF3699FF),
    inset: 0.14,
  ),
  'apple': _appleTech,
  'macbook': _appleTech,
  'macbook air': _appleTech,
  'macbook pro': _appleTech,
  'iphone': _appleTech,
  'ipad': _appleTech,
  'airpods': _appleTech,
  'imac': _appleTech,
  'mac mini': _appleTech,
  'mac studio': _appleTech,
  'apple watch': _appleTech,
  'airtag': _appleTech,
  'app store': BrandSpec(
    'apple.com',
    categoryId: 'assinaturas',
    accent: Color(0xFF0A84FF),
    inset: 0.14,
  ),
  'chatgpt': BrandSpec(
    'openai.com',
    categoryId: 'assinaturas',
    accent: Color(0xFF10A37F),
    inset: 0.14,
  ),
  'openai': BrandSpec(
    'openai.com',
    categoryId: 'assinaturas',
    accent: Color(0xFF10A37F),
    inset: 0.14,
  ),
  'claude': BrandSpec(
    'claude.ai',
    categoryId: 'assinaturas',
    accent: Color(0xFFD97757),
  ),
  'anthropic': BrandSpec(
    'anthropic.com',
    categoryId: 'assinaturas',
    accent: Color(0xFFD97757),
  ),
  'gemini': BrandSpec(
    'gemini.google.com',
    categoryId: 'assinaturas',
    accent: Color(0xFF4285F4),
  ),
  'google one': BrandSpec(
    'one.google.com',
    categoryId: 'assinaturas',
    accent: Color(0xFF4285F4),
  ),
  'google': BrandSpec(
    'google.com',
    categoryId: 'assinaturas',
    accent: Color(0xFF4285F4),
  ),
  'microsoft': BrandSpec(
    'microsoft.com',
    categoryId: 'assinaturas',
    accent: Color(0xFF00A4EF),
  ),
  'office': BrandSpec(
    'microsoft.com',
    categoryId: 'assinaturas',
    accent: Color(0xFFD83B01),
  ),
  'onedrive': BrandSpec(
    'onedrive.live.com',
    categoryId: 'assinaturas',
    accent: Color(0xFF0078D4),
  ),
  'dropbox': BrandSpec(
    'dropbox.com',
    categoryId: 'assinaturas',
    accent: Color(0xFF0061FF),
  ),
  'adobe': BrandSpec(
    'adobe.com',
    categoryId: 'assinaturas',
    accent: Color(0xFFFF0000),
  ),
  'canva': BrandSpec(
    'canva.com',
    categoryId: 'assinaturas',
    accent: Color(0xFF00C4CC),
  ),
  'notion': BrandSpec(
    'notion.so',
    categoryId: 'assinaturas',
    accent: Color(0xFF9CA3AF),
  ),
  'github': BrandSpec(
    'github.com',
    categoryId: 'assinaturas',
    accent: Color(0xFF8B5CF6),
  ),
  'figma': BrandSpec(
    'figma.com',
    categoryId: 'assinaturas',
    accent: Color(0xFFA259FF),
  ),
  'discord': BrandSpec(
    'discord.com',
    categoryId: 'assinaturas',
    accent: Color(0xFF5865F2),
  ),
  'duolingo': BrandSpec(
    'duolingo.com',
    categoryId: 'educacao',
    accent: Color(0xFF58CC02),
  ),
  'linkedin': BrandSpec(
    'linkedin.com',
    categoryId: 'assinaturas',
    accent: Color(0xFF0A66C2),
  ),
  '1password': BrandSpec(
    '1password.com',
    categoryId: 'assinaturas',
    accent: Color(0xFF1A8CFF),
  ),
  'vercel': BrandSpec('vercel.com', categoryId: 'assinaturas'),
  'cloudflare': BrandSpec(
    'cloudflare.com',
    categoryId: 'assinaturas',
    accent: Color(0xFFF38020),
  ),

  // Games — Plataformas & exclusivos Nintendo
  'nintendo': _nintendo,
  'switch': _nintendo,
  'switch 2': _nintendo,
  'eshop': _nintendo,
  'mario': _nintendo,
  'super mario': _nintendo,
  'mario kart': _nintendo,
  'mario party': _nintendo,
  'zelda': _nintendo,
  'legend of zelda': _nintendo,
  'pokemon': _nintendo,
  'metroid': _nintendo,
  'kirby': _nintendo,
  'donkey kong': _nintendo,
  'animal crossing': _nintendo,
  'splatoon': _nintendo,
  'smash bros': _nintendo,
  'fire emblem': _nintendo,
  'xenoblade': _nintendo,
  'pikmin': _nintendo,
  'luigi': _nintendo,
  'yoshi': _nintendo,

  // Games — PlayStation & exclusivos
  'playstation': _playstation,
  'ps4': _playstation,
  'ps5': _playstation,
  'psn': _playstation,
  'ps plus': BrandSpec(
    'playstation.com',
    bg: Color(0xFF003087),
    categoryId: 'assinaturas',
  ),
  'god of war': _playstation,
  'last of us': _playstation,
  'the last of us': _playstation,
  'spider-man': _playstation,
  'spiderman': _playstation,
  'uncharted': _playstation,
  'gran turismo': _playstation,
  'ghost of tsushima': _playstation,
  'bloodborne': _playstation,
  'astro bot': _playstation,
  'ratchet': _playstation,
  'returnal': _playstation,

  // Games — Xbox & exclusivos
  'xbox': _xbox,
  'xbox series': _xbox,
  'game pass': BrandSpec(
    'xbox.com',
    bg: Color(0xFF107C10),
    categoryId: 'assinaturas',
  ),
  'halo': _xbox,
  'forza': _xbox,
  'gears of war': _xbox,
  'starfield': _xbox,
  'sea of thieves': _xbox,

  // Games — Lojas PC & jogos com marca própria
  'steam': BrandSpec(
    'steampowered.com',
    bg: Color(0xFF171A21),
    categoryId: 'jogos',
  ),
  'epic games': BrandSpec(
    'epicgames.com',
    bg: Color(0xFF121212),
    categoryId: 'jogos',
  ),
  'riot': BrandSpec('riotgames.com', categoryId: 'jogos'),
  'valorant': BrandSpec('playvalorant.com', categoryId: 'jogos'),
  'league of legends': BrandSpec('leagueoflegends.com', categoryId: 'jogos'),
  'minecraft': BrandSpec('minecraft.net', categoryId: 'jogos'),
  'fortnite': BrandSpec('fortnite.com', categoryId: 'jogos'),
  'roblox': BrandSpec('roblox.com', categoryId: 'jogos'),
  'genshin': BrandSpec('genshin.hoyoverse.com', categoryId: 'jogos'),
  'ea fc': BrandSpec('ea.com', categoryId: 'jogos'),
  'fifa': BrandSpec('ea.com', categoryId: 'jogos'),

  // Transporte & viagens
  'uber': BrandSpec(
    'uber.com',
    bg: Color(0xFF000000),
    categoryId: 'transporte',
  ),
  '99': BrandSpec('99app.com', categoryId: 'transporte'),
  'indrive': BrandSpec('indrive.com', categoryId: 'transporte'),
  'buser': BrandSpec('buser.com.br', categoryId: 'viagem'),
  'clickbus': BrandSpec('clickbus.com.br', categoryId: 'viagem'),
  'airbnb': BrandSpec('airbnb.com.br', categoryId: 'viagem'),
  'booking': BrandSpec('booking.com', categoryId: 'viagem'),
  'decolar': BrandSpec('decolar.com', categoryId: 'viagem'),
  'azul': BrandSpec('voeazul.com.br', categoryId: 'viagem'),
  'latam': BrandSpec('latamairlines.com', categoryId: 'viagem'),
  'gol': BrandSpec('voegol.com.br', categoryId: 'viagem'),
  'localiza': BrandSpec('localiza.com', categoryId: 'transporte'),
  'sem parar': BrandSpec('semparar.com.br', categoryId: 'transporte'),
  'veloe': BrandSpec('veloe.com.br', categoryId: 'transporte'),
  'shell': BrandSpec('shell.com.br', categoryId: 'transporte'),
  'ipiranga': BrandSpec('ipiranga.com.br', categoryId: 'transporte'),
  'petrobras': BrandSpec('petrobras.com.br', categoryId: 'transporte'),

  // Delivery, restaurantes & alimentação
  'ifood': BrandSpec(
    'ifood.com.br',
    bg: Color(0xFFEA1D2C),
    categoryId: 'alimentacao',
    inset: 0.0,
  ),
  'rappi': BrandSpec(
    'rappi.com.br',
    bg: Color(0xFFFF441F),
    categoryId: 'alimentacao',
    inset: 0.0,
  ),
  'ze delivery': BrandSpec(
    'ze.delivery',
    bg: Color(0xFFFFCC00),
    categoryId: 'alimentacao',
    inset: 0.0,
  ),
  'mcdonalds': BrandSpec(
    'mcdonalds.com.br',
    bg: Color(0xFFDB0007),
    categoryId: 'alimentacao',
    inset: 0.08,
  ),
  'mc donalds': BrandSpec(
    'mcdonalds.com.br',
    bg: Color(0xFFDB0007),
    categoryId: 'alimentacao',
    inset: 0.08,
  ),
  'burger king': BrandSpec('burgerking.com.br', categoryId: 'alimentacao', inset: 0.10),
  'starbucks': BrandSpec('starbucks.com.br', categoryId: 'alimentacao', inset: 0.06),
  'subway': BrandSpec('subway.com', categoryId: 'alimentacao', inset: 0.10),
  'outback': BrandSpec('outback.com.br', categoryId: 'alimentacao', inset: 0.08),
  'dominos': BrandSpec('dominos.com.br', categoryId: 'alimentacao', inset: 0.10),
  'pizza hut': BrandSpec('pizzahut.com.br', categoryId: 'alimentacao', inset: 0.10),
  'bobs': BrandSpec('bobs.com.br', categoryId: 'alimentacao', inset: 0.10),
  'habibs': BrandSpec('habibs.com.br', categoryId: 'alimentacao', inset: 0.10),
  'madero': BrandSpec('restaurantemadero.com.br', categoryId: 'alimentacao'),
  'coco bambu': BrandSpec('cocobambu.com', categoryId: 'alimentacao'),
  'cacau show': BrandSpec('cacaushow.com.br', categoryId: 'alimentacao'),
  'kopenhagen': BrandSpec('kopenhagen.com.br', categoryId: 'alimentacao'),
  'carrefour': BrandSpec('carrefour.com.br', categoryId: 'alimentacao', inset: 0.12),
  'assai': BrandSpec('assai.com.br', categoryId: 'alimentacao', inset: 0.10),
  'atacadao': BrandSpec('atacadao.com.br', categoryId: 'alimentacao', inset: 0.10),
  'pao de acucar': BrandSpec('paodeacucar.com', categoryId: 'alimentacao', inset: 0.10),
  'sams club': BrandSpec('samsclub.com.br', categoryId: 'alimentacao', inset: 0.10),
  'oba': BrandSpec('obahortifruti.com.br', categoryId: 'alimentacao', inset: 0.10),

  // E-commerce, varejo & moda
  'amazon': BrandSpec('amazon.com.br', categoryId: 'compras', inset: 0.12),
  'shopee': BrandSpec(
    'shopee.com.br',
    bg: Color(0xFFEE4D2D),
    categoryId: 'compras',
    inset: 0.0,
  ),
  'mercado livre': BrandSpec(
    'mercadolivre.com.br',
    bg: Color(0xFFFFE600),
    categoryId: 'compras',
    inset: 0.08,
  ),
  'shein': BrandSpec('shein.com', bg: Color(0xFF000000), categoryId: 'moda', inset: 0.08),
  'aliexpress': BrandSpec('aliexpress.com', bg: Color(0xFFE62E04), categoryId: 'compras', inset: 0.06),
  'temu': BrandSpec('temu.com', bg: Color(0xFFFB7701), categoryId: 'compras', inset: 0.0),
  'magalu': BrandSpec('magazineluiza.com.br', bg: Color(0xFF0086FF), categoryId: 'compras', inset: 0.0),
  'magazine luiza': BrandSpec('magazineluiza.com.br', bg: Color(0xFF0086FF), categoryId: 'compras', inset: 0.0),
  'americanas': BrandSpec('americanas.com.br', bg: Color(0xFFE60014), categoryId: 'compras', inset: 0.0),
  'casas bahia': BrandSpec('casasbahia.com.br', categoryId: 'compras', inset: 0.10),
  'kabum': BrandSpec('kabum.com.br', bg: Color(0xFFFF6500), categoryId: 'tecnologia', inset: 0.06),
  'pichau': BrandSpec('pichau.com.br', bg: Color(0xFFE30613), categoryId: 'tecnologia', inset: 0.08),
  'terabyte': BrandSpec('terabyteshop.com.br', categoryId: 'tecnologia', inset: 0.10),
  'fast shop': BrandSpec('fastshop.com.br', categoryId: 'tecnologia', inset: 0.10),
  'leroy merlin': BrandSpec('leroymerlin.com.br', categoryId: 'moradia', inset: 0.10),
  'tok stok': BrandSpec('tokstok.com.br', categoryId: 'moradia', inset: 0.10),
  'renner': BrandSpec('lojasrenner.com.br', bg: Color(0xFFD71920), categoryId: 'moda', inset: 0.06),
  'riachuelo': BrandSpec('riachuelo.com.br', categoryId: 'moda', inset: 0.10),
  'zara': BrandSpec('zara.com', categoryId: 'moda', inset: 0.12),
  'nike': BrandSpec('nike.com.br', categoryId: 'moda', inset: 0.12),
  'adidas': BrandSpec('adidas.com.br', categoryId: 'moda', inset: 0.12),
  'centauro': BrandSpec('centauro.com.br', bg: Color(0xFFE30613), categoryId: 'moda', inset: 0.06),
  'netshoes': BrandSpec('netshoes.com.br', bg: Color(0xFF5A2D82), categoryId: 'moda', inset: 0.06),
  'boticario': BrandSpec('boticario.com.br', categoryId: 'moda', inset: 0.10),
  'o boticario': BrandSpec('boticario.com.br', categoryId: 'moda', inset: 0.10),
  'natura': BrandSpec('natura.com.br', categoryId: 'moda', inset: 0.10),
  'sephora': BrandSpec(
    'sephora.com.br',
    bg: Color(0xFF000000),
    categoryId: 'moda',
    inset: 0.08,
  ),
  'cobasi': BrandSpec('cobasi.com.br', categoryId: 'pets', inset: 0.12),
  'petz': BrandSpec('petz.com.br', categoryId: 'pets', inset: 0.14),
  'petlove': BrandSpec('petlove.com.br', categoryId: 'pets', inset: 0.12),

  // Bancos & finanças
  'nubank': BrandSpec('nubank.com.br', bg: Color(0xFF820AD1), categoryId: 'contas', inset: 0.0),
  'inter': BrandSpec('bancointer.com.br', bg: Color(0xFFFF7A00), categoryId: 'contas', inset: 0.0),
  'itau': BrandSpec('itau.com.br', bg: Color(0xFFEC7000), categoryId: 'contas', inset: 0.0),
  'bradesco': BrandSpec('bradesco.com.br', bg: Color(0xFFCC092F), categoryId: 'contas', inset: 0.0),
  'santander': BrandSpec('santander.com.br', bg: Color(0xFFEC0000), categoryId: 'contas', inset: 0.0),
  'banco do brasil': BrandSpec('bb.com.br', bg: Color(0xFFF8D117), categoryId: 'contas', inset: 0.06),
  'caixa': BrandSpec('caixa.gov.br', bg: Color(0xFF005CA9), categoryId: 'contas', inset: 0.06),
  'c6': BrandSpec('c6bank.com.br', bg: Color(0xFF121212), categoryId: 'contas', inset: 0.06),
  'c6 bank': BrandSpec('c6bank.com.br', bg: Color(0xFF121212), categoryId: 'contas', inset: 0.06),
  'btg': BrandSpec('btgpactual.com', bg: Color(0xFF001E62), categoryId: 'contas', inset: 0.06),
  'picpay': BrandSpec('picpay.com', bg: Color(0xFF11C76F), categoryId: 'contas', inset: 0.0),
  'mercado pago': BrandSpec('mercadopago.com.br', bg: Color(0xFF009EE3), categoryId: 'contas', inset: 0.06),
  'pagbank': BrandSpec('pagbank.com.br', bg: Color(0xFF00A859), categoryId: 'contas', inset: 0.06),
  'sicredi': BrandSpec('sicredi.com.br', categoryId: 'contas', inset: 0.12),
  'sicoob': BrandSpec('sicoob.com.br', categoryId: 'contas', inset: 0.12),
  'wise': BrandSpec('wise.com', bg: Color(0xFF9FE870), categoryId: 'contas', inset: 0.06),
  'nomad': BrandSpec('nomadglobal.com', bg: Color(0xFFFFD100), categoryId: 'contas', inset: 0.06),

  // Telecom, operadoras de internet, contas & saúde (operadoras com fundo branco)
  'vivo': BrandSpec(
    'vivo.com.br',
    bg: Color(0xFFFFFFFF),
    accent: Color(0xFF660099),
    categoryId: 'contas',
    inset: 0.14,
  ),
  'vivo fibra': BrandSpec(
    'vivo.com.br',
    bg: Color(0xFFFFFFFF),
    accent: Color(0xFF660099),
    categoryId: 'contas',
    inset: 0.14,
  ),
  'claro': BrandSpec(
    'claro.com.br',
    bg: Color(0xFFFFFFFF),
    accent: Color(0xFFDA291C),
    categoryId: 'contas',
    inset: 0.12,
  ),
  'claro net': BrandSpec(
    'claro.com.br',
    bg: Color(0xFFFFFFFF),
    accent: Color(0xFFDA291C),
    categoryId: 'contas',
    inset: 0.12,
  ),
  'tim': BrandSpec(
    'tim.com.br',
    bg: Color(0xFFFFFFFF),
    accent: Color(0xFF004691),
    categoryId: 'contas',
    inset: 0.12,
  ),
  'tim live': BrandSpec(
    'tim.com.br',
    bg: Color(0xFFFFFFFF),
    accent: Color(0xFF004691),
    categoryId: 'contas',
    inset: 0.12,
  ),
  'oi': BrandSpec(
    'oi.com.br',
    bg: Color(0xFFFFFFFF),
    accent: Color(0xFF00A859),
    categoryId: 'contas',
    inset: 0.12,
  ),
  'oi fibra': BrandSpec(
    'oi.com.br',
    bg: Color(0xFFFFFFFF),
    accent: Color(0xFF00A859),
    categoryId: 'contas',
    inset: 0.12,
  ),
  'sky': BrandSpec(
    'sky.com.br',
    bg: Color(0xFFFFFFFF),
    accent: Color(0xFFE30613),
    categoryId: 'contas',
    inset: 0.12,
  ),
  'algar': BrandSpec(
    'algar.com.br',
    bg: Color(0xFFFFFFFF),
    accent: Color(0xFF008542),
    categoryId: 'contas',
    inset: 0.12,
  ),
  'brisanet': BrandSpec(
    'brisanet.com.br',
    bg: Color(0xFFFFFFFF),
    accent: Color(0xFFFF6600),
    categoryId: 'contas',
    inset: 0.12,
  ),
  'desktop': BrandSpec(
    'desktop.com.br',
    bg: Color(0xFFFFFFFF),
    accent: Color(0xFFE30613),
    categoryId: 'contas',
    inset: 0.12,
  ),
  'unifique': BrandSpec(
    'unifique.com.br',
    bg: Color(0xFFFFFFFF),
    accent: Color(0xFF005CA9),
    categoryId: 'contas',
    inset: 0.12,
  ),
  'starlink': BrandSpec(
    'starlink.com',
    bg: Color(0xFFFFFFFF),
    accent: Color(0xFF1C1C1E),
    categoryId: 'contas',
    inset: 0.12,
  ),
  'enel': BrandSpec('enel.com', categoryId: 'contas', inset: 0.14),
  'sabesp': BrandSpec('sabesp.com.br', categoryId: 'contas', inset: 0.12),
  'copel': BrandSpec('copel.com', categoryId: 'contas', inset: 0.12),
  'cemig': BrandSpec('cemig.com.br', categoryId: 'contas', inset: 0.12),
  'comgas': BrandSpec('comgas.com.br', categoryId: 'contas', inset: 0.12),
  'smartfit': BrandSpec('smartfit.com.br', categoryId: 'saude', bg: Color(0xFFFFB800), inset: 0.10),
  'smart fit': BrandSpec('smartfit.com.br', categoryId: 'saude', bg: Color(0xFFFFB800), inset: 0.10),
  'bluefit': BrandSpec('bluefit.com.br', categoryId: 'saude'),
  'wellhub': BrandSpec('wellhub.com', categoryId: 'saude'),
  'gympass': BrandSpec('wellhub.com', categoryId: 'saude'),
  'totalpass': BrandSpec('totalpass.com', categoryId: 'saude'),
  'drogasil': BrandSpec('drogasil.com.br', categoryId: 'saude'),
  'droga raia': BrandSpec('drogaraia.com.br', categoryId: 'saude'),
  'drogaria sao paulo': BrandSpec(
    'drogariasaopaulo.com.br',
    categoryId: 'saude',
  ),
  'pague menos': BrandSpec('paguemenos.com.br', categoryId: 'saude'),
  'panvel': BrandSpec('panvel.com', categoryId: 'saude'),
  'unimed': BrandSpec('unimed.coop.br', categoryId: 'saude'),
  'amil': BrandSpec('amil.com.br', categoryId: 'saude'),
  'sulamerica': BrandSpec('sulamerica.com.br', categoryId: 'saude'),
};

/// Palavras-chave do dia a dia e jogos multiplataforma → (ícone Lucide, categoria).
const _smartEntries = <String, (IconData, String?)>{
  // Jogos multiplataforma (sempre ícone de controle + categoria Jogos)
  'gta': (LucideIcons.gamepad2, 'jogos'),
  'grand theft auto': (LucideIcons.gamepad2, 'jogos'),
  'red dead': (LucideIcons.gamepad2, 'jogos'),
  'elden ring': (LucideIcons.gamepad2, 'jogos'),
  'dark souls': (LucideIcons.gamepad2, 'jogos'),
  'cyberpunk': (LucideIcons.gamepad2, 'jogos'),
  'witcher': (LucideIcons.gamepad2, 'jogos'),
  'hollow knight': (LucideIcons.gamepad2, 'jogos'),
  'silksong': (LucideIcons.gamepad2, 'jogos'),
  'stardew valley': (LucideIcons.gamepad2, 'jogos'),
  'hades': (LucideIcons.gamepad2, 'jogos'),
  'baldur': (LucideIcons.gamepad2, 'jogos'),
  'resident evil': (LucideIcons.gamepad2, 'jogos'),
  'final fantasy': (LucideIcons.gamepad2, 'jogos'),
  'call of duty': (LucideIcons.gamepad2, 'jogos'),
  'battlefield': (LucideIcons.gamepad2, 'jogos'),
  'assassins creed': (LucideIcons.gamepad2, 'jogos'),
  'mortal kombat': (LucideIcons.gamepad2, 'jogos'),
  'street fighter': (LucideIcons.gamepad2, 'jogos'),
  'tekken': (LucideIcons.gamepad2, 'jogos'),
  'persona': (LucideIcons.gamepad2, 'jogos'),
  'metaphor': (LucideIcons.gamepad2, 'jogos'),
  'monster hunter': (LucideIcons.gamepad2, 'jogos'),
  'diablo': (LucideIcons.gamepad2, 'jogos'),
  'overwatch': (LucideIcons.gamepad2, 'jogos'),
  'counter-strike': (LucideIcons.gamepad2, 'jogos'),
  'cs2': (LucideIcons.gamepad2, 'jogos'),
  'dota': (LucideIcons.gamepad2, 'jogos'),
  'terraria': (LucideIcons.gamepad2, 'jogos'),
  'celeste': (LucideIcons.gamepad2, 'jogos'),
  'cuphead': (LucideIcons.gamepad2, 'jogos'),
  'balatro': (LucideIcons.gamepad2, 'jogos'),
  'palworld': (LucideIcons.gamepad2, 'jogos'),
  'tomb raider': (LucideIcons.gamepad2, 'jogos'),
  'fallout': (LucideIcons.gamepad2, 'jogos'),
  'skyrim': (LucideIcons.gamepad2, 'jogos'),
  'doom': (LucideIcons.gamepad2, 'jogos'),
  'sonic': (LucideIcons.gamepad2, 'jogos'),
  'crash bandicoot': (LucideIcons.gamepad2, 'jogos'),
  'it takes two': (LucideIcons.gamepad2, 'jogos'),
  'split fiction': (LucideIcons.gamepad2, 'jogos'),
  'rocket league': (LucideIcons.gamepad2, 'jogos'),
  'apex legends': (LucideIcons.gamepad2, 'jogos'),
  'jogo': (LucideIcons.gamepad2, 'jogos'),
  'jogos': (LucideIcons.gamepad2, 'jogos'),
  'game': (LucideIcons.gamepad2, 'jogos'),
  'games': (LucideIcons.gamepad2, 'jogos'),
  'controle': (LucideIcons.gamepad2, 'jogos'),
  'console': (LucideIcons.gamepad2, 'jogos'),

  // Alimentação
  'pizza': (LucideIcons.pizza, 'alimentacao'),
  'pizzaria': (LucideIcons.pizza, 'alimentacao'),
  'cafe': (LucideIcons.coffee, 'alimentacao'),
  'cafeteria': (LucideIcons.coffee, 'alimentacao'),
  'padaria': (LucideIcons.croissant, 'alimentacao'),
  'pao': (LucideIcons.croissant, 'alimentacao'),
  'bolo': (LucideIcons.cake, 'alimentacao'),
  'doce': (LucideIcons.candy, 'alimentacao'),
  'sorvete': (LucideIcons.iceCreamCone, 'alimentacao'),
  'acai': (LucideIcons.iceCreamBowl, 'alimentacao'),
  'cerveja': (LucideIcons.beer, 'lazer'),
  'chopp': (LucideIcons.beer, 'lazer'),
  'bar': (LucideIcons.wine, 'lazer'),
  'vinho': (LucideIcons.wine, 'alimentacao'),
  'drink': (LucideIcons.martini, 'lazer'),
  'hamburguer': (LucideIcons.beef, 'alimentacao'),
  'burger': (LucideIcons.beef, 'alimentacao'),
  'churrasco': (LucideIcons.flame, 'alimentacao'),
  'mercado': (LucideIcons.shoppingCart, 'alimentacao'),
  'supermercado': (LucideIcons.shoppingCart, 'alimentacao'),
  'feira': (LucideIcons.apple, 'alimentacao'),
  'hortifruti': (LucideIcons.apple, 'alimentacao'),
  'lanche': (LucideIcons.sandwich, 'alimentacao'),

  // Transporte
  'gasolina': (LucideIcons.fuel, 'transporte'),
  'combustivel': (LucideIcons.fuel, 'transporte'),
  'etanol': (LucideIcons.fuel, 'transporte'),
  'posto': (LucideIcons.fuel, 'transporte'),
  'estacionamento': (LucideIcons.circleParking, 'transporte'),
  'onibus': (LucideIcons.bus, 'transporte'),
  'metro': (LucideIcons.trainFront, 'transporte'),
  'trem': (LucideIcons.trainFront, 'transporte'),
  'passagem': (LucideIcons.plane, 'viagem'),
  'voo': (LucideIcons.plane, 'viagem'),
  'viagem': (LucideIcons.luggage, 'viagem'),
  'hotel': (LucideIcons.bedDouble, 'viagem'),
  'mecanico': (LucideIcons.wrench, 'transporte'),
  'oficina': (LucideIcons.wrench, 'transporte'),
  'bicicleta': (LucideIcons.bike, 'transporte'),

  // Casa & contas
  'aluguel': (LucideIcons.keyRound, 'moradia'),
  'condominio': (LucideIcons.building2, 'moradia'),
  'luz': (LucideIcons.zap, 'contas'),
  'energia': (LucideIcons.zap, 'contas'),
  'agua': (LucideIcons.droplets, 'contas'),
  'gas': (LucideIcons.flame, 'contas'),
  'internet': (LucideIcons.wifi, 'contas'),
  'wifi': (LucideIcons.wifi, 'contas'),
  'celular': (LucideIcons.smartphone, 'tecnologia'),
  'telefone': (LucideIcons.smartphone, 'contas'),
  'recarga': (LucideIcons.smartphone, 'contas'),
  'limpeza': (LucideIcons.sparkles, 'moradia'),
  'faxina': (LucideIcons.sparkles, 'moradia'),
  'moveis': (LucideIcons.armchair, 'moradia'),
  'mesa': (LucideIcons.armchair, 'moradia'),
  'cadeira': (LucideIcons.armchair, 'moradia'),

  // Tecnologia & compras
  'notebook': (LucideIcons.laptop, 'tecnologia'),
  'computador': (LucideIcons.monitor, 'tecnologia'),
  'pc': (LucideIcons.monitor, 'tecnologia'),
  'teclado': (LucideIcons.keyboard, 'tecnologia'),
  'mouse': (LucideIcons.mouse, 'tecnologia'),
  'fone': (LucideIcons.headphones, 'tecnologia'),
  'camera': (LucideIcons.camera, 'tecnologia'),
  'relogio': (LucideIcons.watch, 'moda'),
  'roupa': (LucideIcons.shirt, 'moda'),
  'camisa': (LucideIcons.shirt, 'moda'),
  'camiseta': (LucideIcons.shirt, 'moda'),
  'tenis': (LucideIcons.footprints, 'moda'),
  'sapato': (LucideIcons.footprints, 'moda'),
  'perfume': (LucideIcons.sparkles, 'moda'),
  'presente': (LucideIcons.gift, 'compras'),
  'flor': (LucideIcons.flower2, 'compras'),
  'flores': (LucideIcons.flower2, 'compras'),

  // Saúde, beleza & pets
  'academia': (LucideIcons.dumbbell, 'saude'),
  'treino': (LucideIcons.dumbbell, 'saude'),
  'personal': (LucideIcons.dumbbell, 'saude'),
  'farmacia': (LucideIcons.pill, 'saude'),
  'remedio': (LucideIcons.pill, 'saude'),
  'medico': (LucideIcons.stethoscope, 'saude'),
  'consulta': (LucideIcons.stethoscope, 'saude'),
  'exame': (LucideIcons.stethoscope, 'saude'),
  'dentista': (LucideIcons.smile, 'saude'),
  'terapia': (LucideIcons.brain, 'saude'),
  'psicologo': (LucideIcons.brain, 'saude'),
  'cabelo': (LucideIcons.scissors, 'moda'),
  'barbearia': (LucideIcons.scissors, 'moda'),
  'salao': (LucideIcons.scissors, 'moda'),
  'manicure': (LucideIcons.sparkles, 'moda'),
  'pet': (LucideIcons.pawPrint, 'pets'),
  'racao': (LucideIcons.pawPrint, 'pets'),
  'veterinario': (LucideIcons.pawPrint, 'pets'),
  'cachorro': (LucideIcons.dog, 'pets'),
  'gato': (LucideIcons.cat, 'pets'),

  // Educação & lazer
  'livro': (LucideIcons.bookOpen, 'educacao'),
  'curso': (LucideIcons.graduationCap, 'educacao'),
  'faculdade': (LucideIcons.graduationCap, 'educacao'),
  'escola': (LucideIcons.graduationCap, 'educacao'),
  'cinema': (LucideIcons.clapperboard, 'lazer'),
  'filme': (LucideIcons.clapperboard, 'lazer'),
  'show': (LucideIcons.music, 'lazer'),
  'musica': (LucideIcons.music, 'lazer'),
  'festa': (LucideIcons.partyPopper, 'lazer'),
  'doacao': (LucideIcons.heartHandshake, 'outros'),
};

T? _matchWord<T>(String name, Map<String, T> table) {
  final n = foldText(name);
  T? best;
  var bestLen = 0;
  for (final e in table.entries) {
    if (e.key.length <= bestLen) continue;
    if (RegExp(
      '(^|[^a-z0-9])${RegExp.escape(e.key)}(\$|[^a-z0-9])',
    ).hasMatch(n)) {
      best = e.value;
      bestLen = e.key.length;
    }
  }
  return best;
}

/// Especificação da marca citada em [name], ou null.
BrandSpec? brandSpecFor(String name) => _matchWord(name, _brandSpecs);

/// Domínio da marca citada em [name], ou null.
String? brandDomainFor(String name) => brandSpecFor(name)?.domain;

/// Ícone inteligente do Lucide sugerido automaticamente pelo nome do gasto.
IconData? smartIconFor(String name) => _matchWord(name, _smartEntries)?.$1;

/// Categoria sugerida a partir de marca conhecida ou palavra-chave/jogo.
String? smartCategoryIdFor(String name) =>
    brandSpecFor(name)?.categoryId ?? _matchWord(name, _smartEntries)?.$2;

/// Cor tema oficial da marca citada em [name], ou null.
Color? brandAccentColorFor(String name) => brandSpecFor(name)?.accent;

/// Logo em alta resolução do domínio (Google Favicon V2 em 256px, gratuito e
/// mais nítido para domínios como Spotify, Enel e bancos).
String brandLogoUrl(String domain) =>
    'https://t2.gstatic.com/faviconV2?client=SOCIAL&type=FAVICON&fallback_opts=TYPE,SIZE,URL&url=https://$domain&size=256';

/// URLs oficiais de gerenciamento para as principais assinaturas recorrentes.
const _manageSubscriptionUrls = <String, String>{
  'netflix': 'https://www.netflix.com/youraccount',
  'spotify': 'https://www.spotify.com/account/overview/',
  'youtube': 'https://www.youtube.com/paid_memberships',
  'youtube music': 'https://www.youtube.com/paid_memberships',
  'chatgpt': 'https://chatgpt.com/#settings/Subscription',
  'openai': 'https://chatgpt.com/#settings/Subscription',
  'claude': 'https://claude.ai/settings/billing',
  'anthropic': 'https://claude.ai/settings/billing',
  'gemini': 'https://one.google.com/settings',
  'google one': 'https://one.google.com/settings',
  'amazon prime': 'https://www.amazon.com.br/mc/pipelines/manage',
  'prime video': 'https://www.amazon.com.br/mc/pipelines/manage',
  'prime': 'https://www.amazon.com.br/mc/pipelines/manage',
  'disney': 'https://www.disneyplus.com/account',
  'disney+': 'https://www.disneyplus.com/account',
  'star+': 'https://www.disneyplus.com/account',
  'hbo': 'https://play.max.com/settings/subscription',
  'max': 'https://play.max.com/settings/subscription',
  'globoplay': 'https://minhaconta.globo.com',
  'icloud': 'https://account.apple.com/account/manage',
  'icloud+': 'https://account.apple.com/account/manage',
  'apple one': 'https://account.apple.com/account/manage',
  'apple music': 'https://account.apple.com/account/manage',
  'apple tv': 'https://account.apple.com/account/manage',
  'crunchyroll': 'https://www.crunchyroll.com/account/membership',
  'paramount': 'https://www.paramountplus.com/account/',
  'deezer': 'https://www.deezer.com/account/subscription',
  'adobe': 'https://account.adobe.com/plans',
  'microsoft': 'https://account.microsoft.com/services',
  'office': 'https://account.microsoft.com/services',
  'xbox': 'https://account.microsoft.com/services',
  'game pass': 'https://account.microsoft.com/services',
  'playstation': 'https://www.playstation.com/acct/management',
  'ps plus': 'https://www.playstation.com/acct/management',
  'nintendo': 'https://accounts.nintendo.com',
  'canva': 'https://www.canva.com/settings/billing-and-teams',
  'figma': 'https://www.figma.com/settings',
  'notion': 'https://www.notion.so/my-account',
  'github': 'https://github.com/settings/billing',
  'discord': 'https://discord.com/app',
  'meli+': 'https://www.mercadolivre.com.br/assinaturas',
  'mercado livre': 'https://www.mercadolivre.com.br/assinaturas',
  'uber one': 'https://riders.uber.com',
  'ifood': 'https://www.ifood.com.br',
};

/// Link oficial de gerenciamento da assinatura para marcas principais, ou null.
String? subscriptionManageUrlFor(String name) =>
    _matchWord(name, _manageSubscriptionUrls);
