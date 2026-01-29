import 'dart:math';
import 'dart:developer' as developer;

class TextClassifier {
  bool _isInitialized = false;
  final Map<String, List<String>> _debugLog = {};

  // ========== MULTI-LANGUAGE PATTERN ARCHITECTURE ==========
  // [PASTE YOUR _multiLanguagePatterns HERE]
  final Map<String, Map<String, List<String>>> _multiLanguagePatterns = {
    'dangerous': {
      'english': [
        // Bangladeshi location-specific dangerous patterns
        r"(terrorist.*attack.*(dhaka|chittagong|sylhet|rajshahi|khulna|barisal|rangpur))",
        r"(bomb.*(motijheel|gulshan|banani|dhanmondi|uttara|mirpur))",
        r"(gun.*fight.*(bazar|market|haat).*bangladesh)",
        r"(political.*violence.*(awami.*league|bnp|jalabad).*clash)",
        r"(hartal.*violence.*burning.*vehicle|petrol.*bomb)",
        r"(ra.*party.*extortion|kidnap|murder)",
        r"(student.*politics.*violent.*clash.*university)",
        r"(land.*dispute.*murder.*(village|gram))",
        r"(acid.*attack.*(woman|girl).*rejected.*proposal)",
        r"(dowry.*torture.*death|burn.*bride)",
        r"(human.*trafficking.*(cox.*bazar|teknaf|border))",
        r"(smuggling.*violence.*(benapole|sonamasjid|border))",
        r"(robbery.*(armed).*(sonali.*bank|janata.*bank|brac.*bank))",
        r"(police.*firing.*(protest|agitation).*killed)",
        r"(factory.*fire.*(gazipur|narayanganj|savar).*trapped)",
        r"(building.*collapse.*(rana.*plaza|shahbagh|old.*dhaka))",
        r"(ferry.*capsize.*(padma|meghna|jamuna|river))",
        r"(road.*accident.*(bus.*truck).*multiple.*deaths)",
        r"(lynching.*(thief|suspected).*mob.*violence)",
        r"(communal.*violence.*(temple|mosque|puja).*attack)",
        r"(cyber.*crime.*(bank.*hack|mobile.*financial.*service.*fraud))",
        r"(attack.*with.*(gun|knife|weapon).*(people|person|victim))",
        r"(shooting.*in.*(area|place|location).*(people|person))",
        r"(bomb.*explosion.*(area|place).*injured.*people)",
        r"(murder.*happened.*(place|area).*killed.*person)",
        r"(violent.*attack.*(group|gang).*using.*weapons)",

        // General dangerous patterns
        r"(active.*shooter.*(mall|school|university|market))",
        r"(multiple.*explosions.*(city|area|building))",
        r"(hostage.*situation.*(bank|school|hospital))",
        r"(mass.*casualty.*(incident|event|accident))",
        r"(immediate.*danger.*(evacuate|run|hide))",
        r"(urgent.*help.*needed.*(bleeding|injured|dying))",
        r"(terror.*attack.*(planned|executed|ongoing))",
        r"(suicide.*bomb.*(vest|car|truck))",
        r"(chemical.*attack.*(gas|poison|toxic))",
        r"(nuclear.*threat.*(material|device|plant))",
        r"(biological.*weapon.*(release|threat|attack))",
        r"(epidemic.*outbreak.*(spreading|contagious|deadly))",
        r"(natural.*disaster.*(earthquake|flood|cyclone|landslide))",
      ],
      'banglish': [
        r"(terrorist.*attack.*(dhaka|chittagong|sylhet|rajshahi|khulna|barishal|rongpur))",
        r"(bomb.*(motijheel|gulshan|banani|dhanmondi|uttara|mirpur))",
        r"(gun.*fight.*(bazar|market|haat).*bangladesh)",
        r"(mar.*diyeche|mara.*gelo|khun.*hoiche|khoon.*kora)",
        r"(laash.*paoa|dead.*body|morto.*shorir)",
        r"(boma.*hattal|bomb.*attack|blasting.*hoise)",
        r"(guli.*chalu|shooting.*hoise|fire.*kora)",
        r"(acid.*attack.*(meye|woman).*proposal.*reject)",
        r"(dowry.*torture.*death|burn.*bou)",
        r"(human.*trafficking.*(coxbazar|teknaf|border))",
        r"(smuggling.*violence.*(benapole|sonamasjid|border))",
        r"(robbery.*(armed).*(sonali.*bank|janata.*bank|brac.*bank))",
        r"(police.*firing.*(protest|agitation).*mara.*gelo)",
        r"(factory.*fire.*(gazipur|narayanganj|savar).*lock)",
        r"(building.*collapse.*(rana.*plaza|shahbagh|old.*dhaka))",
        r"(ferry.*capsize.*(padma|meghna|jamuna|nod))",
        r"(road.*accident.*(bus.*truck).*onek.*mara.*gelo)",
        r"(lynching.*(chor|suspected).*mob.*violence)",
        r"(communal.*violence.*(mondir|mosque|puja).*attack)",
        r"(cyber.*crime.*(bank.*hack|mobile.*financial.*service.*fraud))",
        r"(attack.*with.*(gun|chaku|weapon).*(manush|person))",
        r"(shooting.*(place|location).*(people|person))",
        r"(bomb.*blast.*(place).*injured.*people)",
        r"(murder.*hoise.*(place).*mara.*gelo)",
        r"(violent.*attack.*(group|gang).*weapon.*use)",
      ],
      'bangla': [
        r"(সন্ত্রাসী.*হামলা.*(ঢাকা|চট্টগ্রাম|সিলেট|রাজশাহী|খুলনা|বরিশাল|রংপুর))",
        r"(বোমা.*(মতিঝিল|গুলশান|বনানী|ধানমন্ডি|উত্তরা|মিরপুর))",
        r"(গোলাগুলি.*(বাজার|মার্কেট|হাট).*বাংলাদেশ)",
        r"(মেরে.*দিয়েছে|মারা.*গেছে|খুন.*হয়েছে|খুন.*করা)",
        r"(লাশ.*পাওয়া|মৃত.*দেহ|মরদ.*শরীর)",
        r"(বোমা.*হামলা|ব্লাস্টিং.*হয়েছে)",
        r"(গুলি.*চালু|শুটিং.*হয়েছে|ফায়ার.*করা)",
        r"(এসিড.*আক্রমণ.*(মেয়ে|মহিলা).*প্রপোজাল.*রিজেক্ট)",
        r"(দাবন.*নির্যাতন.*মৃত্যু|পোড়া.*বউ)",
        r"(মানব.*পাচার.*(কক্সবাজার|টেকনাফ|বর্ডার))",
        r"(চোরাচালান.*সহিংসতা.*(বেনাপোল|শনিমসজিদ|বর্ডার))",
        r"(ডাকাতি.*(সশস্ত্র).*(সোনালী.*ব্যাংক|জনতা.*ব্যাংক|ব্র্যাক.*ব্যাংক))",
        r"(পুলিশ.*ফায়ারিং.*(বিক্ষোভ|আন্দোলন).*মারা.*গেছে)",
        r"(কারখানা.*আগুন.*(গাজীপুর|নারায়ণগঞ্জ|সাভার).*আটকা)",
        r"(বিল্ডিং.*ধস.*(রানা.*প্লাজা|শাহবাগ|পুরান.*ঢাকা))",
        r"(ফেরি.*ডুবি.*(পদ্মা|মেঘনা|যমুনা|নদী))",
        r"(সড়ক.*দুর্ঘটনা.*(বাস.*ট্রাক).*অনেক.*মারা.*গেছে)",
        r"(লিঞ্চিং.*(চোর|সন্দেহ).*ভিড়.*সহিংসতা)",
        r"(সাম্প্রদায়িক.*সহিংসতা.*(মন্দির|মসজিদ|পূজা).*আক্রমণ)",
        r"(সাইবার.*অপরাধ.*(ব্যাংক.*হ্যাক|মোবাইল.*আর্থিক.*সেবা.*জালিয়াতি))",
        r"(আক্রমণ.*(বন্দুক|ছুরি|অস্ত্র).*(মানুষ|ব্যক্তি|শিকার))",
        r"(গুলি.*চালানো.*(স্থান|জায়গা).*(মানুষ|ব্যক্তি))",
        r"(বোমা.*বিস্ফোরণ.*(স্থান).*আহত.*মানুষ)",
        r"(খুন.*হয়েছে.*(স্থান).*মারা.*গেছে.*ব্যক্তি)",
        r"(সহিংস.*আক্রমণ.*(গ্রুপ|গ্যাং).*অস্ত্র.*ব্যবহার)",
      ],
    },
    'suspicious': {
      'english': [
        // Bangladeshi context suspicious activities
        r"(corruption.*(government.*official|tender|project).*bribe)",
        r"(illegal.*(land.*grabbing|filling|occupation).*powerful.*person)",
        r"(drug.*party.*(banani|gulshan|dhanmondi).*youth)",
        r"(fake.*degree.*(university|college).*certificate)",
        r"(question.*leak.*(hsc|ssc|admission).*test)",
        r"(tender.*manipulation.*(govt|municipality|city.*corporation))",
        r"(money.*laundering.*(hundi|informal.*channel).*abroad)",
        r"(visa.*fraud.*(middleman|agent).*foreign.*employment)",
        r"(human.*trafficking.*(promise.*job).*middle.*east)",
        r"(organ.*trade.*(kidney|liver).*poor.*donor)",
        r"(child.*labor.*(factory|shop|house).*underage)",
        r"(forced.*prostitution.*(brothel|hotel).*minor)",
        r"(illegal.*factory.*(chemical|dyeing).*river.*pollution)",
        r"(fake.*medicine.*(company|pharmacy).*expired)",
        r"(adulterated.*food.*(formal|fish|vegetable).*chemical)",
        r"(hiding.*weapons?.*(car|vehicle).*(gulshan|banani|dhanmondi|uttara|mirpur))",
        r"(youths?.*suspicious.*behav.*(night|late|11|12|1|2).*(pm|o'clock|night))",
        r"(group.*of.*people.*acting.*suspicious.*(park|lake|area))",
        r"(someone.*hiding.*something.*(car|bag).*looks.*dangerous)",
        r"(suspicious.*activity.*(night|evening).*people.*gathering)",

        // General suspicious patterns
        r"(suspicious.*package.*(unattended|abandoned|wires))",
        r"(unusual.*activity.*(midnight|odd.*hours|secret))",
        r"(person.*loitering.*(school|playground|bank))",
        r"(vehicle.*circling.*(neighborhood|block|repeatedly))",
        r"(peeping.*tom.*(window|bathroom|privacy))",
        r"(trespassing.*(private.*property|restricted.*area))",
        r"(breaking.*entering.*(attempted|successful))",
        r"(drug.*deal.*(observed|witnessed|transaction))",
        r"(prostitution.*(activity|solicitation|visible))",
        r"(human.*trafficking.*(forced|labor|exploitation))",
        r"(child.*exploitation.*(underage|abuse|material))",
        r"(elder.*abuse.*(neglect|mistreatment|financial))",
        r"(animal.*cruelty.*(abuse|neglect|fighting))",
        r"(vandalism.*(graffiti|property.*damage|destruction))",
        r"(arson.*attempt.*(fire|flammable|accelerant))",
      ],
      'banglish': [
        r"(corruption.*(government.*official|tender|project).*bribe)",
        r"(illegal.*(land.*grabbing|filling|occupation).*powerful.*person)",
        r"(drug.*party.*(banani|gulshan|dhanmondi).*youth)",
        r"(fake.*degree.*(university|college).*certificate)",
        r"(question.*leak.*(hsc|ssc|admission).*test)",
        r"(tender.*manipulation.*(govt|municipality|city.*corporation))",
        r"(money.*laundering.*(hundi|informal.*channel).*abroad)",
        r"(visa.*fraud.*(middleman|agent).*foreign.*employment)",
        r"(human.*trafficking.*(promise.*job).*middle.*east)",
        r"(organ.*trade.*(kidney|liver).*poor.*donor)",
        r"(child.*labor.*(factory|shop|house).*underage)",
        r"(forced.*prostitution.*(brothel|hotel).*minor)",
        r"(illegal.*factory.*(chemical|dyeing).*river.*pollution)",
        r"(fake.*medicine.*(company|pharmacy).*expired)",
        r"(adulterated.*food.*(formal|fish|vegetable).*chemical)",
        r"(hiding.*weapons?.*(car|vehicle).*(gulshan|banani|dhanmondi|uttara|mirpur))",
        r"(youths?.*suspicious.*behav.*(night|late|11|12|1|2).*(pm|o'clock|night))",
        r"(group.*of.*people.*acting.*suspicious.*(park|lake|area))",
        r"(someone.*hiding.*something.*(car|bag).*looks.*dangerous)",
        r"(suspicious.*activity.*(night|evening).*people.*gathering)",
      ],
      'bangla': [
        r"(দুর্নীতি.*(সরকারী.*কর্মকর্তা|টেন্ডার|প্রকল্প).*ঘুষ)",
        r"(অবৈধ.*(জমি.*দখল|ভরাট|অধিগ্রহণ).*ক্ষমতাশালী.*ব্যক্তি)",
        r"(ড্রাগ.*পার্টি.*(বনানী|গুলশান|ধানমন্ডি).*যুবক)",
        r"(জাল.*ডিগ্রি.*(বিশ্ববিদ্যালয়|কলেজ).*সনদ)",
        r"(প্রশ্ন.*ফাঁস.*(এইচএসসি|এসএসসি|ভর্তি).*পরীক্ষা)",
        r"(টেন্ডার.*ক manipulations.*(সরকার|পৌরসভা|সিটি.*কর্পোরেশন))",
        r"(মoney.*পাচার.*(হুন্ডি|অনানুষ্ঠানিক.*চ্যানেল).*বিদেশ)",
        r"(ভিসা.*জালিয়াতি.*(মধ্যস্বত্বভোগী|এজেন্ট).*বিদেশ.*চাকরি)",
        r"(মানব.*পাচার.*(চাকরির.*প্রতিশ্রুতি).*মধ্য.*প্রাচ্য)",
        r"(অঙ্গ.*ব্যবসা.*(কিডনি|লিভার).*দরিদ্র.*দাতা)",
        r"(শিশু.*শ্রম.*(কারখানা|দোকান|বাড়ি).*অপ্রাপ্তবয়স্ক)",
        r"(জোরপূর্বক.*পতিতাবৃত্তি.*(পতিতালয়|হোটেল).*নাবালক)",
        r"(অবৈধ.*কারখানা.*(রাসায়নিক|রং).*নদী.*দূষণ)",
        r"(জাল.*ওষুধ.*(কোম্পানি|ফার্মেসি).*মেয়াদোত্তীর্ণ)",
        r"(ভেজাল.*খাদ্য.*(ফরমালিন|মাছ|সবজি).*রাসায়নিক)",
        r"(লুকিয়ে.*অস্ত্র.*(গাড়ি|যান).*(গুলশান|বনানী|ধানমন্ডি|উত্তরা|মিরপুর))",
        r"(যুবক.*সন্দেহজনক.*আচরণ.*(রাত|দেরি|১১|১২|১|2).*(রাত))",
        r"(মানুষের.*দল.*সন্দেহজনক.*কাজ.*(পার্ক|লেক|এলাকা))",
        r"(কেউ.*লুকিয়ে.*রাখছে.*(গাড়ি|ব্যাগ).*বিপজ্জনক)",
        r"(সন্দেহজনক.*কার্যকলাপ.*(রাত|সন্ধ্যা).*মানুষ.*জমায়েত)",
      ],
    },
    'fake': {
      'english': [
        // Psychological fake indicators
        r"(just.*(kidding|joking|messing|testing|practicing))",
        r"(lol.*(nothing.*real|false|prank|hoax|gag))",
        r"(test.*(message|report|system|app|functionality))",
        r"(fake.*(news|story|incident|event|situation))",
        r"(prank.*(friend|brother|sister|cousin|colleague))",
        r"(not.*real.*(just.*checking|making.*sure|curious))",
        r"(money.*(reward|payment|tk|lakh|crore).*urgent)",
        r"(tomorrow.*will.*(happen|occur|take.*place).*crime)",
        r"(future.*(prediction|forecast|will.*happen).*incident)",
        r"(social.*experiment.*(research|study|project|thesis))",
        r"(movie.*(shoot|scene|filming|production|drama))",
        r"(dream.*(nightmare|hallucination|imagination))",
        r"(drunk.*(intoxicated|alcohol|substance).*reporting)",
        r"(bored.*(nothing.*to.*do|just.*for.*fun|entertainment))",
        r"(attention.*seeking.*(want.*to.*see.*reaction|views))",

        // Inconsistency indicators (psychological red flags)
        r"(but.*not.*(serious|real|true|happening))",
        r"(actually.*(false|fake|joke|prank|lie))",
        r"(confused.*(not.*sure|might.*be|possibly).*incident)",
        r"(heard.*from.*(friend|relative).*not.*verified)",
        r"(rumor.*(spreading|circulating).*not.*confirmed)",
        r"(maybe.*(happened|occurred).*not.*certain)",
        r"(could.*be.*(wrong|mistaken|incorrect).*information)",
        r"(dont.*(know|remember).*exactly.*what.*happened)",

        // Bangladeshi specific fake patterns
        r"(taka.*(lakh|crore).*reward.*for.*reporting)",
        r"(bdt.*(money|payment).*urgent.*need)",
        r"(mobile.*(recharge|balance).*send.*money)",
        r"(exam.*(question|paper).*leak.*fake.*news)",
        r"(celebrity.*(death|accident).*false.*rumor)",
        r"(government.*(change|policy).*fake.*notification)",

        // IMPROBABILITY PATTERNS (NEW):
        r"(invisible.*(man|woman|person|thief).*(stealing|robbing|attacking))",
        r"(alien.*(attack|robbery|abduction|spaceship))",
        r"(ghost.*(haunting|killing|attacking|possessing))",
        r"(magic.*(wand|spell|curse).*crime)",
        r"(superhero.*(saved|rescued|stopped).*crime)",
        r"(time.*travel.*(crime|theft|murder))",
        r"(flying.*(without.*wings|like.*superman).*crime)",
        r"(mind.*control.*(device|machine).*crime)",
        r"(teleport.*(robbery|escape|theft))",
        r"(became.*invisible.*(commit|escape))",
        r"(levitat.*(crime|escape|theft))",
        r"(psychic.*(power|ability).*crime)",
        r"(vampire.*werewolf.*(attack|bite))",
        r"(zombie.*apocalypse.*attack)",
        r"(dragon.*unicorn.*(attack|theft))",
        r"(fairy.*mermaid.*(crime|magic))",
        r"(extraterrestrial.*(abduction|attack))",
        r"(ufo.*(sighting|abduction|attack))",
        r"(paranormal.*(activity|event).*crime)",
        r"(haunted.*(house|place).*murder)",
        r"(possessed.*(person|object).*crime)",
        r"(cursed.*(object|place).*death)",
        r"(mythical.*creature.*attack)",
        r"(cartoon.*character.*real.*life)",
        r"(video.*game.*character.*real)",
        r"(movie.*character.*real.*world)",
        r"(physically.*impossible.*(crime|event))",
        r"(scientifically.*impossible.*happened)",
        r"(against.*laws.*of.*physics.*happened)",
        r"(magically.*(appeared|disappeared|vanished))",
        r"(impossible.*for.*human.*to.*do)",
        r"(supernatural.*power.*used.*for.*crime)",
        r"(clearly.*fake.*(story|report|incident))",
        r"(obviously.*not.*real.*(crime|incident))",
        r"(sounds.*like.*(movie|fiction|fantasy))",
        r"(this.*must.*be.*(joke|prank|fake))",
        r"(unbelievable.*(story|claim|incident))",
      ],
      'banglish': [
        r"(majak.*korchi|jok.*korchi|test.*korchi|practice.*korchi)",
        r"(haha.*(kisuta.*real.*na|false|bhul|prank))",
        r"(invisible.*(manush|chor).*(churi|attack))",
        r"(alien.*(attack|churi|kidnap|jahaj))",
        r"(bhut.*(attack|mara|possession))",
        r"(jadu.*(chhari|mantra).*apradh)",
        r"(superhero.*(bachai|stop).*apradh)",
        r"(time.*travel.*(murder|churi))",
        r"(urte.*urte.*(churi|attack))",
        r"(mind.*control.*(jor|yantra).*apradh)",
        r"(teleport.*(churi|escape))",
        r"(invisible.*hoia.*(churi|escape))",
        r"(upore.*uthse.*(churi|escape))",
        r"(psychic.*(shakti|power).*apradh)",
        r"(blood.*piya.*rakshas.*attack)",
        r"(zombie.*world.*attack)",
        r"(dragon.*unicorn.*attack)",
        r"(fairy.*mermaid.*apradh)",
        r"(alien.*bhut.*(kidnap|attack))",
        r"(ufo.*(dekha|attack|kidnap))",
        r"(paranormal.*(ghotona|activity).*apradh)",
        r"(bhutoya.*bari.*murder)",
        r"(possession.*hoise.*apradh)",
        r"(curse.*lagse.*murder)",
        r"(mythical.*jontu.*attack)",
        r"(cartoon.*character.*real)",
        r"(video.*game.*character.*real)",
        r"(movie.*character.*real)",
        r"(physically.*impossible.*(apradh|ghotona))",
        r"(scientifically.*impossible.*hoise)",
        r"(physics.*er.*law.*break.*kora)",
        r"(magically.*(haria|joma|disappear))",
        r"(human.*er.*ability.*er.*baire)",
        r"(supernatural.*power.*use.*apradh)",
        r"(clearly.*fake.*(golpo|report))",
        r"(obviously.*real.*na.*(apradh|ghotona))",
        r"(movie.*r.*moto.*(golpo|ghotona))",
        r"(eta.*(majak|prank|fake))",
        r"(bisshash.*kora.*jai.*na.*(golpo|claim))",
      ],
      'bangla': [
        r"(মজা.*করছি|জোক.*করছি|টেস্ট.*করছি|প্র্যাকটিস.*করছি)",
        r"(হাহা.*(কিছুটা.*রিয়েল.*না|ফলস|ভুল|প্র্যাঙ্ক))",
        r"(অদৃশ্য.*(মানুষ|চোর).*(চুরি|আক্রমণ))",
        r"(এলিয়েন.*(আক্রমণ|চুরি|অপহরণ|জাহাজ))",
        r"(ভূত.*(আক্রমণ|মারা|দখল))",
        r"(জাদু.*(ছড়ি|মন্ত্র).*অপরাধ)",
        r"(সুপারহিরো.*(বাঁচাই|স্টপ).*অপরাধ)",
        r"(টাইম.*ট্রাভেল.*(খুন|চুরি))",
        r"(উড়ে.*উড়ে.*(চুরি|আক্রমণ))",
        r"(মাইন্ড.*কন্ট্রোল.*(জোর|যন্ত্র).*অপরাধ)",
        r"(টেলিপোর্ট.*(চুরি|এস্কেপ))",
        r"(অদৃশ্য.*হয়ে.*(চুরি|এস্কেপ))",
        r"(উপরে.*উঠেছে.*(চুরি|এস্কেপ))",
        r"(সাইকিক.*(শক্তি|পাওয়ার).*অপরাধ)",
        r"(রক্ত.*পিওয়া.*রাক্ষস.*আক্রমণ)",
        r"(জোম্বি.*বিশ্ব.*আক্রমণ)",
        r"(ড্রাগন.*ইউনিকর্ন.*আক্রমণ)",
        r"(পরী.*মৎস্যকন্যা.*অপরাধ)",
        r"(এলিয়েন.*ভূত.*(অপহরণ|আক্রমণ))",
        r"(ইউএফও.*(দেখা|আক্রমণ|অপহরণ))",
        r"(প্যারানরমাল.*(ঘটনা|অ্যাক্টিভিটি).*অপরাধ)",
        r"(ভূতুড়ে.*বাড়ি.*খুন)",
        r"(দখল.*হয়েছে.*অপরাধ)",
        r"(অভিশাপ.*লাগেছে.*খুন)",
        r"(পৌরাণিক.*প্রাণী.*আক্রমণ)",
        r"(কার্টুন.*চরিত্র.*রিয়েল)",
        r"(ভিডিও.*গেম.*চরিত্র.*রিয়েল)",
        r"(মুভি.*চরিত্র.*রিয়েল)",
        r"(শারীরিকভাবে.*অসম্ভব.*(অপরাধ|ঘটনা))",
        r"(বৈজ্ঞানিকভাবে.*অসম্ভব.*হয়েছে)",
        r"(পদার্থবিদ্যার.*নিয়ম.*ভঙ্গ.*করা)",
        r"(জাদুবলে.*(হারিয়ে|জমা|ডিসএপিয়ার))",
        r"(মানুষের.*ক্ষমতার.*বাইরে)",
        r"(অতিপ্রাকৃত.*শক্তি.*ব্যবহার.*অপরাধ)",
        r"(স্পষ্টতই.*ফেইক.*(গল্প|রিপোর্ট))",
        r"(স্পষ্টতই.*রিয়েল.*না.*(অপরাধ|ঘটনা))",
        r"(মুভির.*মতো.*(গল্প|ঘটনা))",
        r"(এটা.*(মজা|প্র্যাঙ্ক|ফেইক))",
        r"(বিশ্বাস.*করা.*যায়.*না.*(গল্প|দাবি))",
      ],
    },
    'theft': {
      'english': [
        // Bangladeshi theft patterns
        r"(mobile.*snatch.*(by.*bike|motorcycle).*running)",
        r"(purse.*snatch.*(bazar|market|crowded.*area))",
        r"(car.*theft.*(toyota.*premio|honda.*city).*parked)",
        r"(bike.*theft.*(yamaha|suzuki|runner).*college.*area)",
        r"(burglary.*(house|shop).*broken.*lock|grill)",
        r"(pickpocket.*(bus|launch|train|crowd).*wallet)",
        r"(bank.*account.*hack.*(dbbl|brac|bkash|nagad))",
        r"(credit.*card.*fraud.*(shopping|online.*purchase))",
        r"(gold.*chain.*snatch.*(neck|hand).*force)",
        r"(cattle.*theft.*(village|farm).*night)",
        r"(crop.*theft.*(paddy|jute|vegetable).*field)",
        r"(fish.*theft.*(pond|enclosure).*net)",
        r"(mobile.*snatch.*(motorcycle|bike).*(mirpur|uttara|gulshan|dhaka))",
        r"(robbers?.*motorcycle.*(helmet|bike).*snatch.*(phone|mobile|purse))",
        r"(stolen.*(phone|wallet|bag).*(bike|motorcycle).*escaped)",
        r"(snatched.*from.*(hand|person).*by.*(bikers|riders))",

        // General theft patterns
        r"(stolen.*(phone|wallet|laptop|jewelry|car))",
        r"(robbery.*(armed|masked|gun|knife).*store)",
        r"(burglary.*(break.*in|entered.*illegally).*home)",
        r"(shoplifting.*(caught|observed|detected).*store)",
        r"(pickpocket.*(operating|active|working).*area)",
        r"(identity.*theft.*(personal.*information|documents))",
        r"(credit.*card.*fraud.*(unauthorized|stolen|cloned))",
        r"(bank.*fraud.*(account|transfer|withdrawal))",
        r"(embezzlement.*(company|organization|funds))",
        r"(intellectual.*property.*theft.*(patent|copyright))",
      ],
      'banglish': [
        r"(mobile.*snatch.*(bike|motorcycle).*running)",
        r"(purse.*snatch.*(bazar|market|crowded.*place))",
        r"(car.*churi.*(toyota.*premio|honda.*city).*parked)",
        r"(bike.*churi.*(yamaha|suzuki|runner).*college.*area)",
        r"(burglary.*(house|shop).*broken.*lock|grill)",
        r"(pickpocket.*(bus|launch|train|crowd).*wallet)",
        r"(bank.*account.*hack.*(dbbl|brac|bkash|nagad))",
        r"(credit.*card.*fraud.*(shopping|online.*purchase))",
        r"(gold.*chain.*snatch.*(neck|hand).*force)",
        r"(cattle.*churi.*(village|farm).*night)",
        r"(crop.*churi.*(paddy|jute|vegetable).*field)",
        r"(fish.*churi.*(pond|enclosure).*net)",
        r"(mobile.*snatch.*(motorcycle|bike).*(mirpur|uttara|gulshan|dhaka))",
        r"(robbers?.*motorcycle.*(helmet|bike).*snatch.*(phone|mobile|purse))",
        r"(stolen.*(phone|wallet|bag).*(bike|motorcycle).*escaped)",
        r"(snatched.*from.*(hand|person).*by.*(bikers|riders))",
      ],
      'bangla': [
        r"(মোবাইল.*ছিনতাই.*(বাইক|মোটরসাইকেল).*চলে.*যাচ্ছে)",
        r"(পার্স.*ছিনতাই.*(বাজার|মার্কেট|ভিড়.*জায়গা))",
        r"(গাড়ি.*চুরি.*(টয়োটা.*প্রেমিও|হোন্ডা.*সিটি).*পার্কড)",
        r"(বাইক.*চুরি.*(ইয়ামাহা|সুজুকি|রানার).*কলেজ.*এলাকা)",
        r"(বুর্গলারি.*(বাড়ি|দোকান).*ভাঙা.*তালা|গ্রিল)",
        r"(পিকপকেট.*(বাস|লঞ্চ|ট্রেন|ভিড়).*ওয়ালেট)",
        r"(ব্যাংক.*একাউন্ট.*হ্যাক.*(ডিবিএল|ব্র্যাক|বিকাশ|নগদ))",
        r"(ক্রেডিট.*কার্ড.*জালিয়াতি.*(শপিং|অনলাইন.*ক্রয়))",
        r"(গোল্ড.*চেইন.*ছিনতাই.*(ঘাড়|হাত).*জোর)",
        r"(গবাদি.*পশু.*চুরি.*(গ্রাম|খামার).*রাত)",
        r"(ফসল.*চুরি.*(ধান|পাট|সবজি).*ক্ষেত)",
        r"(মাছ.*চুরি.*(পুকুর|এনক্লোজার).*জাল)",
        r"(মোবাইল.*ছিনতাই.*(মোটরসাইকেল|বাইক).*(মিরপুর|উত্তরা|গুলশান|ঢাকা))",
        r"(ডাকাত.*মোটরসাইকেল.*(হেলমেট|বাইক).*ছিনতাই.*(ফোন|মোবাইল|পার্স))",
        r"(চুরি.*(ফোন|ওয়ালেট|ব্যাগ).*(বাইক|মোটরসাইকেল).*পালিয়েছে)",
        r"(ছিনিয়ে.*নিয়েছে.*(হাত|ব্যক্তি).*(বাইকার|রাইডার))",
      ],
    },
    'assault': {
      'english': [
        // Bangladeshi assault patterns
        r"(eve.*teasing.*(girl|woman).*street.*harassment)",
        r"(domestic.*violence.*(husband.*wife|in.*laws))",
        r"(political.*assault.*(opponent|rival).*beat.*up)",
        r"(student.*fight.*(college|university).*group.*clash)",
        r"(land.*dispute.*fight.*(neighbor|relative).*injured)",
        r"(road.*rage.*(driver|passenger).*physical.*fight)",
        r"(workplace.*harassment.*(boss.*employee|colleague))",
        r"(acid.*violence.*(rejection|revenge|family.*dispute))",
        r"(dowry.*violence.*(torture|beat|burn).*wife)",
        r"(child.*abuse.*(teacher.*student|relative.*child))",
        r"(fighting.*(sticks?|rods?).*(college|university).*bleeding)",
        r"(groups?.*fight.*(dhaka.*college|university).*violent.*bleeding)",
        r"(people.*fighting.*with.*(sticks|rods|weapons).*injured)",
        r"(attack.*with.*(stick|rod).*caused.*bleeding)",
        r"(violent.*fight.*between.*groups.*(college|area))",

        // General assault patterns
        r"(physical.*assault.*(punched|kicked|beaten).*person)",
        r"(sexual.*assault.*(rape|molestation|harassment))",
        r"(domestic.*violence.*(spouse|partner|family))",
        r"(child.*abuse.*(physical|sexual|emotional|neglect))",
        r"(elder.*abuse.*(physical|financial|emotional))",
        r"(gang.*assault.*(multiple.*attackers|group.*violence))",
        r"(knife.*attack.*(stabbed|cut|slashed).*victim)",
        r"(gun.*attack.*(shot|fired|wounded).*person)",
        r"(acid.*attack.*(chemical|burn|disfigurement))",
        r"(verbal.*assault.*(threats|intimidation|harassment))",
      ],
      'banglish': [
        r"(eve.*teasing.*(girl|woman).*street.*harassment)",
        r"(domestic.*violence.*(husband.*wife|in.*laws))",
        r"(political.*assault.*(opponent|rival).*beat.*up)",
        r"(student.*fight.*(college|university).*group.*clash)",
        r"(land.*dispute.*fight.*(neighbor|relative).*injured)",
        r"(road.*rage.*(driver|passenger).*physical.*fight)",
        r"(workplace.*harassment.*(boss.*employee|colleague))",
        r"(acid.*violence.*(rejection|revenge|family.*dispute))",
        r"(dowry.*violence.*(torture|beat|burn).*wife)",
        r"(child.*abuse.*(teacher.*student|relative.*child))",
        r"(fighting.*(sticks?|rods?).*(college|university).*bleeding)",
        r"(groups?.*fight.*(dhaka.*college|university).*violent.*bleeding)",
        r"(people.*fighting.*with.*(sticks|rods|weapons).*injured)",
        r"(attack.*with.*(stick|rod).*caused.*bleeding)",
        r"(violent.*fight.*between.*groups.*(college|area))",
      ],
      'bangla': [
        r"(ইভ.*টিজিং.*(মেয়ে|মহিলা).*রাস্তা.*হয়রানি)",
        r"(গৃহ.*সহিংসতা.*(স্বামী.*স্ত্রী|শ্বশুরবাড়ি))",
        r"(রাজনৈতিক.*আক্রমণ.*(প্রতিদ্বন্দ্বী|প্রতিপক্ষ).*মারধর)",
        r"(ছাত্র.*ঝগড়া.*(কলেজ|বিশ্ববিদ্যালয়).*গ্রুপ.*সংঘর্ষ)",
        r"(জমি.*বিবাদ.*ঝগড়া.*(প্রতিবেশী|আত্মীয়).*আহত)",
        r"(রাস্তা.*রাগ.*(ড্রাইভার|যাত্রী).*শারীরিক.*লড়াই)",
        r"(কর্মক্ষেত্র.*হয়রানি.*(বস.*কর্মচারী|সহকর্মী))",
        r"(এসিড.*সহিংসতা.*(প্রস্তাব.*প্রত্যাখ্যান|প্রতিশোধ|পরিবার.*বিবাদ))",
        r"(দাবন.*সহিংসতা.*(নির্যাতন|মারা|জ্বালানো).*স্ত্রী)",
        r"(শিশু.*নির্যাতন.*(শিক্ষক.*ছাত্র|আত্মীয়.*শিশু))",
        r"(লড়াই.*(লাঠি|রড).*(কলেজ|বিশ্ববিদ্যালয়).*রক্তপাত)",
        r"(গ্রুপ.*লড়াই.*(ঢাকা.*কলেজ|বিশ্ববিদ্যালয়).*সহিংস.*রক্তপাত)",
        r"(মানুষ.*লড়াই.*(লাঠি|রড|অস্ত্র).*আহত)",
        r"(আক্রমণ.*(লাঠি|রড).*রক্তপাত.*সৃষ্টি)",
        r"(সহিংস.*লড়াই.*গ্রুপ.*মধ্যে.*(কলেজ|এলাকা))",
      ],
    },
    'vandalism': {
      'english': [
        // Bangladeshi vandalism patterns
        r"(political.*graffiti.*(wall|building|poster).*party)",
        r"(bus.*burn.*(hartal|protest).*petrol.*bomb)",
        r"(statue.*damage.*(public.*property|monument))",
        r"(school.*vandalism.*(classroom|furniture).*broken)",
        r"(temple.*mosque.*damage.*(religious.*tension))",
        r"(road.*block.*(tree|tire|stone).*protest)",
        r"(traffic.*signal.*break.*(light|pole).*damaged)",
        r"(government.*office.*damage.*(chair|table|window))",
        r"(youths?.*broke.*sculpture.*(shahbagh|university).*spray.*paint)",
        r"(vandalism.*statue.*(public.*property|monument).*damage)",
        r"(destroyed.*(statue|sculpture).*by.*(youths|people))",
        r"(spray.*paint.*on.*(wall|building|statue).*damage)",
        r"(broken.*(public.*property|monument).*by.*group)",

        // General vandalism patterns
        r"(graffiti.*(spray.*paint|tag|mark).*property)",
        r"(property.*damage.*(broken|smashed|destroyed))",
        r"(car.*vandalism.*(keyed|scratched|smashed.*window))",
        r"(building.*vandalism.*(windows|doors|walls))",
        r"(statue.*vandalism.*(defaced|damaged|destroyed))",
        r"(park.*vandalism.*(equipment|benches|lights))",
        r"(school.*vandalism.*(classroom|equipment|property))",
        r"(church.*vandalism.*(religious|symbols|property))",
      ],
      'banglish': [
        r"(political.*graffiti.*(wall|building|poster).*party)",
        r"(bus.*burn.*(hartal|protest).*petrol.*bomb)",
        r"(statue.*damage.*(public.*property|monument))",
        r"(school.*vandalism.*(classroom|furniture).*broken)",
        r"(temple.*mosque.*damage.*(religious.*tension))",
        r"(road.*block.*(tree|tire|stone).*protest)",
        r"(traffic.*signal.*break.*(light|pole).*damaged)",
        r"(government.*office.*damage.*(chair|table|window))",
        r"(youths?.*broke.*sculpture.*(shahbagh|university).*spray.*paint)",
        r"(vandalism.*statue.*(public.*property|monument).*damage)",
        r"(destroyed.*(statue|sculpture).*by.*(youths|people))",
        r"(spray.*paint.*on.*(wall|building|statue).*damage)",
        r"(broken.*(public.*property|monument).*by.*group)",
      ],
      'bangla': [
        r"(রাজনৈতিক.*গ্রাফিতি.*(দেয়াল|বিল্ডিং|পোস্টার).*দল)",
        r"(বাস.*জ্বালানো.*(হরতাল|বিক্ষোভ).*পেট্রোল.*বোমা)",
        r"(মূর্তি.*ক্ষতি.*(সরকারী.*সম্পত্তি|স্মৃতিস্তম্ভ))",
        r"(স্কুল.*ভ্যান্ডালিজম.*(ক্লাসরুম|ফার্নিচার).*ভাঙ্গা)",
        r"(মন্দির.*মসজিদ.*ক্ষতি.*(ধর্মীয়.*উত্তেজনা))",
        r"(রাস্তা.*ব্লক.*(গাছ|টায়ার|পাথর).*বিক্ষোভ)",
        r"(ট্রাফিক.*সিগন্যাল.*ভাঙ্গা.*(লাইট|পোল).*ক্ষতিগ্রস্ত)",
        r"(সরকারি.*অফিস.*ক্ষতি.*(চেয়ার|টেবিল|জানালা))",
        r"(যুবক.*ভাঙ্গা.*ভাস্কর্য.*(শাহবাগ|বিশ্ববিদ্যালয়).*স্প্রে.*পেইন্ট)",
        r"(ভ্যান্ডালিজম.*মূর্তি.*(সরকারী.*সম্পত্তি|স্মৃতিস্তম্ভ).*ক্ষতি)",
        r"(ধ্বংস.*(মূর্তি|ভাস্কর্য).*(যুবক|মানুষ))",
        r"(স্প্রে.*পেইন্ট.*(দেয়াল|বিল্ডিং|মূর্তি).*ক্ষতি)",
        r"(ভাঙ্গা.*(সরকারী.*সম্পত্তি|স্মৃতিস্তম্ভ).*গ্রুপ)",
      ],
    },
  };

  // ========== ENHANCED KEYWORD WEIGHTS ==========
  // [PASTE YOUR _keywordDetails HERE]
  final Map<String, Map<String, dynamic>> _keywordDetails = {
    // Emotional/psychological markers
    'panic': {'weight': 2.5, 'categories': ['dangerous'], 'psychology': 'emotional'},
    'terrified': {'weight': 2.8, 'categories': ['dangerous'], 'psychology': 'emotional'},
    'scared': {'weight': 2.2, 'categories': ['dangerous'], 'psychology': 'emotional'},
    'frightened': {'weight': 2.3, 'categories': ['dangerous'], 'psychology': 'emotional'},
    'horrified': {'weight': 2.7, 'categories': ['dangerous'], 'psychology': 'emotional'},
    'traumatized': {'weight': 2.6, 'categories': ['dangerous'], 'psychology': 'emotional'},
    'shaking': {'weight': 2.4, 'categories': ['dangerous'], 'psychology': 'physical'},
    'crying': {'weight': 2.3, 'categories': ['dangerous'], 'psychology': 'emotional'},
    'screaming': {'weight': 2.5, 'categories': ['dangerous'], 'psychology': 'behavioral'},

    // Credibility markers
    'witness': {'weight': 1.8, 'categories': ['dangerous', 'suspicious'], 'psychology': 'credibility'},
    'saw': {'weight': 1.7, 'categories': ['dangerous', 'suspicious'], 'psychology': 'credibility'},
    'seen': {'weight': 1.7, 'categories': ['dangerous', 'suspicious'], 'psychology': 'credibility'},
    'observed': {'weight': 1.9, 'categories': ['dangerous', 'suspicious'], 'psychology': 'credibility'},
    'heard': {'weight': 1.6, 'categories': ['dangerous', 'suspicious'], 'psychology': 'credibility'},
    'personally': {'weight': 1.8, 'categories': ['dangerous', 'suspicious'], 'psychology': 'credibility'},
    'myself': {'weight': 1.7, 'categories': ['dangerous', 'suspicious'], 'psychology': 'credibility'},
    'with_my_own_eyes': {'weight': 2.0, 'categories': ['dangerous', 'suspicious'], 'psychology': 'credibility'},

    // Specificity markers
    'approximately': {'weight': 1.5, 'categories': ['dangerous', 'suspicious'], 'psychology': 'specificity'},
    'exactly': {'weight': 1.6, 'categories': ['dangerous', 'suspicious'], 'psychology': 'specificity'},
    'precisely': {'weight': 1.6, 'categories': ['dangerous', 'suspicious'], 'psychology': 'specificity'},
    'specifically': {'weight': 1.5, 'categories': ['dangerous', 'suspicious'], 'psychology': 'specificity'},
    'details': {'weight': 1.4, 'categories': ['dangerous', 'suspicious'], 'psychology': 'specificity'},

    // Bangladeshi specific keywords
    'taka': {'weight': 1.8, 'categories': ['fake'], 'psychology': 'financial'},
    'lakh': {'weight': 1.9, 'categories': ['fake'], 'psychology': 'financial'},
    'crore': {'weight': 2.0, 'categories': ['fake'], 'psychology': 'financial'},
    'bdt': {'weight': 1.7, 'categories': ['fake'], 'psychology': 'financial'},
    'mobile_recharge': {'weight': 2.2, 'categories': ['fake'], 'psychology': 'scam'},
    'bkash': {'weight': 1.6, 'categories': ['fake'], 'psychology': 'financial'},
    'nagad': {'weight': 1.6, 'categories': ['fake'], 'psychology': 'financial'},
    'rocket': {'weight': 1.6, 'categories': ['fake'], 'psychology': 'financial'},
    'hundi': {'weight': 1.8, 'categories': ['suspicious'], 'psychology': 'financial'},

    // Dangerous keywords with psychology
    'murder': {'weight': 3.2, 'categories': ['dangerous', 'assault'], 'psychology': 'violent_intent'},
    'kill': {'weight': 3.0, 'categories': ['dangerous', 'assault'], 'psychology': 'violent_intent'},
    'attack': {'weight': 2.8, 'categories': ['dangerous', 'assault'], 'psychology': 'violent_action'},
    'gun': {'weight': 2.7, 'categories': ['dangerous'], 'psychology': 'weapon'},
    'knife': {'weight': 2.5, 'categories': ['dangerous'], 'psychology': 'weapon'},
    'bomb': {'weight': 3.1, 'categories': ['dangerous'], 'psychology': 'explosive'},
    'explosion': {'weight': 3.0, 'categories': ['dangerous'], 'psychology': 'explosive'},
    'hostage': {'weight': 2.9, 'categories': ['dangerous'], 'psychology': 'captivity'},
    'kidnap': {'weight': 2.8, 'categories': ['dangerous'], 'psychology': 'captivity'},
    'rape': {'weight': 3.0, 'categories': ['dangerous', 'assault'], 'psychology': 'sexual_violence'},
    'shoot': {'weight': 2.8, 'categories': ['dangerous'], 'psychology': 'firearm_action'},
    'terrorist': {'weight': 3.2, 'categories': ['dangerous'], 'psychology': 'extremism'},

    // Suspicious keywords
    'threat': {'weight': 2.2, 'categories': ['suspicious', 'dangerous'], 'psychology': 'intimidation'},
    'follow': {'weight': 2.0, 'categories': ['suspicious'], 'psychology': 'stalking'},
    'stalk': {'weight': 2.1, 'categories': ['suspicious'], 'psychology': 'stalking'},
    'suspicious': {'weight': 2.3, 'categories': ['suspicious'], 'psychology': 'observation'},
    'suspiciously': {'weight': 2.2, 'categories': ['suspicious'], 'psychology': 'observation'},
    'strange': {'weight': 1.8, 'categories': ['suspicious'], 'psychology': 'observation'},
    'unusual': {'weight': 1.9, 'categories': ['suspicious'], 'psychology': 'observation'},
    'fraud': {'weight': 2.2, 'categories': ['suspicious'], 'psychology': 'deception'},
    'scam': {'weight': 2.1, 'categories': ['suspicious', 'fake'], 'psychology': 'deception'},
    'corruption': {'weight': 2.4, 'categories': ['suspicious'], 'psychology': 'dishonesty'},
    'bribe': {'weight': 2.3, 'categories': ['suspicious'], 'psychology': 'dishonesty'},
    'drug': {'weight': 2.2, 'categories': ['suspicious'], 'psychology': 'substance'},

    // Fake keywords with psychology
    'fake': {'weight': 2.8, 'categories': ['fake'], 'psychology': 'deception'},
    'prank': {'weight': 2.6, 'categories': ['fake'], 'psychology': 'playful_deception'},
    'joke': {'weight': 2.5, 'categories': ['fake'], 'psychology': 'playful_deception'},
    'test': {'weight': 2.4, 'categories': ['fake'], 'psychology': 'experimental'},
    'lol': {'weight': 2.7, 'categories': ['fake'], 'psychology': 'playful'},
    'haha': {'weight': 2.3, 'categories': ['fake'], 'psychology': 'playful'},
    'jk': {'weight': 2.6, 'categories': ['fake'], 'psychology': 'playful_deception'},
    'kidding': {'weight': 2.5, 'categories': ['fake'], 'psychology': 'playful_deception'},

    // Theft keywords
    'theft': {'weight': 2.3, 'categories': ['theft'], 'psychology': 'property_crime'},
    'steal': {'weight': 2.2, 'categories': ['theft'], 'psychology': 'property_crime'},
    'rob': {'weight': 2.3, 'categories': ['theft'], 'psychology': 'property_crime'},
    'robbery': {'weight': 2.4, 'categories': ['theft'], 'psychology': 'property_crime'},
    'burglary': {'weight': 2.2, 'categories': ['theft'], 'psychology': 'property_crime'},
    'snatch': {'weight': 2.1, 'categories': ['theft'], 'psychology': 'property_crime'},
    'snatched': {'weight': 2.1, 'categories': ['theft'], 'psychology': 'property_crime'},
    'stolen': {'weight': 2.2, 'categories': ['theft'], 'psychology': 'property_crime'},
    'robbed': {'weight': 2.3, 'categories': ['theft'], 'psychology': 'property_crime'},

    // Assault keywords
    'assault': {'weight': 2.5, 'categories': ['assault'], 'psychology': 'physical_violence'},
    'beat': {'weight': 2.3, 'categories': ['assault'], 'psychology': 'physical_violence'},
    'hit': {'weight': 2.2, 'categories': ['assault'], 'psychology': 'physical_violence'},
    'punch': {'weight': 2.2, 'categories': ['assault'], 'psychology': 'physical_violence'},
    'abuse': {'weight': 2.4, 'categories': ['assault'], 'psychology': 'harm'},
    'fighting': {'weight': 2.3, 'categories': ['assault'], 'psychology': 'violence'},
    'fight': {'weight': 2.2, 'categories': ['assault'], 'psychology': 'violence'},
    'fought': {'weight': 2.1, 'categories': ['assault'], 'psychology': 'violence'},

    // Vandalism keywords
    'vandalism': {'weight': 2.1, 'categories': ['vandalism'], 'psychology': 'property_damage'},
    'damage': {'weight': 1.9, 'categories': ['vandalism'], 'psychology': 'property_damage'},
    'destroy': {'weight': 2.0, 'categories': ['vandalism'], 'psychology': 'property_damage'},
    'graffiti': {'weight': 1.8, 'categories': ['vandalism'], 'psychology': 'property_damage'},
    'break': {'weight': 1.8, 'categories': ['vandalism'], 'psychology': 'property_damage'},
    'broke': {'weight': 1.9, 'categories': ['vandalism'], 'psychology': 'property_damage'},
    'broken': {'weight': 1.9, 'categories': ['vandalism'], 'psychology': 'property_damage'},
    'destroyed': {'weight': 2.1, 'categories': ['vandalism'], 'psychology': 'property_damage'},

    // NEWLY ADDED KEYWORDS:
    'weapon': {'weight': 2.5, 'categories': ['dangerous', 'suspicious'], 'psychology': 'weapon'},
    'weapons': {'weight': 2.6, 'categories': ['dangerous', 'suspicious'], 'psychology': 'weapon'},
    'hiding': {'weight': 1.8, 'categories': ['suspicious'], 'psychology': 'concealment'},
    'motorcycle': {'weight': 1.5, 'categories': ['theft', 'suspicious'], 'psychology': 'getaway'},
    'bike': {'weight': 1.4, 'categories': ['theft', 'suspicious'], 'psychology': 'getaway'},
    'sticks': {'weight': 2.0, 'categories': ['assault'], 'psychology': 'weapon'},
    'stick': {'weight': 1.9, 'categories': ['assault'], 'psychology': 'weapon'},
    'bleeding': {'weight': 2.4, 'categories': ['dangerous', 'assault'], 'psychology': 'injury'},
    'sculpture': {'weight': 1.5, 'categories': ['vandalism'], 'psychology': 'public_property'},
    'spray': {'weight': 1.7, 'categories': ['vandalism'], 'psychology': 'graffiti'},
    'helmet': {'weight': 1.3, 'categories': ['theft'], 'psychology': 'description'},
    'mobile': {'weight': 1.6, 'categories': ['theft'], 'psychology': 'valuable'},
    'youths': {'weight': 1.5, 'categories': ['suspicious', 'vandalism'], 'psychology': 'perpetrator'},
    'group': {'weight': 1.4, 'categories': ['suspicious', 'assault'], 'psychology': 'multiple_perpetrators'},
    'groups': {'weight': 1.5, 'categories': ['suspicious', 'assault'], 'psychology': 'multiple_perpetrators'},
    'people': {'weight': 1.3, 'categories': ['dangerous', 'suspicious'], 'psychology': 'multiple_victims'},
    'injured': {'weight': 2.2, 'categories': ['dangerous', 'assault'], 'psychology': 'harm'},
    'hurt': {'weight': 2.0, 'categories': ['dangerous', 'assault'], 'psychology': 'harm'},
    'violent': {'weight': 2.3, 'categories': ['dangerous', 'assault'], 'psychology': 'aggression'},
    'violence': {'weight': 2.4, 'categories': ['dangerous', 'assault'], 'psychology': 'aggression'},
    'danger': {'weight': 2.2, 'categories': ['dangerous'], 'psychology': 'threat'},
    'dangerous': {'weight': 2.3, 'categories': ['dangerous'], 'psychology': 'threat'},

    // ABSURDITY KEYWORDS:
    'invisible': {'weight': 3.0, 'categories': ['fake'], 'psychology': 'absurdity'},
    'aliens': {'weight': 3.0, 'categories': ['fake'], 'psychology': 'absurdity'},
    'alien': {'weight': 3.0, 'categories': ['fake'], 'psychology': 'absurdity'},
    'superhero': {'weight': 2.9, 'categories': ['fake'], 'psychology': 'absurdity'},
    'mind-control': {'weight': 2.8, 'categories': ['fake'], 'psychology': 'absurdity'},
    'ghost': {'weight': 2.7, 'categories': ['fake'], 'psychology': 'absurdity'},
    'magic': {'weight': 2.6, 'categories': ['fake'], 'psychology': 'absurdity'},
    'teleport': {'weight': 2.7, 'categories': ['fake'], 'psychology': 'absurdity'},
    'supernatural': {'weight': 2.8, 'categories': ['fake'], 'psychology': 'absurdity'},
    'fantasy': {'weight': 2.5, 'categories': ['fake'], 'psychology': 'absurdity'},
    'impossible': {'weight': 2.4, 'categories': ['fake'], 'psychology': 'implausibility'},
    'unbelievable': {'weight': 2.3, 'categories': ['fake'], 'psychology': 'implausibility'},
    'rumor': {'weight': 2.2, 'categories': ['fake'], 'psychology': 'unverified'},
    'claimed': {'weight': 1.8, 'categories': ['fake', 'suspicious'], 'psychology': 'hearsay'},
    'hearsay': {'weight': 2.1, 'categories': ['fake'], 'psychology': 'unverified'},
    'said': {'weight': 1.5, 'categories': ['fake'], 'psychology': 'hearsay'},
    'according to': {'weight': 1.6, 'categories': ['fake'], 'psychology': 'hearsay'},
    'rumor has it': {'weight': 2.5, 'categories': ['fake'], 'psychology': 'unverified'},
    'people say': {'weight': 2.0, 'categories': ['fake'], 'psychology': 'hearsay'},
    'word is': {'weight': 2.1, 'categories': ['fake'], 'psychology': 'hearsay'},
    'vampire': {'weight': 2.8, 'categories': ['fake'], 'psychology': 'absurdity'},
    'werewolf': {'weight': 2.8, 'categories': ['fake'], 'psychology': 'absurdity'},
    'zombie': {'weight': 2.8, 'categories': ['fake'], 'psychology': 'absurdity'},
    'unicorn': {'weight': 2.7, 'categories': ['fake'], 'psychology': 'absurdity'},
    'dragon': {'weight': 2.7, 'categories': ['fake'], 'psychology': 'absurdity'},
    'wizard': {'weight': 2.6, 'categories': ['fake'], 'psychology': 'absurdity'},
    'witch': {'weight': 2.6, 'categories': ['fake'], 'psychology': 'absurdity'},
    'fairy': {'weight': 2.6, 'categories': ['fake'], 'psychology': 'absurdity'},
    'mermaid': {'weight': 2.6, 'categories': ['fake'], 'psychology': 'absurdity'},
    'extraterrestrial': {'weight': 2.9, 'categories': ['fake'], 'psychology': 'absurdity'},
    'ufo': {'weight': 2.9, 'categories': ['fake'], 'psychology': 'absurdity'},
    'paranormal': {'weight': 2.7, 'categories': ['fake'], 'psychology': 'absurdity'},
    'haunted': {'weight': 2.5, 'categories': ['fake'], 'psychology': 'absurdity'},
    'possessed': {'weight': 2.6, 'categories': ['fake'], 'psychology': 'absurdity'},
    'cursed': {'weight': 2.5, 'categories': ['fake'], 'psychology': 'absurdity'},
    'mythical': {'weight': 2.7, 'categories': ['fake'], 'psychology': 'absurdity'},
    'legendary': {'weight': 2.3, 'categories': ['fake'], 'psychology': 'exaggeration'},
    'fictional': {'weight': 2.8, 'categories': ['fake'], 'psychology': 'fabrication'},
    'cartoon': {'weight': 2.7, 'categories': ['fake'], 'psychology': 'absurdity'},
    'animated': {'weight': 2.6, 'categories': ['fake'], 'psychology': 'fabrication'},
    'comic': {'weight': 2.5, 'categories': ['fake'], 'psychology': 'fabrication'},
    'movie': {'weight': 2.0, 'categories': ['fake'], 'psychology': 'entertainment'},
    'tv': {'weight': 2.0, 'categories': ['fake'], 'psychology': 'entertainment'},
    'video game': {'weight': 2.1, 'categories': ['fake'], 'psychology': 'entertainment'},
    'novel': {'weight': 2.2, 'categories': ['fake'], 'psychology': 'fabrication'},
    'fiction': {'weight': 2.5, 'categories': ['fake'], 'psychology': 'fabrication'},
    'fantasy': {'weight': 2.4, 'categories': ['fake'], 'psychology': 'fabrication'},
    'horror': {'weight': 2.3, 'categories': ['fake'], 'psychology': 'entertainment'},


    'বোমা': {'weight': 3.1, 'categories': ['dangerous'], 'psychology': 'explosive'},
    'বিস্ফোরণ': {'weight': 3.0, 'categories': ['dangerous'], 'psychology': 'explosive'},
    'খুন': {'weight': 3.2, 'categories': ['dangerous', 'assault'], 'psychology': 'violent_intent'},
    'মারা': {'weight': 3.0, 'categories': ['dangerous', 'assault'], 'psychology': 'violent_intent'},
    'রক্ত': {'weight': 2.5, 'categories': ['dangerous', 'assault'], 'psychology': 'injury'},
    'আহত': {'weight': 2.2, 'categories': ['dangerous', 'assault'], 'psychology': 'injury'},
    'আক্রমণ': {'weight': 2.8, 'categories': ['dangerous', 'assault'], 'psychology': 'violent_action'},
    'গুলি': {'weight': 2.8, 'categories': ['dangerous'], 'psychology': 'firearm_action'},
    'ডাকাতি': {'weight': 2.4, 'categories': ['theft'], 'psychology': 'property_crime'},
    'ছিনতাই': {'weight': 2.3, 'categories': ['theft'], 'psychology': 'property_crime'},
    'ধর্ষণ': {'weight': 3.0, 'categories': ['dangerous', 'assault'], 'psychology': 'sexual_violence'},
    'অপহরণ': {'weight': 2.8, 'categories': ['dangerous'], 'psychology': 'captivity'},
    'ড্রাগ': {'weight': 2.2, 'categories': ['suspicious'], 'psychology': 'substance'},
    'যুবক': {'weight': 1.5, 'categories': ['suspicious'], 'psychology': 'perpetrator'},
    'লুকিয়ে': {'weight': 1.8, 'categories': ['suspicious'], 'psychology': 'concealment'},
  };

  // ========== CONTEXT MODIFIERS ==========
  // [PASTE YOUR _contextModifiers HERE]
  final Map<String, List<Map<String, dynamic>>> _contextModifiers = {
    'urgency_boosters': [
      {'word': 'now', 'boost': 0.5, 'psychology': 'immediate_threat'},
      {'word': 'immediately', 'boost': 0.6, 'psychology': 'immediate_threat'},
      {'word': 'urgent', 'boost': 0.7, 'psychology': 'immediate_threat'},
      {'word': 'emergency', 'boost': 0.8, 'psychology': 'crisis'},
      {'word': 'asap', 'boost': 0.6, 'psychology': 'immediate_threat'},
      {'word': 'right now', 'boost': 0.5, 'psychology': 'immediate_threat'},
      {'word': 'help', 'boost': 0.6, 'psychology': 'distress_call'},
      {'word': 'quickly', 'boost': 0.4, 'psychology': 'time_sensitive'},
      {'word': 'please help', 'boost': 0.7, 'psychology': 'desperate_distress'},
      {'word': 'need help now', 'boost': 0.8, 'psychology': 'desperate_distress'},
      {'word': 'dying', 'boost': 0.9, 'psychology': 'life_threatening'},
      {'word': 'bleeding', 'boost': 0.8, 'psychology': 'medical_emergency'},
      {'word': 'injured', 'boost': 0.7, 'psychology': 'medical_emergency'},
      {'word': 'trapped', 'boost': 0.8, 'psychology': 'captivity'},
      {'word': 'cannot escape', 'boost': 0.9, 'psychology': 'captivity'},
    ],
    'time_reducers': [
      {'word': 'tomorrow', 'reduction': 0.6, 'psychology': 'future_event'},
      {'word': 'next week', 'reduction': 0.7, 'psychology': 'future_event'},
      {'word': 'later', 'reduction': 0.5, 'psychology': 'future_event'},
      {'word': 'will happen', 'reduction': 0.7, 'psychology': 'future_event'},
      {'word': 'planning', 'reduction': 0.6, 'psychology': 'future_event'},
      {'word': 'future', 'reduction': 0.5, 'psychology': 'future_event'},
      {'word': 'soon', 'reduction': 0.4, 'psychology': 'near_future'},
      {'word': 'eventually', 'reduction': 0.5, 'psychology': 'future_event'},
      {'word': 'someday', 'reduction': 0.6, 'psychology': 'indefinite_future'},
      {'word': 'maybe tomorrow', 'reduction': 0.7, 'psychology': 'uncertain_future'},
      {'word': 'could happen', 'reduction': 0.6, 'psychology': 'speculative'},
      {'word': 'might occur', 'reduction': 0.6, 'psychology': 'speculative'},
      {'word': 'possibly', 'reduction': 0.5, 'psychology': 'uncertain'},
      {'word': 'perhaps', 'reduction': 0.5, 'psychology': 'uncertain'},
    ],
    'credibility_boosters': [
      {'word': 'witness', 'boost': 0.4, 'psychology': 'direct_observation'},
      {'word': 'saw', 'boost': 0.3, 'psychology': 'direct_observation'},
      {'word': 'seen', 'boost': 0.3, 'psychology': 'direct_observation'},
      {'word': 'observed', 'boost': 0.4, 'psychology': 'systematic_observation'},
      {'word': 'heard', 'boost': 0.2, 'psychology': 'auditory_evidence'},
      {'word': 'personally', 'boost': 0.4, 'psychology': 'direct_experience'},
      {'word': 'myself', 'boost': 0.3, 'psychology': 'direct_experience'},
      {'word': 'with my own eyes', 'boost': 0.5, 'psychology': 'direct_visual'},
      {'word': 'clearly saw', 'boost': 0.4, 'psychology': 'clear_observation'},
      {'word': 'distinctly heard', 'boost': 0.3, 'psychology': 'clear_auditory'},
      {'word': 'verified', 'boost': 0.5, 'psychology': 'confirmed'},
      {'word': 'confirmed', 'boost': 0.5, 'psychology': 'confirmed'},
      {'word': 'certain', 'boost': 0.4, 'psychology': 'confidence'},
      {'word': 'definitely', 'boost': 0.4, 'psychology': 'confidence'},
      {'word': 'absolutely', 'boost': 0.4, 'psychology': 'confidence'},
    ],
    'fake_indicators': [
      {'word': 'just kidding', 'reduction': 0.9, 'psychology': 'playful_deception'},
      {'word': 'lol', 'reduction': 0.8, 'psychology': 'playful'},
      {'word': 'haha', 'reduction': 0.7, 'psychology': 'playful'},
      {'word': 'not real', 'reduction': 0.95, 'psychology': 'explicit_deception'},
      {'word': 'prank', 'reduction': 0.85, 'psychology': 'playful_deception'},
      {'word': 'testing', 'reduction': 0.8, 'psychology': 'experimental'},
      {'word': 'test', 'reduction': 0.8, 'psychology': 'experimental'},
      {'word': 'jk', 'reduction': 0.85, 'psychology': 'playful_deception'},
      {'word': 'joke', 'reduction': 0.85, 'psychology': 'playful_deception'},
      {'word': 'funny', 'reduction': 0.7, 'psychology': 'playful'},
      {'word': 'hilarious', 'reduction': 0.8, 'psychology': 'playful'},
      {'word': 'made up', 'reduction': 0.9, 'psychology': 'fabrication'},
      {'word': 'fabricated', 'reduction': 0.9, 'psychology': 'fabrication'},
      {'word': 'false', 'reduction': 0.9, 'psychology': 'deception'},
      {'word': 'fake', 'reduction': 0.95, 'psychology': 'deception'},
      {'word': 'hoax', 'reduction': 0.9, 'psychology': 'deception'},
      {'word': 'lie', 'reduction': 0.9, 'psychology': 'deception'},
      {'word': 'lying', 'reduction': 0.9, 'psychology': 'deception'},
      {'word': 'kidding', 'reduction': 0.85, 'psychology': 'playful_deception'},
      {'word': 'just joking', 'reduction': 0.85, 'psychology': 'playful_deception'},
    ],
    'hearsay_reducers': [
      {'word': 'said', 'reduction': 0.4, 'psychology': 'hearsay'},
      {'word': 'claimed', 'reduction': 0.5, 'psychology': 'hearsay'},
      {'word': 'reported', 'reduction': 0.3, 'psychology': 'hearsay'},
      {'word': 'according to', 'reduction': 0.4, 'psychology': 'hearsay'},
      {'word': 'rumor', 'reduction': 0.7, 'psychology': 'unverified'},
      {'word': 'rumor has it', 'reduction': 0.8, 'psychology': 'unverified'},
      {'word': 'people say', 'reduction': 0.6, 'psychology': 'hearsay'},
      {'word': 'word is', 'reduction': 0.6, 'psychology': 'hearsay'},
      {'word': 'heard that', 'reduction': 0.5, 'psychology': 'hearsay'},
      {'word': 'told me', 'reduction': 0.4, 'psychology': 'hearsay'},
      {'word': 'allegedly', 'reduction': 0.3, 'psychology': 'unverified'},
      {'word': 'supposedly', 'reduction': 0.4, 'psychology': 'unverified'},
      {'word': 'apparently', 'reduction': 0.3, 'psychology': 'unverified'},
    ],
  };

  // ========== REALITY DETECTION MODULES ==========
  final Map<String, List<String>> _realityCheckPatterns = {
    'physically_impossible': [
      r"(flew.*without.*(wings|plane|helicopter))",
      r"(ran.*faster.*than.*(light|sound|bullet|car))",
      r"(teleported.*from.*(place).*to.*(place))",
      r"(became.*invisible.*and.*(stole|attacked))",
      r"(read.*someone.*mind.*and.*(knew|predicted))",
      r"(lifted.*(car|truck|bus).*with.*bare.*hands)",
      r"(survived.*(bullet|knife|fall.*from.*sky))",
      r"(disappeared.*and.*reappeared.*(elsewhere))",
      r"(turned.*into.*(animal|object|person))",
      r"(controlled.*(weather|time|gravity).*with.*mind)",
      r"(walked.*through.*(walls|doors|solid.*objects))",
      r"(telekinetic.*(moved|threw|lifted).*objects)",
      r"(time.*traveled.*to.*(past|future).*and.*back)",
      r"(clone.*of.*myself.*(committed|did).*crime)",
      r"(ghost.*possessed.*me.*and.*(did|committed))",
      r"(magic.*wand.*made.*(things|people).*disappear)",
      r"(super.*strength.*without.*(steroids|equipment))",
      r"(instant.*healing.*from.*(fatal|serious).*wounds)",
      r"(breath.*under.*water.*without.*(equipment))",
      r"(shot.*lasers.*from.*(eyes|hands))",
    ],
    'contradictory_details': [
      r"(witnessed.*but.*did.*not.*see)",
      r"(heard.*but.*was.*deaf)",
      r"(saw.*clearly.*but.*was.*dark)",
      r"(present.*at.*scene.*but.*also.*elsewhere)",
      r"(killed.*by.*(gun|knife).*but.*no.*(wound|blood))",
      r"(stolen.*but.*still.*have.*it)",
      r"(attacked.*by.*(one|multiple).*but.*no.*(marks|injuries))",
      r"(robbed.*but.*nothing.*missing)",
      r"(happened.*(today|yesterday).*but.*mentions.*(tomorrow|future))",
      r"(dead.*but.*talking|breathing|moving)",
      r"(unconscious.*but.*remembering.*details)",
      r"(blindfolded.*but.*saw.*everything)",
      r"(tied.*up.*but.*managed.*to.*(call|escape))",
      r"(no.*phone.*but.*sent.*message|called)",
      r"(alone.*but.*witnesses.*present)",
      r"(indoors.*but.*describes.*outdoor.*details)",
      r"(night.*but.*describes.*daylight.*details)",
      r"(far.*away.*but.*heard.*whispers)",
      r"(silenced.*but.*shouting)",
      r"(hidden.*but.*seen.*by.*everyone)",
    ],
    'supernatural_claims': [
      r"(ghost.*(killed|attacked|possessed|haunted))",
      r"(witch.*(curse|spell|hex).*caused)",
      r"(vampire.*(bite|attack|transformation))",
      r"(werewolf.*(attack|transformation))",
      r"(zombie.*(apocalypse|attack|outbreak))",
      r"(alien.*(abduction|experiment|spaceship))",
      r"(demon.*(summon|possession|attack))",
      r"(angel.*(appeared|helped|saved))",
      r"(god.*(spoke|appeared|punished))",
      r"(prophecy.*(came.*true|predicted))",
      r"(miracle.*(happened|occurred|saved))",
      r"(supernatural.*(power|ability|event))",
      r"(paranormal.*(activity|phenomenon|event))",
      r"(psychic.*(prediction|vision|dream))",
      r"(magic.*(spell|curse|wand|potion))",
      r"(fairies.*(helped|hindered|played))",
      r"(mermaid.*(appeared|sang|saved))",
      r"(dragon.*(flew|attacked|breathed.*fire))",
      r"(unicorn.*(appeared|healed|magic))",
      r"(mythical.*creature.*(real|existed))",
    ],
    'overly_dramatic': [
      r"(blood.*was.*flowing.*like.*river)",
      r"(screamed.*until.*lungs.*burst)",
      r"(cried.*river.*of.*tears)",
      r"(heart.*stopped.*multiple.*times)",
      r"(died.*and.*came.*back.*to.*life)",
      r"(pain.*was.*unbearable.*like.*hell)",
      r"(terror.*froze.*my.*blood)",
      r"(saw.*my.*life.*flash.*before.*eyes)",
      r"(time.*stopped.*completely)",
      r"(world.*went.*completely.*silent)",
      r"(could.*hear.*my.*own.*heartbeat.*miles.*away)",
      r"(saw.*everything.*in.*slow.*motion)",
      r"(felt.*like.*hours.*but.*was.*seconds)",
      r"(screamed.*but.*no.*sound.*came.*out)",
      r"(paralyzed.*with.*fear.*for.*hours)",
      r"(fainted.*multiple.*times)",
      r"(lost.*all.*hope.*and.*accepted.*death)",
      r"(prayed.*to.*every.*god.*existed)",
      r"(promised.*to.*change.*if.*survived)",
      r"(last.*breath.*was.*leaving.*body)",
    ],
  };

  // ========== CONSISTENCY ANALYZER ==========
  final Map<String, List<String>> _consistencyPatterns = {
    'time_inconsistency': [
      r"(happened.*(today|yesterday).*but.*(last.*week|month|year))",
      r"(just.*happened.*but.*(hours|days).*ago)",
      r"(occurred.*at.*(morning|day).*but.*mentions.*(night|dark))",
      r"(said.*(now|currently).*but.*(tomorrow|next.*week))",
      r"(witnessed.*(recently).*but.*details.*are.*old)",
      r"(date.*mentions.*(202[0-9]).*but.*describes.*(202[2-9]))",
      r"(time.*given.*(am).*but.*describes.*(evening|night))",
      r"(duration.*(minutes).*but.*describes.*(hours).*worth)",
    ],
    'location_inconsistency': [
      r"(in.*(dhaka).*but.*describes.*(sea|ocean|mountain))",
      r"(at.*(market).*but.*mentions.*(quiet|isolated))",
      r"(indoors.*but.*describes.*(sun|rain|wind))",
      r"(crowded.*place.*but.*no.*witnesses)",
      r"(familiar.*area.*but.*gets.*directions.*wrong)",
      r"(specific.*address.*but.*vague.*landmarks)",
      r"(known.*location.*but.*impossible.*geography)",
      r"(distance.*(far).*but.*heard.*clearly)",
      r"(visibility.*(poor).*but.*saw.*details)",
    ],
    'detail_inconsistency': [
      r"(did.*not.*see.*but.*describes.*(clothes|face))",
      r"(too.*dark.*but.*identified.*(color|details))",
      r"(too.*far.*but.*heard.*(words|conversation))",
      r"(one.*attacker.*but.*multiple.*descriptions)",
      r"(weapon.*(gun).*but.*sound.*(knife|other))",
      r"(injured.*but.*no.*(pain|treatment|hospital))",
      r"(stolen.*but.*knows.*exact.*(model|serial))",
      r"(quick.*incident.*but.*long.*detailed.*description)",
      r"(emotional.*but.*precise.*technical.*details)",
      r"(traumatized.*but.*remembering.*everything)",
    ],
  };

  // ========== BANGLADESH LOCATIONS ==========
  final List<String> _bangladeshLocations = [
    'dhaka', 'chittagong', 'sylhet', 'rajshahi', 'khulna', 'barisal', 'rangpur',
    'gazipur', 'narayanganj', 'savar', 'tongi', 'bogra', 'comilla', 'mymensingh',
    'cox bazar', 'st martin', 'kuakata', 'sundarbans', 'bandarban', 'rangamati',
    'motijheel', 'gulshan', 'banani', 'dhanmondi', 'uttara', 'mirpur', 'mohakhali',
    'tejgaon', 'shahbagh', 'farmgate', 'new market', 'bashundhara', 'baridhara',
    'padma', 'meghna', 'jamuna', 'buriganga', 'shitalakhya', 'karnaphuli',
    'gulshan lake', 'mirpur 10', 'mirpur 1', 'mirpur 2', 'uttara sector', 'dhanmondi lake',
    'shahbagh area', 'farmgate area', 'motijheel area',
  ];

  // ========== PSYCHOLOGY PATTERNS ==========
  final Map<String, RegExp> _psychologyPatterns = {
    'emotional_distress': RegExp(r'\b(crying|screaming|shaking|terrified|panicking|frightened|scared|afraid|horrified)\b', caseSensitive: false),
    'desperate_call': RegExp(r'\b(help|please help|save me|rescue|emergency|urgent|dying|bleeding|injured|trapped)\b', caseSensitive: false),
    'detailed_description': RegExp(r'\b(approximately|exactly|precisely|specifically|details|description|observed|saw|heard|witnessed)\b', caseSensitive: false),
    'vague_language': RegExp(r'\b(maybe|perhaps|possibly|could be|might be|not sure|think|believe|guess|probably)\b', caseSensitive: false),
    'casual_language': RegExp(r'\b(lol|haha|hehe|lmao|rofl|jk|just kidding|funny|hilarious|hahaha)\b', caseSensitive: false),
    'financial_motive': RegExp(r'\b(money|taka|lakh|crore|reward|payment|tk|bdt|mobile recharge|bkash|nagad|rocket|cash)\b', caseSensitive: false),
  };

  // ========== TEMPORAL PATTERNS ==========
  final Map<String, List<String>> _temporalPatterns = {
    'immediate_past': [
      r"(just.*happened|just.*now|right.*now|this.*moment)",
      r"(seconds.*ago|minutes.*ago|few.*moments.*ago)",
      r"(currently.*happening|ongoing.*right.*now)",
      r"(as.*i.*speak|while.*i.*type|live.*right.*now)",
    ],
    'recent_past': [
      r"(today|earlier.*today|this.*morning|this.*evening)",
      r"(yesterday|last.*night|previous.*day)",
      r"(hours.*ago|recently|lately|past.*few.*hours)",
    ],
    'distant_past': [
      r"(days.*ago|weeks.*ago|months.*ago|years.*ago)",
      r"(last.*week|last.*month|last.*year)",
      r"(long.*time.*ago|previously|before)",
    ],
    'future': [
      r"(will.*happen|going.*to.*happen|about.*to.*happen)",
      r"(tomorrow|next.*week|next.*month|future)",
      r"(planned|schedule|expected|predicted)",
    ],
  };

  // ========== IMPROBABILITY DETECTOR ==========
  final Map<String, double> _improbabilityScores = {
    'ghost': 0.8,
    'alien': 0.9,
    'magic': 0.7,
    'invisible': 0.85,
    'teleport': 0.8,
    'mind-control': 0.75,
    'superhero': 0.7,
    'time-travel': 0.9,
    'vampire': 0.8,
    'werewolf': 0.8,
    'zombie': 0.8,
    'dragon': 0.8,
    'unicorn': 0.8,
    'flying': 0.7,
    'levitation': 0.75,
    'super-strength': 0.6,
    'instant-heal': 0.7,
    'psychic': 0.7,
    'prophecy': 0.65,
    'miracle': 0.6,
  };

  // ========== SPECIFICITY BOOSTERS ==========
  final Map<String, double> _specificityBoosters = {
    'time_specific': 0.3,      // "at 3:15 PM"
    'date_specific': 0.4,      // "on January 15, 2024"
    'address_specific': 0.5,   // "House 45, Road 8"
    'vehicle_details': 0.3,    // "Toyota Premio, white, DHA-1234"
    'person_description': 0.2, // "tall man with beard, blue shirt"
    'weapon_details': 0.4,     // "9mm pistol, black handle"
    'witness_count': 0.3,      // "5 people saw it"
    'measurement': 0.2,        // "about 5 feet tall"
    'direction': 0.2,          // "heading north towards Gulshan"
    'weather_mention': 0.1,    // "it was raining heavily"
  };

  // ========== INITIALIZATION ==========
  Future<void> initialize() async {
    developer.log("🚀 ENHANCED REALITY-AWARE CLASSIFIER: Initializing");
    developer.log("🌐 Multi-Language Support: English, Banglish, Bangla");
    developer.log("🔍 Reality Detection: Physical possibility, consistency, geography");
    developer.log("🎯 Intelligence: Dead/kill detection + reality verification");

    _isInitialized = true;
    _debugLog['initialization'] = [
      'Enhanced classifier initialized',
      'Multi-language patterns loaded',
      'Reality detection active',
      'Bangladesh context enabled'
    ];

    developer.log("✅ ENHANCED CLASSIFIER: Ready with reality-aware intelligence");
  }

  // ========== MAIN CLASSIFICATION METHOD ==========
  Future<Map<String, dynamic>> classify(String text) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      if (text.length < 3) {
        developer.log("⚠️ Text too short (${text.length} chars)");
        return _getDefaultResult();
      }

      // Clear previous debug log
      _debugLog.clear();
      _debugLog['input_text'] = [text];
      _debugLog['text_length'] = ['${text.length} characters'];

      developer.log("\n🔍 ENHANCED CLASSIFICATION =========================");
      developer.log("📝 Text: ${text.substring(0, min(text.length, 100))}${text.length > 100 ? '...' : ''}");

      final enhancedResult = _enhancedRealityAwareClassification(text);

      developer.log("\n🎯 CLASSIFICATION RESULTS:");
      developer.log("🏷️  Primary Label: ${enhancedResult['label']}");
      developer.log("📈 Confidence: ${(enhancedResult['confidence'] * 100).toStringAsFixed(1)}%");
      developer.log("🧠 Reality Score: ${(enhancedResult['reality_analysis']['reality_score'] * 100).toStringAsFixed(1)}%");
      developer.log("⚖️  Verdict: ${enhancedResult['final_verdict']}");

      if (enhancedResult['reality_analysis']['flags'].isNotEmpty) {
        developer.log("🚩 Reality Flags: ${enhancedResult['reality_analysis']['flags'].length}");
        for (var flag in enhancedResult['reality_analysis']['flags']) {
          developer.log("   - $flag");
        }
      }

      developer.log("🌐 Languages: ${enhancedResult['detected_languages']}");
      developer.log("==================================================\n");

      return {
        'label': enhancedResult['label'],
        'confidence': enhancedResult['confidence'],
        'scores': enhancedResult['scores'],
        'crime_types': enhancedResult['crime_types'],
        'pattern_matches': enhancedResult['pattern_matches'],
        'keywords_found': enhancedResult['keywords_found'],
        'context_score': enhancedResult['context_score'],
        'psychology_analysis': enhancedResult['psychology_analysis'],
        'bangladesh_context': enhancedResult['bangladesh_context'],
        'reality_analysis': enhancedResult['reality_analysis'],
        'detected_languages': enhancedResult['detected_languages'],
        'is_multi_language': enhancedResult['is_multi_language'],
        'final_verdict': enhancedResult['final_verdict'],
        'debug_log': _debugLog,
      };
    } catch (e) {
      developer.log("❌ Classification error: $e");
      return _getDefaultResult();
    }
  }

  // ========== ENHANCED REALITY-AWARE CLASSIFICATION ==========
  Map<String, dynamic> _enhancedRealityAwareClassification(String text) {
    final lowerText = text.toLowerCase();

    // Step 1: Multi-language detection
    final Map<String, bool> languages = _detectLanguages(text);
    _debugLog['languages_detected'] = ['Languages: ${languages}'];

    // Step 2: Psychology analysis
    final Map<String, dynamic> psychologyAnalysis = _analyzePsychology(text);
    _debugLog['psychology'] = ['Tone: ${psychologyAnalysis['emotional_tone']}', 'Credibility: ${psychologyAnalysis['credibility']}'];

    // Step 3: Reality and consistency check
    final Map<String, dynamic> realityAnalysis = _realityAndConsistencyCheck(text);
    _debugLog['reality'] = ['Score: ${realityAnalysis['reality_score']}', 'Plausible: ${realityAnalysis['is_plausible']}'];

    // Step 4: Multi-language pattern analysis
    final Map<String, dynamic> patternAnalysis = _analyzeMultiLanguagePatterns(text, languages);
    _debugLog['patterns'] = ['Matches: ${patternAnalysis['total_matches']}'];

    // Step 5: Keyword analysis
    final Map<String, dynamic> keywordAnalysis = _analyzeKeywords(lowerText);
    _debugLog['keywords'] = ['Found: ${keywordAnalysis['total_keywords']}'];

    // Step 6: Bangladesh context analysis
    final Map<String, dynamic> bangladeshContext = _analyzeBangladeshContext(lowerText);
    _debugLog['bangladesh'] = ['Location: ${bangladeshContext['location_mentioned']}'];

    // Step 7: Calculate scores with reality adjustments
    final Map<String, double> finalScores = _calculateFinalScores(
        patternAnalysis['category_scores'],
        keywordAnalysis['category_scores'],
        psychologyAnalysis,
        realityAnalysis,
        bangladeshContext
    );

    // Step 8: Determine label with reality override
    final String primaryLabel = _determineLabelWithRealityOverride(
        finalScores,
        psychologyAnalysis,
        realityAnalysis,
        text
    );

    // Step 9: Calculate confidence with reality factor
    final double confidence = _calculateEnhancedConfidence(
        finalScores,
        primaryLabel,
        patternAnalysis['matches_count'],
        keywordAnalysis['total_keywords'],
        realityAnalysis,
        psychologyAnalysis
    );

    // Step 10: Generate final verdict
    final String verdict = _generateComprehensiveVerdict(
        primaryLabel,
        realityAnalysis,
        psychologyAnalysis,
        bangladeshContext
    );

    return {
      'label': primaryLabel,
      'confidence': confidence,
      'scores': finalScores,
      'crime_types': _extractCrimeTypes(finalScores),
      'pattern_matches': patternAnalysis['matches'],
      'keywords_found': keywordAnalysis['keywords'],
      'context_score': realityAnalysis['context_score'],
      'psychology_analysis': psychologyAnalysis,
      'bangladesh_context': bangladeshContext,
      'reality_analysis': realityAnalysis,
      'detected_languages': languages,
      'is_multi_language': languages.values.where((v) => v).length > 1,
      'final_verdict': verdict,
    };
  }

  // ========== MULTI-LANGUAGE DETECTION ==========
  Map<String, bool> _detectLanguages(String text) {
    final Map<String, bool> detected = {
      'english': false,
      'banglish': false,
      'bangla': false,
    };

    final lowerText = text.toLowerCase();

    // Detect Bangla script (Bengali Unicode range)
    final banglaRegex = RegExp(r'[\u0980-\u09FF]');
    if (banglaRegex.hasMatch(text)) {
      detected['bangla'] = true;
    }

    // Detect Banglish (Romanized Bengali)
    final banglishPatterns = [
      r"\b(khobor|khbr|news)\b",
      r"\b(hoyni|hoina|hoise|hoiche)\b",
      r"\b(korchi|korlam|korbe|korlo)\b",
      r"\b(ache|nei|asa|jai)\b",
      r"\b(ekhon|akhn|ekhane|okhane)\b",
      r"\b(ki|kemon|koto|kon)\b",
      r"\b(manush|bacca|meye|chele)\b",
      r"\b(jayga|jaga|sthane|place)\b",
    ];

    int banglishMatches = 0;
    for (var pattern in banglishPatterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(lowerText)) {
        banglishMatches++;
      }
    }
    detected['banglish'] = banglishMatches >= 2;

    // Detect English (default if no Bangla/Banglish or mixed)
    final englishWords = lowerText.split(' ').where((word) {
      return word.length > 2 &&
          RegExp(r'^[a-zA-Z]+$').hasMatch(word) &&
          !['the', 'and', 'but', 'for', 'you', 'are', 'was', 'were'].contains(word);
    }).length;

    if (!(detected['bangla'] ?? false) && !(detected['banglish'] ?? false)) {
      detected['english'] = true;
    } else if (englishWords > text.split(' ').length * 0.3) {
      detected['english'] = true;
    }


    return detected;
  }

  // ========== PSYCHOLOGY ANALYSIS ==========
  Map<String, dynamic> _analyzePsychology(String text) {
    final lowerText = text.toLowerCase();

    int distressCount = _psychologyPatterns['emotional_distress']!.allMatches(lowerText).length;
    int desperateCount = _psychologyPatterns['desperate_call']!.allMatches(lowerText).length;
    int detailedCount = _psychologyPatterns['detailed_description']!.allMatches(lowerText).length;
    int vagueCount = _psychologyPatterns['vague_language']!.allMatches(lowerText).length;
    int casualCount = _psychologyPatterns['casual_language']!.allMatches(lowerText).length;
    int financialCount = _psychologyPatterns['financial_motive']!.allMatches(lowerText).length;

    // Emotional tone
    String emotionalTone = 'neutral';
    if (distressCount >= 3 || desperateCount >= 2) {
      emotionalTone = 'high_distress';
    } else if (distressCount >= 1 || desperateCount >= 1) {
      emotionalTone = 'moderate_distress';
    } else if (casualCount >= 2) {
      emotionalTone = 'casual';
    }

    // Credibility score
    double credibility = 0.5;
    if (detailedCount >= 3 && vagueCount == 0) {
      credibility = 0.9;
    } else if (detailedCount >= 2 && vagueCount <= 1) {
      credibility = 0.7;
    } else if (vagueCount >= 2) {
      credibility = 0.3;
    }

    // Urgency level
    String urgency = 'low';
    for (final modifier in _contextModifiers['urgency_boosters']!) {
      if (_containsWord(lowerText, modifier['word'])) {
        if (modifier['word'] == 'dying' || modifier['word'] == 'cannot escape') {
          urgency = 'extreme';
        } else if (urgency != 'extreme' &&
            (modifier['word'] == 'emergency' || modifier['word'] == 'trapped')) {
          urgency = 'high';
        } else if (urgency == 'low') {
          urgency = 'medium';
        }
      }
    }

    return {
      'emotional_tone': emotionalTone,
      'credibility': credibility,
      'urgency_level': urgency,
      'distress_markers': distressCount,
      'desperate_markers': desperateCount,
      'detailed_markers': detailedCount,
      'vague_markers': vagueCount,
      'casual_markers': casualCount,
      'financial_markers': financialCount,
      'has_financial_motive': financialCount > 0,
    };
  }

  // ========== REALITY AND CONSISTENCY CHECK ==========
  Map<String, dynamic> _realityAndConsistencyCheck(String text) {
    final lowerText = text.toLowerCase();

    // Initialize scores with non-nullable values
    Map<String, double> scores = {
      'plausibility': 1.0,
      'consistency': 1.0,
      'specificity': 0.0,
      'impossibility': 0.0,
      'supernatural': 0.0,
      'contradictions': 0.0,
      'over_dramatic': 0.0,
      'geographic_plausibility': 1.0,
      'temporal_consistency': 1.0,
    };

    List<String> flags = [];
    List<String> positiveIndicators = [];

    // 1. Check for physically impossible events
    for (var pattern in _realityCheckPatterns['physically_impossible'] ?? []) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(lowerText)) {
        // Safe access with null-coalescing
        scores['impossibility'] = (scores['impossibility'] ?? 0.0) + 0.3;
        scores['plausibility'] = max(0.0, (scores['plausibility'] ?? 1.0) - 0.3);
        flags.add('Physically impossible event: $pattern');
      }
    }

    // 2. Check supernatural claims
    for (var pattern in _realityCheckPatterns['supernatural_claims'] ?? []) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(lowerText)) {
        scores['supernatural'] = (scores['supernatural'] ?? 0.0) + 0.4;
        scores['plausibility'] = max(0.0, (scores['plausibility'] ?? 1.0) - 0.4);
        flags.add('Supernatural claim: $pattern');
      }
    }

    // 3. Check contradictions
    for (var pattern in _realityCheckPatterns['contradictory_details'] ?? []) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(lowerText)) {
        scores['contradictions'] = (scores['contradictions'] ?? 0.0) + 0.2;
        scores['consistency'] = max(0.0, (scores['consistency'] ?? 1.0) - 0.2);
        flags.add('Contradiction: $pattern');
      }
    }

    // 4. Check overly dramatic
    for (var pattern in _realityCheckPatterns['overly_dramatic'] ?? []) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(lowerText)) {
        scores['over_dramatic'] = (scores['over_dramatic'] ?? 0.0) + 0.15;
        flags.add('Overly dramatic language');
      }
    }

    // 5. Check time inconsistencies
    for (var pattern in _consistencyPatterns['time_inconsistency'] ?? []) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(lowerText)) {
        scores['contradictions'] = (scores['contradictions'] ?? 0.0) + 0.15;
        scores['temporal_consistency'] = max(0.0, (scores['temporal_consistency'] ?? 1.0) - 0.15);
        flags.add('Time inconsistency');
      }
    }

    // 6. Check location inconsistencies
    for (var pattern in _consistencyPatterns['location_inconsistency'] ?? []) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(lowerText)) {
        scores['contradictions'] = (scores['contradictions'] ?? 0.0) + 0.15;
        scores['geographic_plausibility'] = max(0.0, (scores['geographic_plausibility'] ?? 1.0) - 0.15);
        flags.add('Location inconsistency');
      }
    }

    // 7. Check detail inconsistencies
    for (var pattern in _consistencyPatterns['detail_inconsistency'] ?? []) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(lowerText)) {
        scores['contradictions'] = (scores['contradictions'] ?? 0.0) + 0.1;
        scores['consistency'] = max(0.0, (scores['consistency'] ?? 1.0) - 0.1);
        flags.add('Detail inconsistency');
      }
    }

    // 8. POSITIVE: Check for specific details (increases plausibility)
    final specificPatterns = [
      r"\b(\d{1,2}:\d{2}\s*(am|pm)?)\b",  // Time
      r"\b(january|february|march|april|may|june|july|august|september|october|november|december)\s+\d{1,2}(?:st|nd|rd|th)?\b",  // Date
      r"\b(house\s+\d+|road\s+\d+|block\s+[a-zA-Z])\b",  // Address
      r"\b([A-Z]{2,3}-\d{1,4})\b",  // Vehicle number
      r"\b(\d+\s*(feet|meters|km|kilometers|miles))\b",  // Measurements
      r"\b(\d+\s*witnesses?|\d+\s*people\s+saw)\b",  // Witness count
    ];

    int specificityCount = 0;
    for (var pattern in specificPatterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(lowerText)) {
        specificityCount++;
        positiveIndicators.add('Specific detail found');
      }
    }

    // Safe calculation with null-coalescing
    final specificityScore = min(specificityCount * 0.2, 1.0);
    scores['specificity'] = specificityScore;
    scores['plausibility'] = min(1.0, (scores['plausibility'] ?? 1.0) + (specificityScore * 0.3));

    // 9. NEGATIVE: Check for vague language
    final vaguePatterns = [
      r"\b(somewhere|someplace|somewhere)\b",
      r"\b(someone|somebody|a\s+person)\b",
      r"\b(something|some\s+stuff|some\s+things)\b",
      r"\b(maybe|perhaps|possibly|probably)\b",
      r"\b(around|about|approximately|roughly)\b",
      r"\b(think|believe|guess|suppose)\b",
      r"\b(not\s+sure|not\s+certain|don't\s+know|unsure)\b",
    ];

    int vagueCount = 0;
    for (var pattern in vaguePatterns) {
      vagueCount += RegExp(pattern, caseSensitive: false).allMatches(lowerText).length;
    }
    final vaguenessScore = min(vagueCount * 0.1, 0.7);
    scores['plausibility'] = max(0.0, (scores['plausibility'] ?? 1.0) - vaguenessScore);
    if (vaguenessScore > 0.3) {
      flags.add('Excessive vague language');
    }

    // 10. Geographic plausibility for Bangladesh
    bool hasBangladeshLocation = false;
    for (var location in _bangladeshLocations) {
      if (_containsWord(lowerText, location)) {
        hasBangladeshLocation = true;
        break;
      }
    }

    // Check for impossible geographic features in Bangladesh
    final impossibleInBangladesh = [
      r"\b(mount\s+everest.*bangladesh|himalayas.*bangladesh)\b",
      r"\b(desert.*bangladesh|sahara.*bangladesh)\b",
      r"\b(volcano.*bangladesh|active\s+volcano)\b",
      r"\b(ocean.*dhaka|sea.*chittagong\s+city)\b",
    ];

    for (var pattern in impossibleInBangladesh) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(lowerText)) {
        scores['geographic_plausibility'] = 0.0;
        flags.add('Impossible geography for Bangladesh');
        break;
      }
    }

    // FIXED: Safe calculation of reality score with null-coalescing
    final realityScore = (
        (scores['plausibility'] ?? 1.0) * 0.35 +
            (scores['consistency'] ?? 1.0) * 0.25 +
            (scores['geographic_plausibility'] ?? 1.0) * 0.15 +
            (scores['temporal_consistency'] ?? 1.0) * 0.15 +
            (scores['specificity'] ?? 0.0) * 0.1 -
            (scores['impossibility'] ?? 0.0) * 0.4 -
            (scores['supernatural'] ?? 0.0) * 0.4 -
            (scores['over_dramatic'] ?? 0.0) * 0.2
    ).clamp(0.0, 1.0);

    // FIXED: Safe comparison for has_impossible_elements
    final hasImpossibleElements =
        (scores['impossibility'] ?? 0.0) > 0.4 ||
            (scores['supernatural'] ?? 0.0) > 0.4;

    return {
      'reality_score': realityScore,
      'scores': scores,
      'flags': flags,
      'positive_indicators': positiveIndicators,
      'is_plausible': realityScore > 0.6,
      'needs_verification': realityScore > 0.3 && realityScore <= 0.6,
      'likely_fake': realityScore <= 0.3,
      'has_impossible_elements': hasImpossibleElements,
      'context_score': (realityScore * 0.7 + (scores['specificity'] ?? 0.0) * 0.3).clamp(0.1, 1.5),
    };
  }

  // ========== MULTI-LANGUAGE PATTERN ANALYSIS ==========
  Map<String, dynamic> _analyzeMultiLanguagePatterns(String text, Map<String, bool> languages) {
    final lowerText = text.toLowerCase();
    final Map<String, double> categoryScores = {
      'dangerous': 0.0,
      'suspicious': 0.0,
      'fake': 0.0,
      'theft': 0.0,
      'assault': 0.0,
      'vandalism': 0.0,
      'normal': 0.1,
    };

    final Map<String, List<String>> matches = {};
    int totalMatches = 0;
    developer.log('🔤 Languages detected: $languages');

    for (final category in _multiLanguagePatterns.keys) {
      final List<String> categoryMatches = [];
      double categoryScore = 0.0;

      // Check each active language
      for (final language in languages.keys.where((lang) => languages[lang] == true)) {
        final languagePatterns = _multiLanguagePatterns[category]?[language];
        developer.log('📁 Category: $category, Language: $language');
        developer.log('📊 Patterns available: ${languagePatterns?.length ?? 0}');
        if (languagePatterns == null) continue;

        for (final pattern in languagePatterns) {
          try {
            final regex = RegExp(pattern, caseSensitive: false);
            final patternMatches = regex.allMatches(lowerText);
            if (patternMatches.isNotEmpty) {
              developer.log('✅ Pattern matched: $pattern');
            }

            for (final match in patternMatches) {
              final matchedText = match.group(0)!;
              if (!categoryMatches.contains(matchedText)) {
                categoryMatches.add(matchedText);
                totalMatches++;

                // Score calculation
                final patternComplexity = pattern.split('.*?').length;
                double baseScore = patternComplexity * 0.3;

                // Language bonus
                if (language == 'bangla') baseScore *= 1.2;  // Bangla gets bonus
                if (language == 'banglish') baseScore *= 1.1; // Banglish gets small bonus

                categoryScore += baseScore;
              }
            }
          } catch (e) {
            // Skip invalid regex patterns
            developer.log('❌ Regex error for pattern: $pattern, Error: $e');
          }
        }
      }

      // Density bonus for multiple matches in same category
      if (categoryMatches.length > 1) {
        categoryScore *= (1.0 + (categoryMatches.length * 0.15));
      }

      categoryScores[category] = categoryScore;
      if (categoryMatches.isNotEmpty) {
        matches[category] = categoryMatches;
        developer.log('🎯 Category "$category" score: $categoryScore');
      }
    }
    developer.log('📊 Final category scores: $categoryScores');

    return {
      'category_scores': categoryScores,
      'matches': matches,
      'total_matches': totalMatches,
      'matches_count': matches.values.fold(0, (sum, list) => sum + list.length),
    };
  }


  Future<void> debugBanglaDetection() async {
    final classifier = TextClassifier();
    await classifier.initialize();

    final testTexts = [
      'বোমা বিস্ফোরণ হয়েছে মতিঝিলে',
      'ড্রাগ নিচ্ছে',
      'রক্তপাত হচ্ছে',
      'আহত হয়েছে',
      'gun fight',
      'bomb attack'
    ];

    for (final text in testTexts) {
      developer.log('\n🔍 Testing: "$text"');

      // Check language detection
      final languages = classifier._detectLanguages(text);
      developer.log('🌐 Languages detected: $languages');

      // Check if patterns match
      final lowerText = text.toLowerCase();

      // Test dangerous patterns
      if (_multiLanguagePatterns['dangerous'] != null) {
        final banglaPatterns = _multiLanguagePatterns['dangerous']!['bangla'] ?? [];
        for (final pattern in banglaPatterns) {
          try {
            if (RegExp(pattern, caseSensitive: false).hasMatch(lowerText)) {
              developer.log('✅ Bangla pattern matched: $pattern');
            }
          } catch (e) {
            developer.log('❌ Pattern error: $pattern');
          }
        }
      }
    }

    classifier.dispose();
  }

  // ========== KEYWORD ANALYSIS ==========
  Map<String, dynamic> _analyzeKeywords(String lowerText) {
    final Map<String, double> categoryScores = {
      'dangerous': 0.0,
      'suspicious': 0.0,
      'fake': 0.0,
      'theft': 0.0,
      'assault': 0.0,
      'vandalism': 0.0,
      'normal': 0.0,
    };

    final List<Map<String, dynamic>> foundKeywords = [];

    for (final entry in _keywordDetails.entries) {
      final keyword = entry.key;
      final details = entry.value;
      final weight = details['weight'] as double;
      final categories = (details['categories'] as List<dynamic>).cast<String>();

      if (_containsWord(lowerText, keyword)) {
        foundKeywords.add({
          'keyword': keyword,
          'weight': weight,
          'categories': categories,
          'psychology': details['psychology'] as String? ?? 'neutral',
        });

        // Distribute weight across categories
        final weightPerCategory = weight / max(1, categories.length);
        for (final category in categories) {
          categoryScores[category] = (categoryScores[category] ?? 0.0) + weightPerCategory;
        }
      }
    }

    // Normalize keyword scores
    final maxScore = categoryScores.values.fold(0.0, max);
    if (maxScore > 0) {
      for (final category in categoryScores.keys) {
        categoryScores[category] = (categoryScores[category]! / maxScore) * 10;
      }
    }

    return {
      'category_scores': categoryScores,
      'keywords': foundKeywords,
      'total_keywords': foundKeywords.length,
    };
  }

  // ========== BANGLADESH CONTEXT ANALYSIS ==========
  Map<String, dynamic> _analyzeBangladeshContext(String text) {
    final lowerText = text.toLowerCase();

    bool locationMentioned = false;
    List<String> foundLocations = [];

    for (final location in _bangladeshLocations) {
      if (_containsWord(lowerText, location)) {
        locationMentioned = true;
        foundLocations.add(location);
      }
    }

    // Check for Bangladeshi cultural terms
    final culturalTerms = [
      'hartal', 'puja', 'eid', 'ramadan', 'bazaar', 'haat',
      'union', 'upazila', 'thana', 'ward', 'pourashava',
      'brac', 'grameen', 'sonali', 'janata',
      'panta', 'ilish', 'ruti', 'dal', 'bhorta'
    ];

    bool culturalRelevance = false;
    for (final term in culturalTerms) {
      if (_containsWord(lowerText, term)) {
        culturalRelevance = true;
        break;
      }
    }

    // DETECT LANGUAGE
    String detectedLanguage = 'english';
    if (text.contains(RegExp(r'[\u0980-\u09FF]'))) {
      detectedLanguage = 'bangla';
    } else if (_detectBanglish(text)) {
      detectedLanguage = 'banglish';
    }

    return {
      'location_mentioned': locationMentioned,
      'cultural_relevance': culturalRelevance,
      'found_locations': foundLocations,
      'language': detectedLanguage, // NEW: Add language detection
      'modifier': locationMentioned ? 1.3 : (culturalRelevance ? 1.2 : 1.0),
    };
  }

  bool _detectBanglish(String text) {
    final lowerText = text.toLowerCase();
    final banglishPatterns = [
      r"\b(khobor|khbr|news)\b",
      r"\b(hoyni|hoina|hoise|hoiche)\b",
      r"\b(korchi|korlam|korbe|korlo)\b",
      r"\b(ache|nei|asa|jai)\b",
      r"\b(ekhon|akhn|ekhane|okhane)\b",
    ];

    int matches = 0;
    for (var pattern in banglishPatterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(lowerText)) {
        matches++;
      }
    }
    return matches >= 2;
  }

  // ========== FINAL SCORE CALCULATION ==========
  Map<String, double> _calculateFinalScores(
      Map<String, double> patternScores,
      Map<String, double> keywordScores,
      Map<String, dynamic> psychology,
      Map<String, dynamic> reality,
      Map<String, dynamic> bangladeshContext
      ) {
    final Map<String, double> finalScores = {};
    final allCategories = ['dangerous', 'suspicious', 'fake', 'theft', 'assault', 'vandalism', 'normal'];

    // DETECT IF TEXT IS IN BANGLA
    final isBangla = (bangladeshContext['language'] as String? ?? 'english') == 'bangla';

    // Psychology modifier
    double psychologyModifier = 1.0;
    final emotionalTone = psychology['emotional_tone'] as String? ?? 'neutral';

    switch (emotionalTone) {
      case 'high_distress': psychologyModifier = 1.5; break;
      case 'moderate_distress': psychologyModifier = 1.3; break;
      case 'mild_distress': psychologyModifier = 1.1; break;
      case 'casual': psychologyModifier = 0.7; break;
    }

    final credibility = psychology['credibility'] as double? ?? 0.5;
    psychologyModifier *= credibility;

    // Reality modifier
    final realityScore = reality['reality_score'] as double? ?? 0.5;
    double realityModifier = realityScore > 0.7 ? 1.3 :
    realityScore > 0.4 ? 1.0 :
    realityScore > 0.2 ? 0.6 : 0.3;

    for (final category in allCategories) {
      final patternScore = patternScores[category] ?? 0.0;
      final keywordScore = keywordScores[category] ?? 0.0;

      // Weighted combination (70% patterns, 30% keywords)
      double combinedScore = (patternScore * 0.7) + (keywordScore * 0.3);

      // 🔥 CRITICAL FIX: APPLY BANGLA BOOST
      if (isBangla && category != 'normal') {
        // Bangla reports get significant boost
        double banglaBoost = 3.0; // Triple the score for Bangla
        if (category == 'dangerous') {
          banglaBoost = 4.0; // Even more for dangerous
        }
        combinedScore *= banglaBoost; // 🔥 THIS WAS MISSING!
      }

      // Apply modifiers
      combinedScore *= psychologyModifier;
      combinedScore *= realityModifier;
      combinedScore *= (bangladeshContext['modifier'] as double? ?? 1.0);
      combinedScore *= (reality['context_score'] as double? ?? 1.0);

      // Special handling for fake category
      if (category == 'fake') {
        final hasImpossible = reality['has_impossible_elements'] as bool? ?? false;
        final hasFinancial = psychology['has_financial_motive'] as bool? ?? false;

        if (hasImpossible) {
          combinedScore *= 1.5;
        }
        if (hasFinancial) {
          combinedScore *= 1.3;
        }
      }

      // Special handling for dangerous category
      if (category == 'dangerous') {
        final isPlausible = reality['is_plausible'] as bool? ?? false;
        final likelyFake = reality['likely_fake'] as bool? ?? false;

        if (isPlausible && credibility > 0.7) {
          combinedScore *= 1.4;
        }
        if (likelyFake) {
          combinedScore *= 0.3;
        }
      }

      finalScores[category] = combinedScore.clamp(0.0, 20.0);
    }

    // DEBUG: Log final scores
    developer.log('📊 FINAL SCORES (after modifiers): $finalScores');

    return finalScores;
  }

  // ========== LABEL DETERMINATION WITH REALITY OVERRIDE ==========
  String _determineLabelWithRealityOverride(
      Map<String, double> scores,
      Map<String, dynamic> psychology,
      Map<String, dynamic> reality,
      String text
      ) {
    // Find highest score among main categories
    final mainCategories = ['dangerous', 'suspicious', 'fake', 'normal'];
    String primaryLabel = 'normal';
    double maxScore = scores['normal'] ?? 0.0;

    for (final category in mainCategories) {
      if (scores[category] != null && scores[category]! > maxScore) {
        maxScore = scores[category]!;
        primaryLabel = category;
      }
    }

    // REALITY OVERRIDE SYSTEM
    // If reality suggests fake but current label is dangerous/suspicious
    if (reality['likely_fake'] &&
        (primaryLabel == 'dangerous' || primaryLabel == 'suspicious')) {
      if (reality['scores']['impossibility'] > 0.4 ||
          reality['scores']['supernatural'] > 0.4) {
        return 'fake';  // Override to fake for impossible/supernatural claims
      }
    }

    // If reality score is high but label is fake (check for false positives)
    if (reality['is_plausible'] && primaryLabel == 'fake') {
      if (reality['scores']['specificity'] > 0.5 &&
          psychology['credibility'] > 0.6) {
        return 'suspicious';  // Upgrade fake to suspicious if plausible and specific
      }
    }

    // Check for immediate danger signals
    final lowerText = text.toLowerCase();
    final immediateDangerKeywords = [
      'dying', 'bleeding', 'trapped', 'cannot breathe', 'heart attack',
      'fire', 'burning', 'drowning', 'suffocating', 'choking'
    ];

    if (primaryLabel != 'dangerous') {
      for (final keyword in immediateDangerKeywords) {
        if (lowerText.contains(keyword) &&
            psychology['emotional_tone'].contains('distress')) {
          return 'dangerous';  // Override for immediate danger
        }
      }
    }

    // Threshold check
    final thresholds = {
      'dangerous': 0.25,
      'suspicious': 0.2,
      'fake': 0.18,
      'theft': 0.15,
      'assault': 0.15,
      'vandalism': 0.12,
      'normal': 0.05,
    };

    if (maxScore >= (thresholds[primaryLabel] ?? 0.1)) {
      return primaryLabel;
    }

    return 'normal';
  }

  // ========== ENHANCED CONFIDENCE CALCULATION ==========
  double _calculateEnhancedConfidence(
      Map<String, double> scores,
      String label,
      int patternMatches,
      int keywordCount,
      Map<String, dynamic> reality,
      Map<String, dynamic> psychology
      ) {
    double baseConfidence = scores[label] ?? 0.0;

    // Normalize based on category
    final normalization = {
      'dangerous': 8.0,
      'suspicious': 6.0,
      'fake': 5.0,
      'theft': 5.0,
      'assault': 5.0,
      'vandalism': 4.0,
      'normal': 3.0,
    };

    baseConfidence = (baseConfidence / normalization[label]!).clamp(0.0, 0.95);

    // Pattern match bonus
    if (patternMatches > 0) {
      baseConfidence += min(patternMatches * 0.08, 0.3);
    }

    // Keyword count bonus
    if (keywordCount > 0) {
      baseConfidence += min(keywordCount * 0.05, 0.2);
    }

    // Reality score adjustment
    if (reality['is_plausible'] && label != 'fake') {
      baseConfidence *= 1.3;
    } else if (reality['likely_fake'] && label == 'fake') {
      baseConfidence *= 1.4;
    } else if (reality['needs_verification']) {
      baseConfidence *= 0.8;
    }

    // Psychology adjustment
    if (psychology['credibility'] > 0.7 && label != 'fake') {
      baseConfidence *= 1.2;
    }
    if (psychology['emotional_tone'] == 'high_distress' && label == 'dangerous') {
      baseConfidence *= 1.3;
    }

    // Score gap factor (difference between top two scores)
    final sortedScores = scores.values.toList()..sort((a, b) => b.compareTo(a));
    if (sortedScores.length > 1) {
      final scoreGap = sortedScores[0] - sortedScores[1];
      if (scoreGap > 2.0) {
        baseConfidence += min(scoreGap * 0.1, 0.3);
      }
    }

    // Minimum confidence for dangerous reports
    if (label == 'dangerous' && baseConfidence < 0.4) {
      baseConfidence = 0.4;
    }

    return baseConfidence.clamp(0.1, 0.99);
  }

  // ========== GENERATE COMPREHENSIVE VERDICT ==========
  String _generateComprehensiveVerdict(
      String label,
      Map<String, dynamic> reality,
      Map<String, dynamic> psychology,
      Map<String, dynamic> bangladeshContext
      ) {
    switch (label) {
      case 'fake':
        if (reality['scores']['impossibility'] > 0.4) {
          return 'FAKE: Physically impossible events described';
        }
        if (reality['scores']['supernatural'] > 0.4) {
          return 'FAKE: Contains supernatural/paranormal claims';
        }
        if (reality['scores']['contradictions'] > 0.3) {
          return 'FAKE: Multiple contradictions detected';
        }
        if (psychology['has_financial_motive']) {
          return 'FAKE: Financial motive detected';
        }
        return 'FAKE: Likely fabricated content';

      case 'dangerous':
        if (reality['is_plausible'] && psychology['credibility'] > 0.7) {
          return 'DANGEROUS: Highly plausible with credible details - URGENT';
        }
        if (psychology['urgency_level'] == 'extreme') {
          return 'DANGEROUS: Extreme urgency - IMMEDIATE RESPONSE NEEDED';
        }
        if (bangladeshContext['location_mentioned']) {
          return 'DANGEROUS: Location-specific threat in Bangladesh';
        }
        return 'DANGEROUS: Potential emergency situation';

      case 'suspicious':
        if (reality['needs_verification']) {
          return 'SUSPICIOUS: Requires verification - inconsistencies found';
        }
        if (bangladeshContext['location_mentioned']) {
          return 'SUSPICIOUS: Unusual activity at known location';
        }
        return 'SUSPICIOUS: Potentially concerning activity';

      case 'theft':
        return 'THEFT: Property crime reported';

      case 'assault':
        return 'ASSAULT: Physical violence reported';

      case 'vandalism':
        return 'VANDALISM: Property damage reported';

      default:
        return 'NORMAL: No concerning content detected';
    }
  }

  // ========== HELPER METHODS ==========
  Map<String, double> _extractCrimeTypes(Map<String, double> scores) {
    final crimeTypes = ['theft', 'assault', 'vandalism'];
    final result = <String, double>{};

    for (final type in crimeTypes) {
      if (scores[type] != null && scores[type]! > 0.1) {
        result[type] = scores[type]!;
      }
    }

    return result;
  }

  bool _containsWord(String text, String word) {
    final escapedWord = RegExp.escape(word);
    final pattern = r'\b' + escapedWord + r'\b';
    return RegExp(pattern, caseSensitive: false).hasMatch(text);
  }

  Map<String, dynamic> _getDefaultResult() {
    return {
      'label': 'normal',
      'confidence': 0.5,
      'scores': {'normal': 0.5},
      'crime_types': {},
      'pattern_matches': {},
      'keywords_found': [],
      'context_score': 1.0,
      'psychology_analysis': {'emotional_tone': 'neutral'},
      'bangladesh_context': {'location_mentioned': false},
      'reality_analysis': {'reality_score': 0.5, 'flags': []},
      'detected_languages': {'english': true},
      'is_multi_language': false,
      'final_verdict': 'NORMAL: No concerning content detected',
      'debug_log': _debugLog,
    };
  }

  // ========== TEST METHOD ==========
  Future<Map<String, dynamic>> testCase(String text, {String? expectedLabel}) async {
    developer.log("\n🧪 TEST CASE ==================================");
    developer.log("📋 Input: $text");

    final result = await classify(text);

    developer.log("🎯 Result: ${result['label']} (${(result['confidence'] * 100).toStringAsFixed(1)}%)");
    developer.log("🧠 Reality: ${(result['reality_analysis']['reality_score'] * 100).toStringAsFixed(1)}%");
    developer.log("⚖️  Verdict: ${result['final_verdict']}");

    if (expectedLabel != null) {
      final passed = result['label'] == expectedLabel;
      developer.log(passed ? "✅ TEST PASSED" : "❌ TEST FAILED - Expected: $expectedLabel");
    }

    if (result['reality_analysis']['flags'].isNotEmpty) {
      developer.log("🚩 Flags: ${result['reality_analysis']['flags'].length} found");
    }

    developer.log("🌐 Languages: ${result['detected_languages']}");
    developer.log("============================================\n");

    return result;
  }

  // ========== DISPOSE ==========
  void dispose() {
    developer.log("🧹 Enhanced classifier disposed");
    _debugLog.clear();
  }
}

// ========== TEST CASES ==========
final testCases = [
  // REAL DANGEROUS CASES
  {
    'text': 'A man was shot near Gulshan Lake at 8:30 PM. He is bleeding heavily and needs urgent help. I saw two men running away with guns.',
    'expected': 'dangerous'
  },
  {
    'text': 'বোমা বিস্ফোরণ হয়েছে মতিঝিলে। অনেক মানুষ আহত হয়েছে। এখনও ধোঁয়া উঠছে।',
    'expected': 'dangerous'
  },
  {
    'text': 'Mobile snatch by bike in Mirpur 10. Two guys on motorcycle took my phone and ran towards Gulshan.',
    'expected': 'theft'
  },

  // FAKE/IMPROBABLE CASES
  {
    'text': 'A ghost attacked me in my house in Dhaka. It became invisible and stole my money.',
    'expected': 'fake'
  },
  {
    'text': 'I can fly without wings and I saw an alien robbery at Banani. They teleported away.',
    'expected': 'fake'
  },
  {
    'text': 'জাদুর ছড়ি দিয়ে একজন আমার টাকা চুরি করেছে। সে অদৃশ্য হয়ে গেছে।',
    'expected': 'fake'
  },

  // SUSPICIOUS CASES
  {
    'text': 'Some suspicious people are hiding weapons in a car near Dhanmondi Lake. They are acting strange.',
    'expected': 'suspicious'
  },
  {
    'text': 'দুইজন যুবক রাতে পার্কে সন্দেহজনক আচরণ করছে। তারা কিছু লুকিয়ে রাখছে।',
    'expected': 'suspicious'
  },

  // BANGLISH CASES
  {
    'text': 'Ami dekhechi ekta murder hoise Gulshan e. 3 jon mara gese. Police ashe nai.',
    'expected': 'dangerous'
  },
  {
    'text': 'Mobile churi hoise Mirpur 10 e. Bike e 2 jon chor. Amar phone niye palaise.',
    'expected': 'theft'
  },

  // CONSISTENCY TEST
  {
    'text': 'I saw a murder yesterday but it will happen tomorrow. The man was killed but he is still talking to me.',
    'expected': 'fake'
  },

  // FINANCIAL SCAM
  {
    'text': 'Send me 5000 taka mobile recharge and I will tell you about a secret bomb attack in Dhaka.',
    'expected': 'fake'
  },

  // MIXED LANGUAGE
  {
    'text': 'Gulshan e ekta বোমা attack hoise. Ami dekhechi. অনেক মানুষ injured. Help needed now.',
    'expected': 'dangerous'
  }
];

void runAllTests() async {
  final classifier = TextClassifier();
  await classifier.initialize();

  for (int i = 0; i < testCases.length; i++) {
    final test = testCases[i];
    await classifier.testCase(test['text']!, expectedLabel: test['expected']);
  }

  classifier.dispose();
}