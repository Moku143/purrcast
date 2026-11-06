"""The listing in the other ten languages (adds to listing.L). Terms follow docs/i18n-glossary.md and the app's own
strings (Localizable.strings) so the store says what the app says."""
from listing import L

SUBS = {
    "ja": "Plusは年額または月額の自動更新サブスクリプションです。初めての登録には無料体験がある場合があり、体験が終わると選んだ料金がApple アカウントに請求されます。期間終了の24時間前までに解約しない限り自動的に更新され、解約は端末の設定 > Apple アカウント > サブスクリプションからいつでもできます。",
}
TERMS = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
PRIVACY = "https://moku143.github.io/purrcast/privacy.html"

L["ja"] = dict(
    name="ゴロゴロ天気 - 天気と服装",
    subtitle="ドット絵のキャラが着替えて伝える天気",
    promo="体感温度に合わせて着替えるドット絵のキャラクターが、今日の天気を伝えます。毎日の天気と服装は天気カレンダーに記録され、ロック画面の時計の上にも服を着たキャラクターが現れます。",
    keywords="傘,雨,ウィジェット,コーデ,体感温度,ロック画面,天気予報,降水確率,カレンダー,かわいい",
    description=f"""今日は何を着る？ キャラクターを見ればわかります。

ゴロゴロ天気は、ドット絵のキャラクターが体感温度に合わせて着替え、雨が降ると傘をさして天気を伝える天気アプリです。数字を読まなくても、ひと目で今日の天気がわかります。予報は世界中でApple 天気、韓国では韓国気象庁です。

• 服装15段階: タンクトップからファー付きフードのダウンまで、体感温度に合わせて着替えます
• 傘の3段階: 今降っていれば傘をさし、これから降るならかばんに入れ、微妙なときは迷います
• 雨の時間を前もって: 「15〜17時に雨の予報です」のように伝えます
• 動く空: 雲が流れ、雨や雪が降り、星がまたたき、雷が光ります
• 時間ごと・10日間の予報と、日ごとの詳しいグラフ（気温・体感・雨・風・紫外線・湿度・大気）
• 大気の状態と、予報の比較（Apple 天気・MET Norway、韓国では韓国気象庁も）
• ホーム画面・ロック画面ウィジェット
• ロック画面の時計の上の1行: 服を着たキャラクターと気温・場所・雨・紫外線・日の出・日の入り・風
• 今週の記録: 最近7日間の天気と服装
• ホームのカードは長押しで好きな順番に
• 朝のまとめ通知
• 12の言語、°C / °F、24時間 / 12時間、ドット文字・通常の文字

ゴロゴロ天気 Plus
• 新しい予報が出るたびに更新
• 近づく雨: これから6時間、いつどれくらい降るか（Apple 天気が分単位を提供する地域では分単位で）
• 雨や雪の1時間前と降り始めの通知、ロック画面のライブアクティビティ
• 気象警報・大気汚染・気温の変化の通知
• 大気質マップ: 6種類の汚染物質と毎時の微小粒子状物質、ロック画面の大気ウィジェット
• 天気カレンダー・月間レポート: 毎日の天気と服装がカレンダーに記録され、過ぎた日も時間ごとに見返せて、毎月1日にレポートの通知と共有カード
• Apple Watch アプリ・コンプリケーション
• 地域は無制限
• キャラクター変更: アビシニアン・ブリティッシュショートヘア、名前・話し方

気象データ: Apple 天気、韓国気象庁（KOGL 第1類型）、MET Norway（CC BY 4.0）、AirKorea（KOGL 第1類型）、OpenWeather

サブスクリプションについて
{SUBS["ja"]}
利用規約: {TERMS}
プライバシーポリシー: {PRIVACY}""",
    group="ゴロゴロ天気 Plus",
    yearly="ゴロゴロ天気 Plus 年額",
    monthly="ゴロゴロ天気 Plus 月額",
    iap="近づく雨・大気質・天気カレンダー・Apple Watch・キャラクター",
)

L["es-ES"] = dict(
    name="Purrcast: Tiempo y Ropa",
    subtitle="Una mascota pixel que se viste",
    promo="Una mascota pixel se viste según la sensación térmica y abre el paraguas si llueve. El tiempo y la ropa de cada día llenan un calendario, y aparece sobre el reloj.",
    keywords="lluvia,paraguas,widget,qué ponerme,pronóstico,gato,pixel,pantalla bloqueo,reloj,ropa,calendario",
    description=f"""¿Qué me pongo hoy? Pregúntale a tu mascota pixel.

Purrcast muestra el tiempo a través de una mascota pixel: se cambia de ropa según la sensación térmica y abre el paraguas cuando llega la lluvia. Sin números que leer: un vistazo y lo sabes. Los pronósticos vienen de El Tiempo de Apple en todo el mundo y de la agencia meteorológica de Corea en Corea.

• 15 conjuntos, de la camiseta de tirantes al plumífero con capucha
• Paraguas: lloviendo ahora, lluvia más tarde (en la mochila), quizá
• Lluvia a la vista: «Lluvia de 15 a 17 h», y el paraguas va a la mochila
• Cielo vivo: las nubes se mueven, cae lluvia y nieve, brillan las estrellas, caen rayos
• Pronóstico por horas y a 10 días, con gráficos de cada día: temperatura, sensación, lluvia, viento, UV, humedad, aire
• Calidad del aire y pronósticos comparados (El Tiempo de Apple y MET Norway; en Corea, también KMA)
• Widgets de inicio y de pantalla bloqueada
• Encima del reloj de la pantalla bloqueada: el personaje vestido y la temperatura, el lugar, la lluvia, UV, amanecer y atardecer, viento
• Esta semana: el tiempo y la ropa de los últimos siete días
• Mantén pulsada una tarjeta de inicio para moverla donde quieras
• Resumen de la mañana
• 12 idiomas, °C / °F, 24 h / 12 h, letra pixel o normal

Purrcast Plus
• Se actualiza con cada nuevo pronóstico
• Lluvia en las próximas 6 horas: cuándo y cuánto — minuto a minuto donde El Tiempo de Apple lo ofrece
• Avisos una hora antes de la lluvia o la nieve y al empezar, con Actividad en Vivo en la pantalla bloqueada
• Avisos oficiales, aire contaminado y cambios de temperatura
• Mapa de calidad del aire con seis contaminantes y partículas cada hora, más un widget de aire para la pantalla bloqueada
• Calendario del tiempo y resumen mensual: el tiempo y la ropa de cada día en un calendario, los días pasados hora a hora, y un resumen con tarjeta para compartir cada día 1
• App y complicaciones para Apple Watch
• Lugares ilimitados
• Más personajes: Abisinio y British Shorthair, con nombre

Datos meteorológicos: El Tiempo de Apple, Korea Meteorological Administration (KOGL tipo 1), MET Norway (CC BY 4.0), AirKorea (KOGL tipo 1), OpenWeather

Suscripciones
Plus es una suscripción anual o mensual de renovación automática. Los nuevos suscriptores pueden tener una prueba gratuita; al terminar, se cobra el precio elegido a tu cuenta de Apple. Se renueva automáticamente salvo que la canceles al menos 24 horas antes del final del periodo. Puedes gestionarla o cancelarla cuando quieras en Ajustes > Cuenta de Apple > Suscripciones.
Condiciones de uso: {TERMS}
Política de privacidad: {PRIVACY}""",
    group="Purrcast Plus",
    yearly="Purrcast Plus anual",
    monthly="Purrcast Plus mensual",
    iap="Lluvia, aire, calendario, Watch, personajes",
)

L["fr-FR"] = dict(
    name="Purrcast : Météo et Tenues",
    subtitle="Un ami pixel qui s’habille",
    promo="Un ami pixel s’habille selon le ressenti et ouvre son parapluie s’il pleut. La météo et la tenue de chaque jour remplissent un calendrier, jusqu’au-dessus de l’heure.",
    keywords="pluie,parapluie,widget,quoi porter,prévisions,chat,pixel,écran verrouillé,montre,tenue,calendrier",
    description=f"""Que porter aujourd’hui ? Demandez à votre ami pixel.

Purrcast montre la météo grâce à un compagnon en pixel : il change de tenue selon la température ressentie et ouvre son parapluie quand la pluie arrive. Pas de chiffres à lire : un coup d’œil suffit. Les prévisions viennent de Météo d’Apple dans le monde entier et de l’agence météorologique coréenne en Corée.

• 15 tenues, du débardeur à la doudoune à capuche fourrée
• Parapluie : il pleut, il pleuvra (rangé dans le sac), peut-être
• Pluie à venir : « Pluie de 15 h à 17 h », et le parapluie va dans le sac
• Un ciel vivant : nuages, pluie, neige, étoiles et éclairs
• Prévisions heure par heure et sur 10 jours, avec les graphiques de chaque jour : température, ressenti, pluie, vent, UV, humidité, air
• Qualité de l’air et prévisions comparées (Météo d’Apple et MET Norway ; en Corée, KMA aussi)
• Widgets pour l’écran d’accueil et l’écran verrouillé
• Au-dessus de l’heure sur l’écran verrouillé : le personnage habillé et la température, le lieu, la pluie, l’UV, le lever et le coucher du soleil, le vent
• Cette semaine : la météo et les tenues des sept derniers jours
• Maintenez une carte de l’accueil appuyée pour la déplacer
• Résumé du matin
• 12 langues, °C / °F, 24 h / 12 h, police pixel ou classique

Purrcast Plus
• Mise à jour à chaque nouvelle prévision
• Pluie dans les 6 prochaines heures : quand et combien — minute par minute là où Météo d’Apple le propose
• Alertes une heure avant la pluie ou la neige et quand elle commence, avec une Activité en direct sur l’écran verrouillé
• Vigilances officielles, air pollué et changements de température
• Carte de la qualité de l’air avec six polluants et les particules heure par heure, plus un widget air pour l’écran verrouillé
• Calendrier météo et bilan du mois : la météo et la tenue de chaque jour dans un calendrier, les jours passés heure par heure, un bilan et une carte à partager chaque 1er du mois
• App et complications Apple Watch
• Lieux illimités
• D’autres personnages : Abyssin et British Shorthair, à baptiser

Données météo : Météo d’Apple, Korea Meteorological Administration (KOGL type 1), MET Norway (CC BY 4.0), AirKorea (KOGL type 1), OpenWeather

Abonnements
Plus est un abonnement annuel ou mensuel à renouvellement automatique. Les nouveaux abonnés peuvent bénéficier d’un essai gratuit ; ensuite, le prix choisi est facturé sur votre compte Apple. L’abonnement se renouvelle automatiquement sauf résiliation au moins 24 heures avant la fin de la période. Gérez-le ou résiliez-le à tout moment dans Réglages > Compte Apple > Abonnements.
Conditions d’utilisation : {TERMS}
Politique de confidentialité : {PRIVACY}""",
    group="Purrcast Plus",
    yearly="Purrcast Plus annuel",
    monthly="Purrcast Plus mensuel",
    iap="Pluie, air, calendrier, Watch, personnages",
)

L["de-DE"] = dict(
    name="Purrcast: Wetter & Outfits",
    subtitle="Pixel-Freunde im Wetter-Outfit",
    promo="Ein Pixel-Freund zieht sich nach der gefühlten Temperatur an und öffnet bei Regen den Schirm. Wetter und Outfit jedes Tages füllen einen Kalender – auch über der Uhr.",
    keywords="regen,schirm,widget,was anziehen,vorhersage,katze,pixel,sperrbildschirm,uhr,kleidung,kalender",
    description=f"""Was ziehe ich heute an? Frag deinen Pixel-Freund.

Purrcast zeigt das Wetter mit einem Pixel-Haustier: Es zieht sich nach der gefühlten Temperatur an und öffnet den Schirm, wenn Regen kommt. Keine Zahlen lesen – ein Blick genügt. Die Vorhersagen kommen weltweit von Apple Wetter und in Korea vom koreanischen Wetterdienst.

• 15 Outfits, vom Tanktop bis zur Daunenjacke mit Fellkapuze
• Schirm: Es regnet, es wird regnen (in der Tasche), vielleicht
• Regen im Voraus: „Regen 15–17 Uhr“ – und der Schirm kommt in die Tasche
• Lebendiger Himmel: Wolken ziehen, Regen und Schnee fallen, Sterne funkeln, Blitze zucken
• Stündliche und 10-Tage-Vorhersage, mit Diagrammen für jeden Tag: Temperatur, gefühlt, Regen, Wind, UV, Luftfeuchtigkeit, Luft
• Luftqualität und Vorhersagen im Vergleich (Apple Wetter und MET Norway; in Korea auch KMA)
• Widgets für Home- und Sperrbildschirm
• Über der Uhr auf dem Sperrbildschirm: die angezogene Figur und die Temperatur, der Ort, Regen, UV, Sonnenauf- und -untergang, Wind
• Diese Woche: Wetter und Outfits der letzten sieben Tage
• Halte eine Karte auf der Startseite gedrückt, um sie zu verschieben
• Morgenübersicht
• 12 Sprachen, °C / °F, 24 / 12 Stunden, Pixel- oder normale Schrift

Purrcast Plus
• Aktualisiert mit jeder neuen Vorhersage
• Regen in den nächsten 6 Stunden: wann und wie viel — minutengenau, wo Apple Wetter es anbietet
• Hinweise eine Stunde vor Regen oder Schnee und wenn es losgeht, mit Live-Aktivität auf dem Sperrbildschirm
• Amtliche Warnungen, schlechte Luft und Temperaturwechsel
• Luftqualitätskarte mit sechs Schadstoffen und stündlichem Feinstaub, dazu ein Luft-Widget für den Sperrbildschirm
• Wetterkalender und Monatsbericht: Wetter und Outfit jedes Tages im Kalender, vergangene Tage Stunde für Stunde, ein Bericht mit Karte zum Teilen an jedem 1.
• Apple Watch-App und Komplikationen
• Unbegrenzt viele Orte
• Mehr Figuren: Abessinier und Britisch Kurzhaar, mit eigenem Namen

Wetterdaten: Apple Wetter, Korea Meteorological Administration (KOGL Typ 1), MET Norway (CC BY 4.0), AirKorea (KOGL Typ 1), OpenWeather

Abos
Plus ist ein jährliches oder monatliches Abo mit automatischer Verlängerung. Neue Abonnenten erhalten eventuell eine kostenlose Testphase; danach wird der gewählte Preis über deinen Apple Account abgerechnet. Das Abo verlängert sich automatisch, wenn du es nicht mindestens 24 Stunden vor Ablauf kündigst. Verwalten oder kündigen jederzeit unter Einstellungen > Apple Account > Abonnements.
Nutzungsbedingungen: {TERMS}
Datenschutzerklärung: {PRIVACY}""",
    group="Purrcast Plus",
    yearly="Purrcast Plus jährlich",
    monthly="Purrcast Plus monatlich",
    iap="Regen, Luft, Kalender, Watch, Figuren",
)

L["pt-BR"] = dict(
    name="Purrcast: Clima e Roupas",
    subtitle="Um amigo pixel que se veste",
    promo="Um amigo pixel se veste conforme a sensação térmica e abre o guarda-chuva se chove. O tempo e a roupa de cada dia vão para um calendário, e ele aparece sobre o relógio.",
    keywords="chuva,guarda-chuva,widget,o que vestir,previsão,gato,pixel,tela bloqueio,relógio,roupa,calendário",
    description=f"""O que vestir hoje? Pergunte ao seu amigo pixel.

O Purrcast mostra o tempo com um bichinho em pixel: ele troca de roupa conforme a sensação térmica e abre o guarda-chuva quando a chuva chega. Nada de números: basta olhar. As previsões vêm do Tempo da Apple no mundo todo e do serviço meteorológico da Coreia na Coreia.

• 15 roupas, da regata ao casaco puffer com capuz de pelo
• Guarda-chuva: chovendo agora, chuva mais tarde (na bolsa), talvez
• Chuva à frente: “Chuva das 15h às 17h”, e o guarda-chuva vai na bolsa
• Céu vivo: nuvens passam, cai chuva e neve, estrelas brilham, relâmpagos piscam
• Previsão por hora e de 10 dias, com gráficos de cada dia: temperatura, sensação, chuva, vento, UV, umidade, ar
• Qualidade do ar e previsões lado a lado (Tempo da Apple e MET Norway; na Coreia, também KMA)
• Widgets para a Tela de Início e a Tela Bloqueada
• Acima do relógio da Tela Bloqueada: o personagem vestido e a temperatura, o local, chuva, UV, nascer e pôr do sol, vento
• Esta semana: o tempo e as roupas dos últimos sete dias
• Toque e segure um cartão da tela inicial para movê-lo
• Resumo da manhã
• 12 idiomas, °C / °F, 24 h / 12 h, fonte pixel ou comum

Purrcast Plus
• Atualiza a cada nova previsão
• Chuva nas próximas 6 horas: quando e quanto — minuto a minuto onde o Tempo da Apple oferece
• Alertas uma hora antes da chuva ou da neve e quando começa, com Atividade ao Vivo na Tela Bloqueada
• Alertas oficiais, ar poluído e mudanças de temperatura
• Mapa da qualidade do ar com seis poluentes e material particulado a cada hora, mais um widget de ar para a Tela Bloqueada
• Calendário do tempo e resumo do mês: o tempo e a roupa de cada dia num calendário, os dias passados hora a hora, e um resumo com cartão para compartilhar todo dia 1º
• App e complicações para Apple Watch
• Locais ilimitados
• Mais personagens: Abissínio e British Shorthair, com nome

Dados do tempo: Tempo da Apple, Korea Meteorological Administration (KOGL tipo 1), MET Norway (CC BY 4.0), AirKorea (KOGL tipo 1), OpenWeather

Assinaturas
O Plus é uma assinatura anual ou mensal com renovação automática. Novos assinantes podem ter um período de teste gratuito; depois, o preço escolhido é cobrado na sua Conta Apple. A assinatura renova automaticamente, a menos que seja cancelada pelo menos 24 horas antes do fim do período. Gerencie ou cancele quando quiser em Ajustes > Conta Apple > Assinaturas.
Termos de Uso: {TERMS}
Política de Privacidade: {PRIVACY}""",
    group="Purrcast Plus",
    yearly="Purrcast Plus anual",
    monthly="Purrcast Plus mensal",
    iap="Chuva, ar, calendário, Watch, personagens",
)

L["it"] = dict(
    name="Purrcast: Meteo e Outfit",
    subtitle="Un amico pixel che si veste",
    promo="Un amico pixel si veste secondo la temperatura percepita e apre l’ombrello se piove. Meteo e outfit di ogni giorno riempiono un calendario, e compare sopra l’orologio.",
    keywords="pioggia,ombrello,widget,cosa indossare,previsioni,gatto,pixel,schermata blocco,orologio,calendario",
    description=f"""Cosa mi metto oggi? Chiedilo al tuo amico pixel.

Purrcast mostra il meteo con un amico in pixel: cambia vestiti secondo la temperatura percepita e apre l’ombrello quando arriva la pioggia. Niente numeri da leggere: basta uno sguardo. Le previsioni arrivano da Meteo di Apple in tutto il mondo e dal servizio meteorologico coreano in Corea.

• 15 outfit, dalla canotta al piumino con cappuccio di pelliccia
• Ombrello: piove ora, pioverà (nello zaino), forse
• Pioggia in arrivo: «Pioggia dalle 15 alle 17», e l’ombrello va nello zaino
• Cielo vivo: nuvole che passano, pioggia e neve, stelle e lampi
• Previsioni orarie e a 10 giorni, con i grafici di ogni giorno: temperatura, percepita, pioggia, vento, UV, umidità, aria
• Qualità dell’aria e previsioni a confronto (Meteo di Apple e MET Norway; in Corea anche KMA)
• Widget per la schermata Home e la schermata di blocco
• Sopra l’orologio della schermata di blocco: il personaggio vestito e la temperatura, il luogo, la pioggia, l’UV, alba e tramonto, il vento
• Questa settimana: meteo e outfit degli ultimi sette giorni
• Tieni premuta una scheda della home per spostarla dove vuoi
• Riepilogo del mattino
• 12 lingue, °C / °F, 24 h / 12 h, carattere pixel o normale

Purrcast Plus
• Aggiornamento a ogni nuova previsione
• Pioggia nelle prossime 6 ore: quando e quanta — minuto per minuto dove Meteo di Apple lo offre
• Avvisi un’ora prima di pioggia o neve e quando inizia, con Attività in tempo reale nella schermata di blocco
• Allerte ufficiali, aria inquinata e cambi di temperatura
• Mappa della qualità dell’aria con sei inquinanti e polveri sottili ogni ora, più un widget aria per la schermata di blocco
• Calendario meteo e resoconto del mese: meteo e outfit di ogni giorno in un calendario, i giorni passati ora per ora, un resoconto con scheda da condividere ogni 1° del mese
• App e complicazioni per Apple Watch
• Luoghi illimitati
• Altri personaggi: Abissino e British Shorthair, con un nome

Dati meteo: Meteo di Apple, Korea Meteorological Administration (KOGL tipo 1), MET Norway (CC BY 4.0), AirKorea (KOGL tipo 1), OpenWeather

Abbonamenti
Plus è un abbonamento annuale o mensile a rinnovo automatico. I nuovi abbonati possono avere una prova gratuita; al termine, il prezzo scelto viene addebitato sul tuo Account Apple. Si rinnova automaticamente se non disdici almeno 24 ore prima della fine del periodo. Gestisci o disdici quando vuoi in Impostazioni > Account Apple > Abbonamenti.
Condizioni d’uso: {TERMS}
Informativa sulla privacy: {PRIVACY}""",
    group="Purrcast Plus",
    yearly="Purrcast Plus annuale",
    monthly="Purrcast Plus mensile",
    iap="Pioggia, aria, calendario, Watch, personaggi",
)

L["id"] = dict(
    name="Purrcast: Cuaca & Pakaian",
    subtitle="Teman piksel berbaju cuaca",
    promo="Teman piksel berganti pakaian sesuai suhu terasa dan membuka payung saat hujan. Cuaca dan pakaian tiap hari tersimpan di kalender, dan ia muncul di atas jam.",
    keywords="hujan,payung,widget,pakai apa,prakiraan,kucing,piksel,layar kunci,jam tangan,baju,kalender",
    description=f"""Pakai apa hari ini? Tanya teman pikselmu.

Purrcast menampilkan cuaca lewat hewan piksel: ia berganti pakaian sesuai suhu terasa dan membuka payung saat hujan datang. Tak perlu membaca angka — sekali lihat langsung tahu. Prakiraan dari Cuaca Apple di seluruh dunia dan badan meteorologi Korea di Korea.

• 15 pakaian, dari kaus tanpa lengan sampai jaket bulu berkerudung
• Payung: sedang hujan, nanti hujan (disimpan di tas), mungkin
• Hujan di depan: "Hujan pukul 15–17", dan payung masuk tas
• Langit hidup: awan bergerak, hujan dan salju turun, bintang berkelip, petir menyambar
• Prakiraan per jam dan 10 hari, dengan grafik tiap hari: suhu, terasa, hujan, angin, UV, kelembapan, udara
• Kualitas udara dan prakiraan berdampingan (Cuaca Apple dan MET Norway; di Korea juga KMA)
• Widget Layar Utama dan Layar Kunci
• Di atas jam Layar Kunci: karakter berpakaian dan suhu, lokasi, hujan, UV, matahari terbit dan terbenam, angin
• Minggu ini: cuaca dan pakaian tujuh hari terakhir
• Tekan lama kartu di beranda untuk memindahkannya
• Ringkasan pagi
• 12 bahasa, °C / °F, 24 jam / 12 jam, huruf piksel atau biasa

Purrcast Plus
• Diperbarui setiap ada prakiraan baru
• Hujan 6 jam ke depan: kapan dan seberapa banyak — menit demi menit di wilayah yang didukung Cuaca Apple
• Pemberitahuan sejam sebelum hujan atau salju dan saat mulai, dengan Aktivitas Langsung di Layar Kunci
• Peringatan resmi, udara buruk, dan perubahan suhu
• Peta kualitas udara dengan enam polutan dan partikel debu tiap jam, plus widget udara di Layar Kunci
• Kalender cuaca dan laporan bulanan: cuaca dan pakaian setiap hari di kalender, hari yang lalu per jam, laporan dan kartu untuk dibagikan tiap tanggal 1
• Aplikasi dan komplikasi Apple Watch
• Lokasi tanpa batas
• Karakter lain: Abyssinian dan British Shorthair, bisa diberi nama

Data cuaca: Cuaca Apple, Korea Meteorological Administration (KOGL Tipe 1), MET Norway (CC BY 4.0), AirKorea (KOGL Tipe 1), OpenWeather

Langganan
Plus adalah langganan tahunan atau bulanan yang diperpanjang otomatis. Pelanggan baru mungkin mendapat uji coba gratis; setelah selesai, harga yang dipilih ditagihkan ke Akun Apple Anda. Langganan diperpanjang otomatis kecuali dibatalkan minimal 24 jam sebelum periode berakhir. Kelola atau batalkan kapan saja di Pengaturan > Akun Apple > Langganan.
Ketentuan Penggunaan: {TERMS}
Kebijakan Privasi: {PRIVACY}""",
    group="Purrcast Plus",
    yearly="Purrcast Plus Tahunan",
    monthly="Purrcast Plus Bulanan",
    iap="Hujan, udara, kalender, Watch, karakter",
)

L["ru"] = dict(
    name="Purrcast: погода и одежда",
    subtitle="Пиксельный друг одет по погоде",
    promo="Пиксельный друг одевается по ощущаемой температуре и раскрывает зонт в дождь. Погода и одежда каждого дня — в календаре, а сам он появляется над часами.",
    keywords="дождь,зонт,виджет,что надеть,прогноз,кот,пиксель,экран блокировки,часы,одежда,календарь",
    description=f"""Что надеть сегодня? Спросите пиксельного друга.

Purrcast показывает погоду с помощью пиксельного питомца: он переодевается по ощущаемой температуре и раскрывает зонт, когда приходит дождь. Не нужно читать цифры — хватит одного взгляда. Прогнозы — от Apple Погоды по всему миру и от метеослужбы Кореи в Корее.

• 15 нарядов — от майки до пуховика с меховым капюшоном
• Зонт: дождь сейчас, дождь позже (в сумке), может быть
• Дождь заранее: «Дождь с 15 до 17» — и зонт отправляется в сумку
• Живое небо: плывут облака, идут дождь и снег, мерцают звёзды, сверкает молния
• Прогноз по часам и на 10 дней, с графиками для каждого дня: температура, ощущается, дождь, ветер, УФ, влажность, воздух
• Качество воздуха и прогнозы рядом (Apple Погода и MET Norway; в Корее ещё и KMA)
• Виджеты для экрана «Домой» и экрана блокировки
• Над часами на экране блокировки: одетый персонаж и температура, место, дождь, УФ, восход и закат, ветер
• Эта неделя: погода и одежда за последние семь дней
• Нажмите и удерживайте карточку на главном экране, чтобы переместить её
• Утренняя сводка
• 12 языков, °C / °F, 24 / 12 часов, пиксельный или обычный шрифт

Purrcast Plus
• Обновление с каждым новым прогнозом
• Дождь на ближайшие 6 часов: когда и сколько — поминутно там, где это даёт Apple Погода
• Уведомления за час до дождя или снега и когда они начинаются, с Live Activity на экране блокировки
• Официальные предупреждения, загрязнённый воздух и перепады температуры
• Карта качества воздуха с шестью загрязнителями и взвешенными частицами каждый час, а также виджет воздуха на экране блокировки
• Календарь погоды и отчёт за месяц: погода и одежда каждого дня в календаре, прошедшие дни по часам, отчёт и открытка для отправки 1-го числа каждого месяца
• Приложение и усложнения для Apple Watch
• Неограниченное число мест
• Новые персонажи: абиссинская и британская короткошёрстная кошки, со своим именем

Данные о погоде: Apple Погода, Korea Meteorological Administration (KOGL тип 1), MET Norway (CC BY 4.0), AirKorea (KOGL тип 1), OpenWeather

Подписки
Plus — годовая или месячная подписка с автоматическим продлением. Новые подписчики могут получить бесплатный пробный период; после него выбранная цена списывается с вашей учётной записи Apple. Подписка продлевается автоматически, если не отменить её минимум за 24 часа до конца периода. Управлять подпиской или отменить её можно в любое время: Настройки > Учётная запись Apple > Подписки.
Условия использования: {TERMS}
Политика конфиденциальности: {PRIVACY}""",
    group="Purrcast Plus",
    yearly="Purrcast Plus на год",
    monthly="Purrcast Plus на месяц",
    iap="Дождь, воздух, календарь, Watch, персонажи",
)

L["zh-Hans"] = dict(
    name="Purrcast：天气穿搭",
    subtitle="像素角色换装告诉你天气",
    promo="像素角色会按照体感温度换衣服，下雨时撑起雨伞。现在每天的天气和穿搭都会记在天气日历里，锁定屏幕的时钟上方也会出现穿好衣服的角色。",
    keywords="雨,雨伞,小组件,穿什么,天气预报,猫,像素,锁定屏幕,手表,穿衣,日历,可爱",
    description=f"""今天穿什么？看看角色就知道。

Purrcast 用一只像素宠物告诉你天气：它会按照体感温度换衣服，下雨时撑起雨伞。不用读数字，看一眼就明白。全球使用 Apple 天气预报，韩国使用韩国气象厅预报。

• 15 种穿搭：从背心到带毛领帽的羽绒服，随体感温度更换
• 雨伞三种状态：正在下雨就撑伞，稍后有雨就放进包里，拿不准时会犹豫
• 提前知道雨：比如"15～17时有雨预报"，记得带伞
• 会动的天空：云在飘，雨雪落下，星星闪烁，闪电划过
• 逐小时和 10 天预报，每天都有详细图表：气温、体感、降雨、风、紫外线、湿度、空气
• 空气质量，以及预报对比（Apple 天气、MET Norway，在韩国还有韩国气象厅）
• 主屏幕和锁定屏幕小组件
• 锁定屏幕时钟上方一行：穿好衣服的角色和气温、位置、雨、紫外线、日出日落、风
• 本周记录：最近 7 天的天气和穿搭
• 长按首页卡片，可以随意调整顺序
• 早间摘要通知
• 12 种语言，°C / °F，24 小时 / 12 小时，像素字体或普通字体

Purrcast Plus
• 每次有新预报就更新
• 未来 6 小时的雨：什么时候下、下多少——在 Apple 天气提供分钟级预报的地区精确到分钟
• 下雨或下雪前 1 小时和开始时提醒，锁定屏幕实时活动
• 气象预警、空气污染和气温变化提醒
• 空气质量地图：6 种污染物和每小时颗粒物，以及锁定屏幕空气小组件
• 天气日历和月度报告：每天的天气和穿搭记在日历上，过去的日子也能逐小时回看，每月 1 日推送报告和分享卡片
• Apple Watch 应用和表盘复杂功能
• 地点不限数量
• 更多角色：阿比西尼亚猫、英国短毛猫，还能取名字

天气数据：Apple 天气、韩国气象厅（KOGL 第一类）、MET Norway（CC BY 4.0）、AirKorea（KOGL 第一类）、OpenWeather

订阅说明
Plus 是按年或按月自动续订的订阅。新订阅用户可能享有免费试用；试用结束后，所选价格将通过你的 Apple 账户扣费。除非在当期结束前至少 24 小时取消，否则会自动续订。你可以随时在"设置 > Apple 账户 > 订阅"中管理或取消。
使用条款：{TERMS}
隐私政策：{PRIVACY}""",
    group="Purrcast Plus",
    yearly="Purrcast Plus 年度",
    monthly="Purrcast Plus 月度",
    iap="近期降雨・空气质量・天气日历・Apple Watch・角色",
)

L["zh-Hant"] = dict(
    name="Purrcast：天氣穿搭",
    subtitle="像素角色換裝告訴你天氣",
    promo="像素角色會依照體感溫度換衣服，下雨時撐起雨傘。現在每天的天氣和穿搭都會記在天氣日曆裡，鎖定畫面的時鐘上方也會出現穿好衣服的角色。",
    keywords="雨,雨傘,小工具,穿什麼,天氣預報,貓,像素,鎖定畫面,手錶,穿搭,日曆,可愛",
    description=f"""今天穿什麼？看看角色就知道。

Purrcast 用一隻像素寵物告訴你天氣：牠會依照體感溫度換衣服，下雨時撐起雨傘。不用讀數字，看一眼就明白。全球使用 Apple 天氣預報，韓國使用韓國氣象廳預報。

• 15 種穿搭：從背心到帶毛領帽的羽絨外套，隨體感溫度更換
• 雨傘三種狀態：正在下雨就撐傘，稍後有雨就放進包包，拿不定時會猶豫
• 提前知道雨：例如「15～17時有雨預報」，記得帶傘
• 會動的天空：雲在飄，雨雪落下，星星閃爍，閃電劃過
• 逐小時和 10 天預報，每天都有詳細圖表：氣溫、體感、降雨、風、紫外線、濕度、空氣
• 空氣品質，以及預報比較（Apple 天氣、MET Norway，在韓國還有韓國氣象廳）
• 主畫面和鎖定畫面小工具
• 鎖定畫面時鐘上方一行：穿好衣服的角色和氣溫、位置、雨、紫外線、日出日落、風
• 本週記錄：最近 7 天的天氣和穿搭
• 長按首頁卡片，可以隨意調整順序
• 早晨摘要通知
• 12 種語言，°C / °F，24 小時 / 12 小時，像素字體或一般字體

Purrcast Plus
• 每次有新預報就更新
• 未來 6 小時的雨：什麼時候下、下多少——在 Apple 天氣提供分鐘級預報的地區精確到分鐘
• 下雨或下雪前 1 小時和開始時提醒，鎖定畫面即時動態
• 氣象特報、空氣污染和氣溫變化提醒
• 空氣品質地圖：6 種污染物和每小時懸浮微粒，以及鎖定畫面空氣小工具
• 天氣日曆和每月報告：每天的天氣和穿搭記在日曆上，過去的日子也能逐小時回顧，每月 1 日推送報告和分享卡片
• Apple Watch App 和錶面複雜功能
• 地點數量不限
• 更多角色：阿比西尼亞貓、英國短毛貓，還能取名字

天氣資料：Apple 天氣、韓國氣象廳（KOGL 第一類）、MET Norway（CC BY 4.0）、AirKorea（KOGL 第一類）、OpenWeather

訂閱說明
Plus 是按年或按月自動續訂的訂閱。新訂閱者可能享有免費試用；試用結束後，所選價格會透過你的 Apple 帳號扣款。除非在當期結束前至少 24 小時取消，否則會自動續訂。你可以隨時在「設定 > Apple 帳號 > 訂閱項目」中管理或取消。
使用條款：{TERMS}
隱私權政策：{PRIVACY}""",
    group="Purrcast Plus",
    yearly="Purrcast Plus 年度",
    monthly="Purrcast Plus 月度",
    iap="近期降雨・空氣品質・天氣日曆・Apple Watch・角色",
)
