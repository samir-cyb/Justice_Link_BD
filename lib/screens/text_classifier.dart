import 'dart:math';
import 'dart:developer' as developer;

class TextClassifier {
  bool _isInitialized = false;
  final Map<String, List<String>> _debugLog = {};

  // Enhanced sentence-level crime patterns with Bangladeshi context
  final Map<String, List<String>> _sentencePatterns = {
    'dangerous': [
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
    'suspicious': [
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
    'fake': [
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
      r"(invisible.*(thief|thieves|person|man|woman).*(stealing|robbing))",
      r"(aliens?.*(rob|robbery|bank|crime|steal|attack))",
      r"(superhero.*(stop|saved|rescue).*crime)",
      r"(mind.?control.*(device|machine|government|traffic.*light))",
      r"(ghost.*(crime|theft|murder|attack))",
      r"(magic.*(spell|wand|curse).*crime)",
      r"(time.*travel.*(crime|theft|prevent))",
      r"(teleport.*(crime|escape|robbery))",
      r"(supernatural.*(power|ability).*crime)",
      r"(fantasy.*(creature|being).*crime)",
      r"(impossible.*(crime|theft|event|situation))",
      r"(clearly.*fake.*(story|report|incident))",
      r"(obviously.*not.*real.*(crime|incident))",
      r"(sounds.*like.*(movie|fiction|fantasy))",
      r"(this.*must.*be.*(joke|prank|fake))",
      r"(unbelievable.*(story|claim|incident))",
      r"(physically.*impossible.*(crime|theft))",
      r"(scientifically.*impossible.*(event))",
      r"(magically.*(appeared|disappeared|vanished))",
      r"(psychic.*(power|ability).*crime)",
      r"(levitat.*(crime|escape|theft))",
      r"(fly.*(without.*wings|air).*crime)",
      r"(read.*minds.*(crime|prevent))",
      r"(became.*invisible.*(crime|escape))",
      r"(turned.*into.*(animal|object).*crime)",
      r"(vampire.*werewolf.*(crime|attack))",
      r"(zombie.*apocalypse.*crime)",
      r"(unicorn.*(crime|magic|theft))",
      r"(dragon.*(attack|crime|theft))",
      r"(wizard.*witch.*(crime|spell))",
      r"(fairy.*(crime|magic|theft))",
      r"(mermaid.*(crime|attack|theft))",
      r"(extraterrestrial.*(crime|attack|abduction))",
      r"(ufo.*(crime|abduction|attack))",
      r"(paranormal.*(activity|event).*crime)",
      r"(haunted.*(place|house).*crime)",
      r"(possessed.*(person|object).*crime)",
      r"(cursed.*(object|place).*crime)",
      r"(mythical.*(creature|being).*crime)",
      r"(legendary.*(creature|being).*crime)",
      r"(fictional.*(character|being).*crime)",
      r"(cartoon.*(character|show).*crime)",
      r"(animated.*(character|movie).*crime)",
      r"(comic.*book.*(character|hero).*crime)",
      r"(movie.*character.*(real|crime))",
      r"(tv.*show.*(character|plot).*crime)",
      r"(video.*game.*(character|plot).*crime)",
      r"(novel.*fiction.*(plot|character).*crime)",
      r"(science.*fiction.*(plot|device).*crime)",
      r"(fantasy.*novel.*(plot|character).*crime)",
      r"(horror.*movie.*(plot|scene).*crime)",
    ],
    'theft': [
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
    'assault': [
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
    'vandalism': [
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
  };

  // Enhanced keyword weights with psychological scoring
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

    // NEWLY ADDED KEYWORDS TO FIX THE PROBLEMS:
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

    // ADD THESE ABSURDITY KEYWORDS:
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
  };

  // Enhanced context modifiers with psychology
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

    // Add to your _contextModifiers:
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

  // Bangladeshi location patterns
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

  // Psychological assessment patterns
  final Map<String, RegExp> _psychologyPatterns = {
    'emotional_distress': RegExp(r'\b(crying|screaming|shaking|terrified|panicking|frightened|scared|afraid|horrified)\b', caseSensitive: false),
    'desperate_call': RegExp(r'\b(help|please help|save me|rescue|emergency|urgent|dying|bleeding|injured|trapped)\b', caseSensitive: false),
    'detailed_description': RegExp(r'\b(approximately|exactly|precisely|specifically|details|description|observed|saw|heard|witnessed)\b', caseSensitive: false),
    'vague_language': RegExp(r'\b(maybe|perhaps|possibly|could be|might be|not sure|think|believe|guess|probably)\b', caseSensitive: false),
    'casual_language': RegExp(r'\b(lol|haha|hehe|lmao|rofl|jk|just kidding|funny|hilarious|hahaha)\b', caseSensitive: false),
    'financial_motive': RegExp(r'\b(money|taka|lakh|crore|reward|payment|tk|bdt|mobile recharge|bkash|nagad|rocket|cash)\b', caseSensitive: false),
  };

  Future<void> initialize() async {
    developer.log("🧠 TextClassifier: Initializing Psychology-Enhanced Classifier");
    developer.log("📍 Context: Bangladesh-specific crime patterns integrated");
    developer.log("📊 Stats: ${_sentencePatterns.length} categories, ${_sentencePatterns.values.fold(0, (sum, patterns) => sum + patterns.length)} patterns");

    _isInitialized = true;
    _debugLog['initialization'] = ['Classifier initialized successfully'];

    developer.log("✅ TextClassifier: Enhanced classifier ready with psychology analysis");
  }

  Future<Map<String, dynamic>> classify(String text) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      if (text.length < 3) {
        developer.log("⚠️ TextClassifier: Text too short (${text.length} chars)");
        return _getDefaultResult();
      }

      // Clear previous debug log
      _debugLog.clear();
      _debugLog['input_text'] = [text];
      _debugLog['text_length'] = ['${text.length} characters'];

      developer.log("\n🔍 TextClassifier: Analyzing text (${text.length} chars)");
      developer.log("📝 Text: ${text.substring(0, min(text.length, 100))}${text.length > 100 ? '...' : ''}");

      final result = _psychologyEnhancedClassification(text);

      developer.log("\n🎯 Classification Result:");
      developer.log("🏷️  Label: ${result['label']}");
      developer.log("📈 Confidence: ${(result['confidence'] * 100).toStringAsFixed(1)}%");
      developer.log("📊 Scores: ${result['scores']}");

      if (_debugLog.containsKey('pattern_matches')) {
        developer.log("🔤 Pattern Matches: ${_debugLog['pattern_matches']!.length} found");
      }
      if (_debugLog.containsKey('keywords_found')) {
        developer.log("🔑 Keywords Found: ${_debugLog['keywords_found']!.length}");
      }
      if (_debugLog.containsKey('psychology_analysis')) {
        developer.log("🧠 Psychology Analysis:");
        for (var analysis in _debugLog['psychology_analysis']!) {
          developer.log("   - $analysis");
        }
      }

      return {
        'label': result['label'],
        'confidence': result['confidence'],
        'scores': result['scores'],
        'crime_types': result['crime_types'],
        'pattern_matches': result['pattern_matches'],
        'keywords_found': result['keywords_found'],
        'context_score': result['context_score'],
        'psychology_analysis': result['psychology_analysis'],
        'bangladesh_context': result['bangladesh_context'],
        'debug_log': _debugLog,
      };
    } catch (e) {
      developer.log("❌ TextClassifier: Error in classification: $e");
      return _getDefaultResult();
    }
  }

  Map<String, dynamic> _psychologyEnhancedClassification(String text) {
    final lowerText = text.toLowerCase();
    final Map<String, dynamic> psychologyAnalysis = {};
    final Map<String, dynamic> bangladeshContext = {};

    // Step 1: Psychology Analysis
    psychologyAnalysis['emotional_tone'] = _analyzeEmotionalTone(text);
    psychologyAnalysis['credibility_indicators'] = _analyzeCredibility(text);
    psychologyAnalysis['urgency_level'] = _analyzeUrgency(text);
    psychologyAnalysis['language_consistency'] = _analyzeLanguageConsistency(text);

    _debugLog['psychology_analysis'] = [
      'Emotional tone: ${psychologyAnalysis['emotional_tone']}',
      'Credibility: ${psychologyAnalysis['credibility_indicators']}',
      'Urgency: ${psychologyAnalysis['urgency_level']}',
      'Consistency: ${psychologyAnalysis['language_consistency']}',
    ];

    // Step 2: Bangladesh Context Analysis
    bangladeshContext['location_mentioned'] = _checkBangladeshLocation(lowerText);
    bangladeshContext['cultural_relevance'] = _checkCulturalRelevance(lowerText);

    _debugLog['bangladesh_context'] = [
      'Location: ${bangladeshContext['location_mentioned']}',
      'Cultural relevance: ${bangladeshContext['cultural_relevance']}',
    ];

    // Step 3: Sentence Pattern Analysis
    final patternAnalysis = _analyzeSentencePatterns(text);
    final patternScores = patternAnalysis['scores'];
    final patternMatches = patternAnalysis['matches'];

    _debugLog['pattern_matches'] = [];
    patternMatches.forEach((category, matches) {
      if (matches.isNotEmpty) {
        _debugLog['pattern_matches']!.add('$category: ${matches.length} matches');
      }
    });

    // Step 4: Enhanced Context Analysis
    final contextAnalysis = _analyzeContext(lowerText);
    final contextScore = contextAnalysis['score'];
    final contextDetails = contextAnalysis['details'];

    _debugLog['context_analysis'] = ['Score: $contextScore', 'Details: $contextDetails'];

    // Step 5: Sentence Complexity
    final complexityModifier = _calculateSentenceComplexity(text);
    _debugLog['complexity'] = ['Modifier: $complexityModifier'];

    // Step 6: Enhanced Keyword Analysis with Psychology
    final keywordAnalysis = _calculateKeywordScores(lowerText);
    final keywordScores = keywordAnalysis['scores'];
    final keywordsFound = keywordAnalysis['found'];

    _debugLog['keywords_found'] = ['Total: ${keywordsFound.length}'];

    // Step 7: Psychology-based score adjustment
    final psychologyModifier = _calculatePsychologyModifier(psychologyAnalysis);
    _debugLog['psychology_modifier'] = ['Modifier: $psychologyModifier'];

    // Step 8: Bangladesh context adjustment
    final bangladeshModifier = _calculateBangladeshModifier(bangladeshContext);
    _debugLog['bangladesh_modifier'] = ['Modifier: $bangladeshModifier'];

    // Step 9: Combine all scores
    final Map<String, double> finalScores = {};
    final allCategories = {'dangerous', 'suspicious', 'theft', 'assault', 'vandalism', 'fake', 'normal'};

    for (final category in allCategories) {
      final patternScore = patternScores[category] ?? 0.0;
      final keywordScore = keywordScores[category] ?? 0.0;

      // Weighted combination
      final combinedScore = (patternScore * 0.7) + (keywordScore * 0.3);

      // Apply all modifiers
      finalScores[category] = combinedScore *
          contextScore *
          complexityModifier *
          psychologyModifier *
          bangladeshModifier;
    }

    // Step 10: Determine primary label with psychology-based thresholds
    final primaryLabel = _determinePrimaryLabelWithPsychology(finalScores, text, psychologyAnalysis);
    _debugLog['primary_label_logic'] = ['Selected: $primaryLabel'];

    // Step 11: Calculate enhanced confidence
    final confidence = _calculatePsychologyBasedConfidence(
        finalScores,
        primaryLabel,
        text,
        patternMatches,
        keywordsFound.length,
        psychologyAnalysis,
        bangladeshContext
    );

    _debugLog['confidence_calculation'] = ['Final confidence: ${(confidence * 100).toStringAsFixed(1)}%'];

    // Step 12: Get crime types
    final crimeTypes = _getDetectedCrimeTypes(finalScores);

    return {
      'label': primaryLabel,
      'confidence': confidence,
      'scores': finalScores,
      'crime_types': crimeTypes,
      'pattern_matches': patternMatches,
      'keywords_found': keywordsFound,
      'context_score': contextScore,
      'psychology_analysis': psychologyAnalysis,
      'bangladesh_context': bangladeshContext,
      'debug_log': _debugLog,
    };
  }

  // Psychology Analysis Methods
  String _analyzeEmotionalTone(String text) {
    int distressCount = 0;
    int casualCount = 0;

    for (final pattern in _psychologyPatterns.entries) {
      final matches = pattern.value.allMatches(text.toLowerCase());
      if (pattern.key == 'emotional_distress' || pattern.key == 'desperate_call') {
        distressCount += matches.length;
      } else if (pattern.key == 'casual_language') {
        casualCount += matches.length;
      }
    }

    if (distressCount >= 3) return 'high_distress';
    if (distressCount >= 2) return 'moderate_distress';
    if (distressCount >= 1) return 'mild_distress';
    if (casualCount >= 2) return 'casual';
    return 'neutral';
  }

  String _analyzeCredibility(String text) {
    int credibilityMarkers = 0;
    int vagueMarkers = 0;

    for (final pattern in _psychologyPatterns.entries) {
      final matches = pattern.value.allMatches(text.toLowerCase());
      if (pattern.key == 'detailed_description') {
        credibilityMarkers += matches.length;
      } else if (pattern.key == 'vague_language') {
        vagueMarkers += matches.length;
      }
    }

    if (credibilityMarkers >= 3 && vagueMarkers == 0) return 'high';
    if (credibilityMarkers >= 2 && vagueMarkers <= 1) return 'moderate';
    if (vagueMarkers >= 2) return 'low';
    return 'neutral';
  }

  String _analyzeUrgency(String text) {
    int urgentMarkers = 0;
    for (final modifier in _contextModifiers['urgency_boosters']!) {
      final word = modifier['word'] as String;
      if (_containsWord(text.toLowerCase(), word)) {
        urgentMarkers++;
      }
    }

    if (urgentMarkers >= 3) return 'extreme_urgency';
    if (urgentMarkers >= 2) return 'high_urgency';
    if (urgentMarkers >= 1) return 'moderate_urgency';
    return 'low_urgency';
  }

  String _analyzeLanguageConsistency(String text) {
    final hasUrgency = _analyzeUrgency(text) != 'low_urgency';
    final hasEmotion = _analyzeEmotionalTone(text).contains('distress');
    final hasCredibility = _analyzeCredibility(text) == 'high';

    // Check for consistency between urgency and emotion
    if (hasUrgency && !hasEmotion) return 'inconsistent';
    if (hasEmotion && !hasUrgency) return 'inconsistent';
    if (hasUrgency && hasEmotion && hasCredibility) return 'highly_consistent';
    return 'consistent';
  }

  double _calculatePsychologyModifier(Map<String, dynamic> psychologyAnalysis) {
    double modifier = 1.0;

    switch (psychologyAnalysis['emotional_tone']) {
      case 'high_distress': modifier *= 1.5; break;
      case 'moderate_distress': modifier *= 1.3; break;
      case 'mild_distress': modifier *= 1.1; break;
      case 'casual': modifier *= 0.7; break;
    }

    switch (psychologyAnalysis['credibility_indicators']) {
      case 'high': modifier *= 1.4; break;
      case 'moderate': modifier *= 1.1; break;
      case 'low': modifier *= 0.6; break;
    }

    switch (psychologyAnalysis['urgency_level']) {
      case 'extreme_urgency': modifier *= 1.6; break;
      case 'high_urgency': modifier *= 1.4; break;
      case 'moderate_urgency': modifier *= 1.2; break;
    }

    switch (psychologyAnalysis['language_consistency']) {
      case 'highly_consistent': modifier *= 1.3; break;
      case 'consistent': modifier *= 1.0; break;
      case 'inconsistent': modifier *= 0.5; break;
    }

    return modifier.clamp(0.3, 2.0);
  }

  // Bangladesh Context Methods
  bool _checkBangladeshLocation(String text) {
    for (final location in _bangladeshLocations) {
      if (_containsWord(text, location)) {
        return true;
      }
    }
    return false;
  }

  bool _checkCulturalRelevance(String text) {
    final culturalTerms = [
      'hartal', 'puja', 'eid', 'ramadan', 'bazaar', 'haat',
      'union', 'upazila', 'thana', 'ward', 'pourashava',
      'brac', 'grameen', 'sonali', 'janata', 'ritu',
      'panta', 'ilish', 'ruti', 'dal', 'bhorta'
    ];

    for (final term in culturalTerms) {
      if (_containsWord(text, term)) {
        return true;
      }
    }
    return false;
  }

  double _calculateBangladeshModifier(Map<String, dynamic> bangladeshContext) {
    double modifier = 1.0;

    if (bangladeshContext['location_mentioned'] == true) {
      modifier *= 1.3;
    }

    if (bangladeshContext['cultural_relevance'] == true) {
      modifier *= 1.2;
    }

    return modifier.clamp(1.0, 1.5);
  }

  // Updated Pattern Analysis
  Map<String, dynamic> _analyzeSentencePatterns(String text) {
    final lowerText = text.toLowerCase();
    final Map<String, double> patternScores = {};
    final Map<String, List<String>> patternMatches = {};

    for (final category in _sentencePatterns.keys) {
      double categoryScore = 0.0;
      final List<String> categoryMatches = [];

      for (final pattern in _sentencePatterns[category]!) {
        try {
          final regex = RegExp(pattern, caseSensitive: false);
          final matches = regex.allMatches(lowerText);

          for (final match in matches) {
            final matchedText = match.group(0)!;
            if (!categoryMatches.contains(matchedText)) {
              categoryMatches.add(matchedText);

              // Score based on pattern specificity
              final patternComplexity = pattern.split('.*?').length;
              final baseScore = patternComplexity * 0.3;

              // Bonus for exact matches
              if (!pattern.contains('.*?')) {
                categoryScore += baseScore * 1.5;
              } else {
                categoryScore += baseScore;
              }
            }
          }
        } catch (e) {
          // Skip invalid patterns
        }
      }

      // Density bonus for multiple matches
      if (categoryMatches.length > 1) {
        categoryScore *= (1 + (categoryMatches.length * 0.2));
      }

      if (categoryScore > 0) {
        patternMatches[category] = categoryMatches;
      }

      patternScores[category] = categoryScore;
    }

    return {
      'scores': patternScores,
      'matches': patternMatches,
    };
  }

  // Enhanced Context Analysis
  Map<String, dynamic> _analyzeContext(String lowerText) {
    double contextScore = 1.0;
    final Map<String, dynamic> contextDetails = {};

    // Urgency boost
    double urgencyBoost = 0.0;
    for (final modifier in _contextModifiers['urgency_boosters']!) {
      final word = modifier['word'] as String;
      final boost = modifier['boost'] as double;
      if (_containsWord(lowerText, word)) {
        urgencyBoost += boost;
        contextDetails['urgency_$word'] = boost;
      }
    }
    if (urgencyBoost > 0) {
      contextScore *= (1 + min(urgencyBoost, 1.5));
    }

    // Time reduction
    double timeReduction = 0.0;
    for (final modifier in _contextModifiers['time_reducers']!) {
      final word = modifier['word'] as String;
      final reduction = modifier['reduction'] as double;
      if (_containsWord(lowerText, word)) {
        timeReduction += reduction;
        contextDetails['time_$word'] = reduction;
      }
    }
    if (timeReduction > 0) {
      contextScore *= (1 - min(timeReduction, 0.7));
    }

    // Credibility boost
    double credibilityBoost = 0.0;
    for (final modifier in _contextModifiers['credibility_boosters']!) {
      final word = modifier['word'] as String;
      final boost = modifier['boost'] as double;
      if (_containsWord(lowerText, word)) {
        credibilityBoost += boost;
        contextDetails['credibility_$word'] = boost;
      }
    }
    if (credibilityBoost > 0) {
      contextScore *= (1 + min(credibilityBoost, 1.0));
    }

    // Fake indicators reduction
    double fakeReduction = 0.0;
    for (final modifier in _contextModifiers['fake_indicators']!) {
      final word = modifier['word'] as String;
      final reduction = modifier['reduction'] as double;
      if (_containsWord(lowerText, word)) {
        fakeReduction += reduction;
        contextDetails['fake_$word'] = reduction;
      }
    }
    if (fakeReduction > 0) {
      contextScore *= (1 - min(fakeReduction, 0.95));
    }

    // Hearsay reduction
    double hearsayReduction = 0.0;
    if (_contextModifiers.containsKey('hearsay_reducers')) {
      for (final modifier in _contextModifiers['hearsay_reducers']!) {
        final word = modifier['word'] as String;
        final reduction = modifier['reduction'] as double;
        if (_containsWord(lowerText, word)) {
          hearsayReduction += reduction;
          contextDetails['hearsay_$word'] = reduction;
        }
      }
    }
    if (hearsayReduction > 0) {
      contextScore *= (1 - min(hearsayReduction, 0.8));
    }

    return {
      'score': contextScore.clamp(0.05, 3.0),
      'details': contextDetails,
    };
  }

  // Enhanced Keyword Analysis
  Map<String, dynamic> _calculateKeywordScores(String lowerText) {
    final Map<String, double> keywordScores = {};
    final List<Map<String, dynamic>> keywordsFound = [];

    for (final category in ['dangerous', 'suspicious', 'theft', 'assault', 'vandalism', 'fake', 'normal']) {
      keywordScores[category] = 0.0;
    }

    for (final entry in _keywordDetails.entries) {
      final keyword = entry.key;
      final details = entry.value;
      final weight = details['weight'] as double;
      final categories = (details['categories'] as List<dynamic>).cast<String>();

      if (_containsWord(lowerText, keyword)) {
        keywordsFound.add({
          'keyword': keyword,
          'weight': weight,
          'categories': categories,
          'psychology': details['psychology'] as String? ?? 'neutral',
        });

        final weightPerCategory = weight / categories.length;
        for (final category in categories) {
          keywordScores[category] = (keywordScores[category] ?? 0.0) + weightPerCategory;
        }
      }
    }

    // Normalize scores
    final maxScore = keywordScores.values.fold(0.0, max);
    if (maxScore > 0) {
      for (final category in keywordScores.keys) {
        keywordScores[category] = (keywordScores[category]! / maxScore) * 15;
      }
    }

    return {
      'scores': keywordScores,
      'found': keywordsFound,
    };
  }

  // Enhanced Sentence Complexity
  double _calculateSentenceComplexity(String text) {
    final words = text.split(RegExp(r'\s+'));
    final wordCount = words.length;
    double complexity = 0.0;

    if (wordCount > 100) complexity += 1.5;
    else if (wordCount > 50) complexity += 1.0;
    else if (wordCount > 30) complexity += 0.7;
    else if (wordCount > 20) complexity += 0.5;
    else if (wordCount > 10) complexity += 0.3;
    else if (wordCount < 5) complexity -= 0.5;
    else if (wordCount < 3) complexity -= 1.0;

    final hasNumbers = RegExp(r'\d+').hasMatch(text);
    final hasLocation = RegExp(r'\b(at|near|beside|between|across from|in front of)\b.*?\b(street|road|avenue|lane|area|place)\b', caseSensitive: false).hasMatch(text);
    final hasTime = RegExp(r'\b(\d+:\d+|am|pm|morning|evening|night|today|yesterday|tomorrow|hours?|minutes?)\b', caseSensitive: false).hasMatch(text);
    final hasNames = RegExp(r'\b(Mr\.|Ms\.|Mrs\.|Dr\.|[A-Z][a-z]+ [A-Z][a-z]+)\b').hasMatch(text);
    final hasDetails = RegExp(r'\b(approximately|exactly|precisely|specifically|details?|description)\b', caseSensitive: false).hasMatch(text);

    if (hasNumbers) complexity += 0.4;
    if (hasLocation) complexity += 0.4;
    if (hasTime) complexity += 0.4;
    if (hasNames) complexity += 0.3;
    if (hasDetails) complexity += 0.3;

    final properSentence = text.trim().isNotEmpty &&
        text.trim()[0] == text.trim()[0].toUpperCase() &&
        (text.trim().endsWith('.') || text.trim().endsWith('!') || text.trim().endsWith('?'));

    if (properSentence) complexity += 0.3;

    return (1.0 + complexity).clamp(0.5, 3.0);
  }

  // Psychology-based Primary Label Selection
  String _determinePrimaryLabelWithPsychology(
      Map<String, double> scores,
      String text,
      Map<String, dynamic> psychologyAnalysis
      ) {
    final mainCategories = ['dangerous', 'suspicious', 'fake', 'normal'];
    final mainScores = <String, double>{};

    for (final entry in scores.entries) {
      if (mainCategories.contains(entry.key)) {
        mainScores[entry.key] = entry.value;
      }
    }

    // Ensure normal baseline
    mainScores['normal'] = (mainScores['normal'] ?? 0.0) + 0.1;

    // Find highest score
    String primaryLabel = 'normal';
    double maxScore = mainScores['normal'] ?? 0.0;

    for (final entry in mainScores.entries) {
      if (entry.value > maxScore) {
        maxScore = entry.value;
        primaryLabel = entry.key;
      }
    }

    // Psychology-based thresholds (LOWERED FOR BETTER DETECTION)
    final baseThresholds = {
      'dangerous': 0.2,  // Lowered from 0.5
      'suspicious': 0.15, // Lowered from 0.3
      'fake': 0.15,      // Lowered from 0.25
      'normal': 0.05,    // Lowered from 0.1
    };

    // Adjust thresholds based on psychology
    double thresholdAdjustment = 1.0;

    switch (psychologyAnalysis['emotional_tone']) {
      case 'high_distress':
        if (primaryLabel == 'dangerous') thresholdAdjustment *= 0.6; // Lower threshold for dangerous
        if (primaryLabel == 'fake') thresholdAdjustment *= 1.8; // Higher threshold for fake
        break;
      case 'casual':
        if (primaryLabel == 'fake') thresholdAdjustment *= 0.7; // Lower threshold for fake
        if (primaryLabel == 'dangerous') thresholdAdjustment *= 1.5; // Higher threshold for dangerous
        break;
    }

    switch (psychologyAnalysis['credibility_indicators']) {
      case 'high':
        if (primaryLabel == 'dangerous') thresholdAdjustment *= 0.7;
        if (primaryLabel == 'fake') thresholdAdjustment *= 1.5;
        break;
      case 'low':
        if (primaryLabel == 'fake') thresholdAdjustment *= 0.6;
        if (primaryLabel == 'dangerous') thresholdAdjustment *= 1.4;
        break;
    }

    final adjustedThreshold = (baseThresholds[primaryLabel] ?? 0.5) * thresholdAdjustment;

    // Check if score meets threshold
    if (maxScore >= adjustedThreshold) {
      // Additional checks for fake reports
      if (primaryLabel == 'fake') {
        final wordCount = text.split(' ').length;
        if (wordCount < 5 && maxScore > 0.4) {
          return 'fake';  // Very short but clearly fake
        }

        // Check for financial motive in fake reports
        if (_psychologyPatterns['financial_motive']!.hasMatch(text.toLowerCase())) {
          if (maxScore > 0.25) return 'fake';
        }

        return maxScore > 0.2 ? 'fake' : 'normal';
      }

      // EMERGENCY FALLBACK CHECK: If normal but has crime keywords, reconsider
      if (primaryLabel == 'normal') {
        final lowerText = text.toLowerCase();
        final dangerKeywords = ['weapon', 'gun', 'knife', 'bomb', 'attack', 'kill', 'murder', 'blood', 'bleeding', 'injured', 'hurt', 'violent', 'danger', 'dangerous'];
        final theftKeywords = ['snatch', 'rob', 'steal', 'theft', 'burglary', 'stolen', 'robbed', 'snatched'];
        final assaultKeywords = ['fight', 'beat', 'hit', 'assault', 'violence', 'fighting', 'fought', 'punch'];
        final vandalismKeywords = ['break', 'damage', 'destroy', 'vandalism', 'broke', 'broken', 'destroyed', 'graffiti', 'spray'];
        final suspiciousKeywords = ['suspicious', 'strange', 'unusual', 'hiding', 'follow', 'stalk', 'threat'];

        int dangerCount = dangerKeywords.where((kw) => lowerText.contains(kw)).length;
        int theftCount = theftKeywords.where((kw) => lowerText.contains(kw)).length;
        int assaultCount = assaultKeywords.where((kw) => lowerText.contains(kw)).length;
        int vandalismCount = vandalismKeywords.where((kw) => lowerText.contains(kw)).length;
        int suspiciousCount = suspiciousKeywords.where((kw) => lowerText.contains(kw)).length;

        if (dangerCount >= 2) return 'dangerous';
        if (theftCount >= 2) return 'theft';
        if (assaultCount >= 2) return 'assault';
        if (vandalismCount >= 2) return 'vandalism';
        if (suspiciousCount >= 2) return 'suspicious';
        if (dangerCount >= 1 || theftCount >= 1 || assaultCount >= 1 || vandalismCount >= 1 || suspiciousCount >= 1) {
          return 'suspicious';
        }
      }

      return primaryLabel;
    }

    // FINAL EMERGENCY FALLBACK if nothing else worked
    if (primaryLabel == 'normal') {
      final lowerText = text.toLowerCase();
      final crimeKeywords = [
        'weapon', 'gun', 'knife', 'bomb', 'attack', 'kill', 'murder',
        'blood', 'bleeding', 'injured', 'snatch', 'rob', 'steal', 'theft',
        'fight', 'beat', 'assault', 'violence', 'break', 'damage', 'destroy',
        'suspicious', 'strange', 'unusual', 'hiding'
      ];

      final crimeKeywordCount = crimeKeywords.where((kw) => lowerText.contains(kw)).length;
      if (crimeKeywordCount >= 1) {
        return 'suspicious';
      }
    }

    return primaryLabel;
  }

  // Psychology-based Confidence Calculation
  double _calculatePsychologyBasedConfidence(
      Map<String, double> scores,
      String primaryLabel,
      String text,
      Map<String, List<String>> patternMatches,
      int keywordCount,
      Map<String, dynamic> psychologyAnalysis,
      Map<String, dynamic> bangladeshContext,
      ) {
    double baseConfidence = scores[primaryLabel] ?? 0.0;

    // Normalize based on category
    final normalizationFactors = {
      'dangerous': 6.0,  // Reduced from 8.0 for higher confidence
      'suspicious': 5.0, // Reduced from 6.0
      'fake': 4.0,      // Reduced from 5.0
      'theft': 5.0,
      'assault': 5.0,
      'vandalism': 4.5,
      'normal': 3.0,    // Reduced from 4.0
    };

    final normalizationFactor = normalizationFactors[primaryLabel] ?? 5.0;
    baseConfidence = (baseConfidence / normalizationFactor).clamp(0.0, 0.95);

    // Psychology-based adjustments
    switch (psychologyAnalysis['emotional_tone']) {
      case 'high_distress':
        if (primaryLabel == 'dangerous') baseConfidence *= 1.5; // Increased from 1.3
        if (primaryLabel == 'fake') baseConfidence *= 0.3; // Reduced from 0.4
        break;
      case 'casual':
        if (primaryLabel == 'fake') baseConfidence *= 1.4; // Increased from 1.2
        if (primaryLabel == 'dangerous') baseConfidence *= 0.5; // Reduced from 0.6
        break;
    }

    switch (psychologyAnalysis['credibility_indicators']) {
      case 'high':
        if (primaryLabel != 'fake') baseConfidence *= 1.4; // Increased from 1.2
        break;
      case 'low':
        if (primaryLabel != 'fake') baseConfidence *= 0.6; // Reduced from 0.7
        break;
    }

    switch (psychologyAnalysis['language_consistency']) {
      case 'highly_consistent': baseConfidence *= 1.4; break;
      case 'consistent': baseConfidence *= 1.1; break;
      case 'inconsistent': baseConfidence *= 0.4; break;
    }

    // Bangladesh context boost
    if (bangladeshContext['location_mentioned'] == true && primaryLabel != 'fake') {
      baseConfidence *= 1.2;
    }

    // Text length factor
    final wordCount = text.split(' ').length;
    if (primaryLabel == 'fake') {
      // Fake reports can be short
      if (wordCount < 5) baseConfidence *= 1.2;
      if (wordCount > 50) baseConfidence *= 0.8;
    } else {
      if (wordCount < 5) baseConfidence *= 0.5; // Increased penalty
      else if (wordCount < 10) baseConfidence *= 0.8;
      else if (wordCount > 50) baseConfidence *= 1.3;
      else if (wordCount > 100) baseConfidence *= 1.5;
    }

    // Score gap factor
    final sortedScores = scores.values.toList();
    sortedScores.sort((a, b) => b.compareTo(a));
    if (sortedScores.length > 1) {
      final scoreGap = sortedScores[0] - sortedScores[1];
      final gapBonus = (scoreGap * 0.8).clamp(0.0, 0.5); // Increased from 0.7
      baseConfidence += gapBonus;
    }

    // Pattern match bonus
    final totalPatternMatches = patternMatches.values.fold(0, (sum, matches) => sum + matches.length);
    if (totalPatternMatches > 0) {
      final patternBonus = min(totalPatternMatches * 0.15, 0.4); // Increased from 0.1
      baseConfidence += patternBonus;
    }

    // Keyword count bonus
    if (keywordCount > 0) {
      final keywordBonus = min(keywordCount * 0.08, 0.3); // Increased from 0.05
      baseConfidence += keywordBonus;
    }

    // Multiple evidence penalty
    final highConfidenceCategories = scores.values.where((score) => score > 2.0).length;
    if (highConfidenceCategories > 2) {
      baseConfidence *= 0.7; // Reduced from 0.8
    }

    // Text quality checks
    final excessivePunctuation = RegExp(r'[!?]{3,}').hasMatch(text);
    final allCapsRatio = text.replaceAll(RegExp(r'[^A-Z]'), '').length / max(text.length, 1);

    if (excessivePunctuation) baseConfidence *= 0.85;
    if (allCapsRatio > 0.5 && primaryLabel != 'dangerous') baseConfidence *= 0.7;

    // Minimum confidence boost for crime reports
    if (primaryLabel != 'normal' && primaryLabel != 'fake') {
      baseConfidence = max(baseConfidence, 0.4); // At least 40% confidence for crime reports
    }

    return baseConfidence.clamp(0.1, 0.99);
  }

  Map<String, double> _getDetectedCrimeTypes(Map<String, double> scores) {
    final crimeTypes = ['theft', 'assault', 'vandalism'];
    final crimeTypeScores = <String, double>{};

    for (final entry in scores.entries) {
      if (crimeTypes.contains(entry.key)) {
        crimeTypeScores[entry.key] = entry.value;
      }
    }

    return crimeTypeScores;
  }

  bool _containsWord(String text, String word) {
    if (word.contains(' ')) {
      final pattern = r'\b' + _escapeRegExp(word) + r'\b';
      return RegExp(pattern, caseSensitive: false).hasMatch(text);
    }

    final pattern = r'\b' + _escapeRegExp(word) + r'\b';
    return RegExp(pattern, caseSensitive: false).hasMatch(text);
  }

  String _escapeRegExp(String string) {
    return string.replaceAllMapped(RegExp(r'[.*+?^${}()|[\]\\]'), (match) {
      return '\\${match.group(0)}';
    });
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
      'debug_log': _debugLog,
    };
  }

  void dispose() {
    developer.log("🧹 TextClassifier: Enhanced classifier disposed");
    _debugLog.clear();
  }
}