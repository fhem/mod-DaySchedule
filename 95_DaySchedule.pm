########################################################################################
#
# $Id$
#
# A daily schedule, based on astronomical data provided by 95_Astro.pm.
# Julian Pawlowski
#
# Seasonal (temporal/roman) hour calculation is based on description on Wikipedia
# https://de.wikipedia.org/wiki/Temporale_Stunden
# https://de.wikipedia.org/wiki/Tageszeit
#
# Seasonal hour naming is based on description about the day by "Nikolaus A. Bär"
# http://www.nabkal.de/tag.html
#
# Estimation of the Phenological Season is based on data provided by "Deutscher Wetterdienst",
#  in particular data about durations of the year 2017.
# https://www.dwd.de/DE/klimaumwelt/klimaueberwachung/phaenologie/produkte/phaenouhr/phaenouhr.html
#
########################################################################################

package FHEM::DaySchedule;
use 5.014;
use strict;
use warnings;
use POSIX;
use utf8;

use Encode;
use FHEM::Meta;
use GPUtils qw(GP_Import GP_Export);
use HttpUtils;
use Time::HiRes qw(gettimeofday);
use Time::Local qw(timelocal_modern timegm_modern);
use UConv;
use Data::Dumper;

my %Astro;
my %Schedule;
my %Date;

my %sets = (
    "create" => "weblink",
    "update" => "noArg",
);

my %gets = (
    "json"     => undef,
    "schedule" => undef,
    "text"     => undef,
    "version"  => undef,
);

my %attrs = (
    "altitude"           => undef,
    "AstroDevice"        => undef,
    "disable"            => "1,0",
    "Earlyfall"          => undef,
    "Earlyspring"        => undef,
    "HolidayDevices"     => undef,
    "horizon"            => undef,
    "InformativeDevices" => undef,
    "interval"           => undef,
    "language"           => "EN,DE,ES,FR,IT,NL,PL",
    "latitude"           => undef,
    "lc_numeric" =>
"en_EN.UTF-8,de_DE.UTF-8,es_ES.UTF-8,fr_FR.UTF-8,it_IT.UTF-8,nl_NL.UTF-8,pl_PL.UTF-8",
    "lc_time" =>
"en_EN.UTF-8,de_DE.UTF-8,es_ES.UTF-8,fr_FR.UTF-8,it_IT.UTF-8,nl_NL.UTF-8,pl_PL.UTF-8",
    "longitude" => undef,
    "recomputeAt" =>
"multiple-strict,MoonRise,MoonSet,MoonTransit,NewDay,SeasonalHr,SunRise,SunSet,SunTransit,AstroTwilightEvening,AstroTwilightMorning,CivilTwilightEvening,CivilTwilightMorning,CustomTwilightEvening,CustomTwilightMorning",
    "Schedule" =>
"multiple-strict,none,MoonPhaseS,MoonRise,MoonSet,MoonSign,MoonTransit,ObsDate,ObsIsDST,SeasonMeteo,SeasonPheno,ObsSeason,DaySeasonalHr,Daytime,SunRise,SunSet,SunSign,SunTransit,AstroTwilightEvening,AstroTwilightMorning,CivilTwilightEvening,CivilTwilightMorning,NauticTwilightEvening,NauticTwilightMorning,CustomTwilightEvening,CustomTwilightMorning",
    "InformativeDays" =>
"multiple-strict,none,ValentinesDay,WalpurgisNight,AshWednesday,MothersDay,FathersDay,HarvestFestival,MartinSingEv,Martinmas,RemembranceDay,LastSundayBeforeAdvent,StNicholasDay,BiblicalMagi,InternationalWomensDay,StPatricksDay,LaborDay,LiberationDay,Ascension,Pentecost,CorpusChristi,AssumptionDay,WorldChildrensDay,GermanUnificationDay,ReformationDay,AllSaintsDay,AllSoulsDay,DayOfPrayerandRepentance",
    "SocialSeasons" =>
"multiple-strict,none,Carnival,CarnivalLong,Fasching,FaschingLong,StrongBeerFestival,HolyWeek,Easter,EasterTraditional,Lenten,Oktoberfest,Halloween,Advent,AdventEarly,TurnOfTheYear,Christmas,ChristmasLong",
    "SeasonalHrs"     => undef,
    "timezone"        => undef,
    "VacationDevices" => undef,
    "WeekendDevices"  => undef,
    "WorkdayDevices"  => undef,
);

my $json;
my $tt;
my $astrott;

# Export variables to other programs
our %transtable = (
    EN => {
        "overview"     => "Summary",
        "dayschedule"  => "Day schedule",
        "yesterday"    => "yesterday",
        "today"        => "today",
        "tomorrow"     => "tomorrow",
        "event"        => "Event",
        "events"       => "Events",
        "noevents"     => "There are no events.",
        "alldayevents" => "All day events",
        "dayevents"    => "Events during the day",
        "teasernext"   => "Teaser for next day",
        "daylight"     => "Daylight",
        "daytype"      => "Day Type",
        "description"  => "Description",

        #
        "cardinaldirection" => "Cardinal direction",
        "duskcivil"         => "Civil dusk",
        "dusknautic"        => "Nautic dusk",
        "duskastro"         => "Astronomical dusk",
        "duskcustom"        => "Custom dusk",
        "dawncivil"         => "Civil dawn",
        "dawnnautic"        => "Nautic dawn",
        "dawnastro"         => "Astronomical dawn",
        "dawncustom"        => "Custom dawn",
        "commonyear"        => "common year",
        "leapyear"          => "leap year",

        #
        "seasonalhour" => "Seasonal Hour",
        "temporalhour" => "Temporal Hour",

        #
        "dayphase"          => "Daytime",
        "dusk"              => "Dusk",
        "earlyevening"      => "Early evening",
        "evening"           => "Evening",
        "lateevening"       => "Late evening",
        "earlynight"        => "Early night",
        "beforemidnight"    => "Before midnight",
        "midnight"          => "Midnight",
        "aftermidnight"     => "After midnight",
        "latenight"         => "Late night",
        "cockcrow"          => "Cock-crow",
        "firstmorninglight" => "First morning light",
        "dawn"              => "Dawn",
        "breakingdawn"      => "Breaking dawn",
        "earlymorning"      => "Early morning",
        "morning"           => "Morning",
        "earlyforenoon"     => "Early forenoon",
        "forenoon"          => "Forenoon",
        "lateforenoon"      => "Late forenoon",
        "noon"              => "Noon",
        "earlyafternoon"    => "Early afternoon",
        "afternoon"         => "Afternoon",
        "lateafternoon"     => "Late afternoon",
        "firstdusk"         => "First dusk",

        #
        "week"      => "week",
        "remaining" => "remaining",
        "weekend"   => [ "Weekend", "W/E" ],
        "holiday"   => [ "Holiday", "Hol" ],
        "vacation"  => [ "Vacation", "Vac" ],
        "workday"   => [ "Workday", "WD" ],

        #
        "season"          => "Season",
        "seasonoftheyear" => "Season of the year",
        "metseason"       => "Meteorological Season",

        #
        "phenseason"  => "Phenological Season",
        "Earlyspring" => "Early Spring",
        "firstspring" => "First Spring",
        "fullspring"  => "Full Spring",
        "earlysummer" => "Early Summer",
        "midsummer"   => "Midsummer",
        "latesummer"  => "Late Summer",
        "Earlyfall"   => "Early Fall",
        "fullfall"    => "Full Fall",
        "latefall"    => "Late Fall",

        #
        "valentinesday"            => "Valentines Day",
        "ashwednesday"             => "Ash Wednesday",
        "walpurgisnight"           => "Walpurgis Night",
        "mothersday"               => "Mothers Day",
        "fathersday"               => "Fathers Day",
        "pentecostsun"             => "Pentecost Sunday",
        "pentecostmon"             => "Pentecost Monday",
        "harvestfestival"          => "Harvest Festival",
        "allsoulsday"              => "All Souls' Day",
        "martinising"              => "St. Martin singing",
        "martinmas"                => "St. Martin's Day",
        "dayofprayerandrepentance" => "Day of Prayer and Repentance",
        "remembranceday"           => "Remembrance Day",
        "lastsundaybeforeadvent"   => "Last Sunday before Advent",
        "stnicholasday"            => "St. Nicholas' Day",
        "biblicalmagi"             => "Biblical Magi",
        "internationalwomensday"   => "International Womens Day",
        "stpatricksday"            => "St. Patrick's Day",
        "laborday"                 => "Labor Day",
        "liberationday"            => "Liberation Day",
        "ascension"                => "Ascension",
        "corpuschristi"            => "Corpus Christi",
        "assumptionday"            => "Assumption Day",
        "worldchildrensday"        => "World Children's Day",
        "germanunificationday"     => "German Unification Day",
        "reformationday"           => "Reformation Day",
        "allsaintsday"             => "All Saints Day",

        #
        "newyearseve"     => "Turn of the year: New Year's Eve",
        "newyear"         => "Turn of the year: New Year",
        "turnoftheyear"   => "Turn of the year",
        "carnivalseason1" => "Carnival: Women's Carnival Day",
        "carnivalseason2" => "Carnival: Carnival Friday",
        "carnivalseason3" => "Carnival: Carnival Saturday",
        "carnivalseason4" => "Carnival: Carnival Sunday",
        "carnivalseason5" => "Carnival: Carnival Monday",
        "carnivalseason6" => "Carnival: Carnival",
        "carnivalseason"  => "Carnival",
        "faschingseason1" => "Fasching: Women's Carnival Day",
        "faschingseason2" => "Fasching: Carnival Friday",
        "faschingseason3" => "Fasching: Carnival Saturday",
        "faschingseason4" => "Fasching: Carnival Sunday",
        "faschingseason5" => "Fasching: Carnival Monday",
        "faschingseason6" => "Fasching: Carnival",
        "faschingseason"  => "Fasching",
        "lentenbegin"     => "Lenten: Beginning of Lent",
        "lentenw1"        => "Lenten: Lent Week 1",
        "lentenw2"        => "Lenten: Lent Week 2",
        "lentenw3"        => "Lenten: Lent Week 3",
        "lentenw4"        => "Lenten: Lent Week 4",
        "lentenw5"        => "Lenten: Lent Week 5",
        "lentenw6"        => "Lenten: Lent Week 6",
        "lentenw7"        => "Lenten: Great Lent Week",
        "lentensun1"      => "Lenten: 1st Lent Sunday",
        "lentensun2"      => "Lenten: 2nd Lent Sunday",
        "lentensun3"      => "Lenten: 3rd Lent Sunday",
        "lentensun4"      => "Lenten: 4th Lent Sunday",
        "lentensun5"      => "Lenten: 5th Lent Sunday",
        "lentensun6"      => "Lenten: 6th Lent Sunday",
        "lentenend"       => "Lenten: End of Lent",
        "sbeerseasonbegin" =>
          "Strong Beer Festival: Beginning of Strong Beer Festival",
        "sbeerseason"       => "Strong Beer Festival",
        "holyweekpalm"      => "Holy Week: Palm and Passion Sunday",
        "holyweekthu"       => "Holy Week: Maundy Thursday",
        "holyweekfri"       => "Holy Week: Good Friday",
        "holyweeksat"       => "Holy Week: Holy Saturday",
        "holyweek"          => "Holy Week",
        "eastersun"         => "Easter: Easter Sunday",
        "eastermon"         => "Easter: Easter Monday",
        "eastersat"         => "Easter: Easter Saturday",
        "easterwhitesun"    => "Easter: White Sunday",
        "easterseason"      => "Easter",
        "oktoberfestbegin"  => "Oktoberfest: Beginning of Oktoberfest",
        "oktoberfestseason" => "Oktoberfest",
        "halloweenbegin"    => "Halloween: Beginning of Halloween Period",
        "halloween"         => "Halloween: Halloween",
        "halloweenseason"   => "Halloween",
        "advent1"           => "Advent: 1st Advent",
        "advent2"           => "Advent: 2nd Advent",
        "advent3"           => "Advent: 3rd Advent",
        "advent4"           => "Advent: 4th Advent",
        "adventseason"      => "Advent",
        "christmaseve"      => "Christmas: Christmas Eve",
        "christmas1"        => "Christmas: Christmas Day",
        "christmas2"        => "Christmas: Day after Christmas",
        "christmasseason"   => "Christmas",
    },

    DE => {
        "overview"     => "Überblick",
        "dayschedule"  => "Tagesablaufplan",
        "yesterday"    => "gestern",
        "today"        => "heute",
        "tomorrow"     => "morgen",
        "event"        => "Ereignis",
        "events"       => "Ereignisse",
        "noevents"     => "Es finden keine Ereignisse statt.",
        "alldayevents" => "Ganztägige Ereignisse",
        "dayevents"    => "Ereignisse im Laufe des Tages",
        "teasernext"   => "Vorschau für nächsten Tag",
        "daylight"     => "Tageslicht",
        "daytype"      => "Tagestyp",
        "description"  => "Beschreibung",

        #
        "cardinaldirection" => "Himmelsrichtung",
        "duskcivil"         => "Bürgerliche Abenddämmerung",
        "dusknautic"        => "Nautische Abenddämmerung",
        "duskastro"         => "Astronomische Abenddämmerung",
        "duskcustom"        => "Konfigurierte Abenddämmerung",
        "dawncivil"         => "Bürgerliche Morgendämmerung",
        "dawnnautic"        => "Nautische Morgendämmerung",
        "dawnastro"         => "Astronomische Morgendämmerung",
        "dawncustom"        => "Konfigurierte Morgendämmerung",
        "commonyear"        => "Gemeinjahr",
        "leapyear"          => "Schaltjahr",

        #
        "seasonalhour" => "Saisonale Stunde",
        "temporalhour" => "Temporale Stunde",

        #
        "dayphase"          => "Tageszeit",
        "dusk"              => "Abenddämmerung",
        "earlyevening"      => "Früher Abend",
        "evening"           => "Abend",
        "lateevening"       => "Später Abend",
        "earlynight"        => "Frühe Nacht",
        "beforemidnight"    => "Vor Mitternacht",
        "midnight"          => "Mitternacht",
        "aftermidnight"     => "Nach Mitternacht",
        "latenight"         => "Späte Nacht",
        "cockcrow"          => "Hahnenschrei",
        "firstmorninglight" => "Erstes Morgenlicht",
        "dawn"              => "Morgendämmerung",
        "breakingdawn"      => "Tagesanbruch",
        "earlymorning"      => "Früher Morgen",
        "morning"           => "Morgen",
        "earlyforenoon"     => "Früher Vormittag",
        "forenoon"          => "Vormittag",
        "lateforenoon"      => "Später Vormittag",
        "noon"              => "Mittag",
        "earlyafternoon"    => "Früher Nachmittag",
        "afternoon"         => "Nachmittag",
        "lateafternoon"     => "Später Nachmittag",
        "firstdusk"         => "Erste Dämmerung",

        #
        "week"      => "Woche",
        "remaining" => "verbleibend",
        "weekend"   => [ "Wochenende", "WE" ],
        "holiday"   => [ "Feiertag", "FT" ],
        "vacation"  => [ "Urlaubstag", "UL" ],
        "workday"   => [ "Arbeitstag", "AT" ],

        #
        "season"          => "Saison",
        "seasonoftheyear" => "Jahreszeit",
        "metseason"       => "Meteorologische Jahreszeit",

        #
        "phenseason"  => "Phänologische Jahreszeit",
        "Earlyspring" => "Vorfrühling",
        "firstspring" => "Erstfrühling",
        "fullspring"  => "Vollfrühling",
        "earlysummer" => "Frühsommer",
        "midsummer"   => "Hochsommer",
        "latesummer"  => "Spätsommer",
        "Earlyfall"   => "Frühherbst",
        "fullfall"    => "Vollherbst",
        "latefall"    => "Spätherbst",

        #
        "valentinesday"            => "Valentinstag",
        "ashwednesday"             => "Aschermittwoch",
        "walpurgisnight"           => "Walpurgisnacht",
        "mothersday"               => "Muttertag",
        "fathersday"               => "Vatertag",
        "pentecostsun"             => "Pfingstsonntag",
        "pentecostmon"             => "Pfingstmontag",
        "harvestfestival"          => "Erntedankfest",
        "allsoulsday"              => "Allerseelen",
        "martinising"              => "Martinisingen",
        "martinmas"                => "Martinstag",
        "dayofprayerandrepentance" => "Buß- und Bettag",
        "remembranceday"           => "Volkstrauertag",
        "lastsundaybeforeadvent"   => "Totensonntag",
        "stnicholasday"            => "Nikolaus",
        "biblicalmagi"             => "Heilige Drei Könige",
        "internationalwomensday"   => "Internationaler Frauentag",
        "stpatricksday"            => "St. Patrick's Day",
        "laborday"                 => "Tag der Arbeit",
        "liberationday"            => "Tag der Befreiung",
        "ascension"                => "Christi Himmelfahrt",
        "corpuschristi"            => "Fronleichnam",
        "assumptionday"            => "Mariä Himmelfahrt",
        "worldchildrensday"        => "Weltkindertag",
        "germanunificationday"     => "Tag der Deutschen Einheit",
        "reformationday"           => "Reformationstag",
        "allsaintsday"             => "Allerheiligen",

        #
        "newyearseve"       => "Jahreswechsel: Silvester",
        "newyear"           => "Jahreswechsel: Neujahr",
        "turnoftheyear"     => "Jahreswechsel",
        "carnivalseason1"   => "Karnevalszeit: Weiberfastnacht",
        "carnivalseason2"   => "Karnevalszeit: Rußiger Freitag",
        "carnivalseason3"   => "Karnevalszeit: Nelkensamstag",
        "carnivalseason4"   => "Karnevalszeit: Tulpensonntag",
        "carnivalseason5"   => "Karnevalszeit: Rosenmontag",
        "carnivalseason6"   => "Karnevalszeit: Veilchendienstag",
        "carnivalseason"    => "Karnevalszeit",
        "faschingseason1"   => "Faschingszeit: Weiberfastnacht",
        "faschingseason2"   => "Faschingszeit: Rußiger Freitag",
        "faschingseason3"   => "Faschingszeit: Faschingssamstag",
        "faschingseason4"   => "Faschingszeit: Faschingssonntag",
        "faschingseason5"   => "Faschingszeit: Rosenmontag",
        "faschingseason6"   => "Faschingszeit: Fastnacht",
        "faschingseason"    => "Faschingszeit",
        "lentenbegin"       => "Fastenzeit: Beginn der Fastenzeit",
        "lentenw1"          => "Fastenzeit: Fastenwoche 1",
        "lentenw2"          => "Fastenzeit: Fastenwoche 2",
        "lentenw3"          => "Fastenzeit: Fastenwoche 3",
        "lentenw4"          => "Fastenzeit: Fastenwoche 4",
        "lentenw5"          => "Fastenzeit: Fastenwoche 5",
        "lentenw6"          => "Fastenzeit: Fastenwoche 6",
        "lentenw7"          => "Fastenzeit: Große Fastenwoche",
        "lentensun1"        => "Fastenzeit: 1. Fastensonntag",
        "lentensun2"        => "Fastenzeit: 2. Fastensonntag",
        "lentensun3"        => "Fastenzeit: 3. Fastensonntag",
        "lentensun4"        => "Fastenzeit: 4. Fastensonntag",
        "lentensun5"        => "Fastenzeit: 5. Fastensonntag",
        "lentensun6"        => "Fastenzeit: 6. Fastensonntag",
        "lentenend"         => "Fastenzeit: Ende der Fastenzeit",
        "sbeerseasonbegin"  => "Starkbierfest: Beginn des Starkbierfests",
        "sbeerseason"       => "Starkbierfest",
        "holyweekpalm"      => "Karwoche: Palm- und Passionssonntag",
        "holyweekthu"       => "Karwoche: Gründonnerstag",
        "holyweekfri"       => "Karwoche: Karfreitag",
        "holyweeksat"       => "Karwoche: Karsamstag",
        "holyweek"          => "Karwoche",
        "eastersun"         => "Osterzeit: Ostersonntag",
        "eastermon"         => "Osterzeit: Ostermontag",
        "eastersat"         => "Osterzeit: Ostersamstag",
        "easterwhitesun"    => "Osterzeit: Weißer Sonntag",
        "easterseason"      => "Osterzeit",
        "oktoberfestbegin"  => "Oktoberfestzeit: Beginn des Oktoberfests",
        "oktoberfestseason" => "Oktoberfestzeit",
        "halloweenbegin"    => "Halloweenzeit: Beginn der Halloweenzeit",
        "halloween"         => "Halloweenzeit: Halloween",
        "halloweenseason"   => "Halloweenzeit",
        "advent1"           => "Adventszeit: 1. Advent",
        "advent2"           => "Adventszeit: 2. Advent",
        "advent3"           => "Adventszeit: 3. Advent",
        "advent4"           => "Adventszeit: 4. Advent",
        "adventseason"      => "Adventszeit",
        "christmaseve"      => "Weihnachtszeit: Heiligabend",
        "christmas1"        => "Weihnachtszeit: 1. Weihnachtstag",
        "christmas2"        => "Weihnachtszeit: 2. Weihnachtstag",
        "christmasseason"   => "Weihnachtszeit",
    },

    ES => {
        "overview"     => "Sumario",
        "dayschedule"  => "Horario diario",
        "yesterday"    => "ayer",
        "today"        => "hoy",
        "tomorrow"     => "mañana",
        "event"        => "Evento",
        "events"       => "Eventos",
        "noevents"     => "No hay eventos.",
        "alldayevents" => "Eventos todo el dia",
        "dayevents"    => "Eventos durante el día",
        "teasernext"   => "Vista previa para el día siguiente",
        "daylight"     => "Luz del día",
        "daytype"      => "Tipo de día",
        "description"  => "Descripción",

        #
        "cardinaldirection" => "Punto cardinal",
        "duskcivil"         => "Oscuridad civil",
        "dusknautic"        => "Oscuridad náutico",
        "duskastro"         => "Oscuridad astronómico",
        "duskcustom"        => "Oscuridad personalizado",
        "dawncivil"         => "Amanecer civil",
        "dawnnautic"        => "Amanecer náutico",
        "dawnastro"         => "Amanecer astronómico",
        "dawncustom"        => "Amanecer personalizado",
        "commonyear"        => "año común",
        "leapyear"          => "año bisiesto",

        #
        "seasonalhour" => "Hora Estacional",
        "temporalhour" => "Hora Temporal",

        #
        "dayphase"          => "Durante el día",
        "dusk"              => "Oscuridad",
        "earlyevening"      => "Atardecer temprano",
        "evening"           => "Nocturno",
        "lateevening"       => "Tarde",
        "earlynight"        => "Madrugada",
        "beforemidnight"    => "Antes de medianoche",
        "midnight"          => "Medianoche",
        "aftermidnight"     => "Después de medianoche",
        "latenight"         => "Noche tardía",
        "cockcrow"          => "Canto al gallo",
        "firstmorninglight" => "Primera luz de la mañana",
        "dawn"              => "Amanecer",
        "breakingdawn"      => "Rotura amanecer",
        "earlymorning"      => "Temprano en la mañana",
        "morning"           => "Mañana",
        "earlyforenoon"     => "Temprano antes de mediodía",
        "forenoon"          => "Antes de mediodía",
        "lateforenoon"      => "Tarde antes de mediodía",
        "noon"              => "Mediodía",
        "earlyafternoon"    => "Temprano después de mediodía",
        "afternoon"         => "Después de mediodía",
        "lateafternoon"     => "Tarde después de mediodía",
        "firstdusk"         => "Temprano oscuridad",

        #
        "week"      => "Semana",
        "remaining" => "restantes",
        "weekend"   => [ "Fin de semana", "Fin" ],
        "holiday"   => [ "Día festivo", "Fes" ],
        "vacation"  => [ "Vacaciones", "Vac" ],
        "workday"   => [ "Trabajo", "Tra" ],

        #
        "season"          => "Condimentar",
        "seasonoftheyear" => "Temporada de año",
        "metseason"       => "Temporada Meteorológica",

        #
        "phenseason"  => "Temporada Fenologica",
        "Earlyspring" => "Inicio de la primavera",
        "firstspring" => "Primera primavera",
        "fullspring"  => "Primavera completa",
        "earlysummer" => "Comienzo del verano",
        "midsummer"   => "Pleno verano",
        "latesummer"  => "El verano pasado",
        "Earlyfall"   => "Inicio del otoño",
        "fullfall"    => "Otoño completo",
        "latefall"    => "Finales de otoño",

        #
        "valentinesday"            => "Día de San Valentín",
        "ashwednesday"             => "Miércoles de Ceniza",
        "walpurgisnight"           => "Noche de Walpurgis",
        "mothersday"               => "Día de la Madre",
        "fathersday"               => "Día del padre",
        "pentecostsun"             => "Domingo de Pentecostés",
        "pentecostmon"             => "Lunes de Pentecostés",
        "harvestfestival"          => "fiesta de la cosecha",
        "allsoulsday"              => "Día de Todos los Santos",
        "martinising"              => "San Martín cantando",
        "martinmas"                => "Día de San Martín",
        "dayofprayerandrepentance" => "Día de Oración y Arrepentimiento",
        "remembranceday"           => "Día de la Recordación",
        "lastsundaybeforeadvent"   => "Domingo cuando los muertos murieron",
        "stnicholasday"            => "Papá Noel",
        "biblicalmagi"             => "Mágicos Bíblicos",
        "internationalwomensday"   => "Día Internacional de la Mujer",
        "stpatricksday"            => "Día de San Patricio",
        "laborday"                 => "Día del Trabajo",
        "liberationday"            => "Día de la Liberación",
        "ascension"                => "Ascensión",
        "corpuschristi"            => "Corpus Christi",
        "assumptionday"            => "Día de la Asunción",
        "worldchildrensday"        => "Día Mundial de la Infancia",
        "germanunificationday"     => "Día de la Unificación Alemana",
        "reformationday"           => "Día de la Reforma",
        "allsaintsday"             => "Día de Todos los Santos",

        #
        "newyearseve"     => "Cambio de año: Nochevieja",
        "newyear"         => "Cambio de año: Año Nuevo",
        "turnoftheyear"   => "Cambio de año",
        "carnivalseason1" => "Carnaval: Carnaval de mujeres",
        "carnivalseason2" => "Carnaval: Viernes de Carnaval",
        "carnivalseason3" => "Carnaval: Sábado de Carnaval",
        "carnivalseason4" => "Carnaval: Domingo de Carnaval",
        "carnivalseason5" => "Carnaval: Lunes de Carnaval",
        "carnivalseason6" => "Carnaval: Carnaval",
        "carnivalseason"  => "Carnaval",
        "faschingseason1" => "Fasching: Carnaval de mujeres",
        "faschingseason2" => "Fasching: Viernes de Carnaval",
        "faschingseason3" => "Fasching: Sábado de Carnaval",
        "faschingseason4" => "Fasching: Domingo de Carnaval",
        "faschingseason5" => "Fasching: Lunes de Carnaval",
        "faschingseason6" => "Fasching: Carnaval",
        "faschingseason"  => "Fasching",
        "lentenbegin"     => "Cuaresma: Comienzo de la Cuaresma",
        "lentenw1"        => "Cuaresma: Cuaresma semana 1",
        "lentenw2"        => "Cuaresma: Cuaresma semana 2",
        "lentenw3"        => "Cuaresma: Cuaresma semana 3",
        "lentenw4"        => "Cuaresma: Cuaresma semana 4",
        "lentenw5"        => "Cuaresma: Cuaresma semana 5",
        "lentenw6"        => "Cuaresma: Cuaresma semana 6",
        "lentenw7"        => "Cuaresma: Gran semana de Cuaresma",
        "lentensun1"      => "Cuaresma: 1er Domingo de Cuaresma",
        "lentensun2"      => "Cuaresma: 2º Domingo de Cuaresma",
        "lentensun3"      => "Cuaresma: 3º Domingo de Cuaresma",
        "lentensun4"      => "Cuaresma: 4º Domingo de Cuaresma",
        "lentensun5"      => "Cuaresma: 5º Domingo de Cuaresma",
        "lentensun6"      => "Cuaresma: 6º Domingo de Cuaresma",
        "lentenend"       => "Cuaresma: Fin de la Cuaresma",
        "sbeerseasonbegin" =>
"Fuerte festival de la cerveza: Comienzo de la Fiesta de la Cerveza Fuerte",
        "sbeerseason"       => "Fuerte festival de la cerveza",
        "holyweekpalm"      => "Semana Santa: Domingo de Ramos y Pasión",
        "holyweekthu"       => "Semana Santa: Jueves Santo",
        "holyweekfri"       => "Semana Santa: Viernes Santo",
        "holyweeksat"       => "Semana Santa: Sábado Santo",
        "holyweek"          => "Semana Santa",
        "eastersun"         => "Pascua: Domingo de Pascua",
        "eastermon"         => "Pascua: Lunes de Pascua",
        "eastersat"         => "Pascua: Sábado de Pascua",
        "easterwhitesun"    => "Pascua: Domingo Blanco",
        "easterseason"      => "Pascua",
        "oktoberfestbegin"  => "Oktoberfest: Comienzo de la Oktoberfest",
        "oktoberfestseason" => "Oktoberfest",
        "halloweenbegin"    => "Halloween: Comienzo del período de Halloween",
        "halloween"         => "Halloween: Halloween",
        "halloweenseason"   => "Halloween",
        "advent1"           => "Adviento: 1er Adviento",
        "advent2"           => "Adviento: 2º Adviento",
        "advent3"           => "Adviento: 3º Adviento",
        "advent4"           => "Adviento: 4º Adviento",
        "adventseason"      => "Adviento",
        "christmaseve"      => "Navidad: Nochebuena",
        "christmas1"        => "Navidad: 1er día de Navidad",
        "christmas2"        => "Navidad: 2º día de Navidad",
        "christmasseason"   => "Navidad",
    },

    FR => {
        "overview"     => "Récapitulatif",
        "dayschedule"  => "Horaire de la journée",
        "yesterday"    => "hier",
        "today"        => "aujourd'hui",
        "tomorrow"     => "demain",
        "event"        => "Événement",
        "events"       => "Événements",
        "noevents"     => "Il n'y a pas d'événements.",
        "alldayevents" => "Événements d'une journée",
        "dayevents"    => "Événements pendant la journée",
        "teasernext"   => "Aperçu pour le lendemain",
        "daylight"     => "Lumière du jour",
        "daytype"      => "Type de jour",
        "description"  => "Description",

        #
        "cardinaldirection" => "Direction cardinale",
        "duskcivil"         => "Crépuscule civil",
        "dusknautic"        => "Crépuscule nautique",
        "duskastro"         => "Crépuscule astronomique",
        "duskcustom"        => "Crépuscule personnalisé",
        "dawncivil"         => "Aube civil",
        "dawnnautic"        => "Aube nautique",
        "dawnastro"         => "Aube astronomique",
        "dawncustom"        => "Aube personnalisé",
        "commonyear"        => "année commune",
        "leapyear"          => "année bissextile",

        #
        "seasonalhour" => "Heure de Saison",
        "temporalhour" => "Heure Temporelle",

        #
        "dayphase"          => "Heure du jour",
        "dusk"              => "Crépuscule",
        "earlyevening"      => "Début de soirée",
        "evening"           => "Soir",
        "lateevening"       => "Fin de soirée",
        "earlynight"        => "Nuit tombante",
        "beforemidnight"    => "Avant minuit",
        "midnight"          => "Minuit",
        "aftermidnight"     => "Après minuit",
        "latenight"         => "Tard dans la nuit",
        "cockcrow"          => "Coq de bruyère",
        "firstmorninglight" => "Première lueur du matin",
        "dawn"              => "Aube",
        "breakingdawn"      => "Aube naissante",
        "earlymorning"      => "Tôt le matin",
        "morning"           => "Matin",
        "earlyforenoon"     => "Matinée matinale",
        "forenoon"          => "Matinée",
        "lateforenoon"      => "Matinée tardive",
        "noon"              => "Midi",
        "earlyafternoon"    => "Début d'après-midi",
        "afternoon"         => "Après-midi",
        "lateafternoon"     => "Fin d'après-midi",
        "firstdusk"         => "Premier crépuscule",

        #
        "week"      => "Semaine",
        "remaining" => "restant",
        "weekend"   => [ "Fin de semaine", "Fin" ],
        "holiday"   => [ "Férié", "Fér" ],
        "vacation"  => [ "Vacances", "Vac" ],
        "workday"   => [ "Ouvrable", "Ouv" ],

        #
        "season"          => "Assaisonner",
        "seasonoftheyear" => "Saison de l'année",
        "metseason"       => "Saison Météorologique",

        #
        "phenseason"  => "Saison Phénologique",
        "Earlyspring" => "Avant du printemps",
        "firstspring" => "Début du printemps",
        "fullspring"  => "Printemps",
        "earlysummer" => "Avant de l'été",
        "midsummer"   => "Milieu de l'été",
        "latesummer"  => "Fin de l'été",
        "Earlyfall"   => "Avant de l'automne",
        "fullfall"    => "Automne",
        "latefall"    => "Fin de l'automne",

        #
        "valentinesday"            => "Saint-Valentin",
        "ashwednesday"             => "Mercredi des Cendres",
        "walpurgisnight"           => "Nuit de Walpurgis",
        "mothersday"               => "Fête des mères",
        "fathersday"               => "Fête des pères",
        "pentecostsun"             => "Dimanche de Pentecôte",
        "pentecostmon"             => "Lundi de Pentecôte",
        "harvestfestival"          => "Festival de la récolte",
        "allsoulsday"              => "Le jour de la Toussaint",
        "martinising"              => "Martin chantant",
        "martinmas"                => "Martinmas",
        "dayofprayerandrepentance" => "Journée de prière et de repentir",
        "remembranceday"           => "Jour commémoratif",
        "lastsundaybeforeadvent"   => "Dimanche, quand les morts sont morts",
        "stnicholasday"            => "Père Noël",
        "biblicalmagi"             => "Mages bibliques",
        "internationalwomensday"   => "Journée internationale de la femme",
        "stpatricksday"            => "Journée de la Saint-Patrick",
        "laborday"                 => "Fête du Travail",
        "liberationday"            => "Jour de la Libération",
        "ascension"                => "Ascension",
        "corpuschristi"            => "Corpus Christi",
        "assumptionday"            => "Fête de l'Assomption",
        "worldchildrensday"        => "Journée mondiale de l'enfant",
        "germanunificationday"     => "Jour de l'unification allemande",
        "reformationday"           => "Jour de la Réforme",
        "allsaintsday"             => "Toussaint",

        #
        "newyearseve"     => "Tournant de l'année: Saint-Sylvestre",
        "newyear"         => "Tournant de l'année: Nouvel An",
        "turnoftheyear"   => "Tournant de l'année",
        "carnivalseason1" => "Carnaval: Fête foraine",
        "carnivalseason2" => "Carnaval: Vendredi de carnaval",
        "carnivalseason3" => "Carnaval: Samedi de carnaval",
        "carnivalseason4" => "Carnaval: Dimanche de carnaval",
        "carnivalseason5" => "Carnaval: Lundi de carnaval",
        "carnivalseason6" => "Carnaval: Carnaval",
        "carnivalseason"  => "Carnaval",
        "faschingseason1" => "Fasching: Fête foraine",
        "faschingseason2" => "Fasching: Vendredi de carnaval",
        "faschingseason3" => "Fasching: Samedi de carnaval",
        "faschingseason4" => "Fasching: Dimanche de carnaval",
        "faschingseason5" => "Fasching: Lundi de carnaval",
        "faschingseason6" => "Fasching: Carnaval",
        "faschingseason"  => "Fasching",
        "lentenbegin"     => "Carême: Début du Carême",
        "lentenw1"        => "Carême: Carême semaine 1",
        "lentenw2"        => "Carême: Carême semaine 2",
        "lentenw3"        => "Carême: Carême semaine 3",
        "lentenw4"        => "Carême: Carême semaine 4",
        "lentenw5"        => "Carême: Carême semaine 5",
        "lentenw6"        => "Carême: Carême semaine 6",
        "lentenw7"        => "Carême: Grande semaine de Carême",
        "lentensun1"      => "Carême: 1er dimanche de Carême",
        "lentensun2"      => "Carême: 2e dimanche de Carême",
        "lentensun3"      => "Carême: 3e dimanche de Carême",
        "lentensun4"      => "Carême: 4e dimanche de Carême",
        "lentensun5"      => "Carême: 5e dimanche de Carême",
        "lentensun6"      => "Carême: 6e dimanche de Carême",
        "lentenend"       => "Carême: Fin du Carême",
        "sbeerseasonbegin" =>
          "Fête de la bière forte: Début de la Fête de la bière forte",
        "sbeerseason" => "Fête de la bière forte",
        "holyweekpalm" =>
          "Semaine Sainte: Dimanche des Rameaux et de la Passion",
        "holyweekthu"       => "Semaine Sainte: Jeudi saint",
        "holyweekfri"       => "Semaine Sainte: Vendredi saint",
        "holyweeksat"       => "Semaine Sainte: Samedi saint",
        "holyweek"          => "Semaine Sainte",
        "eastersun"         => "Pâques: Dimanche de Pâques",
        "eastermon"         => "Pâques: Lundi de Pâques",
        "eastersat"         => "Pâques: Samedi de Pâques",
        "easterwhitesun"    => "Pâques: Dimanche blanc",
        "easterseason"      => "Pâques",
        "oktoberfestbegin"  => "Oktoberfest: Début de la Oktoberfest",
        "oktoberfestseason" => "Oktoberfest",
        "halloweenbegin"    => "Halloween: Début de la période d'Halloween",
        "halloween"         => "Halloween: Halloween",
        "halloweenseason"   => "Halloween",
        "advent1"           => "Avent: 1er Advent",
        "advent2"           => "Avent: 2e Advent",
        "advent3"           => "Avent: 3e Advent",
        "advent4"           => "Avent: 4e Advent",
        "adventseason"      => "Avent",
        "christmaseve"      => "Noël: Veille de Noël",
        "christmas1"        => "Noël: 1er jour de Noël",
        "christmas2"        => "Noël: 2e jour de Noël",
        "christmasseason"   => "Noël",
    },

    IT => {
        "overview"     => "Riepilogo",
        "dayschedule"  => "Programma giornaliero",
        "yesterday"    => "ieri",
        "today"        => "oggigiorno",
        "tomorrow"     => "domani",
        "event"        => "Evento",
        "events"       => "Eventi",
        "noevents"     => "Non ci sono eventi.",
        "alldayevents" => "Eventi per tutto il giorno",
        "dayevents"    => "Eventi durante il giorno",
        "teasernext"   => "Anteprima per il giorno successivo",
        "daylight"     => "Luce diurna",
        "daytype"      => "Tipo di giorno",
        "description"  => "Descrizione",

        #
        "cardinaldirection" => "Direzione cardinale",
        "duskcivil"         => "Crepuscolo civile",
        "dusknautic"        => "Crepuscolo nautico",
        "duskastro"         => "Crepuscolo astronomico",
        "duskcustom"        => "Crepuscolo personalizzato",
        "dawncivil"         => "Alba civile",
        "dawnnautic"        => "Alba nautico",
        "dawnastro"         => "Alba astronomico",
        "dawncustom"        => "Alba personalizzato",
        "commonyear"        => "anno comune",
        "leapyear"          => "anno bisestile",

        #
        "seasonalhour" => "Ora di Stagione",
        "temporalhour" => "Ora Temporale",

        #
        "dayphase"          => "Tempo di giorno",
        "dusk"              => "Crepuscolo",
        "earlyevening"      => "Sera presto",
        "evening"           => "Serata",
        "lateevening"       => "Tarda serata",
        "earlynight"        => "Notte presto",
        "beforemidnight"    => "Prima mezzanotte",
        "midnight"          => "Mezzanotte",
        "aftermidnight"     => "Dopo mezzanotte",
        "latenight"         => "Tarda notte",
        "cockcrow"          => "Gallo corvo",
        "firstmorninglight" => "Prima luce del mattino",
        "dawn"              => "Alba",
        "breakingdawn"      => "Dopo l'alba",
        "earlymorning"      => "Mattina presto",
        "morning"           => "Mattina",
        "earlyforenoon"     => "Prima mattinata",
        "forenoon"          => "Mattinata",
        "lateforenoon"      => "Tarda mattinata",
        "noon"              => "Mezzogiorno",
        "earlyafternoon"    => "Primo pomeriggio",
        "afternoon"         => "Pomeriggio",
        "lateafternoon"     => "Tardo pomeriggio",
        "firstdusk"         => "Primo crepuscolo",

        #
        "week"      => "Settimana",
        "remaining" => "rimanente",
        "weekend"   => [ "Fine settimana", "Fin" ],
        "holiday"   => [ "Vacanza", "Vac" ],
        "vacation"  => [ "Riposo", "Rip" ],
        "workday"   => [ "Lavorativo", "Lav" ],

        #
        "season"          => "Periodo",
        "seasonoftheyear" => "Stagione dell'anno",
        "metseason"       => "Stagione Meteorologica",

        #
        "phenseason"  => "Stagione Fenologica",
        "Earlyspring" => "Inizio primavera",
        "firstspring" => "Prima primavera",
        "fullspring"  => "Piena primavera",
        "earlysummer" => "Inizio estate",
        "midsummer"   => "Mezza estate",
        "latesummer"  => "Estate inoltrata",
        "Earlyfall"   => "Inizio autunno",
        "fullfall"    => "Piena caduta",
        "latefall"    => "Tardo autunno",

        #
        "valentinesday"            => "San Valentino",
        "ashwednesday"             => "Mercoledì delle Ceneri",
        "walpurgisnight"           => "Notte di Walpurgis",
        "mothersday"               => "Festa della mamma",
        "fathersday"               => "Festa del papà",
        "pentecostsun"             => "Pentecoste Domenica",
        "pentecostmon"             => "Pentecoste Lunedì",
        "harvestfestival"          => "Festa del raccolto",
        "allsoulsday"              => "Il giorno di tutte le anime",
        "martinising"              => "Canto di San Martino",
        "martinmas"                => "Martinmas",
        "dayofprayerandrepentance" => "Giorno di preghiera e di pentimento",
        "remembranceday"           => "Giorno della Memoria",
        "lastsundaybeforeadvent"   => "Domenica, quando i morti sono morti.",
        "stnicholasday"            => "Babbo Natale",
        "biblicalmagi"             => "Magi biblico",
        "internationalwomensday"   => "Giornata internazionale della donna",
        "stpatricksday"            => "Il giorno di San Patrizio",
        "laborday"                 => "Festa del lavoro",
        "liberationday"            => "Giorno della Liberazione",
        "ascension"                => "Ascensione",
        "corpuschristi"            => "Corpus Domini",
        "assumptionday"            => "Giorno dell'Assunzione",
        "worldchildrensday"        => "Giornata mondiale del bambino",
        "germanunificationday"     => "Giorno dell'unificazione tedesca",
        "reformationday"           => "Giorno della Riforma",
        "allsaintsday"             => "Ognissanti",

        #
        "newyearseve"     => "Cavallo dell'anno: Capodanno",
        "newyear"         => "Cavallo dell'anno: Capodanno",
        "turnoftheyear"   => "Cavallo dell'anno",
        "carnivalseason1" => "Carnevale: Carnevale delle donne",
        "carnivalseason2" => "Carnevale: Venerdì di Carnevale",
        "carnivalseason3" => "Carnevale: Sabato di Carnevale",
        "carnivalseason4" => "Carnevale: Domenica di Carnevale",
        "carnivalseason5" => "Carnevale: Lunedì di Carnevale",
        "carnivalseason6" => "Carnevale: Carnevale",
        "carnivalseason"  => "Carnevale",
        "faschingseason1" => "Fasching: Carnevale delle donne",
        "faschingseason2" => "Fasching: Venerdì di Carneval",
        "faschingseason3" => "Fasching: Sabato di Carnevale",
        "faschingseason4" => "Fasching: Domenica di Carnevale",
        "faschingseason5" => "Fasching: Lunedì di Carnevale",
        "faschingseason6" => "Fasching: Carnevale",
        "faschingseason"  => "Fasching",
        "lentenbegin"     => "Quaresima: Inizio di Quaresima",
        "lentenw1"        => "Quaresima: 1° Settimana di Quaresima",
        "lentenw2"        => "Quaresima: 2° Settimana di Quaresima",
        "lentenw3"        => "Quaresima: 3° Settimana di Quaresima",
        "lentenw4"        => "Quaresima: 4° Settimana di Quaresima",
        "lentenw5"        => "Quaresima: 5° Settimana di Quaresima",
        "lentenw6"        => "Quaresima: 6° Settimana di Quaresima",
        "lentenw7"        => "Quaresima: Grande Settimana di Quaresima",
        "lentensun1"      => "Quaresima: 1° Domenica di Quaresima",
        "lentensun2"      => "Quaresima: 2° Domenica di Quaresima",
        "lentensun3"      => "Quaresima: 3° Domenica di Quaresima",
        "lentensun4"      => "Quaresima: 4° Domenica di Quaresima",
        "lentensun5"      => "Quaresima: 5° Domenica di Quaresima",
        "lentensun6"      => "Quaresima: 6° Domenica di Quaresima",
        "lentenend"       => "Quaresima: Fine della Quaresima",
        "sbeerseasonbegin" =>
          "Festa della birra forte: Inizio del Festival della birra forte",
        "sbeerseason" => "Festa della birra forte",
        "holyweekpalm" =>
          "Settimana Santa: Domenica delle Palme e della Passione",
        "holyweekthu"       => "Settimana Santa: Giovedì Santo",
        "holyweekfri"       => "Settimana Santa: Venerdì Santo",
        "holyweeksat"       => "Settimana Santa: Sabato Santo",
        "holyweek"          => "Settimana Santa",
        "eastersun"         => "Pasqua: Domenica di Pasqua",
        "eastermon"         => "Pasqua: Lunedì di Pasqua",
        "eastersat"         => "Pasqua: Sabato di Pasqua",
        "easterwhitesun"    => "Pasqua: Domenica Bianca",
        "easterseason"      => "Pasqua",
        "oktoberfestbegin"  => "Oktoberfest: Inizio dell'Oktoberfest",
        "oktoberfestseason" => "Oktoberfest",
        "halloweenbegin"    => "Halloween: Inizio del tempo di Halloween",
        "halloween"         => "Halloween: Halloween",
        "halloweenseason"   => "Halloween",
        "advent1"           => "Avvento: 1° Avvento",
        "advent2"           => "Avvento: 2° Avvento",
        "advent3"           => "Avvento: 3° Avvento",
        "advent4"           => "Avvento: 4° Avvento",
        "adventseason"      => "Avvento",
        "christmaseve"      => "Natale: Vigilia di Natale",
        "christmas1"        => "Natale: 1° giorno di Natale",
        "christmas2"        => "Natale: 2° giorno di Natale",
        "christmasseason"   => "Natale",
    },

    NL => {
        "overview"     => "Summier",
        "dayschedule"  => "Dagschema",
        "yesterday"    => "gisteren",
        "today"        => "vandaag",
        "tomorrow"     => "morgen",
        "event"        => "Evenement",
        "events"       => "Evenementen",
        "noevents"     => "Er zijn geen evenementen.",
        "alldayevents" => "De hele dag evenementen",
        "dayevents"    => "Evenementen overdag",
        "teasernext"   => "Voorbeeld voor de volgende dag",
        "daylight"     => "Daglicht",
        "daytype"      => "Dagtype",
        "description"  => "Beschrijving",

        #
        "cardinaldirection" => "Hoofdrichting",
        "duskcivil"         => "Burgerlijke Schemering",
        "dusknautic"        => "Nautische Schemering",
        "duskastro"         => "Astronomische Schemering",
        "duskcustom"        => "Aangepaste Schemering",
        "dawncivil"         => "Burgerlijke Dageraad",
        "dawnnautic"        => "Nautische Dageraad",
        "dawnastro"         => "Astronomische Dageraad",
        "dawncustom"        => "Aangepaste Dageraad",
        "commonyear"        => "Gemeenschappelijk Jaar",
        "leapyear"          => "Schrikkeljaar",

        #
        "seasonalhour" => "Seizoensgebonden Uur",
        "temporalhour" => "Tijdelijk Uur",

        #
        "dayphase"          => "Dagtijd",
        "dusk"              => "Schemering",
        "earlyevening"      => "Vroege Avond",
        "evening"           => "Avond",
        "lateevening"       => "Late Avond",
        "earlynight"        => "Vroege Nacht",
        "beforemidnight"    => "Voor Middernacht",
        "midnight"          => "Middernacht",
        "aftermidnight"     => "Na Middernacht",
        "latenight"         => "Late Nacht",
        "cockcrow"          => "Hanegekraai",
        "firstmorninglight" => "Eerste Ochtendlicht",
        "dawn"              => "Dageraad",
        "breakingdawn"      => "Ochtendgloren",
        "earlymorning"      => "Vroege Ochtend",
        "morning"           => "Ochtend",
        "earlyforenoon"     => "Vroeg in de Voormiddag",
        "forenoon"          => "Voormiddag",
        "lateforenoon"      => "Late Voormiddag",
        "noon"              => "Middag",
        "earlyafternoon"    => "Vroege Namiddag",
        "afternoon"         => "Namiddag",
        "lateafternoon"     => "Late Namiddag",
        "firstdusk"         => "Eerste Schemering",

        #
        "week"      => "Wee",
        "remaining" => "resterende",
        "weekend"   => [ "Weekend", "We" ],
        "holiday"   => [ "Feestdag", "Fe" ],
        "vacation"  => [ "Snipperdag", "Sn" ],
        "workday"   => [ "Werkdag", "WD" ],

        #
        "season"          => "Jaargetijde",
        "seasonoftheyear" => "Seizoen van het jaar",
        "metseason"       => "Meteorologisch Seizoen",

        #
        "phenseason"  => "Fenologisch Seizoen",
        "Earlyspring" => "Vroeg Voorjaar",
        "firstspring" => "Eerste Voorjaar",
        "fullspring"  => "Voorjaar",
        "earlysummer" => "Vroeg Zomer",
        "midsummer"   => "Zomer",
        "latesummer"  => "Laat Zomer",
        "Earlyfall"   => "Vroeg Herfst",
        "fullfall"    => "Herfst",
        "latefall"    => "Laat Herfst",

        #
        "valentinesday"            => "Valentijnsdag",
        "ashwednesday"             => "Aswoensdag",
        "walpurgisnight"           => "Walpurgis-nacht",
        "mothersday"               => "Moederdag",
        "fathersday"               => "Vaderdag",
        "pentecostsun"             => "Pinksterzondag",
        "pentecostmon"             => "Pinkstermaandag",
        "harvestfestival"          => "Oogstfeest",
        "allsoulsday"              => "Dag van de Zielen",
        "martinising"              => "Martin zingen",
        "martinmas"                => "Martinmas",
        "dayofprayerandrepentance" => "Gebedsdag en berouw",
        "remembranceday"           => "Herdenkingsdag",
        "lastsundaybeforeadvent"   => "Zondag, toen de doden stierven",
        "stnicholasday"            => "De Kerstman",
        "biblicalmagi"             => "Bijbelse Magiërs",
        "internationalwomensday"   => "Internationale Vrouwendag",
        "stpatricksday"            => "St. Patrick's Day",
        "laborday"                 => "Dag van de Arbeid",
        "liberationday"            => "Bevrijdingsdag",
        "ascension"                => "Hemelvaart",
        "corpuschristi"            => "Corpus Christi",
        "assumptionday"            => "Veronderstelling Dag",
        "worldchildrensday"        => "Wereld Kinderdag",
        "germanunificationday"     => "Duitse dag van de eenwording",
        "reformationday"           => "Hervorming Dag",
        "allsaintsday"             => "Allerheiligen",

        #
        "newyearseve"     => "Jaarwisseling: Oudejaarsavond",
        "newyear"         => "Jaarwisseling: Nieuwjaar",
        "turnoftheyear"   => "Jaarwisseling",
        "carnivalseason1" => "Carnaval: Vrouwen carnaval",
        "carnivalseason2" => "Carnaval: Carnavalsvrijdag",
        "carnivalseason3" => "Carnaval: Carnavalszaterdag",
        "carnivalseason4" => "Carnaval: Carnavalszondag",
        "carnivalseason5" => "Carnaval: Vette maandag",
        "carnivalseason6" => "Carnaval: Carnaval",
        "carnivalseason"  => "Carnival",
        "faschingseason1" => "Fasching: Vrouwen carnaval",
        "faschingseason2" => "Fasching: Carnavalsvrijdag",
        "faschingseason3" => "Fasching: Carnavalszaterdag",
        "faschingseason4" => "Fasching: Carnavalszondag",
        "faschingseason5" => "Fasching: Vette maandag",
        "faschingseason6" => "Fasching: Carnaval",
        "faschingseason"  => "Fasching",
        "lentenbegin"     => "Vasten: Begin van de vastentijd",
        "lentenw1"        => "Vasten: Vastenweek 1",
        "lentenw2"        => "Vasten: Vastenweek 2",
        "lentenw3"        => "Vasten: Vastenweek 3",
        "lentenw4"        => "Vasten: Vastenweek 4",
        "lentenw5"        => "Vasten: Vastenweek 5",
        "lentenw6"        => "Vasten: Vastenweek 6",
        "lentenw7"        => "Vasten: Grote vastenweek",
        "lentensun1"      => "Vasten: 1ste zondag van de vastentijd",
        "lentensun2"      => "Vasten: 2e zondag van de vastentijd",
        "lentensun3"      => "Vasten: 3de zondag van de vastentijd",
        "lentensun4"      => "Vasten: 4e zondag van de vastentijd",
        "lentensun5"      => "Vasten: 5e zondag van de vastentijd",
        "lentensun6"      => "Vasten: 6e zondag van de vastentijd",
        "lentenend"       => "Vasten: Einde van de vastentijd",
        "sbeerseasonbegin" =>
          "Sterke Bier Festival: Begin van het Sterke Bier Festival",
        "sbeerseason"       => "Sterke Bier Festival",
        "holyweekpalm"      => "Heilige week: Palm en Passie Zondag",
        "holyweekthu"       => "Heilige week: Witte Donderdag",
        "holyweekfri"       => "Heilige week: Goede Vrijdag",
        "holyweeksat"       => "Heilige week: Paaszaterdag",
        "holyweek"          => "Heilige week",
        "eastersun"         => "Pasen: Paaszondag",
        "eastermon"         => "Pasen: Paasmaandag",
        "eastersat"         => "Pasen: Paaszaterdag",
        "easterwhitesun"    => "Pasen: Witte Zondag",
        "easterseason"      => "Pasen",
        "oktoberfestbegin"  => "Oktoberfest: Begin van het Oktoberfest",
        "oktoberfestseason" => "Oktoberfest",
        "halloweenbegin"    => "Halloween: Begin van de Halloween-periode",
        "halloween"         => "Halloween: Halloween",
        "halloweenseason"   => "Halloween",
        "advent1"           => "Advent: 1e advent",
        "advent2"           => "Advent: 2de advent",
        "advent3"           => "Advent: 3de advent",
        "advent4"           => "Advent: 4de advent",
        "adventseason"      => "Advent",
        "christmaseve"      => "Kerstmis: Kerstavond",
        "christmas1"        => "Kerstmis: 1e kerstdag",
        "christmas2"        => "Kerstmis: 2e kerstdag",
        "christmasseason"   => "Kerstmis",
    },

    PL => {
        "overview"     => "Streszczenie",
        "dayschedule"  => "Rozkład dnia",
        "yesterday"    => "wczoraj",
        "today"        => "aktualnie",
        "tomorrow"     => "przyszłość",
        "event"        => "Zdarzenie",
        "events"       => "Zdarzenia",
        "noevents"     => "Nie ma żadnych wydarzeń.",
        "alldayevents" => "Wydarzenia całodniowe",
        "dayevents"    => "Wydarzenia w ciągu dnia",
        "teasernext"   => "Podgląd dla następnego dnia",
        "daylight"     => "światło dzienne",
        "daytype"      => "Typ dnia",
        "description"  => "Opis",

        #
        "cardinaldirection" => "Kierunek główny",
        "duskcivil"         => "Zmierzch cywilny",
        "dusknautic"        => "Zmierzch morski",
        "duskastro"         => "Zmierzch astronomiczny",
        "duskcustom"        => "Zmierzch niestandardowy",
        "dawncivil"         => "świt cywilny",
        "dawnnautic"        => "świt morski",
        "dawnastro"         => "świt astronomiczny",
        "dawncustom"        => "świt niestandardowy",
        "commonyear"        => "wspólny rok",
        "leapyear"          => "rok przestępny",

        #
        "seasonalhour" => "Godzina Sezonowa",
        "temporalhour" => "Czasowa Godzina",

        #
        "dayphase"          => "Pora dnia",
        "dusk"              => "Zmierzch",
        "earlyevening"      => "Wczesnym wieczorem",
        "evening"           => "Wieczór",
        "lateevening"       => "Późny wieczór",
        "earlynight"        => "Wczesna noc",
        "beforemidnight"    => "Przed północą",
        "midnight"          => "Północ",
        "aftermidnight"     => "Po północy",
        "latenight"         => "Późna noc",
        "cockcrow"          => "Pianie koguta",
        "firstmorninglight" => "Pierwsze światło poranne",
        "dawn"              => "świt",
        "breakingdawn"      => "łamanie świtu",
        "earlymorning"      => "Wcześnie rano",
        "morning"           => "Ranek",
        "earlyforenoon"     => "Wczesne przedpołudnie",
        "forenoon"          => "Przedpołudnie",
        "lateforenoon"      => "Późne przedpołudnie",
        "noon"              => "Południe",
        "earlyafternoon"    => "Wczesne popołudnie",
        "afternoon"         => "Popołudnie",
        "lateafternoon"     => "Późne popołudnie",
        "firstdusk"         => "Pierwszy zmierzch",

        #
        "week"      => "Tydzień",
        "remaining" => "pozostały",
        "weekend"   => [ "Weekend", "WE" ],
        "holiday"   => [ "Urlop", "UR" ],
        "vacation"  => [ "Wakacje", "WA" ],
        "workday"   => [ "Pracy", "PR" ],

        #
        "season"          => "Sezon",
        "seasonoftheyear" => "Sezon roku",
        "metseason"       => "Sezon Meteorologiczny",

        #
        "phenseason"  => "Sezon Fenologiczny",
        "Earlyspring" => "Wczesna wiosna",
        "firstspring" => "Pierwsza wiosna",
        "fullspring"  => "Pełna wiosna",
        "earlysummer" => "Wczesne lato",
        "midsummer"   => "Połowa lata",
        "latesummer"  => "Późne lato",
        "Earlyfall"   => "Wczesna jesień",
        "fullfall"    => "Pełna jesień",
        "latefall"    => "Późną jesienią",

        #
        "valentinesday"            => "Walentynki",
        "ashwednesday"             => "Środa popielcowa",
        "walpurgisnight"           => "Noc Walpurgii",
        "mothersday"               => "Dzień Matki",
        "fathersday"               => "Dzień Ojca",
        "pentecostsun"             => "Niedziela Zielonych Świąt",
        "pentecostmon"             => "Poniedziałek Zielonych Świąt",
        "harvestfestival"          => "Dożynki",
        "allsoulsday"              => "Dzień Zaduszny",
        "martinising"              => "Śpiewanie św. Marcina",
        "martinmas"                => "Martinmas",
        "dayofprayerandrepentance" => "Dzień Modlitwy i Nawrócenia",
        "remembranceday"           => "Dzień Pamięci",
        "lastsundaybeforeadvent"   => "Niedziela, kiedy umarli umarli",
        "stnicholasday"            => "Święty Mikołaj",
        "biblicalmagi"             => "Biblijny Magi",
        "internationalwomensday"   => "Międzynarodowy Dzień Kobiet",
        "stpatricksday"            => "Dzień św. Patryka",
        "laborday"                 => "Dzień Pracy",
        "liberationday"            => "Dzień Wyzwolenia",
        "ascension"                => "Wniebowstąpienie",
        "corpuschristi"            => "Corpus Christi",
        "assumptionday"            => "Dzień Założyciela",
        "worldchildrensday"        => "Światowy Dzień Dziecka",
        "germanunificationday"     => "Niemiecki Dzień Zjednoczenia",
        "reformationday"           => "Dzień Reformacji",
        "allsaintsday"             => "Dzień Wszystkich Świętych",

        #
        "newyearseve"     => "Przełom roku: W Sylwestra",
        "newyear"         => "Przełom roku: Nowy Rok",
        "turnoftheyear"   => "Przełom roku",
        "carnivalseason1" => "Karnawał: Karnawał dla kobiet",
        "carnivalseason2" => "Karnawał: Karnawałowy piątek",
        "carnivalseason3" => "Karnawał: Karnawał w sobotę",
        "carnivalseason4" => "Karnawał: Karnawałowa niedziela",
        "carnivalseason5" => "Karnawał: Poniedziałek karnawałowy",
        "carnivalseason6" => "Karnawał: Karnawał",
        "carnivalseason"  => "Karnawał",
        "faschingseason1" => "Fasching: Karnawał dla kobiet",
        "faschingseason2" => "Fasching: Karnawałowy piątek",
        "faschingseason3" => "Fasching: Karnawał w sobotę",
        "faschingseason4" => "Fasching: Karnawałowa niedziela",
        "faschingseason5" => "Fasching: Poniedziałek karnawałowy",
        "faschingseason6" => "Fasching: Karnawał",
        "faschingseason"  => "Fasching",
        "lentenbegin"     => "Wielki Post: Początek postu",
        "lentenw1"        => "Wielki Post: Tydzień postu 1",
        "lentenw2"        => "Wielki Post: Tydzień postu 2",
        "lentenw3"        => "Wielki Post: Tydzień postu 3",
        "lentenw4"        => "Wielki Post: Tydzień postu 4",
        "lentenw5"        => "Wielki Post: Tydzień postu 5",
        "lentenw6"        => "Wielki Post: Tydzień postu 6",
        "lentenw7"        => "Wielki Post: Wielki tydzień postu",
        "lentensun1"      => "Wielki Post: 1. szybka niedziela",
        "lentensun2"      => "Wielki Post: 2. szybka niedziela",
        "lentensun3"      => "Wielki Post: 3. szybka niedziela",
        "lentensun4"      => "Wielki Post: 4. szybka niedziela",
        "lentensun5"      => "Wielki Post: 5. szybka niedziela",
        "lentensun6"      => "Wielki Post: 6. szybka niedziela",
        "lentenend"       => "Wielki Post: Koniec postu",
        "sbeerseasonbegin" =>
          "Mocny Festiwal Piwa: Początek Festiwalu Piwa Mocnego",
        "sbeerseason"       => "Mocny Festiwal Piwa",
        "holyweekpalm"      => "Wielki Tydzień: Palma i Pasja Niedziela",
        "holyweekthu"       => "Wielki Tydzień: Maundy Thursday",
        "holyweekfri"       => "Wielki Tydzień: Dobry piątek",
        "holyweeksat"       => "Wielki Tydzień: Wielka Sobota",
        "holyweek"          => "Wielki Tydzień",
        "eastersun"         => "Wielkanoc: Niedziela Wielkanocna",
        "eastermon"         => "Wielkanoc: Poniedziałek Wielkanocny",
        "eastersat"         => "Wielkanoc: Sobota Wielkanocna",
        "easterwhitesun"    => "Wielkanoc: Biała Niedziela",
        "easterseason"      => "Wielkanoc",
        "oktoberfestbegin"  => "Oktoberfest: Początek Oktoberfestu",
        "oktoberfestseason" => "Oktoberfest",
        "halloweenbegin"    => "Halloween: Początek okresu Halloween",
        "halloween"         => "Halloween: Halloween",
        "halloweenseason"   => "Halloween",
        "advent1"           => "Adwent: 1. Adwent",
        "advent2"           => "Adwent: 2. Adwent",
        "advent3"           => "Adwent: 3. Adwent",
        "advent4"           => "Adwent: 4. Adwent",
        "adventseason"      => "Adwent",
        "christmaseve"      => "Boże Narodzenie: Wigilia",
        "christmas1"        => "Boże Narodzenie: 1. dzień Bożego Narodzenia",
        "christmas2"        => "Boże Narodzenie: 2. dzień Bożego Narodzenia",
        "christmasseason"   => "Boże Narodzenie",
    }
);

our @dayphases = (

    # night
    "dusk",
    "earlyevening",
    "evening",
    "lateevening",
    "earlynight",
    "beforemidnight",
    "midnight",
    "aftermidnight",
    "latenight",
    "cockcrow",
    "firstmorninglight",
    "dawn",

    # day
    "breakingdawn",
    "earlymorning",
    "morning",
    "earlyforenoon",
    "forenoon",
    "lateforenoon",
    "noon",
    "earlyafternoon",
    "afternoon",
    "afternoon",
    "lateafternoon",
    "firstdusk",
);

our %seasonmn = (
    "spring" => [ 3,  5 ],     #01.03. - 31.5.
    "summer" => [ 6,  8 ],     #01.06. - 31.8.
    "fall"   => [ 9,  11 ],    #01.09. - 30.11.
    "winter" => [ 12, 2 ],     #01.12. - 28./29.2.
);

our @seasonsicon = ( chr(0x26C4), chr(0x1F331), '☀️', chr(0x1F342), );

our @zodiacicon = (
    chr(0x2648), chr(0x2649), chr(0x264A), chr(0x264B),
    chr(0x264C), chr(0x264D), chr(0x264E), chr(0x264F),
    chr(0x2650), chr(0x2651), chr(0x2652), chr(0x2653)
);

our @phasesicon = (
    chr(0x1F311), chr(0x1F312), chr(0x1F313), chr(0x1F314),
    chr(0x1F315), chr(0x1F316), chr(0x1F317), chr(0x1F318)
);

our %transtableHolidays = (
    DE => {
        'Valentinstag'              => 'valentinesday',
        'Aschermittwoch'            => 'ashwednesday',
        'Walpurgisnacht'            => 'walpurgisnight',
        'Muttertag'                 => 'mothersday',
        'Vatertag'                  => 'fathersday',
        'Pfingstsonntag'            => 'pentecostsun',
        'Pfingstmontag'             => 'pentecostmon',
        'Erntedankfest'             => 'harvestfestival',
        'Allerseelen'               => 'allsoulsday',
        'Martinisingen'             => 'martinising',
        'Martinstag'                => 'martinmas',
        'Buß- und Bettag'          => 'dayofprayerandrepentance',
        'Volkstrauertag'            => 'remembranceday',
        'Totensonntag'              => 'lastsundaybeforeadvent',
        'Nikolaus'                  => 'stnicholasday',
        'Heilige Drei Könige'      => 'biblicalmagi',
        'Internationaler Frauentag' => 'internationalwomensday',
        'St. Patrick\'s Day'        => 'stpatricksday',
        'Tag der Arbeit'            => 'laborday',
        'Tag der Befreiung'         => 'liberationday',
        'Christi Himmelfahrt'       => 'ascension',
        'Fronleichnam'              => 'corpuschristi',
        'Mariä Himmelfahrt'        => 'assumptionday',
        'Weltkindertag'             => 'worldchildrensday',
        'Tag der Deutschen Einheit' => 'germanunificationday',
        'Reformationstag'           => 'reformationday',
        'Allerheiligen'             => 'allsaintsday',
        'Silvester'                 => 'newyearseve',

        #
        'Tanz in den Mai'      => 'walpurgisnight',
        'Pfingsten'            => 'pentecostsun',
        'Martinsingen'         => 'martinising',
        'Heilige Drei Koenige' => 'biblicalmagi',
        'St Patrick\'s Day'    => 'stpatricksday',
        'St. Patricks Day'     => 'stpatricksday',
        'St Patricks Day'      => 'stpatricksday',
    },
);

our %holidaysicon = (
    'valentinesday'            => chr(0x0),
    'ashwednesday'             => chr(0x0),
    'walpurgisnight'           => chr(0x0),
    'mothersday'               => chr(0x0),
    'fathersday'               => chr(0x0),
    'pentecostsun'             => chr(0x0),
    'pentecostmon'             => chr(0x0),
    'harvestfestival'          => chr(0x0),
    'allsoulsday'              => chr(0x0),
    'martinising'              => chr(0x0),
    'martinmas'                => chr(0x0),
    'dayofprayerandrepentance' => chr(0x0),
    'remembranceday'           => chr(0x0),
    'lastsundaybeforeadvent'   => chr(0x0),
    'stnicholasday'            => chr(0x0),
    'biblicalmagi'             => chr(0x0),
    'internationalwomensday'   => chr(0x0),
    'stpatricksday'            => chr(0x0),
    'laborday'                 => chr(0x0),
    'liberationday'            => chr(0x0),
    'ascension'                => chr(0x0),
    'corpuschristi'            => chr(0x0),
    'assumptionday'            => chr(0x0),
    'worldchildrensday'        => chr(0x0),
    'germanunificationday'     => chr(0x0),
    'reformationday'           => chr(0x0),
    'allsaintsday'             => chr(0x0),
    'newyearseve'              => chr(0x0),
    'carnivalseason1'          => chr(0x0),
    'carnivalseason2'          => chr(0x0),
    'carnivalseason3'          => chr(0x0),
    'carnivalseason4'          => chr(0x0),
    'carnivalseason5'          => chr(0x0),
    'carnivalseason6'          => chr(0x0),
    'faschingseason1'          => chr(0x0),
    'faschingseason2'          => chr(0x0),
    'faschingseason3'          => chr(0x0),
    'faschingseason4'          => chr(0x0),
    'faschingseason5'          => chr(0x0),
    'faschingseason6'          => chr(0x0),
);

our %seasonssocialicon = (
    Carnival           => chr(0x1F3A0),
    CarnivalLong       => chr(0x1F3AD),
    Fasching           => chr(0x1F38A),
    FaschingLong       => chr(0x1F3AD),
    StrongBeerFestival => chr(0x1F37B),
    HolyWeek           => '✝️',
    Easter             => chr(0x1F430),
    EasterTraditional  => chr(0x1F95A),
    Lenten             => chr(0x1F957),
    Oktoberfest        => chr(0x1F3A1),
    Halloween          => chr(0x1F383),
    Advent             => chr(0x1F56F),
    AdventEarly        => chr(0x1F490),
    TurnOfTheYear      => chr(0x1F389),
    Christmas          => chr(0x1F385),
    ChristmasLong      => chr(0x1F384),
);

our @seasonsp = (
    [ "winter",      chr(0x26C4) ],
    [ "earlyspring", chr(0x1F331) ],
    [ "firstspring", chr(0x1F331) ],
    [ "fullspring",  chr(0x1F331) ],
    [ "earlysummer", '☀️' ],
    [ "midsummer",   '☀️' ],
    [ "latesummer",  '☀️' ],
    [ "earlyfall",   chr(0x1F342) ],
    [ "fullfall",    chr(0x1F342) ],
    [ "latefall",    chr(0x1F342) ]
);

our %seasonppos = (
    earlyspring => [ 37.136633, -8.817837 ],    #South-West Portugal
    earlyfall   => [ 60.161880, 24.937267 ],    #South Finland / Helsinki
);

my @daytypes = (
    [ 'workday',  chr(0x1F454) ],
    [ 'vacation', chr(0x1F334) ],
    [ 'weekend',  chr(0x1F4C6) ],
    [ 'holiday',  chr(0x1F4C5) ]
);

# Run before package compilation
BEGIN {
    ::LoadModule("Astro");

    # Import from main context
    GP_Import(
        qw(
          attr
          Astro_Get
          AttrVal
          CommandAttr
          CommandDefine
          data
          Debug
          defs
          deviceEvents
          FW_hiddenroom
          FW_webArgs
          IsDevice
          IsWe
          FmtDateTime
          GetType
          goodDeviceName
          init_done
          InternalTimer
          IsDisabled
          Log
          Log3
          maxNum
          minNum
          modules
          readingFnAttributes
          readingsBeginUpdate
          readingsBulkUpdateIfChanged
          readingsEndUpdate
          readingsSingleUpdate
          RemoveInternalTimer
          time_str2num
          trim
          toJSON
          urlEncode
          )
    );

    # Export to main context
    GP_Export(
        qw(
          Get
          Initialize
          )
    );
}

_LoadPackagesWrapper();

sub SetTime(;$$$$);
sub Compute($;$$);

sub Initialize ($) {
    my ($hash) = @_;

    $hash->{DefFn}    = "FHEM::DaySchedule::Define";
    $hash->{SetFn}    = "FHEM::DaySchedule::Set";
    $hash->{GetFn}    = "FHEM::DaySchedule::Get";
    $hash->{UndefFn}  = "FHEM::DaySchedule::Undef";
    $hash->{AttrFn}   = "FHEM::DaySchedule::Attr";
    $hash->{NotifyFn} = "FHEM::DaySchedule::Notify";

    my @astroDevices = ::devspec2array("TYPE=Astro");
    $attrs{AstroDevice} = join( ',', @astroDevices )
      if (@astroDevices);
    my @calDevices = ::devspec2array("TYPE=holiday,TYPE=Calendar");
    if (@calDevices) {
        $attrs{HolidayDevices} = 'multiple-strict,' . join( ',', @calDevices );
        $attrs{InformativeDevices} = $attrs{HolidayDevices};
        $attrs{VacationDevices}    = $attrs{HolidayDevices};
        $attrs{WeekendDevices}     = $attrs{HolidayDevices};
        $attrs{WorkdayDevices}     = $attrs{HolidayDevices};
    }

    $hash->{AttrList} = join( " ",
        map { defined( $attrs{$_} ) ? "$_:$attrs{$_}" : $_ } sort keys %attrs )
      . " "
      . $readingFnAttributes;

    $hash->{parseParams} = 1;

    return FHEM::Meta::InitMod( __FILE__, $hash );
}

sub Define ($@) {
    my ( $hash, $a, $h ) = @_;
    my $name = shift @$a;
    my $type = shift @$a;

    return $@ unless ( FHEM::Meta::SetInternals($hash) );
    use version 0.77; our $VERSION = FHEM::Meta::Get( $hash, 'version' );

    $hash->{NOTIFYDEV} = "global";
    $hash->{INTERVAL}  = 3600;
    readingsSingleUpdate( $hash, "state", "Initialized", $init_done );

    $modules{DaySchedule}{defptr}{$name} = $hash;

    # for the very first definition, set some default attributes
    if ( $init_done && !defined( $hash->{OLDDEF} ) ) {
        $attr{$name}{icon}        = 'time_calendar';
        $attr{$name}{recomputeAt} = 'NewDay,SeasonalHr';
        $attr{$name}{Schedule} =
'ObsIsDST,SeasonMeteo,SeasonPheno,ObsSeason,Daytime,SunRise,SunSet,SunSign,AstroTwilightEvening,AstroTwilightMorning,CivilTwilightEvening,CivilTwilightMorning,NauticTwilightEvening,NauticTwilightMorning,CustomTwilightEvening,CustomTwilightMorning';
        $attr{$name}{SocialSeasons} =
'Carnival,Easter,Oktoberfest,Halloween,Advent,TurnOfTheYear,Christmas';
        $attr{$name}{stateFormat} = 'Daytime';
    }

    return undef;
}

sub Undef ($$) {
    my ( $hash, $arg ) = @_;

    RemoveInternalTimer($hash);

    return undef;
}

sub Notify ($$) {
    my ( $hash, $dev ) = @_;
    my $name    = $hash->{NAME};
    my $TYPE    = $hash->{TYPE};
    my $devName = $dev->{NAME};
    my $devType = GetType($devName);

    # Update attribute values
    Initialize( $modules{$TYPE} );

    if ( $devName eq "global" ) {
        my $events = deviceEvents( $dev, 1 );
        return "" unless ($events);

        foreach my $event ( @{$events} ) {
            next unless ( defined($event) );
            next if ( $event =~ m/^[A-Za-z\d_-]+:/ );

            if ( $event =~ m/^INITIALIZED|REREADCFG$/ ) {
                if ( ( defined( $hash->{INTERVAL} ) && $hash->{INTERVAL} > 0 )
                    || defined( $hash->{RECOMPUTEAT} ) )
                {
                    RemoveInternalTimer($hash);
                    InternalTimer( gettimeofday() + 5,
                        "FHEM::DaySchedule::Update", $hash, 0 );
                }
            }
            elsif ($event =~ m/^(DEFINED|MODIFIED)\s+([A-Za-z\d_-]+)$/
                && $2 eq $name )
            {
                if ( ( defined( $hash->{INTERVAL} ) && $hash->{INTERVAL} > 0 )
                    || defined( $hash->{RECOMPUTEAT} ) )
                {
                    RemoveInternalTimer($hash);
                    InternalTimer( gettimeofday() + 1,
                        "FHEM::DaySchedule::Update", $hash, 0 );
                }
            }

            # only process attribute events
            next
              unless ( $event =~
m/^((?:DELETE)?ATTR)\s+([A-Za-z\d._]+)\s+([A-Za-z\d_\.\-\/]+)(?:\s+(.*)\s*)?$/
              );

            my $cmd  = $1;
            my $d    = $2;
            my $attr = $3;
            my $val  = $4;
            my $type = GetType($d);

            # filter attributes to be processed
            next
              unless ( $attr eq "altitude"
                || $attr eq "language"
                || $attr eq "latitude"
                || $attr eq "lc_numeric"
                || $attr eq "lc_time"
                || $attr eq "longitude"
                || $attr eq "timezone" );

            # when global or Astro attributes were changed
            if ( $d eq "global" || IsDevice( $d, "Astro" ) ) {
                RemoveInternalTimer($hash);
                InternalTimer( gettimeofday() + 1,
                    "FHEM::DaySchedule::Update", $hash, 0 );
            }
        }
    }

    return undef;
}

sub Attr(@) {
    my ( $do, $name, $key, $value ) = @_;

    my $hash = $defs{$name};
    my $ret;

    if ( $do eq "set" ) {
      ARGUMENT_HANDLER: {

            # altitude modified at runtime
            $key eq "altitude" and do {

                # check value
                return
                  "$do $name attribute $key must be a float number >= 0 meters"
                  unless ( $value =~ m/^(\d+(?:\.\d+)?)$/ && $1 >= 0. );
            };

            # AstroDevice modified at runtime
            $key eq "AstroDevice" and do {

                # check value
                return
                  "$do $name attribute $key has invalid device name format"
                  unless ( goodDeviceName($value) );

                if ( $init_done && scalar keys %Astro > 0. ) {
                    foreach ( keys %Astro ) {
                        delete $defs{$name}{READINGS}{$_};
                    }
                }

                $hash->{NOTIFYDEV} = "global," . $value;
            };

            # HolidayDevices modified at runtime
            $key eq "HolidayDevices" and do {

                # check value
                foreach ( split( ",", $value ) ) {
                    return
                      "$do $name attribute $key has invalid device name format "
                      . $_
                      unless ( goodDeviceName($_) );
                }
            };

            # InformativeDays modified at runtime
            $key eq "InformativeDays" and do {
                my @skel = split( ',', $attrs{InformativeDays} );
                shift @skel;

                # check value 1/2
                return "$do $name attribute $key must be one or many of "
                  . join( ',', @skel )
                  if ( !$value || $value eq "" );

                # check value 2/2
                my @vals = split( ',', $value );
                foreach my $val (@vals) {
                    return
"$do $name attribute value $val is invalid, must be one or many of "
                      . join( ',', @skel )
                      unless ( grep( m/^$val$/, @skel ) );
                }
            };

            # InformativeDevices modified at runtime
            $key eq "InformativeDevices" and do {

                # check value
                foreach ( split( ",", $value ) ) {
                    return
                      "$do $name attribute $key has invalid device name format "
                      . $_
                      unless ( goodDeviceName($_) );
                }
            };

            # VacationDevices modified at runtime
            $key eq "VacationDevices" and do {

                # check value
                foreach ( split( ",", $value ) ) {
                    return
                      "$do $name attribute $key has invalid device name format "
                      . $_
                      unless ( goodDeviceName($_) );
                }
            };

            # WeekendDevices modified at runtime
            $key eq "WeekendDevices" and do {

                # check value
                foreach ( split( ",", $value ) ) {
                    return
                      "$do $name attribute $key has invalid device name format "
                      . $_
                      unless ( goodDeviceName($_) );
                }
            };

            # WorkdayDevices modified at runtime
            $key eq "WorkdayDevices" and do {

                # check value
                foreach ( split( ",", $value ) ) {
                    return
                      "$do $name attribute $key has invalid device name format "
                      . $_
                      unless ( goodDeviceName($_) );
                }
            };

            # disable modified at runtime
            $key eq "disable" and do {

                # check value
                return "$do $name attribute $key can only be 1 or 0"
                  unless ( $value =~ m/^(1|0)$/ );
                readingsSingleUpdate( $hash, "state",
                    $value ? "inactive" : "Initialized", $init_done );
            };

            # Earlyfall modified at runtime
            $key eq "Earlyfall" and do {

                # check value
                return
"$do $name attribute $key must be in format <month>-<day> while <month> can only be 08 or 09"
                  unless ( $value =~ m/^(0[8-9])-(0[1-9]|[12]\d|30|31)$/ );
            };

            # Earlyspring modified at runtime
            $key eq "Earlyspring" and do {

                # check value
                return
"$do $name attribute $key must be in format <month>-<day> while <month> can only be 02 or 03"
                  unless ( $value =~ m/^(0[2-3])-(0[1-9]|[12]\d|30|31)$/ );
            };

            # horizon modified at runtime
            $key eq "horizon" and do {

                # check value
                return
"$do $name attribute $key must be a float number >= -45 and <= 45 degrees"
                  unless (
                       $value =~ m/^(-?\d+(?:\.\d+)?)(?::(-?\d+(?:\.\d+)?))?$/
                    && $1 >= -45.
                    && $1 <= 45.
                    && ( !$2 || $2 >= -45. && $2 <= 45. ) );
            };

            # interval modified at runtime
            $key eq "interval" and do {

                # check value
                return "$do $name attribute $key must be >= 0 seconds"
                  unless ( $value =~ m/^\d+$/ );

                # update timer
                $hash->{INTERVAL} = $value;
            };

            # latitude modified at runtime
            $key eq "latitude" and do {

                # check value
                return
"$do $name attribute $key must be float number >= -90 and <= 90 degrees"
                  unless ( $value =~ m/^(-?\d+(?:\.\d+)?)$/
                    && $1 >= -90.
                    && $1 <= 90. );
            };

            # longitude modified at runtime
            $key eq "longitude" and do {

                # check value
                return
"$do $name attribute $key must be float number >= -180 and <= 180 degrees"
                  unless ( $value =~ m/^(-?\d+(?:\.\d+)?)$/
                    && $1 >= -180.
                    && $1 <= 180. );
            };

            # recomputeAt modified at runtime
            $key eq "recomputeAt" and do {
                my @skel = split( ',', $attrs{recomputeAt} );
                shift @skel;

                # check value 1/2
                return "$do $name attribute $key must be one or many of "
                  . join( ',', @skel )
                  if ( !$value || $value eq "" );

                # check value 2/2
                my @vals = split( ',', $value );
                foreach my $val (@vals) {
                    return
"$do $name attribute value $val is invalid, must be one or many of "
                      . join( ',', @skel )
                      unless ( grep( m/^$val$/, @skel ) );
                }
                $hash->{RECOMPUTEAT} = join( ',', @vals );
            };

            # Schedule modified at runtime
            $key eq "Schedule" and do {
                my @skel = split( ',', $attrs{Schedule} );
                shift @skel;

                # check value 1/2
                return "$do $name attribute $key must be one or many of "
                  . join( ',', @skel )
                  if ( !$value || $value eq "" );

                # check value 2/2
                my @vals = split( ',', $value );
                foreach my $val (@vals) {
                    return
"$do $name attribute value $val is invalid, must be one or many of "
                      . join( ',', @skel )
                      unless ( grep( m/^$val$/, @skel ) );
                }
            };

            # SeasonalHrs modified at runtime
            $key eq "SeasonalHrs" and do {

                # check value
                return
"$do $name attribute $key must be an integer number >= 1 and <= 24 hours"
                  unless ( $value =~ m/^(\d+)(?::(\d+))?$/
                    && $1 >= 1.
                    && $1 <= 24.
                    && ( !$2 || $2 >= 1. && $2 <= 24. ) );
            };
        }
    }

    elsif ( $do eq "del" ) {
        readingsSingleUpdate( $hash, "state", "Initialized", $init_done )
          if ( $key eq "disable" );
        $hash->{INTERVAL} = 3600
          if ( $key eq "interval" );
        $hash->{NOTIFYDEV} = "global"
          if ( $key eq "AstroDevice" );
        delete $hash->{RECOMPUTEAT}
          if ( $key eq "recomputeAt" );
    }

    if (
           $init_done
        && exists( $attrs{$key} )
        && (   $hash->{INTERVAL} > 0
            || $hash->{RECOMPUTEAT}
            || $hash->{NEXTUPDATE} )
      )
    {
        RemoveInternalTimer($hash);
        InternalTimer( gettimeofday() + 2,
            "FHEM::DaySchedule::Update", $hash, 0 );
    }

    return $ret;
}

sub Set($@) {
    my ( $hash, $a, $h ) = @_;

    my $name = shift @$a;

    if ( $a->[0] eq "update" ) {
        return "$name is disabled"
          if ( IsDisabled($name) );
        RemoveInternalTimer($hash);
        InternalTimer( gettimeofday() + 1,
            "FHEM::DaySchedule::Update", $hash, 1 );
    }
    elsif ( $a->[0] eq "create" ) {
        if ( $a->[1] eq "weblink" ) {
            my $d   = "wl_" . $name;
            my $cl  = defined( $hash->{CL} ) ? $hash->{CL} : undef;
            my $ret = CommandDefine( $cl,
"$d weblink htmlCode { FHEM::DaySchedule::Get(\$defs{'$name'},['DaySchedule','schedule'],{html=>1,backlink=>'$d',dailyschedule=>0}) }"
            );
            return $ret if ($ret);
            if ( my $room = AttrVal( $name, "room", undef ) ) {
                CommandAttr( $cl, "$d room $room" );
            }
            return "device $d was created";
        }
        else {
            return "$name with unknown $a->[0] argument, choose one of "
              . "weblink";
        }
    }
    else {
        return "$name with unknown argument $a->[0], choose one of "
          . join( " ",
            map { defined( $sets{$_} ) ? "$_:$sets{$_}" : $_ }
            sort keys %sets );
    }

    return "";
}

sub Get($@) {
    my ( $hash, $aref, $h, @a ) = @_;
    my $name = "#APIcall";
    my $type = "dummy";

    # backwards compatibility for non-parseParams requests
    if ( !ref($aref) ) {
        $hash = exists( $defs{$hash} ) ? $defs{$hash} : ()
          if ( $hash && !ref($hash) );
        unshift @a, $h;
        $h    = undef;
        $type = $aref;
        $aref = \@a;
    }
    else {
        $type = shift @$aref;
    }
    if ( defined( $hash->{NAME} ) ) {
        $name = $hash->{NAME};
    }
    else {
        $hash->{NAME} = $name;
    }

    my $wantsreading = 0;
    my $dayOffset    = 0;
    my $now          = gettimeofday();
    my $html =
      defined( $hash->{CL} ) && $hash->{CL}{TYPE} eq "FHEMWEB" ? 1 : undef;
    my $AstroDev = AttrVal( $name, "AstroDevice", "" );
    my $tz = AttrVal(
        $name,
        "timezone",
        AttrVal(
            $AstroDev, "timezone", AttrVal( "global", "timezone", undef )
        )
    );
    my $lang = AttrVal(
        $name,
        "language",
        AttrVal(
            $AstroDev, "language", AttrVal( "global", "language", undef )
        )
    );
    my $lc_numeric = AttrVal(
        $name,
        "lc_numeric",
        AttrVal(
            $AstroDev,
            "lc_numeric",
            AttrVal( "global", "lc_numeric",
                ( $lang ? lc($lang) . "_" . uc($lang) . ".UTF-8" : undef ) )

        )
    );
    my $lc_time = AttrVal(
        $name,
        "lc_time",
        AttrVal(
            $AstroDev,
            "lc_time",
            AttrVal( "global", "lc_time",
                ( $lang ? lc($lang) . "_" . uc($lang) . ".UTF-8" : undef ) )

        )
    );
    if ( $h && ref($h) ) {
        $html       = $h->{html}       if ( defined( $h->{html} ) );
        $tz         = $h->{timezone}   if ( defined( $h->{timezone} ) );
        $lc_numeric = $h->{lc_numeric} if ( defined( $h->{lc_numeric} ) );
        $lc_numeric =
          lc( $h->{language} ) . "_" . uc( $h->{language} ) . ".UTF-8"
          if ( !$lc_numeric && defined( $h->{language} ) );
        $lc_time = $h->{lc_time} if ( defined( $h->{lc_time} ) );
        $lc_time = lc( $h->{language} ) . "_" . uc( $h->{language} ) . ".UTF-8"
          if ( !$lc_time && defined( $h->{language} ) );
    }

    # fill %Astro if it is still empty after restart
    Compute( $hash, undef, $h )
      if ( scalar keys %Astro == 0 || scalar keys %Schedule == 0 );

    #-- second parameter may be one or many readings
    my @readings;
    if ( ( int(@$aref) > 1 ) ) {
        @readings = split( ',', $aref->[1] );
        foreach (@readings) {
            if ( exists( $Schedule{$_} ) && !ref( $Schedule{$_} ) ) {
                $wantsreading = 1;
                last;
            }
            elsif ( exists( $Astro{$_} ) && !ref( $Astro{$_} ) ) {
                $wantsreading = 1;
                last;
            }
        }
    }

    # last parameter may be indicating day offset
    if (
        (
            int(@$aref) > 4 + $wantsreading
            && $aref->[ 4 + $wantsreading ] =~
            /^\+?([-+]\d+|yesterday|tomorrow)$/i
        )
        || ( int(@$aref) > 3 + $wantsreading
            && $aref->[ 3 + $wantsreading ] =~
            /^\+?([-+]\d+|yesterday|tomorrow)$/i )
        || ( int(@$aref) > 2 + $wantsreading
            && $aref->[ 2 + $wantsreading ] =~
            /^\+?([-+]\d+|yesterday|tomorrow)$/i )
        || ( int(@$aref) > 1 + $wantsreading
            && $aref->[ 1 + $wantsreading ] =~
            /^\+?([-+]\d+|yesterday|tomorrow)$/i )
      )
    {
        $dayOffset = $1;
        pop @$aref;
        $dayOffset = -1 if ( lc($dayOffset) eq "yesterday" );
        $dayOffset = 1  if ( lc($dayOffset) eq "tomorrow" );
    }

    if ( int(@$aref) > ( 1 + $wantsreading ) ) {
        my $str =
          ( int(@$aref) == ( 3 + $wantsreading ) )
          ? $aref->[ 1 + $wantsreading ] . " " . $aref->[ 2 + $wantsreading ]
          : $aref->[ 1 + $wantsreading ];
        if ( $str =~
/^(\d{2}):(\d{2})(?::(\d{2}))?$|^(?:(?:(\d{4})-)?(\d{2})-(\d{2}))(?:\D+(\d{2}):(\d{2})(?::(\d{2}))?)?$/
          )
        {
            return
              "[FHEM::DaySchedule::Get] hours can only be between 00 and 23"
              if ( defined($1) && $1 > 23. );
            return
              "[FHEM::DaySchedule::Get] minutes can only be between 00 and 59"
              if ( defined($2) && $2 > 59. );
            return
              "[FHEM::DaySchedule::Get] seconds can only be between 00 and 59"
              if ( defined($3) && $3 > 59. );
            return
              "[FHEM::DaySchedule::Get] month can only be between 01 and 12"
              if ( defined($5) && ( $5 > 12. || $5 < 1. ) );
            return "[FHEM::DaySchedule::Get] day can only be between 01 and 31"
              if ( defined($6) && ( $6 > 31. || $6 < 1. ) );
            return
              "[FHEM::DaySchedule::Get] hours can only be between 00 and 23"
              if ( defined($7) && $7 > 23. );
            return
              "[FHEM::DaySchedule::Get] minutes can only be between 00 and 59"
              if ( defined($8) && $8 > 59. );
            return
              "[FHEM::DaySchedule::Get] seconds can only be between 00 and 59"
              if ( defined($9) && $9 > 59. );

            SetTime(
                timelocal_modern(
                    defined($3) ? $3 : ( defined($9) ? $9 : 0 ),
                    defined($2) ? $2 : ( defined($8) ? $8 : 0 ),
                    defined($1) ? $1 : ( defined($7) ? $7 : 12 ),
                    (
                        defined($5) ? ( $6, $5 - 1. )
                        : ( localtime($now) )[ 3, 4 ]
                    ),
                    (
                        defined($4) ? $4
                        : ( localtime($now) )[5] + 1900.
                    )
                  ) + ( $dayOffset * 86400. ),
                $tz, $lc_time
            );
        }
        else {
            return
"$name has improper time specification $str, use [YYYY-]MM-DD [HH:MM[:SS]] [-1|yesterday|+1|tomorrow]";
        }
    }
    else {
        SetTime( $now + ( $dayOffset * 86400. ), $tz, $lc_time );
    }

    #-- disable automatic links to FHEM devices
    delete $FW_webArgs{addLinks};

    # get/version
    if ( $aref->[0] eq "version" ) {
        return version->parse( FHEM::DaySchedule::->VERSION() )->normal;

    }

    # get/json
    elsif ( $aref->[0] eq "json" ) {
        Compute( $hash, undef, $h );

        # beautify JSON at cost of performance only when debugging
        if ( AttrVal( $name, "verbose", AttrVal( "global", "verbose", 3 ) ) >
            3. )
        {
            $json->canonical;
            $json->pretty;
        }

        if ( $wantsreading == 1 ) {
            my %ret;
            foreach (@readings) {
                if ( exists( $Schedule{$_} ) && !ref( $Schedule{$_} ) ) {
                    if (   $h
                        && ref($h)
                        && ( $h->{text} || $h->{unit} || $h->{long} ) )
                    {
                        $ret{text}{$_} = FormatReading( $_, $h, $lc_numeric );
                    }
                    $ret{$_} = $Schedule{$_};
                }
                else {
                    $ret{$_} = $Astro{$_} if ( defined( $Astro{$_} ) );
                    $ret{text}{$_} = $Astro{text}{$_}
                      if ( defined( $Astro{text}{$_} ) );
                }
            }

            return $json->encode( \%ret );
        }
        else {
            # only publish today
            delete $Astro{2};
            delete $Astro{1};
            delete $Astro{"-2"};
            delete $Astro{"-1"};
            delete $Schedule{2};
            delete $Schedule{1};
            delete $Schedule{"-2"};
            delete $Schedule{"-1"};

            if ( $h && ref($h) && $h->{text} ) {
                foreach ( keys %Schedule ) {
                    next if ( ref( $Schedule{$_} ) || $_ =~ /^\./ );
                    $Astro{text}{$_} = FormatReading( $_, $h, $lc_numeric );
                }
            }
            return $json->encode( { %Astro, %Schedule } );
        }
    }

    # get/text
    elsif ( $aref->[0] eq "text" ) {
        Compute( $hash, undef, $h );
        my $ret = "";

        if ( IsDevice( $AstroDev, "Astro" ) ) {
            foreach (
                qw(
                altitude
                horizon
                language
                latitude
                lc_numeric
                longitude
                timezone
                )
              )
            {
                $h->{$_} = $attr{$name}{$_}
                  if ( defined( $attr{$name} )
                    && defined( $attr{$name}{$_} )
                    && $attr{$name}{$_} ne ""
                    && !defined( $h->{$_} ) );
            }
        }

        if ( $wantsreading == 1 && $h && ref($h) && scalar keys %{$h} > 0 ) {
            unshift @$aref, $type;

            foreach (@readings) {
                if ( exists( $Astro{$_} ) ) {
                    $ret .= $html && $html eq "1" ? "<br/>\n" : "\n"
                      if ( $ret ne "" );
                    $ret .= Astro_Get(
                        (
                            IsDevice( $AstroDev, "Astro" ) ? $defs{$AstroDev}
                            : $hash
                        ),
                        [
                            IsDevice( $AstroDev, "Astro" ) ? "Astro"
                            : "DaySchedule",
                            "text", $_,
                            sprintf( "%04d-%02d-%02d",
                                $Date{year}, $Date{month}, $Date{day} ),
                            sprintf( "%02d:%02d:%02d",
                                $Date{hour}, $Date{min}, $Date{sec} )
                        ],
                        $h
                    );
                    next;
                }

                next if ( !defined( $Schedule{$_} ) || ref( $Schedule{$_} ) );
                $ret .= $html && $html eq "1" ? "<br/>\n" : "\n"
                  if ( $ret ne "" );
                $ret .= FormatReading( $_, $h, $lc_numeric )
                  unless ( $_ =~ /^\./ );
                $ret .= encode_utf8( $Schedule{$_} ) if ( $_ =~ /^\./ );
            }
            $ret = "<html>" . $ret . "</html>"
              if ( defined($html) && $html ne "0" );
        }
        elsif ( $wantsreading == 1 ) {
            unshift @$aref, $type;

            foreach (@readings) {
                if ( exists( $Astro{$_} ) ) {
                    $ret .= $html && $html eq "1" ? "<br/>\n" : "\n"
                      if ( $ret ne "" );
                    $ret .= Astro_Get(
                        (
                            IsDevice( $AstroDev, "Astro" ) ? $defs{$AstroDev}
                            : $hash
                        ),
                        [
                            IsDevice( $AstroDev, "Astro" ) ? "Astro"
                            : "DaySchedule",
                            "text", $_,
                            sprintf( "%04d-%02d-%02d",
                                $Date{year}, $Date{month}, $Date{day} ),
                            sprintf( "%02d:%02d:%02d",
                                $Date{hour}, $Date{min}, $Date{sec} )
                        ]
                    );
                    next;
                }

                next if ( !defined( $Schedule{$_} ) || ref( $Schedule{$_} ) );
                $ret .= $html && $html eq "1" ? "<br/>\n" : "\n"
                  if ( $ret ne "" );
                $ret .= encode_utf8( $Schedule{$_} );
            }
            $ret = "<html>" . $ret . "</html>"
              if ( defined($html) && $html ne "0" );
        }
        else {
            $h->{long} = 1 unless ( defined( $h->{long} ) );
            $h->{html} = $html if ($html);

            unshift @$aref, $type;
            $ret = Astro_Get(
                (
                    IsDevice( $AstroDev, "Astro" )
                    ? $defs{$AstroDev}
                    : $hash
                ),
                [
                    IsDevice( $AstroDev, "Astro" ) ? "Astro" : "DaySchedule",
                    "text",
                    sprintf( "%04d-%02d-%02d",
                        $Date{year}, $Date{month}, $Date{day} ),
                    sprintf( "%02d:%02d:%02d",
                        $Date{hour}, $Date{min}, $Date{sec} )
                ],
                $h
            );

            my $txt = FormatReading( "DaySeasonalHr", $h, $lc_numeric ) . ", "
              . FormatReading( "Daytime", $h, $lc_numeric );
            $txt .= $html && $html eq "1" ? "<br/>\n" : "\n";
            $ret =~ s/^((?:[^\n]+\n){1})([\s\S]*)$/$1$txt$2/;

            $txt = FormatReading( "SeasonMeteo", $h );
            $txt .= $html && $html eq "1" ? "<br/>\n" : "\n";
            $ret =~ s/^((?:[^\n]+\n){4})([\s\S]*)$/$1$txt$2/;

            $txt = FormatReading( "SeasonPheno", $h );
            $txt .= $html && $html eq "1" ? "<br/>\n" : "\n";
            $ret =~ s/^((?:[^\n]+\n){5})([\s\S]*)$/$1$txt$2/;

            $txt = FormatReading( "SunCompass", $h );
            $txt .= $html && $html eq "1" ? "<br/>\n" : "\n";
            $ret =~ s/^((?:[^\n]+\n){16})([\s\S]*)$/$1$txt$2/;

            $txt = FormatReading( "MoonCompass", $h );
            $txt .= $html && $html eq "1" ? "<br/>\n" : "\n";
            $ret =~ s/^((?:[^\n]+\n){25})([\s\S]*)$/$1$txt$2/;

            if ( $html && $html eq "1" ) {
                $ret = "<html>" . $ret . "</html>";
                $ret =~ s/   /&nbsp;&nbsp;&nbsp;/g;
                $ret =~ s/  /&nbsp;&nbsp;/g;
            }
        }

        return $ret;
    }

    # get/schedule
    elsif ( $aref->[0] eq "schedule" ) {
        Compute( $hash, undef, $h );
        my @ret;

        my $FW_CSRF = (
            defined( $hash->{CL} )
              && defined( $hash->{CL}{SNAME} )
              && defined( $defs{ $hash->{CL}{SNAME} }{CSRFTOKEN} )
            ? '&fwcsrf=' . $defs{ $hash->{CL}{SNAME} }{CSRFTOKEN}
            : ''
        );

        my $header = '';
        my $footer = '';

        $h->{long} = 3 unless ( defined( $h->{long} ) );
        $h->{html} = $html if ($html);

        if ( $html && defined( $hash->{CL} ) && $hash->{CL}{TYPE} eq "FHEMWEB" )
        {
            $header = '<html>';
            $footer = '</html>';

            if ( !defined( $h->{navigation} ) || $h->{navigation} ne "0" ) {
                $header .=
                    '<div class="wide">'
                  . '<div class="detLink DayScheduleJump" style="float:right; text-align:right; white-space:nowrap;">'
                  .

                  (
                    defined( $h->{backbotton} )
                      && !exists( $FW_hiddenroom{detail} )
                    ? '<a href="?detail='
                      . $name
                      . '">back to <span style="font-style:italic;">'
                      . AttrVal(
                        $name,
                        'alias_' . uc($lang),
                        AttrVal(
                            $name,
                            'alias_' . lc($lang),
                            AttrVal( $name, 'alias', $name )
                        )
                      )
                      . '</span></a>&nbsp;&nbsp;&nbsp;&nbsp;'
                    : ''
                  )

                  . '<a href="?cmd=get '
                  . $name
                  . urlEncode(
                    ' schedule '
                      . sprintf( "%04d-%02d-%02d",
                        $Date{year}, $Date{month}, $Date{day} )
                      . ' -1 backbotton=1'
                  )
                  . $FW_CSRF
                  . '">&larr;&nbsp;Previous day</a>&nbsp;&nbsp;'
                  . (
                    defined( $h->{backbotton} )
                    ? '<a href="?cmd=get '
                      . $name
                      . urlEncode(' schedule backbotton=1')
                      . $FW_CSRF
                      . '">Today</a>&nbsp;&nbsp;'
                    : ''
                  )
                  . '<a href="?cmd=get '
                  . $name
                  . urlEncode(
                    ' schedule '
                      . sprintf( "%04d-%02d-%02d",
                        $Date{year}, $Date{month}, $Date{day} )
                      . ' +1 backbotton=1'
                  )
                  . $FW_CSRF
                  . '">Next day&nbsp;&rarr;</a>'
                  . '</div>'
                  . '</div>';
            }
        }

        my $blockOpen   = '';
        my $tTitleOpen  = '';
        my $tTitleClose = '';
        my $tOpen       = '';
        my $tCOpen      = '';
        my $tCClose     = '';
        my $tHOpen      = '';
        my $tHClose     = '';
        my $tBOpen      = '';
        my $tBClose     = '';
        my $tFOpen      = '';
        my $tFClose     = '';
        my $trOpen      = '';
        my $trOpenEven  = '';
        my $trOpenOdd   = '';
        my $thOpen      = '';
        my $thOpen2     = '';
        my $thOpen3     = '';
        my $tdOpen      = '';
        my $tdOpen2     = '';
        my $tdOpen3     = '';
        my $tdOpen4     = '';
        my $strongOpen  = '';
        my $strongClose = '';
        my $tdClose     = "\t\t\t";
        my $thClose     = "\t\t\t";
        my $trClose     = '';
        my $tClose      = '';
        my $blockClose  = '';
        my $colorRed    = '';
        my $colorGreen  = '';
        my $colorClose  = '';
        my $h3Open      = '';
        my $h3Close     = '';

        if ($html) {
            $blockOpen   = '<div class="makeTable wide internals">';
            $tTitleOpen  = '<span class="mkTitle">';
            $tTitleClose = '</span>';
            $tOpen =
'<table class="block wide internals wrapcolumns" style="width:568px; margin-top:10px;">';
            $tCOpen =
'<caption style="text-align: left; font-size: larger; white-space: nowrap;">';
            $tCClose    = '</caption>';
            $tHOpen     = '<thead>';
            $tHClose    = '</thead>';
            $tBOpen     = '<tbody>';
            $tBClose    = '</tbody>';
            $tFOpen     = '<tfoot style="font-size: smaller;">';
            $tFClose    = '</tfoot>';
            $trOpen     = '<tr class="column">';
            $trOpenEven = '<tr class="column even">';
            $trOpenOdd  = '<tr class="column odd">';
            $thOpen     = '<th style="text-align:left; vertical-align:top;">';
            $thOpen2 =
              '<th style="text-align: left; vertical-align:top;" colspan="2">';
            $thOpen3 =
              '<th style="text-align: left; vertical-align:top;" colspan="3">';
            $tdOpen      = '<td style="vertical-align:top;">';
            $tdOpen2     = '<td style="vertical-align:top;" colspan="2">';
            $tdOpen3     = '<td style="vertical-align:top;" colspan="3">';
            $tdOpen4     = '<td style="vertical-align:top;" colspan="4">';
            $strongOpen  = '<strong>';
            $strongClose = '</strong>';
            $tdClose     = '</td>';
            $thClose     = '</th>';
            $trClose     = '</tr>';
            $tClose      = '</table>';
            $blockClose  = '</div>';
            $colorRed    = '<span style="color:red">';
            $colorGreen  = '<span style="color:green">';
            $colorClose  = '</span>';
            $h3Open      = '<h3 style="margin-top:0;">';
            $h3Close     = '</h3>';
        }

        my $space = $html ? '&nbsp;' : ' ';
        my $lb    = $html ? '<br />' : "\n";

        my @schedsch =
          split(
            ',',
            (
                defined( $h->{"Schedule"} )
                ? $h->{"Schedule"}
                : AttrVal( $name, "Schedule", $attrs{Schedule} )
            )
          );
        unless ( defined( $h->{"Schedule"} )
            || AttrVal( $name, "Schedule", 0 ) )
        {
            shift @schedsch;
            shift @schedsch;
        }

        my $dschedule = "";
        my (
            $secY,  $minY,  $hourY, $dayY, $monthY,
            $yearY, $wdayY, $ydayY, $isdstY
        ) = localtime( $now - 86400. );
        my ( $sec, $min, $hour, $day, $month, $year, $wday, $yday, $isdst ) =
          localtime($now);
        my (
            $secT,  $minT,  $hourT, $dayT, $monthT,
            $yearT, $wdayT, $ydayT, $isdstT
        ) = localtime( $now + 86400. );
        $yearY  += 1900;
        $year   += 1900;
        $yearT  += 1900;
        $monthY += 1;
        $month  += 1;
        $monthT += 1;

        if (   $yearY == $Date{year}
            && $monthY == $Date{month}
            && $dayY == $Date{day} )
        {
            $dschedule = ucfirst( $tt->{yesterday} ) . ' ';
        }
        elsif ($year == $Date{year}
            && $month == $Date{month}
            && $day == $Date{day} )
        {
            $dschedule = ucfirst( $tt->{today} ) . ' ';
        }
        elsif ($yearT == $Date{year}
            && $monthT == $Date{month}
            && $dayT == $Date{day} )
        {
            $dschedule = ucfirst( $tt->{tomorrow} ) . ' ';
        }

        push @ret, $blockOpen;

        my $aliasname = AttrVal(
            $name,
            'alias_' . uc($lang),
            AttrVal(
                $name,
                'alias_' . lc($lang),
                AttrVal( $name, 'alias', undef )
            )
        );

        if (   defined( $h->{backlink} )
            && $html
            && ( $aliasname || !exists( $FW_hiddenroom{detail} ) ) )
        {
            $aliasname = $name unless ($aliasname);
            unless ( exists( $FW_hiddenroom{detail} ) ) {
                $aliasname =
                    '<a href="?detail='
                  . ( IsDevice( $h->{backlink} ) ? $h->{backlink} : $name )
                  . '">'
                  . $aliasname . '</a>';
            }
            push @ret, $aliasname;
        }

        push @ret,
            $h3Open
          . encode_utf8( $dschedule . $Schedule{DayDatetime} )
          . $h3Close;

        ######## Overview Begin

        push @ret, $tOpen;
        push @ret, $tCOpen . encode_utf8( $tt->{overview} ) . $tCClose;

        push @ret, $tBOpen;

        if (   grep( /^Daytime|DaySeasonalHr$/, @schedsch )
            && $year == $Date{year}
            && $month == $Date{month}
            && $day == $Date{day} )
        {
            push @ret, $trOpenOdd;
            push @ret, $thOpen . encode_utf8( $tt->{dayphase} ) . $thClose;
            push @ret,
              $tdOpen
              . encode_utf8(
                (
                    grep( /^Daytime$/, @schedsch )
                      && $Schedule{Daytime} ne '---' ? $Schedule{Daytime}
                    : FormatReading(
                        'DaySeasonalHr', { long => 1, language => $lang },
                        $lc_numeric
                    )
                )
                . ' ('
                  . chr(0x029D6)
                  . chr(0x202F)
                  . (
                    $Schedule{'.DaySeasonalHrNextT'} == 0. ? '00:00'
                    : FHEM::Astro::HHMM( $Schedule{'.DaySeasonalHrNextT'} )
                  )
                  . ')'
              ) . $tdClose;
            push @ret, $trClose;
        }

        if ( $Schedule{DayDesc} ne '---' ) {
            push @ret, $trOpenOdd;
            push @ret, $thOpen . encode_utf8( $tt->{description} ) . $thClose;

            my $desc = $Schedule{DayDesc};
            if ( $html && $desc =~ /\n/ ) {
                $desc =~ s/^(.+)/<li>$1/gm;
                $desc =~ s/\n/<\/li>/gm;
                $desc .= '</li>' unless ( $desc =~ /<\/li>$/ );
                $desc = '<ul>' . $desc . '</ul>';
            }

            push @ret, $tdOpen . encode_utf8($desc) . $tdClose;

            push @ret, $trClose;
        }

        push @ret,
            $trOpenOdd
          . $thOpen
          . encode_utf8( $tt->{daylight} )
          . $thClose
          . $tdOpen
          . encode_utf8(
                chr(0x1F305)
              . chr(0x00A0)
              . (
                $Astro{SunRise} ne '---' || $Astro{SunSet} ne '---'
                ? (
                    (
                        $Astro{SunRise} ne '---' ? $Astro{SunRise} : chr(0x221E)
                    )
                    . chr(0x2013)
                      . (
                        $Astro{SunSet} ne '---' ? $Astro{SunSet} : chr(0x221E)
                      )
                  )
                : '---'
              )
              . ' ('
              . $Astro{SunHrsVisible}
              . chr(0x202F) . 'h)'
          )
          . $tdClose
          . $trClose;

        push @ret,
            $trOpenOdd
          . $thOpen
          . encode_utf8( $tt->{daytype} )
          . $thClose
          . $tdOpen
          . encode_utf8(
            $Schedule{DayTypeSym} . chr(0x00A0) . $Schedule{DayType} )
          . $tdClose
          . $trClose;

        if ( grep( /^MoonRise|MoonSet|MoonPhaseS$/, @schedsch ) ) {
            push @ret,
                $trOpenOdd
              . $thOpen
              . encode_utf8( $astrott->{moon} )
              . $thClose
              . $tdOpen
              . encode_utf8(
                    $Schedule{MoonPhaseSym}
                  . chr(0x00A0)
                  . (
                    grep( /^MoonPhaseS$/, @schedsch )
                    ? $Astro{MoonPhaseS} . ' | '
                    : ''
                  )
                  . (
                    $Astro{MoonRise} ne '---' || $Astro{MoonSet} ne '---'
                    ? (
                        (
                              $Astro{MoonRise} ne '---'
                            ? $Astro{MoonRise}
                            : chr(0x267E)
                        )
                        . chr(0x2013)
                          . (
                              $Astro{MoonSet} ne '---'
                            ? $Astro{MoonSet}
                            : chr(0x267E)
                          )
                      )
                    : '---'
                  )
                  . ' ('
                  . $Astro{MoonHrsVisible}
                  . chr(0x202F) . 'h)'
              )
              . $tdClose
              . $trClose;
        }

        if ( grep( /^SunSign|MoonSign$/, @schedsch ) ) {
            push @ret,
                $trOpenOdd
              . $thOpen
              . encode_utf8( $astrott->{sign} )
              . $thClose
              . $tdOpen
              . encode_utf8(
                (
                    grep( /^SunSign$/, @schedsch )
                    ? (
                        grep( /^MoonSign$/, @schedsch )
                        ? $astrott->{sun} . ':' . chr(0x00A0)
                        : ''
                      )
                      . $Schedule{SunSignSym}
                      . ( grep( /^MoonSign$/, @schedsch ) ? '' : chr(0x00A0) )
                      . $Astro{SunSign}
                    : ''
                )
                . (
                    grep( /^SunSign$/, @schedsch )
                      && grep( /^MoonSign$/, @schedsch )
                    ? $space . $space . $space . $space
                    : ''
                  )
                  . (
                    grep( /^MoonSign$/, @schedsch )
                    ? (
                        grep( /^SunSign$/, @schedsch )
                        ? $astrott->{moon} . ':' . chr(0x00A0)
                        : ''
                      )
                      . $Schedule{MoonSignSym}
                      . ( grep( /^SunSign$/, @schedsch ) ? '' : chr(0x00A0) )
                      . $Astro{MoonSign}
                    : ''
                  )
              )
              . $tdClose
              . $trClose;
        }

        if ( defined( $Schedule{'.SeasonSocial'} ) ) {
            push @ret, $trOpenOdd;
            push @ret, $thOpen . encode_utf8( $tt->{season} ) . $thClose;

            push @ret, $tdOpen;
            my $l;
            my $i = 0;
            foreach my $e ( @{ $Schedule{'.SeasonSocial'} } ) {
                $l .= $lb if ($l);
                $l .=
                  encode_utf8( @{ $Schedule{'.SeasonSocialSym'} }[$i] . $e );
                $i++;
            }
            push @ret, $l . $tdClose;

            push @ret, $trClose;
        }

        if ( grep( /^ObsIsDST$/, @schedsch ) && $Astro{ObsIsDST} == 1. ) {
            push @ret,
                $trOpenOdd
              . $thOpen
              . encode_utf8( $astrott->{dst} )
              . $thClose
              . $tdOpen
              . encode_utf8(
                $Schedule{DayTypeSym} . chr(0x00A0) . $Schedule{DayType} )
              . $tdClose
              . $trClose;
        }

        push @ret,
            $trOpenOdd
          . $thOpen
          . encode_utf8( $tt->{seasonoftheyear} )
          . $thClose
          . $tdOpen
          . encode_utf8(
            (
                grep( /^SeasonPheno$/, @schedsch )
                  && defined( $Schedule{SeasonPheno} )
                ? $Schedule{SeasonPhenoSym}
                  . chr(0x00A0)
                  . $Schedule{SeasonPheno}
                : (
                    grep( /^SeasonMeteo$/, @schedsch )
                      && defined( $Schedule{SeasonMeteo} )
                    ? $Schedule{SeasonMeteoSym}
                      . chr(0x00A0)
                      . $Schedule{SeasonMeteo}
                    : $Schedule{ObsSeasonSym} . chr(0x00A0) . $Astro{ObsSeason}
                )
            )
            . (
                grep( /^ObsIsDST$/, @schedsch )
                  && $Astro{ObsIsDST} == 1.
                ? $space
                  . $space
                  . $space
                  . $space
                  . chr(0x1F552)
                  . chr(0x00A0)
                  . $astrott->{dst}
                : ''
            )
          )
          . $tdClose
          . $trClose;

        push @ret, $tBClose . $tClose;

        ######## Overview End

        if (
            (
                   !ref($h)
                || !defined( $h->{dailyschedule} )
                || $h->{dailyschedule} ne '0'
            )
            && defined( $Schedule{'.schedule'} )
          )
        {
            push @ret, $tOpen;
            push @ret, $tCOpen . encode_utf8( $tt->{dayschedule} ) . $tCClose;

            push @ret, $tHOpen . $trOpen;
            push @ret, $thOpen . encode_utf8( $astrott->{time} ) . $thClose;
            push @ret, $thOpen . encode_utf8( $tt->{event} ) . $thClose;
            push @ret, $trClose . $tHClose;

            push @ret, $tBOpen;

            my $linecount = 1;
            foreach
              my $t ( sort { $a <=> $b } keys %{ $Schedule{'.schedule'} } )
            {
                next if ( $t == 24. );
                my $l = $linecount % 2 == 0 ? $trOpenEven : $trOpenOdd;

                $l .= $tdOpen
                  . (
                    $t == 0.
                    ? '00:00:00'
                    : FHEM::Astro::HHMMSS($t)
                  ) . $tdClose;
                $l .= $tdOpen;

                foreach my $e ( @{ $Schedule{'.schedule'}{$t} } ) {
                    if ( $e =~ m/^(\S+)(?: (.+))?$/ ) {
                        if ( defined( $Astro{$1} ) ) {
                            $l .=
                              FHEM::Astro::FormatReading( $1, $h, $lc_numeric,
                                defined($2) ? $2 : '' );
                        }
                        elsif ( defined( $Schedule{$1} ) ) {
                            $l .= FormatReading( $1, $h, $lc_numeric,
                                defined($2) ? $2 : '' );
                        }
                        else {
                            $l .= encode_utf8($e);
                        }
                    }
                    $l .= $lb;
                }

                $l .= $tdClose;

                $l .= $trClose;
                push @ret, $l;
                $linecount++;
            }
            push @ret, $tBClose . $tClose;
        }

        # unless ( defined( $Schedule{'.SeasonSocial'} )
        #     || defined( $Schedule{'.scheduleAllday'} )
        #     || defined( $Schedule{'.scheduleDay'} )
        #     || defined( $Schedule{'.schedule'} ) )
        # {
        #     push @ret, $tOpen;
        #     push @ret, $tCOpen . encode_utf8( $tt->{dayschedule} ) . $tCClose;
        #
        #     push @ret, $tBOpen;
        #
        #     push @ret, $trOpen;
        #     push @ret,
        #         $tdOpen
        #       . $lb
        #       . encode_utf8( $tt->{noevents} )
        #       . $lb
        #       . $lb
        #       . $tdClose;
        #     push @ret, $trClose;
        #
        #     push @ret, $tBClose . $tClose;
        # }

        # if ( defined( $Schedule{'.scheduleTom'} ) ) {
        #
        #     push @ret, $trOpen;
        #     push @ret, $thOpen2 . encode_utf8( $tt->{teasernext} ) . $thClose;
        #     push @ret, $trClose;
        #
        #     my $linecount = 1;
        #     foreach
        #       my $t ( sort { $a <=> $b } keys %{ $Schedule{'.scheduleTom'} } )
        #     {
        #         my $l = $linecount % 2 == 0 ? $trOpenEven : $trOpenOdd;
        #
        #         $l .= $tdOpen
        #           . (
        #             $t == 0.
        #             ? '00:00:00'
        #             : FHEM::Astro::HHMMSS($t)
        #           ) . $tdClose;
        #         $l .= $tdOpen;
        #
        #         foreach my $e ( @{ $Schedule{'.scheduleTom'}{$t} } ) {
        #             if ( $e =~ m/^(\S+)(?: (.+))?$/ ) {
        #                 if ( defined( $Astro{$1} ) ) {
        #                     $l .=
        #                       FHEM::Astro::FormatReading( $1, $h, $lc_numeric,
        #                         defined($2) ? $2 : '' );
        #                 }
        #                 else {
        #                     $l .= FormatReading( $1, $h, $lc_numeric,
        #                         defined($2) ? $2 : '' );
        #                 }
        #             }
        #             $l .= $lb;
        #         }
        #
        #         $l .= $tdClose;
        #
        #         $l .= $trClose;
        #         push @ret, $l;
        #         $linecount++;
        #     }
        #
        #     if (   defined( $Schedule{'.SeasonSocial'} )
        #         || defined( $Schedule{'.schedule'} )
        #         || defined( $Schedule{'.scheduleDay'} )
        #         || defined( $Schedule{'.scheduleAllday'} ) )
        #     {
        #         push @ret, $tFClose;
        #     }
        #     else {
        #         push @ret, $tBClose;
        #     }
        # }

        push @ret, $blockClose;
        return $header . join( "\n", @ret ) . $footer;
    }

    # get/?
    else {
        return "$name with unknown argument $aref->[0], choose one of "
          . join( " ",
            map { defined( $gets{$_} ) ? "$_:$gets{$_}" : $_ }
            sort keys %gets );
    }
}

sub FormatReading($$;$$) {
    my ( $r, $h, $lc_numeric, $val ) = @_;
    my $ret;
    $val = $Schedule{$r} unless ( defined($val) );

    my $f = "%s";

    #-- number formatting
    $f = "%2.1f" if ( $r eq "MonthProgress" );
    $f = "%2.1f" if ( $r eq "YearProgress" );

    $ret = $val ne "" ? sprintf( $f, $val ) : "";
    $ret = UConv::decimal_mark( $ret, $lc_numeric )
      unless ( $h && ref($h) && defined( $h->{html} ) && $h->{html} eq "0" );

    $ret = ( $val == 1. ? $tt->{"leapyear"} : $tt->{"commonyear"} )
      if ( $r eq "YearIsLY" );
    $ret = (
          $val == 2.
        ? $tt->{"tomorrow"}
        : ( $val == 1. ? $tt->{"today"} : '---' )
    ) if ( $r =~ /^DayChange/ );

    if ( $h && ref($h) && ( !$h->{html} || $h->{html} ne "0" ) ) {

        #-- add unit if desired
        if (
            $h->{unit}
            || ( $h->{long}
                && ( !defined( $h->{unit} ) || $h->{unit} ne "0" ) )
          )
        {
            $ret .= chr(0x00A0) . "h" if ( $r eq "DaySeasonalHrLenDay" );
            $ret .= chr(0x00A0) . "h" if ( $r eq "DaySeasonalHrLenNight" );
            $ret .= chr(0x00A0) . "h" if ( $r eq "DaySeasonalHrsDay" );
            $ret .= chr(0x00A0) . "h" if ( $r eq "DaySeasonalHrsNight" );
            $ret .= chr(0x00A0) . "%" if ( $r eq "MonthProgress" );
            $ret .= chr(0x00A0) . "d" if ( $r eq "MonthRemainD" );
            $ret .= chr(0x00A0) . "%" if ( $r eq "YearProgress" );
            $ret .= chr(0x00A0) . "d" if ( $r eq "YearRemainD" );
        }

        #-- add text if desired
        if ( $h->{long} ) {
            my $sep = " ";
            $sep = ": " if ( $h->{long} > 2. );
            $sep = ""   if ( $ret eq "" );

            $ret = (
                (
                    (
                             $Schedule{"DaySeasonalHr"} < 0.
                          && $Schedule{"DaySeasonalHrsNight"} == 12.
                    )
                      || ( $Schedule{"DaySeasonalHr"} > 0.
                        && $Schedule{"DaySeasonalHrsDay"} == 12. )
                )
                ? $tt->{"temporalhour"}
                : $tt->{"seasonalhour"}
              )
              . $sep
              . $ret
              if ( $r eq "DaySeasonalHr" );
            $ret = $tt->{"az"} . $sep . $ret if ( $r eq "DaySeasonalHrLenDay" );
            $ret = $tt->{"dec"} . $sep . $ret
              if ( $r eq "DaySeasonalHrLenNight" );
            $ret = $tt->{"diameter"} . $sep . $ret
              if ( $r eq "DaySeasonalHrR" );
            $ret = $ret . $sep . $tt->{"toce"}
              if ( $r =~ /^DaySeasonalHrT/ );
            $ret = $ret . $sep . $tt->{"toobs"}
              if ( $r eq "DaySeasonalHrNextT" );
            $ret = $tt->{"hoursofvisibility"} . $sep . $ret
              if ( $r eq "DaySeasonalHrsDay" );
            $ret = $tt->{"latecl"} . $sep . $ret
              if ( $r eq "DaySeasonalHrsNight" );
            $ret = $tt->{"dayphase"} . $sep . $ret if ( $r eq "Daytime" );
            $ret = $tt->{"phase"} . $sep . $ret    if ( $r eq "DaytimeN" );
            $ret = $tt->{"phase"} . $sep . $ret    if ( $r eq "MonthProgress" );
            $ret = $tt->{"ra"} . $sep . $ret       if ( $r eq "MonthRemainD" );
            $ret = $tt->{"cardinaldirection"} . $sep . $ret
              if ( $r eq "MoonCompass" );
            $ret = $tt->{"cardinaldirection"} . $sep . $ret
              if ( $r eq "MoonCompassI" );
            $ret = $tt->{"cardinaldirection"} . $sep . $ret
              if ( $r eq "MoonCompassS" );
            $ret = $tt->{"transit"} . $sep . $ret if ( $r eq "ObsTimeR" );
            $ret = $tt->{"twilightnautic"} . $sep . $ret
              if ( $r eq "SchedLast" );
            $ret = $tt->{"twilightnautic"} . $sep . $ret
              if ( $r eq "SchedLastT" );
            $ret = $ret . $sep . $tt->{"altitude"} if ( $r eq "SchedNext" );
            $ret = $tt->{"date"} . $sep . $ret     if ( $r eq "SchedNextT" );
            $ret = $ret . $sep . $tt->{"dayofyear"}
              if ( $r eq "SchedRecent" );
            $ret = $tt->{"alt"} . $sep . $ret if ( $r eq "SchedUpcoming" );
            $ret = $tt->{"metseason"} . $sep . $ret  if ( $r eq "SeasonMeteo" );
            $ret = $tt->{"phenseason"} . $sep . $ret if ( $r eq "SeasonPheno" );
            $ret = $tt->{"cardinaldirection"} . $sep . $ret
              if ( $r eq "SunCompass" );
            $ret = $tt->{"cardinaldirection"} . $sep . $ret
              if ( $r eq "SunCompassI" );
            $ret = $tt->{"cardinaldirection"} . $sep . $ret
              if ( $r eq "SunCompassS" );
            $ret = $tt->{"week"} . $sep . $ret if ( $r eq "Weekofyear" );
            $ret = $tt->{"alt"} . $sep . $ret  if ( $r eq "YearProgress" );
            $ret = $tt->{"az"} . $sep . $ret   if ( $r eq "YearRemainD" );
        }
    }

    return encode_utf8($ret);
}

sub _LoadPackagesWrapper {

    # JSON preference order
    local $ENV{PERL_JSON_BACKEND} =
      'Cpanel::JSON::XS,JSON::XS,JSON::PP,JSON::backportPP'
      unless ( defined( $ENV{PERL_JSON_BACKEND} ) );

    # try to use JSON::MaybeXS wrapper
    #   for chance of better performance + open code
    eval {
        require JSON::MaybeXS;
        $json = JSON::MaybeXS->new;
        1;
    };
    if ($@) {
        $@ = undef;

        # try to use JSON wrapper
        #   for chance of better performance
        eval {
            require JSON;
            $json = JSON->new;
            1;
        };

        if ($@) {
            $@ = undef;

            # In rare cases, Cpanel::JSON::XS may
            #   be installed but JSON|JSON::MaybeXS not ...
            eval {
                require Cpanel::JSON::XS;
                $json = Cpanel::JSON::XS->new;
                1;
            };

            if ($@) {
                $@ = undef;

                # In rare cases, JSON::XS may
                #   be installed but JSON not ...
                eval {
                    require JSON::XS;
                    $json = JSON::XS->new;
                    1;
                };

                if ($@) {
                    $@ = undef;

                    # Fallback to built-in JSON which SHOULD
                    #   be available since 5.014 ...
                    eval {
                        require JSON::PP;
                        $json = JSON::PP->new;
                        1;
                    };

                    if ($@) {
                        $@ = undef;

                        # Last chance may be a backport
                        require JSON::backportPP;
                        $json = JSON::backportPP->new;
                    }
                }
            }
        }
    }

    $json->allow_nonref;
    $json->shrink;
    $json->utf8;
}

sub SetTime (;$$$$) {
    my ( $time, $tz, $lc_time, $dayOffset ) = @_;

    # readjust locale
    my $old_lctime = setlocale(LC_TIME);
    setlocale( LC_TIME, $lc_time ) if ($lc_time);
    use locale ':not_characters';

    # readjust timezone
    local $ENV{TZ} = $tz if ($tz);
    tzset();

    $time = gettimeofday() unless ( defined($time) );

    # as we can only hand over accuracy in sec to Astro,
    #  we'll calc everything based on full seconds
    $time = int($time);
    $dayOffset = 2 unless ( defined($dayOffset) );
    my $D = $dayOffset ? \%Date : {};

    my ( $sec, $min, $hour, $day, $month, $year, $wday, $yday, $isdst ) =
      localtime($time);
    $year += 1900;

    my $daybegin = timegm_modern( 0,  0,  0,  $day, $month, $year );
    my $daymid   = timegm_modern( 0,  0,  12, $day, $month, $year );
    my $dayend   = timegm_modern( 59, 59, 23, $day, $month, $year );
    my $isdstultimo = ( localtime($dayend) )[8];
    $month += 1;
    $D->{timestamp}   = $time;
    $D->{timeday}     = $hour + $min / 60. + $sec / 3600.;
    $D->{year}        = $year;
    $D->{month}       = $month;
    $D->{day}         = $day;
    $D->{hour}        = $hour;
    $D->{min}         = $min;
    $D->{sec}         = $sec;
    $D->{isdst}       = $isdst;
    $D->{isdstultimo} = $isdstultimo;

    # broken on windows
    #$D->{zonedelta} = (strftime "%z", localtime)/100;
    $D->{zonedelta} = FHEM::Astro::_tzoffset($time) / 100;

    # half broken in windows
    $D->{dayofyear} = 1 * strftime( "%j", localtime($time) );

    $D->{wdayl}    = strftime( "%A", localtime($time) );
    $D->{wdays}    = strftime( "%a", localtime($time) );
    $D->{monthl}   = strftime( "%B", localtime($time) );
    $D->{months}   = strftime( "%b", localtime($time) );
    $D->{datetime} = strftime( "%c", localtime($time) );
    $D->{week} = 1 * strftime( "%V", localtime($time) );
    $D->{wday} = 1 * strftime( "%w", localtime($time) );
    $D->{time} = strftime( "%X", localtime($time) );
    $D->{date} = strftime( "%x", localtime($time) );
    $D->{tz}   = strftime( "%Z", localtime($time) );

    $D->{weekofyear}   = 1 * strftime( "%V", localtime($time) );
    $D->{isly}         = UConv::IsLeapYear($year);
    $D->{yearremdays}  = 365. + $D->{isly} - $D->{dayofyear};
    $D->{yearprogress} = $D->{dayofyear} / ( 365. + $D->{isly} );
    $D->{monthremdays} =
      UConv::DaysOfMonth( $D->{year}, $D->{month} ) - $D->{day};
    $D->{monthprogress} =
      $D->{day} / UConv::DaysOfMonth( $D->{year}, $D->{month} );

    delete $D->{tz} if ( !$D->{tz} || $D->{tz} eq "" || $D->{tz} eq " " );

    # add info from X days before+after
    if ($dayOffset) {
        my $i = $dayOffset * -1.;
        while ( $i < $dayOffset + 1. ) {
            if ( $i != 0. ) {
                $D->{$i} = SetTime( $time + ( 86400. * $i ), $tz, $lc_time, 0 );
                $D->{$i}{'000000'} =
                  SetTime( $daybegin + ( 86400. * $i ), $tz, $lc_time, 0 );
                $D->{$i}{'120000'} =
                  SetTime( $daymid + ( 86400. * $i ), $tz, $lc_time, 0 );
                $D->{$i}{'235959'} =
                  SetTime( $dayend + ( 86400. * $i ), $tz, $lc_time, 0 );
            }
            $i++;
        }
    }
    else {
        return $D;
    }

    delete local $ENV{TZ};
    tzset();

    setlocale( LC_TIME, "" );
    setlocale( LC_TIME, $old_lctime );
    no locale;

    return (undef);
}

sub Compute($;$$) {
    return undef if ( !$init_done );
    my ( $hash, $dayOffset, $params ) = @_;
    undef %Astro    unless ($dayOffset);
    undef %Schedule unless ($dayOffset);
    my $name = $hash->{NAME};
    my $AstroDev = AttrVal( $name, "AstroDevice", "" );

    # fill %Date if it is still empty after restart
    SetTime() if ( scalar keys %Date == 0 );

    my $dayOffsetSeg;
    if ( $dayOffset && $dayOffset =~ /^(-?(?:\d+))(?:-(\d{6}))?$/ ) {
        $dayOffset    = $1;
        $dayOffsetSeg = $2;
    }

    my $D =
        $dayOffsetSeg
      ? $Date{$dayOffset}{$dayOffsetSeg}
      : ( $dayOffset ? $Date{$dayOffset} : \%Date );
    my $S = $dayOffset ? {} : \%Schedule;

    my $lang = uc(
        AttrVal(
            $name,
            "language",
            AttrVal(
                $AstroDev, "language",
                AttrVal( "global", "language", "EN" )
            )
        )
    );
    my $lc_numeric = AttrVal(
        $name,
        "lc_numeric",
        AttrVal(
            $AstroDev,
            "lc_numeric",
            AttrVal( "global", "lc_numeric",
                ( $lang ? lc($lang) . "_" . uc($lang) . ".UTF-8" : undef ) )

        )
    );
    $lc_numeric = $params->{"lc_numeric"}
      if ( defined( $params->{"lc_numeric"} ) );
    my $lc_time = AttrVal(
        $name,
        "lc_time",
        AttrVal(
            $AstroDev,
            "lc_time",
            AttrVal( "global", "lc_time",
                ( $lang ? lc($lang) . "_" . uc($lang) . ".UTF-8" : undef ) )

        )
    );
    $lc_time = $params->{"lc_time"}
      if ( defined( $params->{"lc_time"} ) );

    # readjust language
    if ( defined( $params->{"language"} )
        && exists( $transtable{ uc( $params->{"language"} ) } ) )
    {
        $lang = uc( $params->{"language"} );
        $tt   = $transtable{$lang};
    }
    elsif ( exists( $transtable{ uc($lang) } ) ) {
        $tt = $transtable{ uc($lang) };
    }
    else {
        $tt = $transtable{EN};
    }
    if ( defined( $params->{"language"} )
        && exists( $FHEM::Astro::transtable{ uc( $params->{"language"} ) } ) )
    {
        $astrott = $FHEM::Astro::transtable{ uc( $params->{"language"} ) };
    }
    elsif ( exists( $FHEM::Astro::transtable{ uc($lang) } ) ) {
        $astrott = $FHEM::Astro::transtable{ uc($lang) };
    }
    else {
        $astrott = $FHEM::Astro::transtable{EN};
    }

    # readjust timezone
    my $tz = AttrVal(
        $name,
        "timezone",
        AttrVal(
            $AstroDev, "timezone", AttrVal( "global", "timezone", undef )
        )
    );
    $tz = $params->{"timezone"}
      if ( defined( $params->{"timezone"} ) );
    local $ENV{TZ} = $tz if ($tz);
    tzset();

    # load schemata
    my @schedsch =
      split(
        ',',
        (
            defined( $params->{"Schedule"} )
            ? $params->{"Schedule"}
            : AttrVal( $name, "Schedule", $attrs{Schedule} )
        )
      );
    unless ( defined( $params->{"Schedule"} )
        || AttrVal( $name, "Schedule", 0 ) )
    {
        shift @schedsch;
        shift @schedsch;
    }
    my @infoDays =
      split(
        ',',
        (
            defined( $params->{"InformativeDays"} )
            ? $params->{"InformativeDays"}
            : AttrVal( $name, "InformativeDays", $attrs{InformativeDays} )
        )
      );
    unless ( defined( $params->{"InformativeDays"} )
        || AttrVal( $name, "InformativeDays", 0 ) )
    {
        shift @infoDays;
        shift @infoDays;
    }
    my @socialSeasons =
      split(
        ',',
        (
            defined( $params->{"SocialSeasons"} )
            ? $params->{"SocialSeasons"}
            : AttrVal( $name, "SocialSeasons", $attrs{SocialSeasons} )
        )
      );
    unless ( defined( $params->{"SocialSeasons"} )
        || AttrVal( $name, "SocialSeasons", 0 ) )
    {
        shift @socialSeasons;
        shift @socialSeasons;
    }

    # prepare Astro attributes
    if ( IsDevice( $AstroDev, "Astro" ) ) {
        foreach (
            qw(
            altitude
            horizon
            language
            latitude
            lc_numeric
            longitude
            timezone
            )
          )
        {
            $params->{$_} = $attr{$name}{$_}
              if ( defined( $attr{$name} )
                && defined( $attr{$name}{$_} )
                && $attr{$name}{$_} ne ""
                && !defined( $params->{$_} ) );
        }
    }

    # load Astro data
    my $A;
    if ($dayOffset) {
        $A = $json->decode(
            Astro_Get(
                ( IsDevice( $AstroDev, "Astro" ) ? $defs{$AstroDev} : $hash ),
                [
                    IsDevice( $AstroDev, "Astro" ) ? "Astro" : "DaySchedule",
                    "json",
                    sprintf(
                        "%04d-%02d-%02d %02d:%02d:%02d",
                        $D->{year}, $D->{month}, $D->{day},
                        $D->{hour}, $D->{min},   $D->{sec}
                    )
                ],
                $params
            )
        );
    }
    else {
        %Astro = %{
            $json->decode(
                Astro_Get(
                    (
                        IsDevice( $AstroDev, "Astro" ) ? $defs{$AstroDev}
                        : $hash
                    ),
                    [
                        IsDevice( $AstroDev, "Astro" ) ? "Astro"
                        : "DaySchedule",
                        "json",
                        sprintf(
                            "%04d-%02d-%02d %02d:%02d:%02d",
                            $D->{year}, $D->{month}, $D->{day},
                            $D->{hour}, $D->{min},   $D->{sec}
                        )
                    ],
                    $params
                )
            )
        };
        $A = \%Astro;
    }

    # custom date for early spring
    my $earlyspring = '02-22';
    if ( defined( $params->{"Earlyspring"} ) ) {
        $earlyspring = $params->{"Earlyspring"};
    }
    elsif (defined( $attr{$name} )
        && defined( $attr{$name}{"Earlyspring"} ) )
    {
        $earlyspring = $attr{$name}{"Earlyspring"};
    }
    else {
        Log3 $name, 5,
          "$name: No Earlyspring attribute defined, using date $earlyspring"
          if ( !$dayOffset );
    }

    # custom date for early fall
    my $earlyfall = '08-20';
    if ( defined( $params->{"Earlyfall"} ) ) {
        $earlyfall = $params->{"Earlyfall"};
    }
    elsif ( defined( $attr{$name} ) && defined( $attr{$name}{"Earlyfall"} ) ) {
        $earlyfall = $attr{$name}{"Earlyfall"};
    }
    else {
        Log3 $name, 5,
          "$name: No Earlyfall attribute defined, using date $earlyfall"
          if ( !$dayOffset );
    }

    # custom number for seasonal hours
    my $daypartsIsRoman = 0;
    my $dayparts        = 12;
    my $nightparts      = 12;
    if ( defined( $params->{"SeasonalHrs"} )
        && $params->{"SeasonalHrs"} =~ m/^(([^:]+)(?::(.+))?)$/ )
    {
        $daypartsIsRoman = 1
          if ( $1 eq '4' );    # special handling of '^4$' as roman format
        $dayparts = $daypartsIsRoman ? 12. : $2;
        $nightparts = $3 ? $3 : $2;
    }
    elsif (defined( $attr{$name} )
        && defined( $attr{$name}{"SeasonalHrs"} )
        && $attr{$name}{"SeasonalHrs"} =~ m/^(([^:]+)(?::(.+))?)$/ )
    {
        $daypartsIsRoman = 1
          if ( $1 eq '4' );    # special handling of '^4$' as roman format
        $dayparts = $daypartsIsRoman ? 12. : $2;
        $nightparts = $3 ? $3 : $2;
    }
    else {
        Log3 $name, 5,
"$name: No SeasonalHrs attribute defined, using $dayparts seasonal hours for day and night"
          if ( !$dayOffset );
    }

    # Add predefined informative days to schedule
    unless ( grep ( /^none$/, @infoDays ) ) {
        if (   grep ( /^ValentinesDay$/, @infoDays )
            && $D->{month} == 2.
            && $D->{day} == 14. )
        {
            AddToSchedule( $S, '*', $tt->{valentinesday} );
        }
        if (   grep ( /^WalpurgisNight$/, @infoDays )
            && $D->{month} == 4.
            && $D->{day} == 30. )
        {
            AddToSchedule( $S, '*', $tt->{walpurgisnight} );
        }
        if ( grep ( /^AshWednesday$/, @infoDays )
            && IsSpecificDay( '2 -46', $D->{day}, $D->{month}, $D->{year} ) )
        {
            AddToSchedule( $S, '*', $tt->{ashwednesday} );
        }
        if ( grep ( /^MothersDay$/, @infoDays )
            && IsSpecificDay( '3 2 Sun 05', $D->{day}, $D->{month}, $D->{year} )
          )
        {
            AddToSchedule( $S, '*', $tt->{mothersday} );
        }
        if ( grep ( /^FathersDay$/, @infoDays )
            && IsSpecificDay( '2 39', $D->{day}, $D->{month}, $D->{year} ) )
        {
            AddToSchedule( $S, '*', $tt->{fathersday} );
        }
        if ( grep ( /^HarvestFestival$/, @infoDays )
            && IsSpecificDay( '3 1 Sun 10', $D->{day}, $D->{month}, $D->{year} )
          )
        {
            AddToSchedule( $S, '*', $tt->{harvestfestival} );
        }
        if (   grep ( /^MartinSingEv$/, @infoDays )
            && $D->{month} == 11.
            && $D->{day} == 10. )
        {
            AddToSchedule( $S, '*', $tt->{martinising} );
        }
        if (   grep ( /^Martinmas$/, @infoDays )
            && $D->{month} == 11.
            && $D->{day} == 11. )
        {
            AddToSchedule( $S, '*', $tt->{martinmas} );
        }
        if (
            grep ( /^RemembranceDay$/, @infoDays )
            && IsSpecificDay(
                '5 -6 Sun 12 25',
                $D->{day}, $D->{month}, $D->{year}
            )
          )
        {
            AddToSchedule( $S, '*', $tt->{remembranceday} );
        }
        if (
            grep ( /^LastSundayBeforeAdvent$/, @infoDays )
            && IsSpecificDay(
                '5 -5 Sun 12 25',
                $D->{day}, $D->{month}, $D->{year}
            )
          )
        {
            AddToSchedule( $S, '*', $tt->{lastsundaybeforeadvent} );
        }
        if (   grep ( /^StNicholasDay$/, @infoDays )
            && $D->{month} == 12.
            && $D->{day} == 6. )
        {
            AddToSchedule( $S, '*', $tt->{stnicholasday} );
        }
        if (   grep ( /^BiblicalMagi$/, @infoDays )
            && $D->{month} == 1.
            && $D->{day} == 6. )
        {
            AddToSchedule( $S, '*', $tt->{biblicalmagi} );
        }
        if (   grep ( /^InternationalWomensDay$/, @infoDays )
            && $D->{month} == 3.
            && $D->{day} == 8. )
        {
            AddToSchedule( $S, '*', $tt->{internationalwomensday} );
        }
        if (   grep ( /^StPatricksDay$/, @infoDays )
            && $D->{month} == 3.
            && $D->{day} == 17. )
        {
            AddToSchedule( $S, '*', $tt->{stpatricksday} );
        }
        if (   grep ( /^StPatricksDay$/, @infoDays )
            && $D->{month} == 3.
            && $D->{day} == 17. )
        {
            AddToSchedule( $S, '*', $tt->{stpatricksday} );
        }
        if (   grep ( /^LaborDay$/, @infoDays )
            && $D->{month} == 5.
            && $D->{day} == 1. )
        {
            AddToSchedule( $S, '*', $tt->{laborday} );
        }
        if (   grep ( /^LiberationDay$/, @infoDays )
            && $D->{month} == 5.
            && $D->{day} == 8. )
        {
            AddToSchedule( $S, '*', $tt->{liberationday} );
        }
        if ( grep ( /^Ascension$/, @infoDays )
            && IsSpecificDay( '2 39', $D->{day}, $D->{month}, $D->{year} ) )
        {
            AddToSchedule( $S, '*', $tt->{ascension} );
        }
        if ( grep ( /^Pentecost$/, @infoDays ) ) {
            AddToSchedule( $S, '*', $tt->{pentecostsun} )
              if (
                IsSpecificDay( '2 49', $D->{day}, $D->{month}, $D->{year} ) );
            AddToSchedule( $S, '*', $tt->{pentecostmon} )
              if (
                IsSpecificDay( '2 50', $D->{day}, $D->{month}, $D->{year} ) );
        }
        if ( grep ( /^CorpusChristi$/, @infoDays )
            && IsSpecificDay( '2 60', $D->{day}, $D->{month}, $D->{year} ) )
        {
            AddToSchedule( $S, '*', $tt->{corpuschristi} );
        }
        if (   grep ( /^AssumptionDay$/, @infoDays )
            && $D->{month} == 8.
            && $D->{day} == 15. )
        {
            AddToSchedule( $S, '*', $tt->{assumptionday} );
        }
        if (   grep ( /^WorldChildrensDay$/, @infoDays )
            && $D->{month} == 9.
            && $D->{day} == 20. )
        {
            AddToSchedule( $S, '*', $tt->{worldchildrensday} );
        }
        if (   grep ( /^GermanUnificationDay$/, @infoDays )
            && $D->{month} == 10.
            && $D->{day} == 3. )
        {
            AddToSchedule( $S, '*', $tt->{germanunificationday} );
        }
        if (   grep ( /^ReformationDay$/, @infoDays )
            && $D->{month} == 10.
            && $D->{day} == 31. )
        {
            AddToSchedule( $S, '*', $tt->{reformationday} );
        }
        if (   grep ( /^AllSaintsDay$/, @infoDays )
            && $D->{month} == 11.
            && $D->{day} == 1. )
        {
            AddToSchedule( $S, '*', $tt->{allsaintsday} );
        }
        if (   grep ( /^AllSoulsDay$/, @infoDays )
            && $D->{month} == 11.
            && $D->{day} == 2. )
        {
            AddToSchedule( $S, '*', $tt->{allsoulsday} );
        }
        if (
            grep ( /^DayOfPrayerandRepentance$/, @infoDays )
            && IsSpecificDay(
                '5 -1 Wed 11 23',
                $D->{day}, $D->{month}, $D->{year}
            )
          )
        {
            AddToSchedule( $S, '*', $tt->{dayofprayerandrepentance} );
        }
    }

    # social seasons
    $S->{SeasonSocial}    = '---';
    $S->{SeasonSocialSym} = chr(0x27B0);
    unless ( grep ( /^none$/, @socialSeasons ) ) {
        foreach my $season (@socialSeasons) {
            my $r = $season;

            # alias names
            $r = 'Carnival'
              if ( $season eq 'CarnivalLong'
                || $season eq 'Fasching'
                || $season eq 'FaschingLong' );
            $r = 'Easter'
              if ( $season eq 'EasterTraditional'
                && !grep ( /^Easter$/, @socialSeasons ) );
            $r = 'Advent'
              if ( $season eq 'AdventEarly'
                && !grep ( /^Advent$/, @socialSeasons ) );
            $r = 'Christmas'
              if ( $season eq 'ChristmasLong'
                && !grep ( /^Christmas$/, @socialSeasons ) );

            $S->{ 'SeasonSocial' . $r } = 0
              unless ( defined( $S->{ 'SeasonSocial' . $r } ) );
            no strict "refs";
            my $ret =
              &{ 'IsSeason' . $season }( $D->{day}, $D->{month}, $D->{year} );
            use strict "refs";
            if ( $ret =~ /^([^0][^:]+)(?:: (.+))?$/ ) {
                $S->{ 'SeasonSocial' . $r } = 1;
                unless ( defined( $S->{'.SeasonSocial'} )
                    && grep( /^$1$/, @{ $S->{'.SeasonSocial'} } ) )
                {
                    push @{ $S->{'.SeasonSocial'} }, $1;
                    push @{ $S->{'.SeasonSocialSym'} },
                      $seasonssocialicon{$season};
                }
                AddToSchedule( $S, '*', $2 ) if ( defined($2) );
            }
        }
        if ( defined( $S->{'.SeasonSocial'} )
            && int( @{ $S->{'.SeasonSocial'} } ) > 0. )
        {
            $S->{SeasonSocial}    = join( ', ', @{ $S->{'.SeasonSocial'} } );
            $S->{SeasonSocialSym} = join( '',   @{ $S->{'.SeasonSocialSym'} } );
        }
    }

    $S->{DayTypeN} = 0;

    my $date =
      sprintf( '%d-%02d-%02d', $D->{year}, $D->{month}, $D->{day} );
    my $dateISO =
      sprintf( '%02d.%02d.%04d', $D->{day}, $D->{month}, $D->{year} );

    # add VacationDevices to schedule
    my $vacationDevs = AttrVal( $name, "VacationDevices", "" );
    foreach my $dev ( split( ',', $vacationDevs ) ) {
        if ( IsDevice( $dev, "holiday" ) ) {
            my $event = ::holiday_refresh( $dev, $date );
            if ( $event ne "none" ) {
                $S->{DayTypeN} = 1;
                foreach my $e ( split( ',', $event ) ) {
                    AddToSchedule( $S, '*', decode_utf8($e) );
                }
            }
        }
        elsif ( IsDevice( $dev, "Calendar" ) ) {
            my $date =
              sprintf( '%02d.%02d.%04d', $D->{day}, $D->{month}, $D->{year} );
            my $list = Calendar_Get( $defs{$dev}, "get", "events",
                "format:text filter:mode=~'alarm|start|upcoming'" );
            if ($list) {
                chomp($list);
                my @events = split( '\n', $list );
                foreach my $event (@events) {
                    chomp($event);
                    my $edate = substr( $event, 0, 10 );
                    $event = substr( $event, 17 );
                    if ( $edate eq $dateISO ) {
                        $S->{DayTypeN} = 1;
                        foreach my $e ( split( ',', $event ) ) {
                            AddToSchedule( $S, '*', decode_utf8($e) );
                        }
                    }
                }
            }
        }
    }

    my $workdayDevs = AttrVal( $name, "WorkdayDevices", "" );
    my $weekendDevs = AttrVal( $name, "WeekendDevices", "" );
    if ( $workdayDevs eq '' && $weekendDevs eq '' ) {
        $S->{DayTypeN} = 2 if ( IsWe($date) );
    }

    # add HolidayDevices to schedule
    my $holidayDevs = AttrVal( $name, "HolidayDevices", "" );
    foreach my $dev ( split( ',', $holidayDevs ) ) {
        if ( IsDevice( $dev, "holiday" ) ) {
            my $event = ::holiday_refresh( $dev, $date );
            if ( $event ne "none" ) {
                $S->{DayTypeN} = 3;
                foreach my $e ( split( ',', $event ) ) {
                    AddToSchedule( $S, '*', decode_utf8($e) );
                }
            }
        }
        elsif ( IsDevice( $dev, "Calendar" ) ) {
            my $list = Calendar_Get( $defs{$dev}, "get", "events",
                "format:text filter:mode=~'alarm|start|upcoming'" );
            if ($list) {
                chomp($list);
                my @events = split( '\n', $list );
                foreach my $event (@events) {
                    chomp($event);
                    my $edate = substr( $event, 0, 10 );
                    $event = substr( $event, 17 );
                    if ( $edate eq $dateISO ) {
                        $S->{DayTypeN} = 3;
                        foreach my $e ( split( ',', $event ) ) {
                            AddToSchedule( $S, '*', decode_utf8($e) );
                        }
                    }
                }
            }
        }
    }

    # add WorkdayDevices to schedule:
    #  handle every entry as being a working day
    foreach my $dev ( split( ',', $workdayDevs ) ) {
        if ( IsDevice( $dev, "holiday" ) ) {
            my $event = ::holiday_refresh( $dev, $date );
            if ( $event eq "none" ) {
                $S->{DayTypeN} = 2;
            }
            else {
                foreach my $e ( split( ',', $event ) ) {
                    AddToSchedule( $S, '*', decode_utf8($e) );
                }
            }
        }
        elsif ( IsDevice( $dev, "Calendar" ) ) {
            my $date =
              sprintf( '%02d.%02d.%04d', $D->{day}, $D->{month}, $D->{year} );
            my $list = Calendar_Get( $defs{$dev}, "get", "events",
                "format:text filter:mode=~'alarm|start|upcoming'" );
            if ($list) {
                chomp($list);
                my @events = split( '\n', $list );
                my $found = 0;
                foreach my $event (@events) {
                    chomp($event);
                    my $edate = substr( $event, 0, 10 );
                    $event = substr( $event, 17 );
                    if ( $edate eq $dateISO ) {
                        $found = 1;
                        foreach my $e ( split( ',', $event ) ) {
                            AddToSchedule( $S, '*', decode_utf8($e) );
                        }
                    }
                }
                $S->{DayTypeN} = 2 unless ($found);
            }
        }
    }

    # add WeekendDevices to schedule:
    #  handle every entry as being a weekend day
    foreach my $dev ( split( ',', $weekendDevs ) ) {
        if ( IsDevice( $dev, "holiday" ) ) {
            my $event = ::holiday_refresh( $dev, $date );
            if ( $event ne "none" ) {
                $S->{DayTypeN} = 2;
            }
        }
        elsif ( IsDevice( $dev, "Calendar" ) ) {
            my $date =
              sprintf( '%02d.%02d.%04d', $D->{day}, $D->{month}, $D->{year} );
            my $list = Calendar_Get( $defs{$dev}, "get", "events",
                "format:text filter:mode=~'alarm|start|upcoming'" );
            if ($list) {
                chomp($list);
                my @events = split( '\n', $list );
                foreach my $event (@events) {
                    chomp($event);
                    my $edate = substr( $event, 0, 10 );
                    $event = substr( $event, 17 );
                    if ( $edate eq $dateISO ) {
                        $S->{DayTypeN} = 2;
                    }
                }
            }
        }
    }

    $S->{DayType}    = $tt->{ $daytypes[ $S->{DayTypeN} ][0] }[0];
    $S->{DayTypeS}   = $tt->{ $daytypes[ $S->{DayTypeN} ][0] }[1];
    $S->{DayTypeSym} = $daytypes[ $S->{DayTypeN} ][1];

    # add InformativeDevices to schedule
    my $informativeDevs = AttrVal( $name, "InformativeDevices", "" );
    foreach my $dev ( split( ',', $informativeDevs ) ) {
        if ( IsDevice( $dev, "holiday" ) ) {
            my $event = ::holiday_refresh( $dev, $date );
            if ( $event ne "none" ) {
                foreach my $e ( split( ',', $event ) ) {
                    AddToSchedule( $S, '*', decode_utf8($e) );
                }
            }
        }
        elsif ( IsDevice( $dev, "Calendar" ) ) {
            my $list = Calendar_Get( $defs{$dev}, "get", "events",
                "format:text filter:mode=~'alarm|start|upcoming'" );
            if ($list) {
                chomp($list);
                my @events = split( '\n', $list );
                foreach my $event (@events) {
                    chomp($event);
                    my $edate = substr( $event, 0, 10 );
                    $event = substr( $event, 17 );
                    if ( $edate eq $dateISO ) {
                        foreach my $e ( split( ',', $event ) ) {
                            AddToSchedule( $S, '*', decode_utf8($e) );
                        }
                    }
                }
            }
        }
    }

    # add info from 2 days after but only +1 day will be useful after all
    if ( !defined($dayOffset) ) {

        # today+2, has no tomorrow or yesterday
        ( $A->{2}, $S->{2} ) = Compute( $hash, 2, $params );
        ( $A->{2}{'000000'}, $S->{2}{'000000'} ) =
          Compute( $hash, '2-000000', $params );
        ( $A->{2}{'120000'}, $S->{2}{'120000'} ) =
          Compute( $hash, '2-120000', $params );
        ( $A->{2}{'235959'}, $S->{2}{'235959'} ) =
          Compute( $hash, '2-235959', $params );

        # today+1, only has tomorrow and incomplete yesterday
        ( $A->{1}, $S->{1} ) = Compute( $hash, 1, $params );
        ( $A->{1}{'000000'}, $S->{1}{'000000'} ) =
          Compute( $hash, '1-000000', $params );
        ( $A->{1}{'120000'}, $S->{1}{'120000'} ) =
          Compute( $hash, '1-120000', $params );
        ( $A->{1}{'235959'}, $S->{1}{'235959'} ) =
          Compute( $hash, '1-235959', $params );
    }

    # reference for tomorrow
    my $At;
    my $St;
    if (   !defined($dayOffset)
        || $dayOffset == -1.
        || $dayOffset == 0.
        || $dayOffset == 1. )
    {
        my $t = ( !defined($dayOffset) ? 0. : $dayOffset ) + 1.;
        $At = \%Astro unless ($t);
        $At = $Astro{$t} if ( $t && defined( $Astro{$t} ) );
        $St = \%Schedule unless ($t);
        $St = $Schedule{$t} if ( $t && defined( $Schedule{$t} ) );
    }
    if ( $A->{SunAlt} >= 0. ) {
        $S->{SunCompassI} =
          UConv::direction2compasspoint( $A->{SunAz}, 0, $lang );
        $S->{SunCompassS} =
          UConv::direction2compasspoint( $A->{SunAz}, 1, $lang );
        $S->{SunCompass} =
          UConv::direction2compasspoint( $A->{SunAz}, 2, $lang );
        $S->{SunCompassSym} =
          UConv::direction2compasspoint( $A->{SunAz}, 3, $lang );
    }
    else {
        $S->{SunCompassI} = '---';
        $S->{SunCompassS} = '---';
        $S->{SunCompass}  = '---';
    }
    if ( $A->{MoonAlt} >= 0. ) {
        $S->{MoonCompassI} =
          UConv::direction2compasspoint( $A->{MoonAz}, 0, $lang );
        $S->{MoonCompassS} =
          UConv::direction2compasspoint( $A->{MoonAz}, 1, $lang );
        $S->{MoonCompass} =
          UConv::direction2compasspoint( $A->{MoonAz}, 2, $lang );
        $S->{MoonCompassSym} =
          UConv::direction2compasspoint( $A->{MoonAz}, 3, $lang );
    }
    else {
        $S->{MoonCompassI} = '---';
        $S->{MoonCompassS} = '---';
        $S->{MoonCompass}  = '---';
    }
    $S->{ObsTimeR} =
      UConv::arabic2roman( $D->{hour} <= 12. ? $D->{hour} : $D->{hour} - 12. )
      . (
        $D->{min} == 0.
        ? ( $D->{sec} == 0 ? "" : ":" )
        : ":" . UConv::arabic2roman( $D->{min} )
      ) . ( $D->{sec} == 0. ? "" : ":" . UConv::arabic2roman( $D->{sec} ) );

    my $datetime = $D->{datetime};
    $datetime =~ s/\d{2}:\d{2}:\d{2} //g;
    my $wdays = $D->{wdays};
    $datetime =~ s/$wdays/$wdays,/g;
    my $datetimel = $datetime;
    my $wdayl     = $D->{wdayl};
    $datetimel =~ s/$wdays/$wdayl/g;
    my $months = $D->{months};
    my $monthl = $D->{monthl};
    $datetimel =~ s/$months/$monthl/g;

    $S->{DayDatetime}      = $datetimel;
    $S->{DayDatetimeS}     = $datetime;
    $S->{DayWeekday}       = $D->{wdayl};
    $S->{DayWeekdayS}      = $D->{wdays};
    $S->{DayWeekdayN}      = $D->{wday};
    $S->{Weekofyear}       = $D->{weekofyear};
    $S->{".isdstultimo"}   = $D->{isdstultimo};
    $S->{YearIsLY}         = $D->{isly};
    $S->{YearRemainD}      = $D->{yearremdays};
    $S->{Month}            = $D->{monthl};
    $S->{MonthS}           = $D->{months};
    $S->{WeekdayN}         = $D->{wday};
    $S->{MonthRemainD}     = $D->{monthremdays};
    $S->{".YearProgress"}  = $D->{yearprogress};
    $S->{".MonthProgress"} = $D->{monthprogress};
    $S->{YearProgress} =
      FHEM::Astro::_round( $S->{".YearProgress"} * 100, 0 );
    $S->{MonthProgress} =
      FHEM::Astro::_round( $S->{".MonthProgress"} * 100, 0 );

    AddToSchedule( $S, $A->{".SunTransit"}, "SunTransit" )
      if ( grep ( /^SunTransit$/, @schedsch ) );
    AddToSchedule( $S, $A->{".SunRise"}, "SunRise" )
      if ( grep ( /^SunRise$/, @schedsch ) );
    AddToSchedule( $S, $A->{".SunSet"}, "SunSet" )
      if ( grep ( /^SunSet$/, @schedsch ) );
    AddToSchedule( $S, $A->{".CivilTwilightMorning"}, "CivilTwilightMorning" )
      if ( grep ( /^CivilTwilightMorning$/, @schedsch ) );
    AddToSchedule( $S, $A->{".CivilTwilightEvening"}, "CivilTwilightEvening" )
      if ( grep ( /^CivilTwilightEvening$/, @schedsch ) );
    AddToSchedule( $S, $A->{".NauticTwilightMorning"}, "NauticTwilightMorning" )
      if ( grep ( /^NauticTwilightMorning$/, @schedsch ) );
    AddToSchedule( $S, $A->{".NauticTwilightEvening"}, "NauticTwilightEvening" )
      if ( grep ( /^NauticTwilightEvening$/, @schedsch ) );
    AddToSchedule( $S, $A->{".AstroTwilightMorning"}, "AstroTwilightMorning" )
      if ( grep ( /^AstroTwilightMorning$/, @schedsch ) );
    AddToSchedule( $S, $A->{".AstroTwilightEvening"}, "AstroTwilightEvening" )
      if ( grep ( /^AstroTwilightEvening$/, @schedsch ) );
    AddToSchedule( $S, $A->{".CustomTwilightMorning"}, "CustomTwilightMorning" )
      if ( grep ( /^CustomTwilightMorning$/, @schedsch ) );
    AddToSchedule( $S, $A->{".CustomTwilightEvening"}, "CustomTwilightEvening" )
      if ( grep ( /^CustomTwilightEvening$/, @schedsch ) );
    AddToSchedule( $S, $A->{".MoonTransit"}, "MoonTransit" )
      if ( grep ( /^MoonTransit$/, @schedsch ) );
    AddToSchedule( $S, $A->{".MoonRise"}, "MoonRise" )
      if ( grep ( /^MoonRise$/, @schedsch ) );
    AddToSchedule( $S, $A->{".MoonSet"}, "MoonSet" )
      if ( grep ( /^MoonSet$/, @schedsch ) );
    AddToSchedule( $S, 0, "ObsDate " . $A->{ObsDate} )
      if ( grep ( /^ObsDate$/, @schedsch ) );

    # Seasonal hours
    $S->{DaySeasonalHrsDay}   = $dayparts;
    $S->{DaySeasonalHrsNight} = $nightparts;
    my $daypartlen   = $A->{".SunHrsVisible"} / $dayparts;
    my $nightpartlen = $A->{".SunHrsInvisible"} / $nightparts;
    $S->{".DaySeasonalHrLenDay"}   = $daypartlen;
    $S->{".DaySeasonalHrLenNight"} = $nightpartlen;
    $S->{DaySeasonalHrLenDay}      = FHEM::Astro::HHMMSS($daypartlen);
    $S->{DaySeasonalHrLenNight}    = FHEM::Astro::HHMMSS($nightpartlen);

    my $daypart;
    my $daypartnext;

    #   sunrise and sunset do not occur
    my $daypartTNow = $D->{timeday} + 1. / 3600.;
    if (   ( !defined( $A->{".SunRise"} ) || $A->{".SunRise"} !~ m/^\d+/ )
        && ( !defined( $A->{".SunSet"} ) || $A->{".SunSet"} !~ m/^\d+/ ) )
    {
        $daypartlen += $nightpartlen;
        if ( $A->{SunAlt} > 0. ) {
            $daypart = ceil( $daypartTNow / $daypartlen );
        }
        else {
            $daypart =
              ( $nightparts + 1. ) * -1. + ceil( $daypartTNow / $daypartlen );
        }
    }

    #   sunset does not occur
    elsif ( ( !defined( $A->{".SunSet"} ) || $A->{".SunSet"} !~ m/^\d+/ )
        && $daypartTNow < $A->{".SunRise"} )
    {
        $daypart =
          ( $dayparts + 1. ) * -1. + ceil( $daypartTNow / $nightpartlen );
    }

    #   sunrise does not occur
    elsif ( ( !defined( $A->{".SunRise"} ) || $A->{".SunRise"} !~ m/^\d+/ )
        && $daypartTNow < $A->{".SunSet"} )
    {
        $daypart = ceil( $daypartTNow / $daypartlen );
    }

    #   sunrise or sunset do not occur
    elsif (!defined( $A->{".SunRise"} )
        || $A->{".SunRise"} !~ m/^\d+/
        || !defined( $A->{".SunSet"} )
        || $A->{".SunSet"} !~ m/^\d+/ )
    {
        $daypartlen += $nightpartlen;
        $daypart = ceil( $daypartTNow / $daypartlen )
          if ( $A->{SunAlt} >= 0. );
        $daypart = ( $nightparts + 1 ) * -1 + ceil( $daypartTNow / $daypartlen )
          if ( $A->{SunAlt} < 0. );
    }

    #   very long days where sunset seems to happen before sunrise
    elsif ( $A->{".SunSet"} < $A->{".SunRise"} ) {
        if ( $D->{timeday} >= $A->{".SunRise"} ) {
            $daypart =
              ceil( ( $daypartTNow - $A->{".SunRise"} ) / $daypartlen );
        }
        else {
            $daypart =
              ceil( ( $daypartTNow - $A->{".SunSet"} ) / $nightpartlen );
        }
    }

    #   regular day w/ sunrise and sunset
    elsif ( $daypartTNow < $A->{".SunRise"} )
    {    # after newCalDay but before sunrise
        $daypart = ( $nightparts + 1 ) * -1. +
          ceil( ( $daypartTNow + 24. - $A->{".SunSet"} ) / $nightpartlen );
    }
    elsif ( $daypartTNow < $A->{".SunSet"} ) { # after sunrise but before sunset
        $daypart = ceil( ( $daypartTNow - $A->{".SunRise"} ) / $daypartlen );
    }
    else {    # after sunset but before newCalDay
        $daypart = ( $nightparts + 1 ) * -1. +
          ceil( ( $daypartTNow - $A->{".SunSet"} ) / $nightpartlen );
    }
    my $daypartdigits = maxNum( $dayparts, $nightparts ) =~ tr/0-9//;
    my $idp = $nightparts * -1. - 1.;
    while ( $idp < -1. ) {
        my $id =
          "-" . sprintf( "%0" . $daypartdigits . "d", ( $idp + 1. ) * -1. );
        my $d = ( $nightparts + 1 - $idp * -1. ) * $nightpartlen;
        $d += $A->{".SunSet"} if ( $A->{".SunSet"} ne '---' );
        $d -= 24. if ( $d >= 24. );

        AddToSchedule( $S, $d, "DaySeasonalHr -" . ( ( $idp + 1. ) * -1. ) )
          if ( grep ( /^DaySeasonalHr$/, @schedsch ) );
        AddToSchedule( $S, $d, "Daytime " . $tt->{ $dayphases[ 13. + $idp ] } )
          if ( grep ( /^Daytime$/, @schedsch ) && $nightparts == 12. );
        AddToSchedule( $S, $d,
            "Daytime Vigilia "
              . UConv::arabic2roman( $idp + $nightparts + 2. ) )
          if ( grep ( /^Daytime$/, @schedsch ) && $nightparts == 4. );

        # if time passed us already, we want it for tomorrow
        if ( $D->{timeday} >= $d ) {
            if ( ref($At) && ref($St) ) {
                $d = ( $nightparts + 1 - $idp * -1. ) *
                  $St->{".DaySeasonalHrLenNight"};
                $d += $At->{".SunSet"} if ( $At->{".SunSet"} ne '---' );
                $d -= 24. if ( $d >= 24. );
            }
            else {
                $d = "---";
            }
        }
        $S->{".DaySeasonalHrT$id"} = $d;
        $S->{"DaySeasonalHrT$id"} =
            $d eq '---'
          ? $d
          : (
            $d == 0.
            ? ( $daypart < 0. ? '00:00:00' : '---' )
            : FHEM::Astro::HHMMSS($d)
          );
        $idp++;
    }
    $idp = 0;
    while ( $idp < $dayparts ) {
        my $id = sprintf( "%0" . $daypartdigits . "d", $idp + 1. );
        my $d = $idp * $daypartlen;
        $d += $A->{".SunRise"} if ( $A->{".SunRise"} ne '---' );
        $d -= 24. if ( $d >= 24. );

        AddToSchedule( $S, $d, "DaySeasonalHr " . ( $idp + 1. ) )
          if ( grep ( /^DaySeasonalHr$/, @schedsch ) );
        AddToSchedule( $S, $d, "Daytime " . $tt->{ $dayphases[ 12. + $idp ] } )
          if ( grep ( /^Daytime$/, @schedsch )
            && $dayparts == 12.
            && !$daypartsIsRoman );
        AddToSchedule( $S, $d,
            "Daytime Hora " . UConv::arabic2roman( $idp + 1. ) )
          if ( grep ( /^Daytime$/, @schedsch ) && $daypartsIsRoman );

        # if time passed us already, we want it for tomorrow
        if ( $D->{timeday} >= $d ) {
            if ( ref($At) && ref($St) ) {
                $d = $idp * $St->{".DaySeasonalHrLenDay"};
                $d += $At->{".SunRise"} if ( $At->{".SunRise"} ne '---' );
                $d -= 24. if ( $d >= 24. );
            }
            else {
                $d = "---";
            }
        }
        $S->{".DaySeasonalHrT$id"} = $d;
        $S->{"DaySeasonalHrT$id"} =
            $d eq '---'
          ? $d
          : (
            $d == 0.
            ? ( $daypart > 0. ? '00:00:00' : '---' )
            : FHEM::Astro::HHMMSS($d)
          );
        $idp++;
    }
    if ( $daypart > 0. ) {
        $daypartnext = $daypart * $daypartlen;
        $daypartnext += $A->{".SunRise"} if ( $A->{".SunRise"} ne '---' );
    }
    else {
        $daypartnext = ( $nightparts + 1 - $daypart * -1. ) * $nightpartlen;
        $daypartnext += $A->{".SunSet"} if ( $A->{".SunSet"} ne '---' );
    }
    $daypartnext -= 24. if ( $daypartnext >= 24. );

    $S->{".DaySeasonalHrNextT"} = $daypartnext;
    $S->{DaySeasonalHrNextT} =
      $daypartnext == 0. ? '00:00:00' : FHEM::Astro::HHMMSS($daypartnext);
    $S->{DaySeasonalHr} = $daypart;
    $S->{DaySeasonalHrR} =
      UConv::arabic2roman(
        $daypart < 0 ? ( $nightparts + 1. + $daypart ) : $daypart );

    # Daytime
    #  modern classification
    if (   ( $dayparts == 12. && $nightparts == 12. )
        || ( $dayparts == 12. && $daypart > 0. && !$daypartsIsRoman )
        || ( $nightparts == 12. && $daypart < 0. ) )
    {
        my $dayphase = ( $daypart < 0. ? 12. : 11. ) + $daypart;
        $S->{DaytimeN} = $dayphase;
        $S->{Daytime}  = $tt->{ $dayphases[$dayphase] };
    }

    #  roman classification
    elsif ( $daypartsIsRoman
        || ( $nightparts == 4. && $daypart < 0. ) )
    {
        my $dayphase = ( $daypart < 0. ? 4. : 3 ) + $daypart;
        $S->{DaytimeN} = $dayphase;
        $S->{Daytime} =
          ( $daypart < 0. ? 'Vigilia ' : 'Hora ' )
          . UConv::arabic2roman(
            $daypart < 0 ? $daypart + $nightparts + 1. : $daypart );
    }

    #  unknown classification
    else {
        $S->{DaytimeN} = "---";
        $S->{Daytime}  = "---";
    }

    # Extend Astro data with symbols
    $S->{ObsSeasonSym} = $seasonsicon[ $A->{ObsSeasonN} ];
    $S->{MoonPhaseSym} = $phasesicon[ $A->{MoonPhaseI} ];
    $S->{MoonSignSym}  = $zodiacicon[ $A->{MoonSignN} ];
    $S->{SunSignSym}   = $zodiacicon[ $A->{SunSignN} ];

    # check meteorological season
    for ( my $i = 0 ; $i < 4 ; $i++ ) {
        my $key = $FHEM::Astro::seasons{'N'}[$i];
        if (
            (
                   ( $seasonmn{$key}[0] < $seasonmn{$key}[1] )
                && ( $seasonmn{$key}[0] <= $D->{month} )
                && ( $seasonmn{$key}[1] >= $D->{month} )
            )
            || (
                ( $seasonmn{$key}[0] > $seasonmn{$key}[1] )
                && (   ( $seasonmn{$key}[0] <= $D->{month} )
                    || ( $seasonmn{$key}[1] >= $D->{month} ) )
            )
          )
        {
            my $k = $FHEM::Astro::seasons{ $A->{ObsLat} < 0 ? 'S' : 'N' }[$i];
            $S->{SeasonMeteo}    = $astrott->{$k};
            $S->{SeasonMeteoN}   = $i;
            $S->{SeasonMeteoSym} = $seasonsicon[$i];
            last;
        }
    }

    # check phenological season (for Central Europe only)
    if (   $A->{ObsLat} >= 35.0
        && $A->{ObsLon} >= -11.0
        && $A->{ObsLat} < 71.0
        && $A->{ObsLon} < 25.0 )
    {
        my $pheno = 0;

        #      waiting for summer
        if ( $D->{month} < 6.0 ) {
            my $distObs = UConv::distance(
                $A->{ObsLat}, $A->{ObsLon},
                $seasonppos{earlyspring}[0],
                $seasonppos{earlyspring}[1],
            );
            my $distTotal = UConv::distance(
                $seasonppos{earlyspring}[0], $seasonppos{earlyspring}[1],
                $seasonppos{earlyfall}[0],   $seasonppos{earlyfall}[1],
            );
            my $timeBeg =
              time_str2num( $D->{year} . '-' . $earlyspring . ' 00:00:00' );
            $timeBeg -= 86400.0 #starts 1 day earlier after 28.2. in a leap year
              if ( UConv::IsLeapYear( $D->{year} )
                && $earlyspring =~ m/^(\d+)-(\d+)$/
                && ( $1 == 3 || $2 == 29 ) );
            my $timeNow =
              time_str2num( $D->{year} . '-'
                  . $D->{month} . '-'
                  . $D->{day}
                  . ' 00:00:00' );
            my $progessDays = ( $timeNow - $timeBeg ) / 86400.0;

            if ( $progessDays >= 0.0 ) {
                $pheno = 1;     # spring begins
                my $currDistObs = $distObs - ( $progessDays * 37.5 );
                if ( $currDistObs <= $distObs * 0.4 ) {
                    $pheno = 2;    # spring made 40 % of its way to observer
                    $currDistObs = $distObs - ( $progessDays * 31.0 );
                    if ( $currDistObs <= 0.0 ) {
                        $pheno = 3;    # spring reached observer
                        my $currDistTotal =
                          $distTotal - ( $progessDays * 37.5 );
                        if ( $currDistTotal <= 0.0 ) {
                            $pheno = 4;    # should be early summer already
                        }
                    }
                }
            }
        }

        #     fairly simple progress during summer
        elsif ( $D->{month} < 9.0 ) {
            $pheno = 4;
            $pheno++ if ( $D->{month} >= 7.0 );
            $pheno++ if ( $D->{month} == 8.0 );
        }

        #     waiting for winter
        if ( $D->{month} >= 8.0 && $D->{month} < 12.0 ) {
            my $distObs = UConv::distance(
                $A->{ObsLat}, $A->{ObsLon},
                $seasonppos{earlyfall}[0],
                $seasonppos{earlyfall}[1],
            );
            my $distTotal = UConv::distance(
                $seasonppos{earlyfall}[0],   $seasonppos{earlyfall}[1],
                $seasonppos{earlyspring}[0], $seasonppos{earlyspring}[1],
            );
            my $timeBeg =
              time_str2num( $D->{year} . '-' . $earlyfall . ' 00:00:00' );
            $timeBeg -= 86400.0    #starts 1 day earlier in a leap year
              if ( UConv::IsLeapYear( $D->{year} ) );
            my $timeNow =
              time_str2num( $D->{year} . '-'
                  . $D->{month} . '-'
                  . $D->{day}
                  . ' 00:00:00' );
            my $progessDays = ( $timeNow - $timeBeg ) / 86400.0;

            if ( $progessDays >= 0.0 ) {
                $pheno = 7;        # fall begins
                my $currDistObs = $distObs - ( $progessDays * 35.0 );
                if ( $currDistObs <= $distObs * 0.4 ) {
                    $pheno = 8;    # fall made 40 % of its way to observer
                    $currDistObs = $distObs - ( $progessDays * 29.5 );
                    if ( $currDistObs <= 0.0 ) {
                        $pheno = 9;    # fall reached observer
                        my $currDistTotal =
                          $distTotal - ( $progessDays * 45.0 );
                        if ( $currDistTotal <= 0.0 ) {
                            $pheno = 0;    # should be winter already
                        }
                    }
                }
            }
        }

        if ( $pheno == 0. ) {
            $S->{SeasonPheno}    = $astrott->{ $seasonsp[0][0] };
            $S->{SeasonPhenoSym} = $seasonsp[0][1];
        }
        else {
            $S->{SeasonPheno}    = $tt->{ $seasonsp[$pheno][0] };
            $S->{SeasonPhenoSym} = $seasonsp[$pheno][1];
        }
        $S->{SeasonPhenoN} = $pheno;
    }
    else {
        Log3 $name, 5,
          "$name: Location is out of range to calculate phenological season"
          if ( !$dayOffset );
    }

    # add info from 2 days before but only -1 day will be useful after all
    if ( !defined($dayOffset) ) {

        # today-2, has no tomorrow or yesterday
        ( $A->{'-2'}, $S->{'-2'} ) = Compute( $hash, -2, $params );
        ( $A->{'-2'}{'000000'}, $S->{'-2'}{'000000'} ) =
          Compute( $hash, '-2-000000', $params );
        ( $A->{'-2'}{'120000'}, $S->{'-2'}{'120000'} ) =
          Compute( $hash, '-2-120000', $params );
        ( $A->{'-2'}{'235959'}, $S->{'-2'}{'235959'} ) =
          Compute( $hash, '-2-235959', $params );

        # today-1, has tomorrow and yesterday
        ( $A->{'-1'}, $S->{'-1'} ) = Compute( $hash, -1, $params );
        ( $A->{'-1'}{'000000'}, $S->{'-1'}{'000000'} ) =
          Compute( $hash, '-1-000000', $params );
        ( $A->{'-1'}{'120000'}, $S->{'-1'}{'120000'} ) =
          Compute( $hash, '-1-120000', $params );
        ( $A->{'-1'}{'235959'}, $S->{'-1'}{'235959'} ) =
          Compute( $hash, '-1-235959', $params );
    }

    # reference for yesterday
    my $Ay;
    my $Sy;
    if (   !defined($dayOffset)
        || $dayOffset == -1.
        || $dayOffset == 0.
        || $dayOffset == 1. )
    {
        my $t = ( !defined($dayOffset) ? 0. : $dayOffset ) - 1.;
        $Ay = \%Astro unless ($t);
        $Ay = $Astro{$t} if ( $t && defined( $Astro{$t} ) );
        $Sy = \%Schedule unless ($t);
        $Sy = $Schedule{$t} if ( $t && defined( $Schedule{$t} ) );
    }

    # Change indicators for event day and day before
    $S->{DayChangeSeason}      = 0 unless ( $S->{DayChangeSeason} );
    $S->{DayChangeSeasonMeteo} = 0 unless ( $S->{DayChangeSeasonMeteo} );
    $S->{DayChangeSeasonPheno} = 0
      unless ( !defined( $S->{SeasonPhenoN} ) || $S->{DayChangeSeasonPheno} );
    $S->{DayChangeIsDST} = 0 unless ( $S->{DayChangeIsDST} );

    #  Astronomical season is going to change tomorrow
    if (   ref($At)
        && ref($St)
        && !$St->{DayChangeSeason}
        && defined( $At->{ObsSeasonN} )
        && $At->{ObsSeasonN} != $A->{ObsSeasonN} )
    {
        $S->{DayChangeSeason}  = -1;
        $St->{DayChangeSeason} = 1;
        AddToSchedule( $St, '*', "ObsSeason " . $At->{ObsSeason} )
          if ( grep ( /^ObsSeason$/, @schedsch ) );
    }

    #  Astronomical season changed since yesterday
    elsif (ref($Ay)
        && ref($Sy)
        && !$Sy->{DayChangeSeason}
        && defined( $Ay->{ObsSeasonN} )
        && $Ay->{ObsSeasonN} != $A->{ObsSeasonN} )
    {
        $Sy->{DayChangeSeason} = -1;
        $S->{DayChangeSeason}  = 1;
        AddToSchedule( $S, '*', "ObsSeason " . $A->{ObsSeason} )
          if ( grep ( /^ObsSeason$/, @schedsch ) );
    }

    #  Meteorological season is going to change tomorrow
    if (   ref($St)
        && !$St->{DayChangeSeasonMeteo}
        && defined( $St->{SeasonMeteoN} )
        && $St->{SeasonMeteoN} != $S->{SeasonMeteoN} )
    {
        $S->{DayChangeSeasonMeteo}  = -1;
        $St->{DayChangeSeasonMeteo} = 1;
        AddToSchedule( $St, '*', "SeasonMeteo " . $St->{SeasonMeteo} )
          if ( grep ( /^SeasonMeteo$/, @schedsch ) );
    }

    #  Meteorological season changed since yesterday
    elsif (ref($Sy)
        && !$Sy->{DayChangeSeasonMeteo}
        && defined( $Sy->{SeasonMeteoN} )
        && $Sy->{SeasonMeteoN} != $S->{SeasonMeteoN} )
    {
        $Sy->{DayChangeSeasonMeteo} = -1;
        $S->{DayChangeSeasonMeteo}  = 1;
        AddToSchedule( $S, '*', "SeasonMeteo " . $S->{SeasonMeteo} )
          if ( grep ( /^SeasonMeteo$/, @schedsch ) );
    }

#FIXME
# for change from Summer to Fall and Winter to Spring
#  --> empty values?
# 2019.07.01 15:14:43.410 1: PERL WARNING: Use of uninitialized value in concatenation (.) or string at ./FHEM/95_DaySchedule.pm line 4490.
# 2019.07.01 15:14:50.712 1: PERL WARNING: Use of uninitialized value in concatenation (.) or string at ./FHEM/95_DaySchedule.pm line 4503.

    #  Phenological season is going to change tomorrow
    if (   ref($St)
        && !$St->{DayChangeSeasonPheno}
        && defined( $St->{SeasonPhenoN} )
        && $St->{SeasonPhenoN} != $S->{SeasonPhenoN} )
    {
        $S->{DayChangeSeasonPheno}  = -1;
        $St->{DayChangeSeasonPheno} = 1;
        AddToSchedule( $St, '*', "SeasonPheno " . $St->{SeasonPheno} )
          if ( grep ( /^SeasonPheno$/, @schedsch ) );
    }

    #  Phenological season changed since yesterday
    elsif (ref($Sy)
        && !$Sy->{DayChangeSeasonPheno}
        && defined( $Sy->{SeasonPhenoN} )
        && $Sy->{SeasonPhenoN} != $S->{SeasonPhenoN} )
    {
        $Sy->{DayChangeSeasonPheno} = -1;
        $S->{DayChangeSeasonPheno}  = 1;
        AddToSchedule( $S, '*', "SeasonPheno " . $S->{SeasonPheno} )
          if ( grep ( /^SeasonPheno$/, @schedsch ) );
    }

    #  DST is going to change tomorrow
    if (   ref($St)
        && !$St->{DayChangeIsDST}
        && defined( $St->{".isdstultimo"} )
        && $St->{".isdstultimo"} != $S->{".isdstultimo"} )
    {
        $S->{DayChangeIsDST}  = -1;
        $St->{DayChangeIsDST} = 1;
        AddToSchedule( $St, '?', "ObsIsDST " . $St->{".isdstultimo"} )
          if ( grep ( /^ObsIsDST$/, @schedsch ) );
    }

    #  DST is going to change somewhere today
    elsif (ref($Sy)
        && !$Sy->{DayChangeIsDST}
        && defined( $Sy->{".isdstultimo"} )
        && $Sy->{".isdstultimo"} != $S->{".isdstultimo"} )
    {
        $Sy->{DayChangeIsDST} = -1;
        $S->{DayChangeIsDST}  = 1;
        AddToSchedule( $S, '?', "ObsIsDST " . $S->{".isdstultimo"} )
          if ( grep ( /^ObsIsDST$/, @schedsch ) );
    }

    # schedule
    if ( defined( $S->{".schedule"} ) ) {

        # past of yesterday
        if ( ref($Sy) ) {
            foreach my $e ( sort { $b <=> $a } keys %{ $Sy->{".schedule"} } ) {
                foreach ( @{ $Sy->{".schedule"}{$e} } ) {
                    AddToSchedule( $S, 'y' . $e, $_ );
                }
                last;    # only last event from last day
            }

            if (  !defined( $S->{".scheduleYest"} )
                && defined( $Sy->{".scheduleDay"} ) )
            {
                foreach ( @{ $Sy->{".scheduleDay"} } ) {
                    AddToSchedule( $S, 'y?', $_ );
                }
            }

            if (  !defined( $S->{".scheduleYest"} )
                && defined( $Sy->{".scheduleAllday"} ) )
            {
                foreach ( @{ $Sy->{".scheduleAllday"} } ) {
                    AddToSchedule( $S, 'y*', $_ );
                }
            }
        }

        # future of tomorrow
        if ( ref($St) ) {
            foreach my $e ( sort { $a <=> $b } keys %{ $St->{".schedule"} } ) {
                foreach ( @{ $St->{".schedule"}{$e} } ) {
                    AddToSchedule( $S, 't' . $e, $_ );
                }
                last if ( $e > 0. );
            }

            if ( defined( $St->{".scheduleAllday"} ) ) {
                foreach ( @{ $St->{".scheduleAllday"} } ) {
                    AddToSchedule( $S, 't*', $_ );
                }
            }

            if ( defined( $St->{".scheduleDay"} ) ) {
                foreach ( @{ $St->{".scheduleDay"} } ) {
                    AddToSchedule( $S, 't?', $_ );
                }
            }
        }

        foreach my $e ( sort { $a <=> $b } keys %{ $S->{".schedule"} } ) {

            # past of today
            if ( $e <= $daypartTNow ) {
                $S->{".SchedLastT"} = $e == 24. ? 0 : $e;
                $S->{SchedLastT} = $e == 0.
                  || $e == 24. ? '00:00:00' : FHEM::Astro::HHMMSS($e);
                $S->{SchedLast} = join( ", ", @{ $S->{".schedule"}{$e} } );
                $S->{SchedRecent} =
                  join( ", ", reverse @{ $S->{".schedule"}{$e} } )
                  . (
                    defined( $S->{SchedRecent} )
                    ? ", " . $S->{SchedRecent}
                    : ""
                  );
            }

            # future of today
            else {
                unless ( defined( $S->{".SchedNextT"} ) ) {
                    $S->{".SchedNextT"} = $e == 24. ? 0 : $e;
                    $S->{SchedNextT} = $e == 0.
                      || $e == 24. ? '00:00:00' : FHEM::Astro::HHMMSS($e);
                    $S->{SchedNext} =
                      join( ", ", @{ $S->{".schedule"}{$e} } );
                }
                $S->{SchedUpcoming} .= ", "
                  if ( defined( $S->{SchedUpcoming} ) );
                $S->{SchedUpcoming} .=
                  join( ", ", @{ $S->{".schedule"}{$e} } );
            }
        }

        # no event happend today until now
        if (  !defined( $S->{SchedRecent} )
            && defined( $S->{".scheduleYest"} ) )
        {
            foreach my $e ( keys %{ $S->{".scheduleYest"} } ) {
                $S->{".SchedLastT"} = $e == 24. ? 0 : $e;
                $S->{SchedLastT} = $e == 0.
                  || $e == 24. ? '00:00:00' : FHEM::Astro::HHMMSS($e);
                $S->{SchedLast}   = $S->{".scheduleYest"}{$e};
                $S->{SchedRecent} = $S->{SchedLast};
            }
        }

        # no event left for today
        if (  !defined( $S->{SchedUpcoming} )
            && defined( $S->{".scheduleTom"} ) )
        {
            foreach my $e ( keys %{ $S->{".scheduleTom"} } ) {
                $S->{".SchedNextT"} = $e == 24. ? 0 : $e;
                $S->{SchedNextT} = $e == 0.
                  || $e == 24. ? '00:00:00' : FHEM::Astro::HHMMSS($e);
                $S->{SchedNext} = join( ", ", @{ $S->{".scheduleTom"}{$e} } );
                $S->{SchedUpcoming} = $S->{SchedNext};
            }
        }
    }
    else {
        $S->{SchedLast}     = "---";
        $S->{SchedLastT}    = "---";
        $S->{SchedNext}     = "---";
        $S->{SchedNextT}    = "---";
        $S->{SchedRecent}   = "---";
        $S->{SchedUpcoming} = "---";
    }

    # DayDesc
    if ( defined( $S->{'.scheduleAllday'} ) || defined( $S->{'.scheduleDay'} ) )
    {
        my $l;

        if ( defined( $Schedule{'.scheduleAllday'} ) ) {
            foreach my $e ( @{ $Schedule{'.scheduleAllday'} } ) {
                $l .= "\n" if ($l);

                if ( $e =~ m/^(\S+)(?: (.+))?$/ ) {
                    if ( defined( $Astro{$1} ) ) {
                        $l .=
                          decode_utf8 FHEM::Astro::FormatReading( $1,
                            { long => 3 },
                            $lc_numeric, defined($2) ? $2 : '' );
                    }
                    elsif ( defined( $Schedule{$1} ) ) {
                        $l .= decode_utf8 FormatReading( $1, { long => 3 },
                            $lc_numeric, defined($2) ? $2 : '' );
                    }
                    else {
                        $l .= $e;
                    }
                }
            }
        }

        if ( defined( $Schedule{'.scheduleDay'} ) ) {
            foreach my $e ( @{ $Schedule{'.scheduleDay'} } ) {
                $l .= "\n" if ($l);

                if ( $e =~ m/^(\S+)(?: (.+))?$/ ) {
                    if ( defined( $Astro{$1} ) ) {
                        $l .=
                          decode_utf8 FHEM::Astro::FormatReading( $1,
                            { long => 3 },
                            $lc_numeric, defined($2) ? $2 : '' );
                    }
                    elsif ( defined( $Schedule{$1} ) ) {
                        $l .= decode_utf8 FormatReading( $1, { long => 3 },
                            $lc_numeric, defined($2) ? $2 : '' );
                    }
                    else {
                        $l .= $e;
                    }
                }
            }
        }

        $S->{DayDesc} = $l;
    }
    else {
        $S->{DayDesc} = '---';
    }

    delete local $ENV{TZ};
    tzset();

    return $A, $S
      if ($dayOffset);
    return (undef);
}

# This is based on code from 95_holiday.pm / holiday_refresh()
#  as there is no dedicated function to use
sub IsSpecificDay($$$;$) {
    my ( $l, $d, $m, $y ) = @_;

    $y = ( localtime( gettimeofday() ) )[5] + 1900. unless ( defined($y) );
    my $fordate = sprintf( "%02d-%02d", $m, $d );
    my @fd = localtime( mktime( 1, 1, 1, $d, $m - 1, $y - 1900., 0, 0, -1 ) );

    # Exact date: 1 MM-DD
    if ( $l =~ m/^1/ ) {
        my @args = split( " ", $l, 3 );
        return 1
          if ( $args[1] eq $fordate );
    }

    # Easter date: 2 +1
    elsif ( $l =~ m/^2/ ) {
        my @a = split( " ", $l, 3 );
        my ( $Om, $Od ) = GetWesternEaster($y);
        my $timex = mktime( 0, 0, 12, $Od, $Om - 1, $y - 1900., 0, 0, -1 );
        $timex = $timex + $a[1] * 86400.;
        my ( $msecond, $mminute, $mhour, $mday, $mmonth, $myear, $mrest ) =
          localtime($timex);
        $myear  = $myear + 1900.;
        $mmonth = $mmonth + 1.;
        return 0 if ( $mday != $fd[3] || $mmonth != $fd[4] + 1. );
        return 1;
    }

    # Relative date: 3 -1 Mon 03
    elsif ( $l =~ m/^3/ ) {
        my @a = split( " ", $l, 5 );
        my %wd = (
            "Sun" => 0,
            "Mon" => 1,
            "Tue" => 2,
            "Wed" => 3,
            "Thu" => 4,
            "Fri" => 5,
            "Sat" => 6
        );
        my @md = ( 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 );
        $md[1] = 29
          if ( UConv::IsLeapYear( $fd[5] + 1900. ) && $fd[4] == 1. );
        my $wd = $wd{ $a[2] };
        if ( !defined($wd) ) {
            return wantarray ? ( undef, "Wrong timespec: $l" ) : undef;
        }
        return 0 if ( $wd != $fd[6] );               # Weekday
        return 0 if ( $a[3] != ( $fd[4] + 1. ) );    # Month
        if ( $a[1] > 0. ) {                          # N'th day from the start
            my $d = $fd[3] - ( $a[1] - 1. ) * 7.;
            return 0 if ( $d < 1. || $d > 7. );
        }
        elsif ( $a[1] < 0. ) {                       # N'th day from the end
            my $d = $fd[3] - ( $a[1] + 1. ) * 7.;
            my $md = $md[ $fd[4] ];
            return 0 if ( $d > $md || $d < $md - 6. );
        }
        return 1;
    }

    # Interval: 4 MM-DD MM-DD Holiday
    elsif ( $l =~ m/^4/ ) {
        my @args = split( " ", $l, 4 );
        return 1
          if ( $args[1] <= $fordate && $args[2] >= $fordate );
    }

    # nth weekday since MM-DD / before MM-DD
    elsif ( $l =~ m/^5/ ) {
        my @a = split( " ", $l, 6 );
        my %wd = (
            "Sun" => 0,
            "Mon" => 1,
            "Tue" => 2,
            "Wed" => 3,
            "Thu" => 4,
            "Fri" => 5,
            "Sat" => 6
        );

        my $wd = $wd{ $a[2] };
        if ( !defined($wd) ) {
            return wantarray ? ( 0, "Wrong weekday spec: $l" ) : 0;
        }

        return 0 if $wd != $fd[6];

        my $yday     = $fd[7];
        my $tgt      = mktime( 0, 0, 1, $a[4], $a[3] - 1., $fd[5], 0, 0, -1 );
        my $tgtmin   = $tgt;
        my $tgtmax   = $tgt;
        my $weeksecs = 7. * 86400.;
        my $cd       = mktime( 0, 0, 1, $fd[3], $fd[4], $fd[5], 0, 0, -1 );

        if ( $a[1] =~ /^-([0-9])*$/ ) {
            $tgtmin -= $1 * $weeksecs;
            $tgtmax = $tgtmin + $weeksecs;
            return 1
              if ( ( $cd >= $tgtmin ) && ( $cd < $tgtmax ) );
        }
        elsif ( $a[1] =~ /^\+?([0-9])*$/ ) {
            $tgtmin += ( $1 - 1 ) * $weeksecs;
            $tgtmax = $tgtmin + $weeksecs;
            return 1
              if ( ( $cd > $tgtmin ) && ( $cd <= $tgtmax ) );
        }
        else {
            return wantarray ? ( 0, "Wrong distance spec: $l" ) : 0;
        }
    }

    # own calculation
    elsif ( $l =~ m/^6/ ) {
        my @args = split( " ", $l, 4 );
        my $res = "?";
        no strict "refs";
        eval { $res = &{ $args[1] }( $args[2] ); };
        use strict "refs";
        return wantarray
          ? (
            undef,
            "[FHEM::DaySchedule::IsSpecificDay]: Error in own function: $@"
          )
          : undef
          if ($@);
        return 1
          if ( $res eq $fordate );
    }

    return 0;
}

sub IsSeasonAdvent($$;$$) {
    my ( $d, $m, $y, $lang ) = @_;
    return IsSeasonAdventEarly( $d, $m, $y, $lang, 0 );
}

sub IsSeasonAdventEarly($$;$$$) {
    my ( $d, $m, $y, $lang, $early ) = @_;
    $early = 1 unless ( defined($early) );

    my $now   = gettimeofday();
    my $today = timegm_modern( 0, 0, 0, $d, $m - 1,
        ( defined($y) ? $y : ( localtime($now) )[5] + 1900. ) );
    my $christmas = timegm_modern( 0, 0, 0, 25, 11,
        ( defined($y) ? $y : ( localtime($now) )[5] + 1900. ) );
    my $christmaseve = $christmas - 86400.;
    my ( $secC, $minC, $hourC, $dayC, $monthC, $yearC, $wdayC, $ydayC, $isdstC )
      = localtime($christmas);
    my $adv4 = $christmas - 86400. * $wdayC;
    my $adv3 = $adv4 - 86400. * 7;
    my $adv2 = $adv3 - 86400. * 7;
    my $adv1 = $adv2 - 86400. * 7;

    my $advbeginearly = timegm_modern( 0, 0, 0, 27, 10,
        ( defined($y) ? $y : ( localtime($now) )[5] + 1900. ) );
    my $advbegin = $early ? $advbeginearly : $adv1;

    return 0 unless ( $today >= $advbegin && $today < $christmaseve );

    if ($lang) {
        if ( exists( $transtable{ uc($lang) } ) ) {
            $tt = $transtable{ uc($lang) };
        }
        else {
            $tt = $transtable{EN};
        }
    }

    if ( $today == $adv1 ) {
        return ref($tt) ? $tt->{advent1} : 2;
    }
    elsif ( $today == $adv2 ) {
        return ref($tt) ? $tt->{advent2} : 3;
    }
    elsif ( $today == $adv3 ) {
        return ref($tt) ? $tt->{advent3} : 4;
    }
    elsif ( $today == $adv4 ) {
        return ref($tt) ? $tt->{advent4} : 5;
    }
    else {
        return ref($tt) ? $tt->{adventseason} : 1;
    }
}

sub IsSeasonFasching($$;$$) {
    my ( $d, $m, $y, $lang ) = @_;
    return IsSeasonCarnivalLong( $d, $m, $y, $lang, 1, 0 );
}

sub IsSeasonFaschingLong($$;$$) {
    my ( $d, $m, $y, $lang ) = @_;
    return IsSeasonCarnivalLong( $d, $m, $y, $lang, 1, 1 );
}

sub IsSeasonCarnival($$;$$) {
    my ( $d, $m, $y, $lang ) = @_;
    return IsSeasonCarnivalLong( $d, $m, $y, $lang, 0, 0 );
}

sub IsSeasonCarnivalLong($$;$$$) {
    my ( $d, $m, $y, $lang, $fasching, $long ) = @_;
    $long = 1 unless ( defined($long) );

    my $now   = gettimeofday();
    my $today = timegm_modern( 0, 0, 0, $d, $m - 1,
        ( defined($y) ? $y : ( localtime($now) )[5] + 1900. ) );

    my $easterSun     = GetWesternEaster($y);
    my $carnival1     = $easterSun - 86400. * 52.;
    my $carnival2     = $carnival1 + 86400.;
    my $carnival3     = $carnival2 + 86400.;
    my $carnival4     = $carnival3 + 86400.;
    my $carnival5     = $carnival4 + 86400.;
    my $carnivalEnd   = $carnival5 + 86400.;
    my $carnivalBegin = timegm_modern( 0, 0, 0, 11, 10,
        ( defined($y) ? $y : ( localtime($now) )[5] + 1900. ) );
    my $newyearseve = timegm_modern( 0, 0, 0, 31, 11,
        ( defined($y) ? $y : ( localtime($now) )[5] + 1900. ) );
    my $newyear = timegm_modern( 0, 0, 0, 1, 0,
        ( defined($y) ? $y : ( localtime($now) )[5] + 1900. ) );

    if ($long) {
        return 0
          unless ( ( $today >= $carnivalBegin && $today <= $newyearseve )
            || ( $today >= $newyear && $today <= $carnivalEnd ) );
    }
    else {
        $carnivalBegin = $carnival1 - 86400. * 11.;
        return 0
          unless ( $today >= $carnivalBegin && $today <= $carnivalEnd );
    }

    if ($lang) {
        if ( exists( $transtable{ uc($lang) } ) ) {
            $tt = $transtable{ uc($lang) };
        }
        else {
            $tt = $transtable{EN};
        }
    }

    my $prefix = $fasching ? 'fasching' : 'carnival';
    if ( $today == $carnival1 ) {
        return ref($tt) ? $tt->{ $prefix . 'season1' } : 2;
    }
    elsif ( $today == $carnival2 ) {
        return ref($tt) ? $tt->{ $prefix . 'season2' } : 3;
    }
    elsif ( $today == $carnival3 ) {
        return ref($tt) ? $tt->{ $prefix . 'season3' } : 4;
    }
    elsif ( $today == $carnival4 ) {
        return ref($tt) ? $tt->{ $prefix . 'season4' } : 5;
    }
    elsif ( $today == $carnival5 ) {
        return ref($tt) ? $tt->{ $prefix . 'season5' } : 6;
    }
    elsif ( $today == $carnivalEnd ) {
        return ref($tt) ? $tt->{ $prefix . 'season6' } : 6;
    }
    else {
        return ref($tt) ? $tt->{ $prefix . 'season' } : 1;
    }
}

sub IsSeasonChanukka($$;$$) {

    #TODO
    return 0;
}

sub IsSeasonChristmas($$;$$) {
    my ( $d, $m, $y, $lang ) = @_;
    return IsSeasonChristmasLong( $d, $m, $y, $lang, 0 );
}

sub IsSeasonChristmasLong($$;$$$) {
    my ( $d, $m, $y, $lang, $long ) = @_;
    $long = 1 unless ( defined($long) );

    my $now   = gettimeofday();
    my $today = timegm_modern( 0, 0, 0, $d, $m - 1,
        ( defined($y) ? $y : ( localtime($now) )[5] + 1900. ) );
    my $christmaseve = timegm_modern( 0, 0, 0, 24, 11,
        ( defined($y) ? $y : ( localtime($now) )[5] + 1900. ) );
    my $christmas1  = $christmaseve + 86400.;
    my $christmas2  = $christmas1 + 86400.;
    my $newyearseve = $christmas2 + 86400. * 5.;
    my $newyear     = timegm_modern( 0, 0, 0, 1, 0,
        ( defined($y) ? $y : ( localtime($now) )[5] + 1900. ) );
    my $christmasend = $newyear + 86400. * 5.;

    if ($long) {
        return 0
          unless ( ( $today >= $christmaseve && $today <= $newyearseve )
            || ( $today >= $newyear && $today <= $christmasend ) );
    }
    else {
        return 0
          unless ( $today >= $christmaseve && $today <= $christmas2 );
    }

    if ($lang) {
        if ( exists( $transtable{ uc($lang) } ) ) {
            $tt = $transtable{ uc($lang) };
        }
        else {
            $tt = $transtable{EN};
        }
    }

    if ( $today == $christmaseve ) {
        return ref($tt) ? $tt->{christmaseve} : 2;
    }
    elsif ( $today == $christmas1 ) {
        return ref($tt) ? $tt->{christmas1} : 3;
    }
    elsif ( $today == $christmas2 ) {
        return ref($tt) ? $tt->{christmas2} : 4;
    }
    else {
        return ref($tt) ? $tt->{christmasseason} : 1;
    }
}

sub IsSeasonEaster($$;$$) {
    my ( $d, $m, $y, $lang ) = @_;
    return IsSeasonEasterTraditional( $d, $m, $y, $lang, 0 );
}

sub IsSeasonEasterTraditional($$;$$) {
    my ( $d, $m, $y, $lang, $traditional ) = @_;
    $traditional = 1 unless ( defined($traditional) );

    my $today = timegm_modern( 0, 0, 0, $d, $m - 1,
        ( defined($y) ? $y : ( localtime( gettimeofday() ) )[5] + 1900. ) );

    my $easterSun       = GetWesternEaster($y);
    my $easterMon       = $easterSun + 86400.;
    my $easterSat       = $easterSun + 86400. * 6.;
    my $easterWSun      = $easterSun + 86400. * 7.;
    my $easterTimeEnd   = $easterSun + 86400. * 49.;
    my $easterTimeBegin = $easterSun;
    unless ($traditional) {
        $easterTimeBegin -= 86400 * 14.;
        $easterTimeEnd = $easterWSun;
    }

    return 0
      unless ( $today >= $easterTimeBegin && $today <= $easterTimeEnd );

    if ($lang) {
        if ( exists( $transtable{ uc($lang) } ) ) {
            $tt = $transtable{ uc($lang) };
        }
        else {
            $tt = $transtable{EN};
        }
    }

    if ( $today == $easterSun ) {
        return ref($tt) ? $tt->{eastersun} : 2;
    }
    elsif ( $today == $easterMon ) {
        return ref($tt) ? $tt->{eastermon} : 3;
    }
    elsif ( $today == $easterSat ) {
        return ref($tt) ? $tt->{eastersat} : 4;
    }
    elsif ( $today == $easterWSun ) {
        return ref($tt) ? $tt->{easterwhitesun} : 5;
    }
    else {
        return ref($tt) ? $tt->{easterseason} : 1;
    }
}

sub IsSeasonHalloween($$;$$) {
    my ( $d, $m, $y, $lang ) = @_;

    return 0 unless ( $m == 10. && $d >= 24. && $d <= 31. );

    if ($lang) {
        if ( exists( $transtable{ uc($lang) } ) ) {
            $tt = $transtable{ uc($lang) };
        }
        else {
            $tt = $transtable{EN};
        }
    }

    if ( $d == 24. ) {
        return ref($tt) ? $tt->{halloweenbegin} : 1;
    }
    elsif ( $d == 31. ) {
        return ref($tt) ? $tt->{halloween} : 2;
    }
    else {
        return ref($tt) ? $tt->{halloweenseason} : 1;
    }
}

sub IsSeasonHolyWeek($$;$$) {
    my ( $d, $m, $y, $lang ) = @_;

    my $today = timegm_modern( 0, 0, 0, $d, $m - 1,
        ( defined($y) ? $y : ( localtime( gettimeofday() ) )[5] + 1900. ) );

    my $easterSun = GetWesternEaster($y);
    my $hwBegin   = $easterSun - 86400. * 7.;
    my $hwThu     = $easterSun - 86400. * 3.;
    my $hwFri     = $easterSun - 86400. * 2.;
    my $hwSat     = $easterSun - 86400. * 1.;

    return 0 unless ( $today >= $hwBegin && $today < $easterSun );

    if ($lang) {
        if ( exists( $transtable{ uc($lang) } ) ) {
            $tt = $transtable{ uc($lang) };
        }
        else {
            $tt = $transtable{EN};
        }
    }

    if ( $today == $hwBegin ) {
        return ref($tt) ? $tt->{holyweekpalm} : 2;
    }
    elsif ( $today == $hwThu ) {
        return ref($tt) ? $tt->{holyweekthu} : 3;
    }
    elsif ( $today == $hwFri ) {
        return ref($tt) ? $tt->{holyweekfri} : 4;
    }
    elsif ( $today == $hwSat ) {
        return ref($tt) ? $tt->{holyweeksat} : 5;
    }
    else {
        return ref($tt) ? $tt->{holyweek} : 1;
    }
}

sub IsSeasonPessach($$;$$) {

    #TODO
    return 0;
}

sub IsSeasonRamadan($$;$$) {

    #TODO
    return 0;
}

sub IsSeasonLenten($$;$$) {
    my ( $d, $m, $y, $lang ) = @_;

    my $today = timegm_modern( 0, 0, 0, $d, $m - 1,
        ( defined($y) ? $y : ( localtime( gettimeofday() ) )[5] + 1900. ) );

    my $easterSun   = GetWesternEaster($y);
    my $lentenBegin = $easterSun - 86400. * 46;
    my $lentenW1    = $easterSun - 86400. * 45;
    my $lentenW2    = $easterSun - 86400. * 42;
    my $lentenW3    = $lentenW2 + 86400. * 7.;
    my $lentenW4    = $lentenW3 + 86400. * 7.;
    my $lentenW5    = $lentenW4 + 86400. * 7.;
    my $lentenW6    = $lentenW5 + 86400. * 7.;
    my $lentenW7    = $lentenW6 + 86400. * 7.;
    my $lentenEnd   = $easterSun - 86400.;

    return 0 unless ( $today >= $lentenBegin && $today <= $lentenEnd );

    if ($lang) {
        if ( exists( $transtable{ uc($lang) } ) ) {
            $tt = $transtable{ uc($lang) };
        }
        else {
            $tt = $transtable{EN};
        }
    }

    if ( $today == $lentenBegin ) {
        return ref($tt) ? $tt->{lentenbegin} : 2;
    }
    elsif ( $today == $lentenW2 ) {
        return ref($tt) ? $tt->{lentensun1} : 4;
    }
    elsif ( $today == $lentenW3 ) {
        return ref($tt) ? $tt->{lentensun2} : 6;
    }
    elsif ( $today == $lentenW4 ) {
        return ref($tt) ? $tt->{lentensun3} : 8;
    }
    elsif ( $today == $lentenW5 ) {
        return ref($tt) ? $tt->{lentensun4} : 10;
    }
    elsif ( $today == $lentenW6 ) {
        return ref($tt) ? $tt->{lentensun5} : 12;
    }
    elsif ( $today == $lentenW7 ) {
        return ref($tt) ? $tt->{lentensun6} : 14;
    }
    elsif ( $today >= $lentenW1 && $today < $lentenW2 ) {
        return ref($tt) ? $tt->{lentenw1} : 3;
    }
    elsif ( $today >= $lentenW2 && $today < $lentenW3 ) {
        return ref($tt) ? $tt->{lentenw2} : 5;
    }
    elsif ( $today >= $lentenW3 && $today < $lentenW4 ) {
        return ref($tt) ? $tt->{lentenw3} : 7;
    }
    elsif ( $today >= $lentenW4 && $today < $lentenW5 ) {
        return ref($tt) ? $tt->{lentenw4} : 9;
    }
    elsif ( $today >= $lentenW5 && $today < $lentenW6 ) {
        return ref($tt) ? $tt->{lentenw5} : 11;
    }
    elsif ( $today >= $lentenW6 && $today < $lentenW7 ) {
        return ref($tt) ? $tt->{lentenw6} : 13;
    }
    elsif ( $today >= $lentenW7 && $today < $lentenEnd ) {
        return ref($tt) ? $tt->{lentenw7} : 15;
    }
    else {
        return ref($tt) ? $tt->{lentenend} : 16;
    }
}

sub IsSeasonStrongBeerFestival($$;$$) {
    my ( $d, $m, $y, $lang ) = @_;

    my $now   = gettimeofday();
    my $today = timegm_modern( 0, 0, 0, $d, $m - 1.,
        ( defined($y) ? $y : ( localtime($now) )[5] + 1900. ) );

    my $josef = timegm_modern( 0, 0, 0, 19, 2,
        ( defined($y) ? $y : ( localtime($now) )[5] + 1900. ) );
    my ( $secJ, $minJ, $hourJ, $dayJ, $monthJ, $yearJ, $wdayJ, $ydayJ, $isdstJ )
      = localtime($josef);

    my $sbeerBegin = $josef - 86400. * $wdayJ - 86400. * 2.;
    my $sbeerEnd   = $sbeerBegin + 86400. * 23.;

    return 0 unless ( $today >= $sbeerBegin && $today <= $sbeerEnd );

    if ($lang) {
        if ( exists( $transtable{ uc($lang) } ) ) {
            $tt = $transtable{ uc($lang) };
        }
        else {
            $tt = $transtable{EN};
        }
    }

    if ( $today == $sbeerBegin ) {
        return ref($tt) ? $tt->{sbeerseasonbegin} : 2;
    }
    else {
        return ref($tt) ? $tt->{sbeerseason} : 1;
    }
}

sub IsSeasonTurnOfTheYear($$;$$) {
    my ( $d, $m, $y, $lang ) = @_;

    my $now   = gettimeofday();
    my $today = timegm_modern( 0, 0, 0, $d, $m - 1,
        ( defined($y) ? $y : ( localtime($now) )[5] + 1900. ) );
    my $turnbegin = timegm_modern( 0, 0, 0, 27, 11,
        ( defined($y) ? $y : ( localtime($now) )[5] + 1900. ) );
    my $newyearseve = $turnbegin + 86400. * 4.;
    my $newyear     = timegm_modern( 0, 0, 0, 1, 0,
        ( defined($y) ? $y : ( localtime($now) )[5] + 1900. ) );
    my $turnend = $newyear + 86400. * 5.;

    return 0
      unless ( ( $today >= $turnbegin && $today <= $newyearseve )
        || ( $today >= $newyear && $today <= $turnend ) );

    if ($lang) {
        if ( exists( $transtable{ uc($lang) } ) ) {
            $tt = $transtable{ uc($lang) };
        }
        else {
            $tt = $transtable{EN};
        }
    }

    if ( $today == $newyearseve ) {
        return ref($tt) ? $tt->{newyearseve} : 2;
    }
    elsif ( $today == $newyear ) {
        return ref($tt) ? $tt->{newyear} : 3;
    }
    else {
        return ref($tt) ? $tt->{turnoftheyear} : 1;
    }
}

sub IsSeasonOktoberfest($$;$$) {
    my ( $d, $m, $y, $lang ) = @_;

    my $now   = gettimeofday();
    my $today = timegm_modern( 0, 0, 0, $d, $m - 1.,
        ( defined($y) ? $y : ( localtime($now) )[5] + 1900. ) );

    my $midsept = timegm_modern( 0, 0, 0, 15, 8,
        ( defined($y) ? $y : ( localtime($now) )[5] + 1900. ) );
    my ( $secS, $minS, $hourS, $dayS, $monthS, $yearS, $wdayS, $ydayS, $isdstS )
      = localtime($midsept);
    my $oct1st = timegm_modern( 0, 0, 0, 1, 9,
        ( defined($y) ? $y : ( localtime($now) )[5] + 1900. ) );
    my ( $secO, $minO, $hourO, $dayO, $monthO, $yearO, $wdayO, $ydayO, $isdstO )
      = localtime($oct1st);
    my $oct3rd = timegm_modern( 0, 0, 0, 3, 9,
        ( defined($y) ? $y : ( localtime($now) )[5] + 1900. ) );

    my $oktoberfestBegin =
        $wdayS == 6.
      ? $midsept + 86400. * 7.
      : $midsept + 86400. * ( 7. - $wdayS ) - 86400.;
    my $oktoberfestEnd = $oct1st + 86400. * ( 7. - $wdayO );
    $oktoberfestEnd = $oct3rd if ( $wdayO == 0. || $wdayO == 6. );

    return 0
      unless ( $today >= $oktoberfestBegin && $today <= $oktoberfestEnd );

    if ($lang) {
        if ( exists( $transtable{ uc($lang) } ) ) {
            $tt = $transtable{ uc($lang) };
        }
        else {
            $tt = $transtable{EN};
        }
    }

    if ( $today == $oktoberfestBegin ) {
        return ref($tt) ? $tt->{oktoberfestbegin} : 2;
    }
    else {
        return ref($tt) ? $tt->{oktoberfestseason} : 1;
    }
}

sub AddToSchedule {
    my ( $h, $e, $n ) = @_;
    return unless ( defined($e) );
    chomp($n);
    $n = trim($n);
    if ( $e =~ m/^\d+(?:\.\d+)?$/ ) {
        push @{ $h->{".schedule"}{$e} }, $n
          unless ( grep( m/^$n$/i, @{ $h->{".schedule"}{$e} } ) );
    }
    elsif ( $e eq '*' ) {
        push @{ $h->{".scheduleAllday"} },
          $n
          unless (
            grep( m/^$n$/i, @{ $h->{".scheduleAllday"} } )
            || (   $n ne 'Halloween'
                && defined( $h->{'.SeasonSocial'} )
                && grep( m/^$n$/i, @{ $h->{'.SeasonSocial'} } ) )
          );
    }
    elsif ( $e eq '?' ) {
        push @{ $h->{".scheduleDay"} }, $n
          unless ( grep( m/^$n$/i, @{ $h->{".scheduleDay"} } ) );
    }
    elsif ( $e =~ /^t(.+)/ ) {
        my $t = $1;
        $t = 0. unless ( $t =~ /^\d/ );
        push @{ $h->{".scheduleTom"}{$t} }, $n
          unless ( grep( m/^$n$/i, @{ $h->{".scheduleTom"}{$t} } ) );
    }
    elsif ( $e =~ /^y(.+)/ ) {
        my $t = $1;
        $t = 24. unless ( $t =~ /^\d/ );
        $h->{".scheduleYest"}{$t} = $n;
    }
}

sub GetWesternEaster(;$) {
    my ($year) = @_;
    $year = ( localtime( gettimeofday() ) )[5] + 1900.
      unless ( defined($year) );
    my $golden_number = $year % 19.;

    #quasicentury is so named because its a century, only its
    # the number of full centuries rather than the current century
    my $quasicentury = int( $year / 100. );
    my $epact =
      ( $quasicentury -
          int( $quasicentury / 4. ) -
          int( ( $quasicentury * 8. + 13. ) / 25. ) +
          ( $golden_number * 19. ) +
          15. )
      % 30.;

    my $interval =
      $epact -
      int( $epact / 28. ) *
      ( 1. -
          int( 29. / ( $epact + 1. ) ) *
          int( ( 21. - $golden_number ) / 11. ) );
    my $weekday =
      ( $year +
          int( $year / 4. ) +
          $interval + 2. -
          $quasicentury +
          int( $quasicentury / 4. ) )
      % 7;

    my $offset = $interval - $weekday;
    my $month  = 3. + int( ( $offset + 40. ) / 44. );
    my $day    = $offset + 28. - 31. * int( $month / 4. );

    return wantarray
      ? ( $month, $day )
      : timegm_modern( 0, 0, 0, $day, $month - 1, $year );
}

sub Update($@) {
    my ($hash) = @_;

    my $name = $hash->{NAME};
    RemoveInternalTimer($hash);
    delete $hash->{NEXTUPDATE};

    return undef if ( IsDisabled($name) );

    my $AstroDevice = AttrVal( $name, "AstroDevice", "" );
    my $tz = AttrVal(
        $name,
        "timezone",
        AttrVal(
            $AstroDevice, "timezone",
            AttrVal( "global", "timezone", undef )
        )
    );
    my $lang = AttrVal(
        $name,
        "language",
        AttrVal(
            $AstroDevice, "language",
            AttrVal( "global", "language", undef )
        )
    );
    my $lc_time = AttrVal(
        $name,
        "lc_time",
        AttrVal(
            $AstroDevice,
            "lc_time",
            AttrVal(
                "global", "lc_time",
                ( $lang ? lc($lang) . "_" . uc($lang) . ".UTF-8" : undef )
            )
        )
    );
    my $now = gettimeofday();    # conserve timestamp before recomputing

    SetTime( undef, $tz, $lc_time );
    Compute($hash);

    my @next;

    # add regular update interval time
    push @next, $now + $hash->{INTERVAL}
      if ( defined( $hash->{INTERVAL} ) && $hash->{INTERVAL} > 0 );

    # add event times
    foreach my $comp (
        defined( $hash->{RECOMPUTEAT} )
        ? split( ',', $hash->{RECOMPUTEAT} )
        : ()
      )
    {
        if ( $comp eq 'NewDay' ) {
            push @next,
              timelocal_modern(
                0, 0, 0,
                ( localtime( $now + 86400. ) )[ 3, 4 ],
                ( localtime( $now + 86400. ) )[5] + 1900.
              );
            next;
        }
        my $k = ".$comp";
        $k = '.DaySeasonalHrNextT' if ( $comp eq 'SeasonalHr' );
        my $t;
        if ( defined( $Schedule{$k} )
            && $Schedule{$k} =~ /^\d+(?:\.\d+)?$/ )
        {
            $t = timelocal_modern(
                0, 0, 0,
                ( localtime($now) )[ 3, 4 ],
                ( localtime($now) )[5] + 1900.
              ) +
              $Schedule{$k} * 3600.;
            $t += 86400. if ( $t < $now );    # that is for tomorrow
        }
        elsif ( defined( $Astro{$k} ) && $Astro{$k} =~ /^\d+(?:\.\d+)?$/ ) {
            $t = timelocal_modern(
                0, 0, 0,
                ( localtime($now) )[ 3, 4 ],
                ( localtime($now) )[5] + 1900.
              ) +
              $Astro{$k} * 3600.;
            $t += 86400. if ( $t < $now );    # that is for tomorrow
        }
        else {
            next;
        }
        push @next, $t;
    }

    # set timer for next update
    if (@next) {
        my $n = minNum( $next[0], @next );
        $hash->{NEXTUPDATE} = FmtDateTime($n);
        InternalTimer( $n, "FHEM::DaySchedule::Update", $hash, 1 );
    }

    readingsBeginUpdate($hash);
    unless ( IsDevice( $AstroDevice, "Astro" ) ) {
        foreach my $key ( keys %Astro ) {
            next if ( ref( $Astro{$key} ) );
            readingsBulkUpdateIfChanged( $hash, $key,
                encode_utf8( $Astro{$key} ) )
              if ( defined( $Astro{$key} ) && $Astro{$key} ne "" );
        }
    }
    delete $hash->{READINGS}{SeasonPheno}
      unless ( defined( $Schedule{SeasonPheno} ) );
    delete $hash->{READINGS}{SeasonPhenoN}
      unless ( defined( $Schedule{SeasonPhenoN} ) );
    delete $hash->{READINGS}{DayChangeSeasonPheno}
      unless ( defined( $Schedule{DayChangeSeasonPheno} ) );
    foreach my $key ( keys %Schedule ) {
        next if ( ref( $Schedule{$key} ) );
        readingsBulkUpdateIfChanged( $hash, $key,
            encode_utf8( $Schedule{$key} ) )
          if ( defined( $Schedule{$key} ) && $Schedule{$key} ne "" );
    }
    readingsEndUpdate( $hash, 1 );
    readingsSingleUpdate( $hash, "state", "Updated", 1 );
}

1;

=pod
=encoding utf8
=item helper
=item summary Schedule for daily events, based on calendar data and astronomical data
=item summary_DE Ablaufplan für tägliche Events, basierend auf astronomischen und kalendarischen Daten
=begin html

    <a name="DaySchedule" id="DaySchedule"></a>
    <h3>
      DaySchedule
    </h3>
    <ul>
      <p>
        FHEM module with a collection of various routines for astronomical data
      </p><a name="DayScheduledefine" id="DayScheduledefine"></a>
      <h4>
        Define
      </h4>
      <p>
        <code>define &lt;name&gt; DaySchedule</code><br>
        Defines the DaySchedule device.
      </p>
      <p>
        Readings with prefix <i>Sun</i>, <i>Moon</i>, <i>Obs</i> as well as the <i>*Twilight*</i> readings are provided by the Astro module and will only be shown as part of a DaySchedule device if no AstroDevice attribute was set. Some readings with the same prefix are added by the DaySchedule module, these readings are:
      </p>
      <ul>
        <li>
          <i>Compass,CompassI,CompassS</i> = Azimuth as point of the compass
          <i>TimeR</i> = Time in roman format
        </li>
      </ul>
      <p>
        Readings with prefix <i>Day</i> refer to the current day, with prefix <i>Week</i> refer to the current week, with prefix <i>Month</i> refer to the current month and with prefix <i>Year</i> refer to the current year. The suffixes for these readings are:
      </p>
      <ul>
        <li>
          <i>Changed*</i> = Change indicators. Value is 2 the day before the change is going to take place, 1 at the day the change has occurred.
        </li>
        <li><i>YearRemainD,YearProgress,MonthRemainD,MonthProgress</i> = progress throughout month and year</li>
        <li><i>Daytime,DaytimeN</i> = String and numerical (0..23) value of relative daytime/nighttime, based on SeasonalHr. Counting begins after sunset.</li>
        <li>
          <i>SeasonalHrLenDay,SeasonalHrLenNight</i> = Length of a single seasonal hour during sunlight and nighttime as defined by SeasonalHrsDay and SeasonalHrsNight
        </li>
        <li>
          <i>SeasonalHr,DaySeasonalHrR,SeasonalHrsDay,SeasonalHrsNight</i> = Current and total seasonal hours of a full day. Values for SeasonalHr will be between -12 and 12 (actual range depends on the definition of SeasonalHrsDay and SeasonalHrsNight), but will never be 0. Positive values will occur between sunrise and sunset while negative values will occur during nighttime. Numbers will always be counting upwards, for example from 1 to 12 during daytime and from -12 to -1 during nighttime. That way switching between daytime&lt;&gt;nighttime means only to change the algebraic sign from -1 to 1 and 12 to -12 respectively.
        </li>
        <li>
          <i>SeasonalHrTNext,SeasonalHrT*</i> Calculated times for the beginning of the respective seasonal hour. SeasonalHrTNext will be set for the next upcoming seasonal hour. Hours that are in the past for today will actually show times for the next calendar day.
        </li>
        <li>
          <i>SchedLast,SchedLastT,SchedNext,SchedNextT</i> = Last/current event and next event
        </li>
        <li>
          <i>SchedRecent,SchedUpcoming</i> = List of recent and upcoming events today. SchedUpcoming includes the very first events at 00:00:00 of the next day at the end.
        </li>
        <li>
          <i>SeasonMeteo,SeasonMeteoN</i> = String and numerical (0..3) value of meteorological season
        </li>
        <li>
          <i>SeasonPheno,SeasonPhenoN</i> = String and numerical (0..9) value of phenological season
        </li>
        <li>
          <i>IsLY</i> = 1 if the year is a leap year, 0 otherwise
        </li>
        <li><i>Weekofyear,YearRemainD,YearProgress,MonthRemainD,MonthProgress</i> = date</li>
      </ul>
      <p>
        Notes:
      </p>
      <ul>
        <li>Pay attention to notes described in the Astro module as they are to be considered for this module as well.
        </li>
        <li>The phenological season will only be estimated if the observers position is located in Central Europe. Due to its definition, a phenological season cannot be strictly calculated. It is not supposed to be 100% accurate and therefore not to be used for agrarian purposes but should be close enough for other home automations like heating, cooling, shading, etc.
        </li>
        <li>As the relative daytime is based on temporal hours, it can only be emerged if SeasonalHrs is set to 12 (which is the default setting).
        </li>
        <li>It is not necessary to define a DaySchedule device to use the data provided by this or the Astro module.<br>
          To use its data in any other module, you just need to put <code>require "95_DaySchedule.pm";</code><br>
          at the start of your own code, and then may call, for example, the function<br>
          <ul>
            <code>DaySchedule_Get( SOME_HASH_REFERENCE,"dummy","text", "SunRise","2019-12-24");</code>
          </ul>to acquire the sunrise on Christmas Eve 2019. The hash reference may also be undefined or an existing device name of any type. Note that device attributes of the respective device will be respected as long as their name matches those mentioned for an DaySchedule device. attribute=value pairs may be added in text format to enforce settings like language that would otherwise be defined by a real device.
        </li>
      </ul><a name="DayScheduleset" id="DayScheduleset"></a>
      <h4>
        Set
      </h4>
      <ul>
        <li>
          <a name="DaySchedule_update" id="DaySchedule_update"></a> <code>set &lt;name&gt; update</code><br>
          trigger to recompute values immediately.
        </li>
      </ul><a name="DayScheduleget" id="DayScheduleget"></a>
      <h4>
        Get
      </h4>Attention: Get-calls are NOT written into the readings of the device. Readings change only through periodic updates.<br>
      <ul>
        <li>
          <a name="DaySchedule_json" id="DaySchedule_json"></a> <code>get &lt;name&gt; json [&lt;reading&gt;] [-1|yesterday|+1|tomorrow]</code><br>
          <code>get &lt;name&gt; json [&lt;reading&gt;] YYYY-MM-DD [-1|yesterday|+1|tomorrow]</code><br>
          <code>get &lt;name&gt; json [&lt;reading&gt;] HH:MM[:SS] [-1|yesterday|+1|tomorrow]</code><br>
          <code>get &lt;name&gt; json [&lt;reading&gt;] YYYY-MM-DD HH:MM[:SS] [-1|yesterday|+1|tomorrow]</code><br>
          returns the complete set of an individual reading of day schedule related data either for the current time, or for a day and time given in the argument. <code>yesterday</code>, <code>tomorrow</code> or any other integer number may be given at the end to get data relative to the given day and time.
        </li>
        <li>
          <a name="DaySchedule_text" id="DaySchedule_text"></a> <code>get &lt;name&gt; text [&lt;reading&gt;] [-1|yesterday|+1|tomorrow]</code><br>
          <code>get &lt;name&gt; text [&lt;reading&gt;] YYYY-MM-DD [-1|yesterday|+1|tomorrow]</code><br>
          <code>get &lt;name&gt; text [&lt;reading&gt;] HH:MM[:SS] [-1|yesterday|+1|tomorrow]</code><br>
          <code>get &lt;name&gt; text [&lt;reading&gt;] YYYY-MM-DD HH:MM[:SS] [-1|yesterday|+1|tomorrow]</code><br>
          returns the complete set of an individual reading of day schedule related data either for the current time, or for a day and time given in the argument. <code>yesterday</code>, <code>tomorrow</code> or any other integer number may be given at the end to get data relative to the given day and time.
        </li>
        <li>
          <a name="DaySchedule_version" id="DaySchedule_version"></a> <code>get &lt;name&gt; version</code><br>
          Display the version of the module
        </li>
      </ul><a name="DayScheduleattr" id="DayScheduleattr"></a>
      <h4>
        Attributes
      </h4>
      <ul>
        <li>
          <a name="DaySchedule_AstroDevice" id="DaySchedule_AstroDevice"></a> <code>&lt;AstroDevice&gt;</code><br>
          May link to an existing Astro device to calculate astronomic data, otherwise the calculation will be handled internally. Readings provided by the Astro device will only be created for the DaySchedule device if no Astro device was referenced.
        </li>
        <li>
          <a name="DaySchedule_Earlyfall" id="DaySchedule_Earlyfall"></a> <code>&lt;Earlyfall&gt;</code><br>
          The early beginning of fall will set a marker to calculate all following phenological seasons until winter time. This defaults to 08-20 to begin early fall on August 20th.
        </li>
        <li>
          <a name="DaySchedule_Earlyspring" id="DaySchedule_Earlyspring"></a> <code>&lt;Earlyspring&gt;</code><br>
          The early beginning of spring will set a marker to calculate all following phenological seasons until summer time. This defaults to 02-22 to begin early spring on February 22nd.
        </li>
        <li>
          <a name="DaySchedule_interval" id="DaySchedule_interval"></a> <code>&lt;interval&gt;</code><br>
          Update interval in seconds. The default is 3600 seconds, a value of 0 disables the periodic update.
        </li>
        <li>
          <a name="DaySchedule_language" id="DaySchedule_language"></a> <code>&lt;language&gt;</code><br>
          A language may be set to overwrite global attribute settings.
        </li>
        <li>
          <a name="DaySchedule_recomputeAt" id="DaySchedule_recomputeAt"></a> <code>&lt;recomputeAt&gt;</code><br>
          Enforce recomputing values at specific event times, independant from update interval. This attribute contains a list of one or many of the following values:<br>
          <ul>
            <li>
              <i>MoonRise,MoonSet,MoonTransit</i> = for moon rise, set, and transit
            </li>
            <li>
              <i>NewDay</i> = for 00:00:00 hours of the next calendar day (some people may say midnight)
            </li>
            <li>
              <i>SeasonalHr</i> = for the beginning of every seasonal hour
            </li>
            <li>
              <i>SunRise,SunSet,SunTransit</i> = for sun rise, set, and transit
            </li>
            <li>
              <i>*TwilightEvening,*TwilightMorning</i> = for the respective twilight stage begin
            </li>
          </ul>
        </li>
        <li>
          <a name="DaySchedule_schedule" id="DaySchedule_schedule"></a> <code>&lt;schedule&gt;</code><br>
          Define which events will be part of the schedule list. A full schedule will be generated if this attribute was not specified. This also controls the value of Sched* readings.
        </li>
        <li>
          <a name="DaySchedule_SeasonalHrs" id="DaySchedule_SeasonalHrs"></a> <code>&lt;SeasonalHrs&gt;</code><br>
          Number of total seasonal hours to divide daylight time and nighttime into (day parts). It controls the calculation of reading DaySeasonalHr throughout a full day. The default value is 12 which corresponds to the definition of temporal hours. In case the amount of hours during nighttime shall be different, they can be defined as <code>&lt;dayHours&gt;:&lt;nightHours&gt;</code>. A value of '4' will enforce historic roman mode with implicit 12:4 settings but the Daytime to be reflected in latin notation. Defining a value of 12:4 directly will still show regular daytimes during daytime. Defining *:4 nighttime parts will always calculate Daytime in latin notation during nighttime, independent from daytime settings.
        </li>
        <li>
          <a name="DaySchedule_timezone" id="DaySchedule_timezone"></a> <code>&lt;timezone&gt;</code><br>
          A timezone may be set to overwrite global and system settings. Format may depend on your local system implementation but is likely in the format similar to <code>Europe/Berlin</code>.
        </li>
        <li>Some definitions determining the observer position:<br>
          <ul>
            <code>attr &lt;name&gt; longitude &lt;value&gt;</code><br>
            <code>attr &lt;name&gt; latitude &lt;value&gt;</code><br>
            <code>attr &lt;name&gt; altitude &lt;value&gt;</code>(in m above sea level)<br>
            <code>attr &lt;name&gt; horizon &lt;value&gt;</code>custom horizon angle in degrees, default 0. Different values for morning/evening may be set as <code>&lt;morning&gt;:&lt;evening&gt;</code>
          </ul>These definitions take precedence over global attribute settings.
        </li>
        <li>
          <a name="DaySchedule_disable" id="DaySchedule_disable"></a> <code>&lt;disable&gt;</code><br>
          When set, this will completely disable any device update.
        </li>
      </ul>
    </ul>

=end html
=begin html_DE

<a name="DaySchedule"></a>
<h3>DaySchedule</h3>
<ul>
  Leider keine deutsche Dokumentation vorhanden. Die englische Version gibt es
  hier: <a href='commandref.html#DaySchedule'>DaySchedule</a><br/>
</ul>

=end html_DE
=for :application/json;q=META.json 95_DaySchedule.pm
{
  "version": "v0.0.1",
  "author": [
    "Julian Pawlowski <julian.pawlowski@gmail.com>"
  ],
  "x_fhem_maintainer": [
    "loredo"
  ],
  "keywords": [
    "date",
    "dawn",
    "dusk",
    "season",
    "time",
    "twilight",
    "Dämmerung",
    "Datum",
    "Jahreszeit",
    "Uhrzeit"
  ],
  "prereqs": {
    "runtime": {
      "requires": {
        "Encode": 0,
        "FHEM::Astro": 0,
        "GPUtils": 0,
        "POSIX": 0,
        "Time::HiRes": 0,
        "Time::Local": 0,
        "UConv": 0,
        "locale": 0,
        "strict": 0,
        "utf8": 0,
        "warnings": 0
      },
      "recommends": {
        "JSON": 0
      },
      "suggests": {
        "Cpanel::JSON::XS": 0,
        "JSON::XS": 0
      }
    }
  }
}
=end :application/json;q=META.json
=cut
