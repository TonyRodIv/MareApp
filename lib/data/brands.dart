import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Especificação de uma marca conhecida: domínio para buscar o favicon em alta
/// resolução (Google S2 Favicons, gratuito e sem chave de API) e cor de fundo
/// opcional para o círculo do logo.
class BrandSpec {
  final String domain;
  final Color bg;
  final double paddingRatio;
  const BrandSpec(
    this.domain, {
    this.bg = const Color(0xFFFFFFFF),
    this.paddingRatio = 0.16,
  });
}

/// Remove acentos e normaliza espaços para o casamento funcionar com ou sem
/// acentuação ("Itaú" == "itau", "Pão de Açúcar" == "pao de acucar").
String _fold(String input) {
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

/// Marcas conhecidas (BR + globais): palavra-chave normalizada → [BrandSpec].
const _brandSpecs = <String, BrandSpec>{
  // Streaming, música & entretenimento
  'netflix': BrandSpec('netflix.com', bg: Color(0xFF000000)),
  'spotify': BrandSpec('spotify.com', bg: Color(0xFF121212)),
  'disney': BrandSpec('disneyplus.com', bg: Color(0xFF0B1C3D)),
  'disney+': BrandSpec('disneyplus.com', bg: Color(0xFF0B1C3D)),
  'hbo': BrandSpec('max.com', bg: Color(0xFF002BE7)),
  'max': BrandSpec('max.com', bg: Color(0xFF002BE7)),
  'prime video': BrandSpec('primevideo.com', bg: Color(0xFF00A8E1)),
  'amazon prime': BrandSpec('primevideo.com', bg: Color(0xFF00A8E1)),
  'prime': BrandSpec('primevideo.com', bg: Color(0xFF00A8E1)),
  'youtube': BrandSpec('youtube.com'),
  'youtube music': BrandSpec('music.youtube.com'),
  'globoplay': BrandSpec('globoplay.globo.com'),
  'deezer': BrandSpec('deezer.com', bg: Color(0xFF121212)),
  'apple music': BrandSpec('music.apple.com'),
  'apple tv': BrandSpec('tv.apple.com', bg: Color(0xFF000000)),
  'crunchyroll': BrandSpec('crunchyroll.com'),
  'paramount': BrandSpec('paramountplus.com'),
  'star+': BrandSpec('disneyplus.com', bg: Color(0xFF0B1C3D)),
  'twitch': BrandSpec('twitch.tv'),
  'audible': BrandSpec('audible.com'),
  'kindle': BrandSpec('amazon.com.br'),
  'cinemark': BrandSpec('cinemark.com.br'),
  'ingresso': BrandSpec('ingresso.com'),

  // IA, nuvem & produtividade
  'icloud': BrandSpec('apple.com'),
  'apple': BrandSpec('apple.com'),
  'chatgpt': BrandSpec('openai.com'),
  'openai': BrandSpec('openai.com'),
  'claude': BrandSpec('claude.ai'),
  'anthropic': BrandSpec('anthropic.com'),
  'gemini': BrandSpec('gemini.google.com'),
  'google one': BrandSpec('one.google.com'),
  'google': BrandSpec('google.com'),
  'microsoft': BrandSpec('microsoft.com'),
  'office': BrandSpec('microsoft.com'),
  'onedrive': BrandSpec('onedrive.live.com'),
  'dropbox': BrandSpec('dropbox.com'),
  'adobe': BrandSpec('adobe.com'),
  'canva': BrandSpec('canva.com'),
  'notion': BrandSpec('notion.so'),
  'github': BrandSpec('github.com'),
  'figma': BrandSpec('figma.com'),
  'discord': BrandSpec('discord.com'),
  'duolingo': BrandSpec('duolingo.com'),
  'linkedin': BrandSpec('linkedin.com'),
  '1password': BrandSpec('1password.com'),
  'vercel': BrandSpec('vercel.com'),
  'cloudflare': BrandSpec('cloudflare.com'),

  // Games
  'steam': BrandSpec('steampowered.com', bg: Color(0xFF171A21)),
  'playstation': BrandSpec('playstation.com', bg: Color(0xFF003087)),
  'psn': BrandSpec('playstation.com', bg: Color(0xFF003087)),
  'ps plus': BrandSpec('playstation.com', bg: Color(0xFF003087)),
  'xbox': BrandSpec('xbox.com', bg: Color(0xFF107C10)),
  'game pass': BrandSpec('xbox.com', bg: Color(0xFF107C10)),
  'nintendo': BrandSpec('nintendo.com', bg: Color(0xFFE60012)),
  'switch': BrandSpec('nintendo.com', bg: Color(0xFFE60012)),
  'mario': BrandSpec('nintendo.com', bg: Color(0xFFE60012)),
  'zelda': BrandSpec('nintendo.com', bg: Color(0xFFE60012)),
  'pokemon': BrandSpec('pokemon.com'),
  'epic games': BrandSpec('epicgames.com', bg: Color(0xFF121212)),
  'riot': BrandSpec('riotgames.com'),
  'valorant': BrandSpec('playvalorant.com'),
  'roblox': BrandSpec('roblox.com'),

  // Transporte & viagens
  'uber': BrandSpec('uber.com', bg: Color(0xFF000000)),
  '99': BrandSpec('99app.com'),
  'indrive': BrandSpec('indrive.com'),
  'buser': BrandSpec('buser.com.br'),
  'clickbus': BrandSpec('clickbus.com.br'),
  'airbnb': BrandSpec('airbnb.com.br'),
  'booking': BrandSpec('booking.com'),
  'decolar': BrandSpec('decolar.com'),
  'azul': BrandSpec('voeazul.com.br'),
  'latam': BrandSpec('latamairlines.com'),
  'gol': BrandSpec('voegol.com.br'),
  'localiza': BrandSpec('localiza.com'),
  'sem parar': BrandSpec('semparar.com.br'),
  'veloe': BrandSpec('veloe.com.br'),
  'shell': BrandSpec('shell.com.br'),
  'ipiranga': BrandSpec('ipiranga.com.br'),
  'petrobras': BrandSpec('petrobras.com.br'),

  // Delivery, restaurantes & alimentação
  'ifood': BrandSpec('ifood.com.br'),
  'rappi': BrandSpec('rappi.com.br'),
  'ze delivery': BrandSpec('ze.delivery'),
  'mcdonalds': BrandSpec('mcdonalds.com.br'),
  'mc donalds': BrandSpec('mcdonalds.com.br'),
  'burger king': BrandSpec('burgerking.com.br'),
  'starbucks': BrandSpec('starbucks.com.br'),
  'subway': BrandSpec('subway.com'),
  'outback': BrandSpec('outback.com.br'),
  'dominos': BrandSpec('dominos.com.br'),
  'pizza hut': BrandSpec('pizzahut.com.br'),
  'bobs': BrandSpec('bobs.com.br'),
  'habibs': BrandSpec('habibs.com.br'),
  'madero': BrandSpec('restaurantemadero.com.br'),
  'coco bambu': BrandSpec('cocobambu.com'),
  'cacau show': BrandSpec('cacaushow.com.br'),
  'kopenhagen': BrandSpec('kopenhagen.com.br'),
  'carrefour': BrandSpec('carrefour.com.br'),
  'assai': BrandSpec('assai.com.br'),
  'atacadao': BrandSpec('atacadao.com.br'),
  'pao de acucar': BrandSpec('paodeacucar.com'),
  'sams club': BrandSpec('samsclub.com.br'),
  'oba': BrandSpec('obahortifruti.com.br'),

  // E-commerce, varejo & moda
  'amazon': BrandSpec('amazon.com.br'),
  'shopee': BrandSpec('shopee.com.br'),
  'mercado livre': BrandSpec('mercadolivre.com.br'),
  'shein': BrandSpec('shein.com'),
  'aliexpress': BrandSpec('aliexpress.com'),
  'temu': BrandSpec('temu.com'),
  'magalu': BrandSpec('magazineluiza.com.br'),
  'magazine luiza': BrandSpec('magazineluiza.com.br'),
  'americanas': BrandSpec('americanas.com.br'),
  'casas bahia': BrandSpec('casasbahia.com.br'),
  'kabum': BrandSpec('kabum.com.br'),
  'pichau': BrandSpec('pichau.com.br'),
  'terabyte': BrandSpec('terabyteshop.com.br'),
  'fast shop': BrandSpec('fastshop.com.br'),
  'leroy merlin': BrandSpec('leroymerlin.com.br'),
  'tok stok': BrandSpec('tokstok.com.br'),
  'renner': BrandSpec('lojasrenner.com.br'),
  'riachuelo': BrandSpec('riachuelo.com.br'),
  'zara': BrandSpec('zara.com'),
  'nike': BrandSpec('nike.com.br'),
  'adidas': BrandSpec('adidas.com.br'),
  'centauro': BrandSpec('centauro.com.br'),
  'netshoes': BrandSpec('netshoes.com.br'),
  'boticario': BrandSpec('boticario.com.br'),
  'o boticario': BrandSpec('boticario.com.br'),
  'natura': BrandSpec('natura.com.br'),
  'sephora': BrandSpec('sephora.com.br', bg: Color(0xFF000000)),
  'cobasi': BrandSpec('cobasi.com.br'),
  'petz': BrandSpec('petz.com.br'),
  'petlove': BrandSpec('petlove.com.br'),

  // Bancos & finanças
  'nubank': BrandSpec('nubank.com.br'),
  'inter': BrandSpec('bancointer.com.br'),
  'itau': BrandSpec('itau.com.br'),
  'bradesco': BrandSpec('bradesco.com.br'),
  'santander': BrandSpec('santander.com.br'),
  'banco do brasil': BrandSpec('bb.com.br'),
  'caixa': BrandSpec('caixa.gov.br'),
  'c6': BrandSpec('c6bank.com.br'),
  'c6 bank': BrandSpec('c6bank.com.br'),
  'btg': BrandSpec('btgpactual.com'),
  'picpay': BrandSpec('picpay.com'),
  'mercado pago': BrandSpec('mercadopago.com.br'),
  'pagbank': BrandSpec('pagbank.com.br'),
  'sicredi': BrandSpec('sicredi.com.br'),
  'sicoob': BrandSpec('sicoob.com.br'),
  'wise': BrandSpec('wise.com'),
  'nomad': BrandSpec('nomadglobal.com'),

  // Telecom, contas & saúde
  'vivo': BrandSpec('vivo.com.br'),
  'claro': BrandSpec('claro.com.br'),
  'tim': BrandSpec('tim.com.br'),
  'oi': BrandSpec('oi.com.br'),
  'sky': BrandSpec('sky.com.br'),
  'starlink': BrandSpec('starlink.com'),
  'enel': BrandSpec('enel.com.br'),
  'sabesp': BrandSpec('sabesp.com.br'),
  'copel': BrandSpec('copel.com'),
  'cemig': BrandSpec('cemig.com.br'),
  'comgas': BrandSpec('comgas.com.br'),
  'smartfit': BrandSpec('smartfit.com.br'),
  'smart fit': BrandSpec('smartfit.com.br'),
  'bluefit': BrandSpec('bluefit.com.br'),
  'wellhub': BrandSpec('wellhub.com'),
  'gympass': BrandSpec('wellhub.com'),
  'totalpass': BrandSpec('totalpass.com'),
  'drogasil': BrandSpec('drogasil.com.br'),
  'droga raia': BrandSpec('drogaraia.com.br'),
  'drogaria sao paulo': BrandSpec('drogariasaopaulo.com.br'),
  'pague menos': BrandSpec('paguemenos.com.br'),
  'panvel': BrandSpec('panvel.com'),
  'unimed': BrandSpec('unimed.coop.br'),
  'amil': BrandSpec('amil.com.br'),
  'sulamerica': BrandSpec('sulamerica.com.br'),
};

/// Mapeamento inteligente de palavras-chave do dia a dia → ícone do Lucide,
/// usado automaticamente quando o gasto não corresponde a uma marca específica.
const _smartIcons = <String, IconData>{
  // Alimentação
  'pizza': LucideIcons.pizza,
  'pizzaria': LucideIcons.pizza,
  'cafe': LucideIcons.coffee,
  'cafeteria': LucideIcons.coffee,
  'padaria': LucideIcons.croissant,
  'pao': LucideIcons.croissant,
  'bolo': LucideIcons.cake,
  'doce': LucideIcons.candy,
  'sorvete': LucideIcons.iceCreamCone,
  'acai': LucideIcons.iceCreamBowl,
  'cerveja': LucideIcons.beer,
  'chopp': LucideIcons.beer,
  'bar': LucideIcons.wine,
  'vinho': LucideIcons.wine,
  'drink': LucideIcons.martini,
  'hamburguer': LucideIcons.beef,
  'burger': LucideIcons.beef,
  'churrasco': LucideIcons.flame,
  'mercado': LucideIcons.shoppingCart,
  'supermercado': LucideIcons.shoppingCart,
  'feira': LucideIcons.apple,
  'hortifruti': LucideIcons.apple,
  'lanche': LucideIcons.sandwich,

  // Transporte
  'gasolina': LucideIcons.fuel,
  'combustivel': LucideIcons.fuel,
  'etanol': LucideIcons.fuel,
  'posto': LucideIcons.fuel,
  'estacionamento': LucideIcons.circleParking,
  'onibus': LucideIcons.bus,
  'metro': LucideIcons.trainFront,
  'trem': LucideIcons.trainFront,
  'passagem': LucideIcons.plane,
  'voo': LucideIcons.plane,
  'viagem': LucideIcons.luggage,
  'hotel': LucideIcons.bedDouble,
  'mecanico': LucideIcons.wrench,
  'oficina': LucideIcons.wrench,
  'bicicleta': LucideIcons.bike,

  // Casa & contas
  'aluguel': LucideIcons.keyRound,
  'condominio': LucideIcons.building2,
  'luz': LucideIcons.zap,
  'energia': LucideIcons.zap,
  'agua': LucideIcons.droplets,
  'gas': LucideIcons.flame,
  'internet': LucideIcons.wifi,
  'wifi': LucideIcons.wifi,
  'celular': LucideIcons.smartphone,
  'telefone': LucideIcons.smartphone,
  'recarga': LucideIcons.smartphone,
  'limpeza': LucideIcons.sparkles,
  'faxina': LucideIcons.sparkles,
  'moveis': LucideIcons.armchair,
  'mesa': LucideIcons.armchair,
  'cadeira': LucideIcons.armchair,

  // Tecnologia & compras
  'notebook': LucideIcons.laptop,
  'computador': LucideIcons.monitor,
  'pc': LucideIcons.monitor,
  'teclado': LucideIcons.keyboard,
  'mouse': LucideIcons.mouse,
  'fone': LucideIcons.headphones,
  'camera': LucideIcons.camera,
  'relogio': LucideIcons.watch,
  'roupa': LucideIcons.shirt,
  'camisa': LucideIcons.shirt,
  'camiseta': LucideIcons.shirt,
  'tenis': LucideIcons.footprints,
  'sapato': LucideIcons.footprints,
  'perfume': LucideIcons.sparkles,
  'presente': LucideIcons.gift,
  'flor': LucideIcons.flower2,
  'flores': LucideIcons.flower2,

  // Saúde, beleza & pets
  'academia': LucideIcons.dumbbell,
  'treino': LucideIcons.dumbbell,
  'personal': LucideIcons.dumbbell,
  'farmacia': LucideIcons.pill,
  'remedio': LucideIcons.pill,
  'medico': LucideIcons.stethoscope,
  'consulta': LucideIcons.stethoscope,
  'exame': LucideIcons.stethoscope,
  'dentista': LucideIcons.smile,
  'terapia': LucideIcons.brain,
  'psicologo': LucideIcons.brain,
  'cabelo': LucideIcons.scissors,
  'barbearia': LucideIcons.scissors,
  'salao': LucideIcons.scissors,
  'manicure': LucideIcons.sparkles,
  'pet': LucideIcons.pawPrint,
  'racao': LucideIcons.pawPrint,
  'veterinario': LucideIcons.pawPrint,
  'cachorro': LucideIcons.dog,
  'gato': LucideIcons.cat,

  // Educação & lazer
  'livro': LucideIcons.bookOpen,
  'curso': LucideIcons.graduationCap,
  'faculdade': LucideIcons.graduationCap,
  'escola': LucideIcons.graduationCap,
  'cinema': LucideIcons.clapperboard,
  'filme': LucideIcons.clapperboard,
  'show': LucideIcons.music,
  'musica': LucideIcons.music,
  'jogo': LucideIcons.gamepad2,
  'game': LucideIcons.gamepad2,
  'festa': LucideIcons.partyPopper,
  'doacao': LucideIcons.heartHandshake,
};

/// Especificação da marca citada em [name], ou null. Casa por palavra inteira
/// (sem sensibilidade a acentos), então "Uber pra casa" acha uber.com, mas
/// "super" não casa com nada.
BrandSpec? brandSpecFor(String name) {
  final n = _fold(name);
  BrandSpec? best;
  var bestLen = 0;
  for (final e in _brandSpecs.entries) {
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

/// Domínio da marca citada em [name], ou null.
String? brandDomainFor(String name) => brandSpecFor(name)?.domain;

/// Ícone inteligente do Lucide sugerido automaticamente pelo nome do gasto.
IconData? smartIconFor(String name) {
  final n = _fold(name);
  IconData? best;
  var bestLen = 0;
  for (final e in _smartIcons.entries) {
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

/// Logo 128px do domínio (favicon em alta resolução via Google S2, gratuito).
String brandLogoUrl(String domain) =>
    'https://www.google.com/s2/favicons?domain=$domain&sz=128';
