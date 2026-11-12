//
//  DailyAyah.swift
//  Noor Glass
//
//  The Daily Ayah: a curated list of well-known verses, cycled by
//  the day's ordinal so the same verse shows all day and changes at
//  local midnight. The Arabic text, the Saheeh International
//  English and the Hamidullah French are the app's own bundled
//  texts (quran_text.json / quran_fr.json), extracted verbatim, so
//  the widget, the reminder and the in-app card can never disagree.
//  Fully offline. Target Membership: NoorGlass + NoorGlassWidgets.
//
//  Copyright (c) 2026 c12n Apps
//

import Foundation

struct DailyAyah: Equatable {
    let arabic: String
    let english: String
    let french: String
    let surahEnglish: String
    let surahArabic: String
    let chapter: Int
    let verse: Int

    /// e.g. "Al-Baqarah | 2:152"
    var reference: String { "\(surahEnglish) | \(chapter):\(verse)" }
}

enum DailyAyahs {
    static let all: [DailyAyah] = [
        DailyAyah(arabic: "فَٱذْكُرُونِىٓ أَذْكُرْكُمْ وَٱشْكُرُوا۟ لِى وَلَا تَكْفُرُونِ",
                  english: "So remember Me; I will remember you. And be grateful to Me and do not deny Me.",
                  french: "Souvenez-vous de Moi donc. Je vous récompenserai. Remerciez-Moi et ne soyez pas ingrats envers Moi!",
                  surahEnglish: "Al-Baqara", surahArabic: "البقرة",
                  chapter: 2, verse: 152),
        DailyAyah(arabic: "لَا يُكَلِّفُ ٱللَّهُ نَفْسًا إِلَّا وُسْعَهَا ۚ لَهَا مَا كَسَبَتْ وَعَلَيْهَا مَا ٱكْتَسَبَتْ ۗ رَبَّنَا لَا تُؤَاخِذْنَآ إِن نَّسِينَآ أَوْ أَخْطَأْنَا ۚ رَبَّنَا وَلَا تَحْمِلْ عَلَيْنَآ إِصْرًۭا كَمَا حَمَلْتَهُۥ عَلَى ٱلَّذِينَ مِن قَبْلِنَا ۚ رَبَّنَا وَلَا تُحَمِّلْنَا مَا لَا طَاقَةَ لَنَا بِهِۦ ۖ وَٱعْفُ عَنَّا وَٱغْفِرْ لَنَا وَٱرْحَمْنَآ ۚ أَنتَ مَوْلَىٰنَا فَٱنصُرْنَا عَلَى ٱلْقَوْمِ ٱلْكَٰفِرِينَ",
                  english: "Allah does not charge a soul except [with that within] its capacity. It will have [the consequence of] what [good] it has gained, and it will bear [the consequence of] what [evil] it has earned. \"Our Lord, do not impose blame upon us if we have forgotten or erred. Our Lord, and lay not upon us a burden like that which You laid upon those before us. Our Lord, and burden us not with that which we have no ability to bear. And pardon us; and forgive us; and have mercy upon us. You are our protector, so give us victory over the disbelieving people.\"",
                  french: "Allah n'impose à aucune âme une charge supérieure à sa capacité. Elle sera récompensée du bien qu'elle aura fait, punie du mal qu'elle aura fait. Seigneur, ne nous châtie pas s'il nous arrive d'oublier ou de commettre une erreur. Seigneur! Ne nous charge pas d'un fardeau lourd comme Tu as chargé ceux qui vécurent avant nous. Seigneur! Ne nous impose pas ce que nous ne pouvons supporter, efface nos fautes, pardonne-nous et fais nous miséricorde. Tu es Notre Maître, accorde-nous donc la victoire sur les peuples infidèles.",
                  surahEnglish: "Al-Baqara", surahArabic: "البقرة",
                  chapter: 2, verse: 286),
        DailyAyah(arabic: "إِنَّ مَعَ ٱلْعُسْرِ يُسْرًۭا",
                  english: "Indeed, with hardship [will be] ease.",
                  french: "A côté de la difficulté est, certes, une facilité!",
                  surahEnglish: "Ash-Sharh", surahArabic: "الشرح",
                  chapter: 94, verse: 6),
        DailyAyah(arabic: "وَيَرْزُقْهُ مِنْ حَيْثُ لَا يَحْتَسِبُ ۚ وَمَن يَتَوَكَّلْ عَلَى ٱللَّهِ فَهُوَ حَسْبُهُۥٓ ۚ إِنَّ ٱللَّهَ بَٰلِغُ أَمْرِهِۦ ۚ قَدْ جَعَلَ ٱللَّهُ لِكُلِّ شَىْءٍۢ قَدْرًۭا",
                  english: "And will provide for him from where he does not expect. And whoever relies upon Allah - then He is sufficient for him. Indeed, Allah will accomplish His purpose. Allah has already set for everything a [decreed] extent.",
                  french: "et lui accordera Ses dons par [des moyens] sur lesquels il ne comptait pas. Et quiconque place sa confiance en Allah, Il [Allah] lui suffit. Allah atteint ce qu'Il Se propose, et Allah a assigné une mesure à chaque chose.",
                  surahEnglish: "At-Talaaq", surahArabic: "الطلاق",
                  chapter: 65, verse: 3),
        DailyAyah(arabic: "يَٰٓأَيُّهَا ٱلَّذِينَ ءَامَنُوا۟ ٱسْتَعِينُوا۟ بِٱلصَّبْرِ وَٱلصَّلَوٰةِ ۚ إِنَّ ٱللَّهَ مَعَ ٱلصَّٰبِرِينَ",
                  english: "O you who have believed, seek help through patience and prayer. Indeed, Allah is with the patient.",
                  french: "O les croyants! Cherchez secours dans l'endurance et la Salât. Car Allah est avec ceux qui sont endurants.",
                  surahEnglish: "Al-Baqara", surahArabic: "البقرة",
                  chapter: 2, verse: 153),
        DailyAyah(arabic: "وَلَا تَهِنُوا۟ وَلَا تَحْزَنُوا۟ وَأَنتُمُ ٱلْأَعْلَوْنَ إِن كُنتُم مُّؤْمِنِينَ",
                  english: "So do not weaken and do not grieve, and you will be superior if you are [true] believers.",
                  french: "Ne vous laissez pas battre, ne vous affligez pas alors que vous êtes les supérieurs, si vous êtes de vrais croyants.",
                  surahEnglish: "Aal-i-Imraan", surahArabic: "آل عمران",
                  chapter: 3, verse: 139),
        DailyAyah(arabic: "وَإِذْ تَأَذَّنَ رَبُّكُمْ لَئِن شَكَرْتُمْ لَأَزِيدَنَّكُمْ ۖ وَلَئِن كَفَرْتُمْ إِنَّ عَذَابِى لَشَدِيدٌۭ",
                  english: "And [remember] when your Lord proclaimed, 'If you are grateful, I will surely increase you [in favor]; but if you deny, indeed, My punishment is severe.' \"",
                  french: "Et lorsque votre Seigneur proclama: «Si vous êtes reconnaissants, très certainement J'augmenterai [Mes bienfaits] pour vous. Mais si vous êtes ingrats, Mon châtiment sera terrible».",
                  surahEnglish: "Ibrahim", surahArabic: "إبراهيم",
                  chapter: 14, verse: 7),
        DailyAyah(arabic: "وَإِذَا سَأَلَكَ عِبَادِى عَنِّى فَإِنِّى قَرِيبٌ ۖ أُجِيبُ دَعْوَةَ ٱلدَّاعِ إِذَا دَعَانِ ۖ فَلْيَسْتَجِيبُوا۟ لِى وَلْيُؤْمِنُوا۟ بِى لَعَلَّهُمْ يَرْشُدُونَ",
                  english: "And when My servants ask you, [O Muhammad], concerning Me - indeed I am near. I respond to the invocation of the supplicant when he calls upon Me. So let them respond to Me [by obedience] and believe in Me that they may be [rightly] guided.",
                  french: "Et quand Mes serviteurs t'interrogent sur Moi.. alors Je suis tout proche: Je réponds à l'appel de celui qui Me prie quand il Me prie. Qu'ils répondent à Mon appel, et qu'ils croient en Moi, afin qu'ils soient bien guidés.",
                  surahEnglish: "Al-Baqara", surahArabic: "البقرة",
                  chapter: 2, verse: 186),
        DailyAyah(arabic: "۞ قُلْ يَٰعِبَادِىَ ٱلَّذِينَ أَسْرَفُوا۟ عَلَىٰٓ أَنفُسِهِمْ لَا تَقْنَطُوا۟ مِن رَّحْمَةِ ٱللَّهِ ۚ إِنَّ ٱللَّهَ يَغْفِرُ ٱلذُّنُوبَ جَمِيعًا ۚ إِنَّهُۥ هُوَ ٱلْغَفُورُ ٱلرَّحِيمُ",
                  english: "Say, \"O My servants who have transgressed against themselves [by sinning], do not despair of the mercy of Allah. Indeed, Allah forgives all sins. Indeed, it is He who is the Forgiving, the Merciful.\"",
                  french: "Dis: «O Mes serviteurs qui avez commis des excès à votre propre détriment, ne désespérez pas de la miséricorde d'Allah. Car Allah pardonne tous les péchés. Oui, c'est Lui le Pardonneur, le Très Miséricordieux.",
                  surahEnglish: "Az-Zumar", surahArabic: "الزمر",
                  chapter: 39, verse: 53),
        DailyAyah(arabic: "وَٱلَّذِينَ جَٰهَدُوا۟ فِينَا لَنَهْدِيَنَّهُمْ سُبُلَنَا ۚ وَإِنَّ ٱللَّهَ لَمَعَ ٱلْمُحْسِنِينَ",
                  english: "And those who strive for Us - We will surely guide them to Our ways. And indeed, Allah is with the doers of good.",
                  french: "Et quant à ceux qui luttent pour Notre cause, Nous les guiderons certes sur Nos sentiers. Allah est en vérité avec les bienfaisants.",
                  surahEnglish: "Al-Ankaboot", surahArabic: "العنكبوت",
                  chapter: 29, verse: 69),
        DailyAyah(arabic: "كُتِبَ عَلَيْكُمُ ٱلْقِتَالُ وَهُوَ كُرْهٌۭ لَّكُمْ ۖ وَعَسَىٰٓ أَن تَكْرَهُوا۟ شَيْـًۭٔا وَهُوَ خَيْرٌۭ لَّكُمْ ۖ وَعَسَىٰٓ أَن تُحِبُّوا۟ شَيْـًۭٔا وَهُوَ شَرٌّۭ لَّكُمْ ۗ وَٱللَّهُ يَعْلَمُ وَأَنتُمْ لَا تَعْلَمُونَ",
                  english: "Fighting has been enjoined upon you while it is hateful to you. But perhaps you hate a thing and it is good for you; and perhaps you love a thing and it is bad for you. And Allah Knows, while you know not.",
                  french: "Le combat vous a été prescrit alors qu'il vous est désagréable. Or, il se peut que vous ayez de l'aversion pour une chose alors qu'elle vous est un bien. Et il se peut que vous aimiez une chose alors qu'elle vous est mauvaise. C'est Allah qui sait, alors que vous ne savez pas.",
                  surahEnglish: "Al-Baqara", surahArabic: "البقرة",
                  chapter: 2, verse: 216),
        DailyAyah(arabic: "فَتَعَٰلَى ٱللَّهُ ٱلْمَلِكُ ٱلْحَقُّ ۗ وَلَا تَعْجَلْ بِٱلْقُرْءَانِ مِن قَبْلِ أَن يُقْضَىٰٓ إِلَيْكَ وَحْيُهُۥ ۖ وَقُل رَّبِّ زِدْنِى عِلْمًۭا",
                  english: "So high [above all] is Allah, the Sovereign, the Truth. And, [O Muhammad], do not hasten with [recitation of] the Qur'an before its revelation is completed to you, and say, \"My Lord, increase me in knowledge.\"",
                  french: "Que soit éxalté Allah, le Vrai Souverain! Ne te hâte pas [de réciter] le Coran avant que ne te soit achevée sa révélation. Et dis: «O mon Seigneur, accroît mes connaissances!»",
                  surahEnglish: "Taa-Haa", surahArabic: "طه",
                  chapter: 20, verse: 114),
        DailyAyah(arabic: "أَلَآ إِنَّ أَوْلِيَآءَ ٱللَّهِ لَا خَوْفٌ عَلَيْهِمْ وَلَا هُمْ يَحْزَنُونَ",
                  english: "Unquestionably, [for] the allies of Allah there will be no fear concerning them, nor will they grieve",
                  french: "En vérité, les bien-aimés d'Allah seront à l'abri de toute crainte, et ils ne seront point affligés,",
                  surahEnglish: "Yunus", surahArabic: "يونس",
                  chapter: 10, verse: 62),
        DailyAyah(arabic: "وَٱسْتَعِينُوا۟ بِٱلصَّبْرِ وَٱلصَّلَوٰةِ ۚ وَإِنَّهَا لَكَبِيرَةٌ إِلَّا عَلَى ٱلْخَٰشِعِينَ",
                  english: "And seek help through patience and prayer, and indeed, it is difficult except for the humbly submissive [to Allah]",
                  french: "Et cherchez secours dans l'endurance et la salât: certes, la Salât est une lourde obligation, sauf pour les humbles,",
                  surahEnglish: "Al-Baqara", surahArabic: "البقرة",
                  chapter: 2, verse: 45),
        DailyAyah(arabic: "ٱلَّذِينَ ءَامَنُوا۟ وَتَطْمَئِنُّ قُلُوبُهُم بِذِكْرِ ٱللَّهِ ۗ أَلَا بِذِكْرِ ٱللَّهِ تَطْمَئِنُّ ٱلْقُلُوبُ",
                  english: "Those who have believed and whose hearts are assured by the remembrance of Allah. Unquestionably, by the remembrance of Allah hearts are assured.\"",
                  french: "ceux qui ont cru, et dont les cœurs se tranquillisent à l'évocation d'Allah». Certes, c'est par l'évocation d'Allah que les cœurs se tranquillisent.",
                  surahEnglish: "Ar-Ra'd", surahArabic: "الرعد",
                  chapter: 13, verse: 28),
        DailyAyah(arabic: "فَإِنَّ مَعَ ٱلْعُسْرِ يُسْرًا",
                  english: "For indeed, with hardship [will be] ease.",
                  french: "A côté de la difficulté est, certes, une facilité!",
                  surahEnglish: "Ash-Sharh", surahArabic: "الشرح",
                  chapter: 94, verse: 5),
        DailyAyah(arabic: "وَقَالَ رَبُّكُمُ ٱدْعُونِىٓ أَسْتَجِبْ لَكُمْ ۚ إِنَّ ٱلَّذِينَ يَسْتَكْبِرُونَ عَنْ عِبَادَتِى سَيَدْخُلُونَ جَهَنَّمَ دَاخِرِينَ",
                  english: "And your Lord says, \"Call upon Me; I will respond to you.\" Indeed, those who disdain My worship will enter Hell [rendered] contemptible.",
                  french: "Et votre Seigneur dit: «Appelez-Moi, Je vous répondrai. Ceux qui, par orgueil, se refusent à M'adorer entreront bientôt dans l'Enfer, humiliés».",
                  surahEnglish: "Ghafir", surahArabic: "غافر",
                  chapter: 40, verse: 60),
        DailyAyah(arabic: "إِن يَنصُرْكُمُ ٱللَّهُ فَلَا غَالِبَ لَكُمْ ۖ وَإِن يَخْذُلْكُمْ فَمَن ذَا ٱلَّذِى يَنصُرُكُم مِّنۢ بَعْدِهِۦ ۗ وَعَلَى ٱللَّهِ فَلْيَتَوَكَّلِ ٱلْمُؤْمِنُونَ",
                  english: "If Allah should aid you, no one can overcome you; but if He should forsake you, who is there that can aid you after Him? And upon Allah let the believers rely.",
                  french: "Si Allah vous donne Son secours, nul ne peut vous vaincre. S'Il vous abandonne, qui donc après Lui vous donnera secours? C'est à Allah que les croyants doivent faire confiance.",
                  surahEnglish: "Aal-i-Imraan", surahArabic: "آل عمران",
                  chapter: 3, verse: 160),
        DailyAyah(arabic: "وَٱذْكُرِ ٱسْمَ رَبِّكَ وَتَبَتَّلْ إِلَيْهِ تَبْتِيلًۭا",
                  english: "And remember the name of your Lord and devote yourself to Him with [complete] devotion.",
                  french: "Et rappelle-toi le nom de ton Seigneur et consacre-toi totalement à Lui,",
                  surahEnglish: "Al-Muzzammil", surahArabic: "المزمل",
                  chapter: 73, verse: 8),
        DailyAyah(arabic: "وَنُنَزِّلُ مِنَ ٱلْقُرْءَانِ مَا هُوَ شِفَآءٌۭ وَرَحْمَةٌۭ لِّلْمُؤْمِنِينَ ۙ وَلَا يَزِيدُ ٱلظَّٰلِمِينَ إِلَّا خَسَارًۭا",
                  english: "And We send down of the Qur'an that which is healing and mercy for the believers, but it does not increase the wrongdoers except in loss.",
                  french: "Nous faisons descendre du Coran, ce qui est une guérison et une miséricorde pour les croyants. Cependant, cela ne fait qu'accroître la perdition des injustes.",
                  surahEnglish: "Al-Israa", surahArabic: "الإسراء",
                  chapter: 17, verse: 82),
        DailyAyah(arabic: "أَلَيْسَ ٱللَّهُ بِكَافٍ عَبْدَهُۥ ۖ وَيُخَوِّفُونَكَ بِٱلَّذِينَ مِن دُونِهِۦ ۚ وَمَن يُضْلِلِ ٱللَّهُ فَمَا لَهُۥ مِنْ هَادٍۢ",
                  english: "Is not Allah sufficient for His Servant [Prophet Muhammad]? And [yet], they threaten you with those [they worship] other than Him. And whoever Allah leaves astray - for him there is no guide.",
                  french: "Allah ne suffit-Il pas à Son esclave [comme soutien]? Et ils te font peur avec ce qui est en dehors de Lui. Et quiconque Allah égare n'a point de guide.",
                  surahEnglish: "Az-Zumar", surahArabic: "الزمر",
                  chapter: 39, verse: 36),
        DailyAyah(arabic: "يَٰبَنِىَّ ٱذْهَبُوا۟ فَتَحَسَّسُوا۟ مِن يُوسُفَ وَأَخِيهِ وَلَا تَا۟يْـَٔسُوا۟ مِن رَّوْحِ ٱللَّهِ ۖ إِنَّهُۥ لَا يَا۟يْـَٔسُ مِن رَّوْحِ ٱللَّهِ إِلَّا ٱلْقَوْمُ ٱلْكَٰفِرُونَ",
                  english: "O my sons, go and find out about Joseph and his brother and despair not of relief from Allah. Indeed, no one despairs of relief from Allah except the disbelieving people.\"",
                  french: "O mes fils! Partez et enquérez-vous de Joseph et de son frère. Et ne désespérez pas de la miséricorde d'Allah. Ce sont seulement les gens mécréants qui désespèrent de la miséricorde d'Allah».",
                  surahEnglish: "Yusuf", surahArabic: "يوسف",
                  chapter: 12, verse: 87),
        DailyAyah(arabic: "مَنْ عَمِلَ صَٰلِحًۭا مِّن ذَكَرٍ أَوْ أُنثَىٰ وَهُوَ مُؤْمِنٌۭ فَلَنُحْيِيَنَّهُۥ حَيَوٰةًۭ طَيِّبَةًۭ ۖ وَلَنَجْزِيَنَّهُمْ أَجْرَهُم بِأَحْسَنِ مَا كَانُوا۟ يَعْمَلُونَ",
                  english: "Whoever does righteousness, whether male or female, while he is a believer - We will surely cause him to live a good life, and We will surely give them their reward [in the Hereafter] according to the best of what they used to do.",
                  french: "Quiconque, mâle ou femelle, fait une bonne œuvre tout en étant croyant, Nous lui ferons vivre une bonne vie. Et Nous les récompenserons, certes, en fonction des meilleures de leurs actions.",
                  surahEnglish: "An-Nahl", surahArabic: "النحل",
                  chapter: 16, verse: 97),
        DailyAyah(arabic: "بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ قُلْ هُوَ ٱللَّهُ أَحَدٌ",
                  english: "Say, \"He is Allah, [who is] One,",
                  french: "Dis: «Il est Allah, Unique.",
                  surahEnglish: "Al-Ikhlaas", surahArabic: "الإخلاص",
                  chapter: 112, verse: 1),
        DailyAyah(arabic: "إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ",
                  english: "It is You we worship and You we ask for help.",
                  french: "C'est Toi [Seul] que nous adorons, et c'est Toi [Seul] dont nous implorons secours.",
                  surahEnglish: "Al-Fatiha", surahArabic: "الفاتحة",
                  chapter: 1, verse: 5),
        DailyAyah(arabic: "فَمَن يَعْمَلْ مِثْقَالَ ذَرَّةٍ خَيْرًۭا يَرَهُۥ",
                  english: "So whoever does an atom's weight of good will see it,",
                  french: "Quiconque fait un bien fût-ce du poids d'un atome, le verra,",
                  surahEnglish: "Az-Zalzala", surahArabic: "الزلزلة",
                  chapter: 99, verse: 7),
        DailyAyah(arabic: "وَذَا ٱلنُّونِ إِذ ذَّهَبَ مُغَٰضِبًۭا فَظَنَّ أَن لَّن نَّقْدِرَ عَلَيْهِ فَنَادَىٰ فِى ٱلظُّلُمَٰتِ أَن لَّآ إِلَٰهَ إِلَّآ أَنتَ سُبْحَٰنَكَ إِنِّى كُنتُ مِنَ ٱلظَّٰلِمِينَ",
                  english: "And [mention] the man of the fish, when he went off in anger and thought that We would not decree [anything] upon him. And he called out within the darknesses, \"There is no deity except You; exalted are You. Indeed, I have been of the wrongdoers.\"",
                  french: "Et Dû'n-Nûn (Jonas) quand il partit, irrité. Il pensa que Nous N'allions pas l'éprouver. Puis il fit, dans les ténèbres, l'appel que voici: «Pas de divinité à part Toi! Pureté à Toi! J'ai été vraiment du nombre des injustes».",
                  surahEnglish: "Al-Anbiyaa", surahArabic: "الأنبياء",
                  chapter: 21, verse: 87),
        DailyAyah(arabic: "قَالَ لَا تَخَافَآ ۖ إِنَّنِى مَعَكُمَآ أَسْمَعُ وَأَرَىٰ",
                  english: "[Allah] said, \"Fear not. Indeed, I am with you both; I hear and I see.",
                  french: "Il dit: «Ne craignez rien. Je suis avec vous: J'entends et Je vois.",
                  surahEnglish: "Taa-Haa", surahArabic: "طه",
                  chapter: 20, verse: 46),
    ]

    /// The same verse all day, changing at local midnight: the
    /// day's ordinal picks the verse, so it never repeats two days
    /// running and cycles through the whole list.
    static func ayah(for date: Date) -> DailyAyah {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        return all[day % all.count]
    }
}
