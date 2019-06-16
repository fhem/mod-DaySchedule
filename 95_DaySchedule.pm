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
use GPUtils qw(GP_Import);
use Time::HiRes qw(gettimeofday);
use Time::Local;
use UConv;
use Data::Dumper;

require "95_Astro.pm" unless ( defined( *{"main::Astro_Initialize"} ) );

my %Astro;
my %Schedule;
my %Date;

our $VERSION = "v0.0.1";

my %sets = ( "update" => "noArg", );

my %gets = (
    "json"     => undef,
    "schedule" => undef,
    "text"     => undef,
    "version"  => undef,
);

my %attrs = (
    "altitude"    => undef,
    "AstroDevice" => undef,
    "disable"     => "1,0",
    "earlyfall"   => undef,
    "earlyspring" => undef,
    "horizon"     => undef,
    "interval"    => undef,
    "language"    => "EN,DE,ES,FR,IT,NL,PL",
    "latitude"    => undef,
    "lc_numeric" =>
"en_EN.UTF-8,de_DE.UTF-8,es_ES.UTF-8,fr_FR.UTF-8,it_IT.UTF-8,nl_NL.UTF-8,pl_PL.UTF-8",
    "lc_time" =>
"en_EN.UTF-8,de_DE.UTF-8,es_ES.UTF-8,fr_FR.UTF-8,it_IT.UTF-8,nl_NL.UTF-8,pl_PL.UTF-8",
    "longitude" => undef,
    "recomputeAt" =>
"multiple-strict,MoonRise,MoonSet,MoonTransit,NewDay,SeasonalHr,SunRise,SunSet,SunTransit,AstroTwilightEvening,AstroTwilightMorning,CivilTwilightEvening,CivilTwilightMorning,CustomTwilightEvening,CustomTwilightMorning",
    "schedule" =>
"multiple-strict,MoonPhaseS,MoonRise,MoonSet,MoonSign,MoonTransit,ObsDate,ObsIsDST,SeasonMeteo,SeasonPheno,ObsSeason,DaySeasonalHr,Daytime,SunRise,SunSet,SunSign,SunTransit,AstroTwilightEvening,AstroTwilightMorning,CivilTwilightEvening,CivilTwilightMorning,NauticTwilightEvening,NauticTwilightMorning,CustomTwilightEvening,CustomTwilightMorning",
    "seasonalHrs" => undef,
    "timezone"    => undef,
);

my $json;
my $tt;
my $astrott;

# Export variables to other programs
our %transtable = (
    EN => {
        "direction"  => "Direction",
        "duskcivil"  => "Civil dusk",
        "dusknautic" => "Nautic dusk",
        "duskastro"  => "Astronomical dusk",
        "duskcustom" => "Custom dusk",
        "dawncivil"  => "Civil dawn",
        "dawnnautic" => "Nautic dawn",
        "dawnastro"  => "Astronomical dawn",
        "dawncustom" => "Custom dawn",
        "leapyear"   => "leap year",

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
        "daysremaining" => "days remaining",
        "dayremaining"  => "day remaining",

        #
        "metseason" => "Meteorological Season",

        #
        "phenseason"  => "Phenological Season",
        "earlyspring" => "Early Spring",
        "firstspring" => "First Spring",
        "fullspring"  => "Full Spring",
        "earlysummer" => "Early Summer",
        "midsummer"   => "Midsummer",
        "latesummer"  => "Late Summer",
        "earlyfall"   => "Early Fall",
        "fullfall"    => "Full Fall",
        "latefall"    => "Late Fall",
    },

    DE => {
        "direction"  => "Richtung",
        "duskcivil"  => "Bürgerliche Abenddämmerung",
        "dusknautic" => "Nautische Abenddämmerung",
        "duskastro"  => "Astronomische Abenddämmerung",
        "duskcustom" => "Konfigurierte Abenddämmerung",
        "dawncivil"  => "Bürgerliche Morgendämmerung",
        "dawnnautic" => "Nautische Morgendämmerung",
        "dawnastro"  => "Astronomische Morgendämmerung",
        "dawncustom" => "Konfigurierte Morgendämmerung",
        "leapyear"   => "Schaltjahr",

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
        "beforemidnight"    => "Vor-Mitternacht",
        "midnight"          => "Mitternacht",
        "aftermidnight"     => "Nach-Mitternacht",
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
        "daysremaining" => "Tage verbleibend",
        "dayremaining"  => "Tag verbleibend",

        #
        "metseason" => "Meteorologische Jahreszeit",

        #
        "phenseason"  => "Phänologische Jahreszeit",
        "earlyspring" => "Vorfrühling",
        "firstspring" => "Erstfrühling",
        "fullspring"  => "Vollfrühling",
        "earlysummer" => "Frühsommer",
        "midsummer"   => "Hochsommer",
        "latesummer"  => "Spätsommer",
        "earlyfall"   => "Frühherbst",
        "fullfall"    => "Vollherbst",
        "latefall"    => "Spätherbst",
    },

    ES => {
        "direction"  => "Dirección",
        "duskcivil"  => "Oscuridad civil",
        "dusknautic" => "Oscuridad náutico",
        "duskastro"  => "Oscuridad astronómico",
        "duskcustom" => "Oscuridad personalizado",
        "dawncivil"  => "Amanecer civil",
        "dawnnautic" => "Amanecer náutico",
        "dawnastro"  => "Amanecer astronómico",
        "dawncustom" => "Amanecer personalizado",
        "leapyear"   => "año bisiesto",

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
        "daysremaining" => "Días restantes",
        "dayremaining"  => "Día restante",

        #
        "metseason" => "Temporada Meteorológica",

        #
        "phenseason"  => "Temporada Fenologica",
        "earlyspring" => "Inicio de la primavera",
        "firstspring" => "Primera primavera",
        "fullspring"  => "Primavera completa",
        "earlysummer" => "Comienzo del verano",
        "midsummer"   => "Pleno verano",
        "latesummer"  => "El verano pasado",
        "earlyfall"   => "Inicio del otoño",
        "fullfall"    => "Otoño completo",
        "latefall"    => "Finales de otoño",
    },

    FR => {
        "direction"  => "Direction",
        "duskcivil"  => "Crépuscule civil",
        "dusknautic" => "Crépuscule nautique",
        "duskastro"  => "Crépuscule astronomique",
        "duskcustom" => "Crépuscule personnalisé",
        "dawncivil"  => "Aube civil",
        "dawnnautic" => "Aube nautique",
        "dawnastro"  => "Aube astronomique",
        "dawncustom" => "Aube personnalisé",
        "leapyear"   => "année bissextile",

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
        "daysremaining" => "jours restant",
        "dayremaining"  => "jour restant",

        #
        "metseason" => "Saison Météorologique",

        #
        "phenseason"  => "Saison Phénologique",
        "earlyspring" => "Avant du printemps",
        "firstspring" => "Début du printemps",
        "fullspring"  => "Printemps",
        "earlysummer" => "Avant de l'été",
        "midsummer"   => "Milieu de l'été",
        "latesummer"  => "Fin de l'été",
        "earlyfall"   => "Avant de l'automne",
        "fullfall"    => "Automne",
        "latefall"    => "Fin de l'automne",
    },

    IT => {
        "direction"  => "Direzione",
        "duskcivil"  => "Crepuscolo civile",
        "dusknautic" => "Crepuscolo nautico",
        "duskastro"  => "Crepuscolo astronomico",
        "duskcustom" => "Crepuscolo personalizzato",
        "dawncivil"  => "Alba civile",
        "dawnnautic" => "Alba nautico",
        "dawnastro"  => "Alba astronomico",
        "dawncustom" => "Alba personalizzato",
        "leapyear"   => "anno bisestile",

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
        "daysremaining" => "giorni rimanenti",
        "dayremaining"  => "giorno rimanente",

        #
        "metseason" => "Stagione Meteorologica",

        #
        "phenseason"  => "Stagione Fenologica",
        "earlyspring" => "Inizio primavera",
        "firstspring" => "Prima primavera",
        "fullspring"  => "Piena primavera",
        "earlysummer" => "Inizio estate",
        "midsummer"   => "Mezza estate",
        "latesummer"  => "Estate inoltrata",
        "earlyfall"   => "Inizio autunno",
        "fullfall"    => "Piena caduta",
        "latefall"    => "Tardo autunno",
    },

    NL => {
        "direction"  => "Richting",
        "duskcivil"  => "Burgerlijke Schemering",
        "dusknautic" => "Nautische Schemering",
        "duskastro"  => "Astronomische Schemering",
        "duskcustom" => "Aangepaste Schemering",
        "dawncivil"  => "Burgerlijke Dageraad",
        "dawnnautic" => "Nautische Dageraad",
        "dawnastro"  => "Astronomische Dageraad",
        "dawncustom" => "Aangepaste Dageraad",
        "leapyear"   => "Schrikkeljaar",

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
        "daysremaining" => "resterende Dagen",
        "dayremaining"  => "resterende Dag",

        #
        "metseason" => "Meteorologisch Seizoen",

        #
        "phenseason"  => "Fenologisch Seizoen",
        "earlyspring" => "Vroeg Voorjaar",
        "firstspring" => "Eerste Voorjaar",
        "fullspring"  => "Voorjaar",
        "earlysummer" => "Vroeg Zomer",
        "midsummer"   => "Zomer",
        "latesummer"  => "Laat Zomer",
        "earlyfall"   => "Vroeg Herfst",
        "fullfall"    => "Herfst",
        "latefall"    => "Laat Herfst",
    },

    PL => {
        "direction"  => "Kierunek",
        "duskcivil"  => "Zmierzch cywilny",
        "dusknautic" => "Zmierzch morski",
        "duskastro"  => "Zmierzch astronomiczny",
        "duskcustom" => "Zmierzch niestandardowy",
        "dawncivil"  => "świt cywilny",
        "dawnnautic" => "świt morski",
        "dawnastro"  => "świt astronomiczny",
        "dawncustom" => "świt niestandardowy",
        "leapyear"   => "rok przestępny",

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
        "daysremaining" => "pozostało dni",
        "dayremaining"  => "pozostały dzień",

        #
        "metseason" => "Sezon Meteorologiczny",

        #
        "phenseason"  => "Sezon Fenologiczny",
        "earlyspring" => "Wczesna wiosna",
        "firstspring" => "Pierwsza wiosna",
        "fullspring"  => "Pełna wiosna",
        "earlysummer" => "Wczesne lato",
        "midsummer"   => "Połowa lata",
        "latesummer"  => "Późne lato",
        "earlyfall"   => "Wczesna jesień",
        "fullfall"    => "Pełna jesień",
        "latefall"    => "Późną jesienią",
    }
);

our %readingsLabel = (
    "AstroTwilightEvening"  => [ "duskastro",  undef ],
    "AstroTwilightMorning"  => [ "dawnastro",  undef ],
    "CivilTwilightEvening"  => [ "duskcivil",  undef ],
    "CivilTwilightMorning"  => [ "dawncivil",  undef ],
    "CustomTwilightEvening" => [ "duskcustom", undef ],
    "CustomTwilightMorning" => [ "dawncustom", undef ],

    #
    "MoonAge"               => [ "age",               "°" ],
    "MoonAlt"               => [ "alt",               "°" ],
    "MoonAz"                => [ "az",                "°" ],
    "MoonCompass"           => [ "direction",         undef ],
    "MoonCompassI"          => [ "direction",         undef ],
    "MoonCompassS"          => [ "direction",         undef ],
    "MoonDec"               => [ "dec",               "°" ],
    "MoonDiameter"          => [ "diameter",          "'" ],
    "MoonDistance"          => [ "distance toce",     "km" ],
    "MoonDistanceObserver"  => [ "distance toobs",    "km" ],
    "MoonHrsVisible"        => [ "hoursofvisibility", "h" ],
    "MoonLat"               => [ "latitude",          "°" ],
    "MoonLon"               => [ "longitude",         "°" ],
    "MoonPhaseI"            => [ "phase",             undef ],
    "MoonPhaseN"            => [ "progress",          "%" ],
    "MoonPhaseS"            => [ "phase",             undef ],
    "MoonRa"                => [ "ra",                "h" ],
    "MoonRise"              => [ "rise",              undef ],
    "MoonSet"               => [ "set",               undef ],
    "MoonSign"              => [ "sign",              undef ],
    "MoonTransit"           => [ "transit",           undef ],
    "NauticTwilightEvening" => [ "dusknautic",        undef ],
    "NauticTwilightMorning" => [ "dawnnautic",        undef ],

    #
    "ObsAlt"        => [ "altitude",    "m" ],
    "ObsDate"       => [ "date",        undef ],
    "ObsDayofyear"  => [ "dayofyear",   "day", 1 ],
    "Daytime"       => [ "dayphase",    undef ],
    "DaytimeN"      => [ "dayphase",    undef ],
    "ObsIsDST"      => [ "dst",         undef ],
    "YearIsLY"      => [ "leapyear",    undef ],
    "ObsJD"         => [ "jdate",       undef ],
    "ObsLat"        => [ "latitude",    "°" ],
    "ObsLMST"       => [ "lmst",        undef ],
    "ObsLon"        => [ "longitude",   "°" ],
    "SeasonMeteo"   => [ "metseason",   undef ],
    "SeasonMeteoN"  => [ "metseason",   undef ],
    "MonthProgress" => [ "progress",    "%" ],
    "MonthRemainD"  => [ "remaining",   "1:day|days", 1 ],
    "SeasonPheno"   => [ "phenoseason", undef ],
    "SeasonPhenoN"  => [ "phenoseason", undef ],
    "ObsSeason"     => [ "season",      undef ],
    "DaySeasonalHr" =>
      [ "12(DaySeasonalHrsDay):temporalhour|seasonalhour", undef ],
    "DaySeasonalHrR" =>
      [ "12(DaySeasonalHrsDay):temporalhour|seasonalhour", undef ],
    "ObsSeasonN"   => [ "season",    undef ],
    "ObsTime"      => [ "time",      undef ],
    "ObsTimeR"     => [ "time",      undef ],
    "ObsTimezone"  => [ "timezone",  undef ],
    "Weekofyear"   => [ "week",      undef ],
    "YearProgress" => [ "progress",  "%" ],
    "YearRemainD"  => [ "remaining", "1:day|days", 1 ],

    #
    "SunAlt"              => [ "alt",             undef ],
    "SunAz"               => [ "az",              "°" ],
    "SunCompass"          => [ "direction",       undef ],
    "SunCompassI"         => [ "direction",       undef ],
    "SunCompassS"         => [ "direction",       undef ],
    "SunDec"              => [ "dec",             "°" ],
    "SunDiameter"         => [ "diameter",        "'" ],
    "SunDistance"         => [ "distance toce",   "km" ],
    "SunDistanceObserver" => [ "distance toobs",  "km" ],
    "SunHrsInvisible"     => [ "hoursofnight",    "h" ],
    "SunHrsVisible"       => [ "hoursofsunlight", "h" ],
    "SunLon"              => [ "longitude",       "°" ],
    "SunRa"               => [ "ra",              "h" ],
    "SunRise"             => [ "rise",            undef ],
    "SunSet"              => [ "set",             undef ],
    "SunSign"             => [ "sign",            undef ],
    "SunTransit"          => [ "transit",         undef ],
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

our @seasonsp = (
    "winter",      "earlyspring", "firstspring", "fullspring",
    "earlysummer", "midsummer",   "latesummer",  "earlyfall",
    "fullfall",    "latefall"
);

our %seasonppos = (
    earlyspring => [ 37.136633, -8.817837 ],    #South-West Portugal
    earlyfall   => [ 60.161880, 24.937267 ],    #South Finland / Helsinki
);

# Run before package compilation
BEGIN {

    # Import from main context
    GP_Import(
        qw(
          attr
          Astro_Get
          AttrVal
          data
          Debug
          defs
          deviceEvents
          FW_webArgs
          IsDevice
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
          toJSON
          )
    );
}

# Export to main context with different name
_Export(
    qw(
      Get
      Initialize
      )
);

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
    $hash->{AttrList} = join( " ",
        map { defined( $attrs{$_} ) ? "$_:$attrs{$_}" : $_ } sort keys %attrs )
      . " "
      . $readingFnAttributes;

    $hash->{parseParams} = 1;

    return undef;
}

sub Define ($@) {
    my ( $hash, $a, $h ) = @_;
    my $name = shift @$a;
    my $type = shift @$a;

    $hash->{VERSION}   = $VERSION;
    $hash->{NOTIFYDEV} = "global";
    $hash->{INTERVAL}  = 3600;
    readingsSingleUpdate( $hash, "state", "Initialized", $init_done );

    $modules{DaySchedule}{defptr}{$name} = $hash;

    # for the very first definition, set some default attributes
    if ( $init_done && !defined( $hash->{OLDDEF} ) ) {
        $attr{$name}{icon}        = 'time_calendar';
        $attr{$name}{recomputeAt} = 'NewDay,SeasonalHr';
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

            # disable modified at runtime
            $key eq "disable" and do {

                # check value
                return "$do $name attribute $key can only be 1 or 0"
                  unless ( $value =~ m/^(1|0)$/ );
                readingsSingleUpdate( $hash, "state",
                    $value ? "inactive" : "Initialized", $init_done );
            };

            # earlyfall modified at runtime
            $key eq "earlyfall" and do {

                # check value
                return
"$do $name attribute $key must be in format <month>-<day> while <month> can only be 08 or 09"
                  unless ( $value =~ m/^(0[8-9])-(0[1-9]|[12]\d|30|31)$/ );
            };

            # earlyspring modified at runtime
            $key eq "earlyspring" and do {

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

            # schedule modified at runtime
            $key eq "schedule" and do {
                my @skel = split( ',', $attrs{schedule} );
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

            # seasonalHrs modified at runtime
            $key eq "seasonalHrs" and do {

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
    else {
        return "$name with unknown argument $a->[0], choose one of "
          . join( " ",
            map { defined( $sets{$_} ) ? "$_:$sets{$_}" : $_ }
            sort keys %sets );
    }

    return "";
}

sub Get($@) {
    my ( $hash, $a, $h, @a ) = @_;
    my $name = "#APIcall";
    my $type = "dummy";

    # backwards compatibility for non-parseParams requests
    if ( !ref($a) ) {
        $hash = exists( $defs{$hash} ) ? $defs{$hash} : ()
          if ( $hash && !ref($hash) );
        unshift @a, $h;
        $h    = undef;
        $type = $a;
        $a    = \@a;
    }
    else {
        $type = shift @$a;
    }
    if ( defined( $hash->{NAME} ) ) {
        $name = $hash->{NAME};
    }
    else {
        $hash->{NAME} = $name;
    }

    my $wantsreading = 0;
    my $dayOffset    = 0;
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
    if ( ( int(@$a) > 1 ) ) {
        @readings = split( ',', $a->[1] );
        foreach (@readings) {
            if ( exists( $Schedule{$_} ) ) {
                $wantsreading = 1;
                last;
            }
            elsif ( exists( $Astro{$_} ) ) {
                $wantsreading = 1;
                last;
            }
        }
    }

    # last parameter may be indicating day offset
    if (
        (
            int(@$a) > 4 + $wantsreading
            && $a->[ 4 + $wantsreading ] =~
            /^\+?([-+]\d+|yesterday|tomorrow)$/i
        )
        || ( int(@$a) > 3 + $wantsreading
            && $a->[ 3 + $wantsreading ] =~
            /^\+?([-+]\d+|yesterday|tomorrow)$/i )
        || ( int(@$a) > 2 + $wantsreading
            && $a->[ 2 + $wantsreading ] =~
            /^\+?([-+]\d+|yesterday|tomorrow)$/i )
        || ( int(@$a) > 1 + $wantsreading
            && $a->[ 1 + $wantsreading ] =~
            /^\+?([-+]\d+|yesterday|tomorrow)$/i )
      )
    {
        $dayOffset = $1;
        pop @$a;
        $dayOffset = -1 if ( lc($dayOffset) eq "yesterday" );
        $dayOffset = 1  if ( lc($dayOffset) eq "tomorrow" );
    }

    if ( int(@$a) > ( 1 + $wantsreading ) ) {
        my $str =
          ( int(@$a) == ( 3 + $wantsreading ) )
          ? $a->[ 1 + $wantsreading ] . " " . $a->[ 2 + $wantsreading ]
          : $a->[ 1 + $wantsreading ];
        if ( $str =~
/^(\d{2}):(\d{2})(?::(\d{2}))?|(?:(\d{4})-(\d{2})-(\d{2}))(?:\D+(\d{2}):(\d{2})(?::(\d{2}))?)?$/
          )
        {
            SetTime(
                timelocal(
                    defined($3) ? $3 : ( defined($9) ? $9 : 0 ),
                    defined($2) ? $2 : ( defined($8) ? $8 : 0 ),
                    defined($1) ? $1 : ( defined($7) ? $7 : 12 ),
                    (
                        defined($4)
                        ? ( $6, $5 - 1, $4 )
                        : ( localtime( gettimeofday() ) )[ 3, 4, 5 ]
                    )
                  ) + ( $dayOffset * 86400. ),
                $tz, $lc_time
            );
        }
        else {
            return
"$name has improper time specification $str, use YYYY-MM-DD [HH:MM:SS] [-1|yesterday|+1|tomorrow]";
        }
    }
    else {
        SetTime( gettimeofday() + ( $dayOffset * 86400. ), $tz, $lc_time );
    }

    #-- disable automatic links to FHEM devices
    delete $FW_webArgs{addLinks};

    if ( $a->[0] eq "version" ) {
        return $VERSION;

    }
    elsif ( $a->[0] eq "json" ) {
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
    elsif ( $a->[0] eq "text" ) {
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
            unshift @$a, $type;

            foreach (@readings) {
                if ( exists( $Astro{$_} ) ) {
                    $ret .= $html && $html eq "1" ? "<br/>\n" : "\n"
                      if ( $ret ne "" );
                    $ret .= Astro_Get(
                        (
                            IsDevice( $AstroDev, "Astro" )
                            ? $defs{$AstroDev}
                            : $hash
                        ),
                        [
                            IsDevice( $AstroDev, "Astro" ) ? "Astro" : "dummy",
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
                $ret .= encode_utf8( FormatReading( $_, $h, $lc_numeric ) )
                  unless ( $_ =~ /^\./ );
                $ret .= encode_utf8( $Schedule{$_} ) if ( $_ =~ /^\./ );
            }
            $ret = "<html>" . $ret . "</html>"
              if ( defined($html) && $html ne "0" );
        }
        elsif ( $wantsreading == 1 ) {
            unshift @$a, $type;

            foreach (@readings) {
                if ( exists( $Astro{$_} ) ) {
                    $ret .= $html && $html eq "1" ? "<br/>\n" : "\n"
                      if ( $ret ne "" );
                    $ret .= Astro_Get(
                        (
                            IsDevice( $AstroDev, "Astro" )
                            ? $defs{$AstroDev}
                            : $hash
                        ),
                        [
                            IsDevice( $AstroDev, "Astro" ) ? "Astro" : "dummy",
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
            $h->{long} = 1;
            $h->{html} = $html if ($html);

            unshift @$a, $type;
            $ret = Astro_Get(
                (
                    IsDevice( $AstroDev, "Astro" )
                    ? $defs{$AstroDev}
                    : $hash
                ),
                $a, $h
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

            if ( $html && $html eq "1" ) {
                $ret = "<html>" . $ret . "</html>";
                $ret =~ s/   /&nbsp;&nbsp;&nbsp;/g;
                $ret =~ s/  /&nbsp;&nbsp;/g;
            }
        }

        return $ret;
    }
    else {
        return "$name with unknown argument $a->[0], choose one of "
          . join( " ",
            map { defined( $gets{$_} ) ? "$_:$gets{$_}" : $_ }
            sort keys %gets );
    }
}

sub FormatReading($$;$) {
    my ( $r, $h, $lc_numeric ) = @_;
    my $ret;

    my $f = "%s";

    #-- number formatting
    $f = "%2.1f" if ( $r eq "MonthProgress" );
    $f = "%2.1f" if ( $r eq "YearProgress" );

    $ret = sprintf( $f, $Schedule{$r} );
    $ret = UConv::decimal_mark( $ret, $lc_numeric )
      unless ( $h && ref($h) && defined( $h->{html} ) && $h->{html} eq "0" );

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
            $ret .= chr(0x00A0) . $astrott->{"days"}
              if ( $r eq "MonthRemainD" );
            $ret .= "." if ( $r eq "Weekofyear" );
            $ret .= chr(0x00A0) . "%" if ( $r eq "YearProgress" );
            $ret .= chr(0x00A0) . $astrott->{"days"} if ( $r eq "YearRemainD" );
        }

        #-- add text if desired
        if ( $h->{long} ) {
            $ret = $tt->{"twilightastro"} . " " . $ret
              if ( $r eq "DayChangeIsDST" );
            $ret = $tt->{"twilightastro"} . " " . $ret
              if ( $r eq "DayChangeMoonPhaseS" );
            $ret = $tt->{"twilightcivil"} . " " . $ret
              if ( $r eq "DayChangeMoonSign" );
            $ret = $tt->{"twilightcivil"} . " " . $ret
              if ( $r eq "DayChangeSeason" );
            $ret = $tt->{"twilightcustom"} . " " . $ret
              if ( $r eq "DayChangeSeasonMeteo" );
            $ret = $tt->{"twilightcustom"} . " " . $ret
              if ( $r eq "DayChangeSeasonPheno" );
            $ret = $tt->{"age"} . " " . $ret if ( $r eq "DayChangeSunSign" );
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
              . " "
              . $ret
              if ( $r eq "DaySeasonalHr" );
            $ret = $tt->{"az"} . " " . $ret if ( $r eq "DaySeasonalHrLenDay" );
            $ret = $tt->{"dec"} . " " . $ret
              if ( $r eq "DaySeasonalHrLenNight" );
            $ret = $tt->{"diameter"} . " " . $ret if ( $r eq "DaySeasonalHrR" );
            $ret = $ret . " " . $tt->{"toce"}
              if ( $r =~ /^DaySeasonalHrT/ );
            $ret = $ret . " " . $tt->{"toobs"}
              if ( $r eq "DaySeasonalHrTNext" );
            $ret = $tt->{"hoursofvisibility"} . " " . $ret
              if ( $r eq "DaySeasonalHrsDay" );
            $ret = $tt->{"latecl"} . " " . $ret
              if ( $r eq "DaySeasonalHrsNight" );
            $ret = $tt->{"dayphase"} . " " . $ret  if ( $r eq "Daytime" );
            $ret = $tt->{"phase"} . " " . $ret   if ( $r eq "DaytimeN" );
            $ret = $tt->{"phase"} . " " . $ret   if ( $r eq "MonthProgress" );
            $ret = $tt->{"ra"} . " " . $ret      if ( $r eq "MonthRemainD" );
            $ret = $tt->{"rise"} . " " . $ret    if ( $r eq "MoonCompass" );
            $ret = $tt->{"set"} . " " . $ret     if ( $r eq "MoonCompassI" );
            $ret = $tt->{"sign"} . " " . $ret    if ( $r eq "MoonCompassS" );
            $ret = $tt->{"transit"} . " " . $ret if ( $r eq "ObsTimeR" );
            $ret = $tt->{"twilightnautic"} . " " . $ret
              if ( $r eq "SchedLast" );
            $ret = $tt->{"twilightnautic"} . " " . $ret
              if ( $r eq "SchedLastT" );
            $ret = $ret . " " . $tt->{"altitude"} if ( $r eq "SchedNext" );
            $ret = $tt->{"date"} . " " . $ret     if ( $r eq "SchedNextT" );
            $ret = $ret . " " . $tt->{"dayofyear"}
              if ( $r eq "SchedRecent" );
            $ret = $tt->{"alt"} . " " . $ret if ( $r eq "SchedUpcoming" );
            $ret = $tt->{"metseason"} . " " . $ret if ( $r eq "SeasonMeteo" );
            $ret = $tt->{"phenseason"} . " " . $ret     if ( $r eq "SeasonPheno" );
            $ret = $ret . " " . $tt->{"latitude"}  if ( $r eq "SunCompass" );
            $ret = $ret . " " . $tt->{"longitude"} if ( $r eq "SunCompassI" );
            $ret = $tt->{"season"} . " " . $ret    if ( $r eq "SunCompassS" );
            $ret = $tt->{"time"} . " " . $ret      if ( $r eq "Weekofyear" );
            $ret = $tt->{"timezone"} . " " . $ret  if ( $r eq "YearIsLY" );
            $ret = $tt->{"alt"} . " " . $ret       if ( $r eq "YearProgress" );
            $ret = $tt->{"az"} . " " . $ret        if ( $r eq "YearRemainD" );
        }
    }

    return $ret;
}

sub _Export {
    no strict qw/refs/;    ## no critic
    my $pkg  = caller(0);
    my $main = $pkg;
    $main =~ s/^(?:.+::)?([^:]+)$/main::$1\_/g;
    foreach (@_) {
        *{ $main . $_ } = *{ $pkg . '::' . $_ };
    }
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
    my $isdstnoon =
      ( localtime( timelocal( 0, 0, 12, $day, $month, $year ) ) )[8];
    $year  += 1900;
    $month += 1;
    $D->{timestamp} = $time;
    $D->{timeday}   = $hour + $min / 60. + $sec / 3600.;
    $D->{year}      = $year;
    $D->{month}     = $month;
    $D->{day}       = $day;
    $D->{hour}      = $hour;
    $D->{min}       = $min;
    $D->{sec}       = $sec;
    $D->{isdst}     = $isdst;
    $D->{isdstnoon} = $isdstnoon;

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
            $D->{$i} = SetTime( $time + ( 86400. * $i ), $tz, $lc_time, 0 )
              unless ( $i == 0 );
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

    my $D = $dayOffset ? $Date{$dayOffset} : \%Date;
    my $S = $dayOffset ? {} : \%Schedule;

    # readjust language
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
    if ( defined( $params->{"language"} )
        && exists( $transtable{ uc( $params->{"language"} ) } ) )
    {
        $tt = $transtable{ uc( $params->{"language"} ) };
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

    # load schedule schema
    my @schedsch =
      split(
        ',',
        (
            defined( $params->{"schedule"} )
            ? $params->{"schedule"}
            : AttrVal( $name, "schedule", $attrs{schedule} )
        )
      );

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
                    $name, "json",
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
                        IsDevice( $AstroDev, "Astro" )
                        ? $defs{$AstroDev}
                        : $hash
                    ),
                    [
                        $name, "json",
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
    if ( defined( $params->{"earlyspring"} ) ) {
        $earlyspring = $params->{"earlyspring"};
    }
    elsif (defined( $attr{$name} )
        && defined( $attr{$name}{"earlyspring"} ) )
    {
        $earlyspring = $attr{$name}{"earlyspring"};
    }
    else {
        Log3 $name, 5,
          "$name: No earlyspring attribute defined, using date $earlyspring"
          if ( !$dayOffset );
    }

    # custom date for early fall
    my $earlyfall = '08-20';
    if ( defined( $params->{"earlyfall"} ) ) {
        $earlyfall = $params->{"earlyfall"};
    }
    elsif ( defined( $attr{$name} ) && defined( $attr{$name}{"earlyfall"} ) ) {
        $earlyfall = $attr{$name}{"earlyfall"};
    }
    else {
        Log3 $name, 5,
          "$name: No earlyfall attribute defined, using date $earlyfall"
          if ( !$dayOffset );
    }

    # custom number for seasonal hours
    my $daypartsIsRoman = 0;
    my $dayparts        = 12;
    my $nightparts      = 12;
    if ( defined( $params->{"seasonalHrs"} )
        && $params->{"seasonalHrs"} =~ m/^(([^:]+)(?::(.+))?)$/ )
    {
        $daypartsIsRoman = 1
          if ( $1 eq '4' );    # special handling of '^4$' as roman format
        $dayparts = $daypartsIsRoman ? 12. : $2;
        $nightparts = $3 ? $3 : $2;
    }
    elsif (defined( $attr{$name} )
        && defined( $attr{$name}{"seasonalHrs"} )
        && $attr{$name}{"seasonalHrs"} =~ m/^(([^:]+)(?::(.+))?)$/ )
    {
        $daypartsIsRoman = 1
          if ( $1 eq '4' );    # special handling of '^4$' as roman format
        $dayparts = $daypartsIsRoman ? 12. : $2;
        $nightparts = $3 ? $3 : $2;
    }
    else {
        Log3 $name, 5,
"$name: No seasonalHrs attribute defined, using $dayparts seasonal hours for day and night"
          if ( !$dayOffset );
    }

    # add info from 2 days after but only +1 day will be useful after all
    if ( !defined($dayOffset) ) {

        # today+2, has no tomorrow or yesterday
        ( $A->{2}, $S->{2} ) = Compute( $hash, 2, $params );

        # today+1, only has tomorrow and incomplete yesterday
        ( $A->{1}, $S->{1} ) = Compute( $hash, 1, $params );
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
    $S->{SunCompassI} =
      UConv::direction2compasspoint( $A->{".SunAz"}, 0, $lang );
    $S->{SunCompassS} =
      UConv::direction2compasspoint( $A->{".SunAz"}, 1, $lang );
    $S->{SunCompass} =
      UConv::direction2compasspoint( $A->{".SunAz"}, 2, $lang );
    $S->{MoonCompassI} =
      UConv::direction2compasspoint( $A->{".MoonAz"}, 0, $lang );
    $S->{MoonCompassS} =
      UConv::direction2compasspoint( $A->{".MoonAz"}, 1, $lang );
    $S->{MoonCompass} =
      UConv::direction2compasspoint( $A->{".MoonAz"}, 2, $lang );
    $S->{ObsTimeR} =
      UConv::arabic2roman( $D->{hour} <= 12. ? $D->{hour} : $D->{hour} - 12. )
      . (
        $D->{min} == 0.
        ? ( $D->{sec} == 0 ? "" : ":" )
        : ":" . UConv::arabic2roman( $D->{min} )
      ) . ( $D->{sec} == 0. ? "" : ":" . UConv::arabic2roman( $D->{sec} ) );
    $S->{Weekofyear}       = $D->{weekofyear};
    $S->{".isdstnoon"}     = $D->{isdstnoon};
    $S->{YearIsLY}         = $D->{isly};
    $S->{YearRemainD}      = $D->{yearremdays};
    $S->{MonthRemainD}     = $D->{monthremdays};
    $S->{".YearProgress"}  = $D->{yearprogress};
    $S->{".MonthProgress"} = $D->{monthprogress};
    $S->{YearProgress} =
      FHEM::Astro::_round( $S->{".YearProgress"} * 100, 0 );
    $S->{MonthProgress} =
      FHEM::Astro::_round( $S->{".MonthProgress"} * 100, 0 );

    AddToSchedule( $S, $A->{".SunTransit"}, "SunTransit" )
      if ( grep ( /^SunTransit/, @schedsch ) );
    AddToSchedule( $S, $A->{".SunRise"}, "SunRise" )
      if ( grep ( /^SunRise/, @schedsch ) );
    AddToSchedule( $S, $A->{".SunSet"}, "SunSet" )
      if ( grep ( /^SunSet/, @schedsch ) );
    AddToSchedule( $S, $A->{".CivilTwilightMorning"}, "CivilTwilightMorning" )
      if ( grep ( /^CivilTwilightMorning/, @schedsch ) );
    AddToSchedule( $S, $A->{".CivilTwilightEvening"}, "CivilTwilightEvening" )
      if ( grep ( /^CivilTwilightEvening/, @schedsch ) );
    AddToSchedule( $S, $A->{".NauticTwilightMorning"}, "NauticTwilightMorning" )
      if ( grep ( /^NauticTwilightMorning/, @schedsch ) );
    AddToSchedule( $S, $A->{".NauticTwilightEvening"}, "NauticTwilightEvening" )
      if ( grep ( /^NauticTwilightEvening/, @schedsch ) );
    AddToSchedule( $S, $A->{".AstroTwilightMorning"}, "AstroTwilightMorning" )
      if ( grep ( /^AstroTwilightMorning/, @schedsch ) );
    AddToSchedule( $S, $A->{".AstroTwilightEvening"}, "AstroTwilightEvening" )
      if ( grep ( /^AstroTwilightEvening/, @schedsch ) );
    AddToSchedule( $S, $A->{".CustomTwilightMorning"}, "CustomTwilightMorning" )
      if ( grep ( /^CustomTwilightMorning/, @schedsch ) );
    AddToSchedule( $S, $A->{".CustomTwilightEvening"}, "CustomTwilightEvening" )
      if ( grep ( /^CustomTwilightEvening/, @schedsch ) );
    AddToSchedule( $S, $A->{".MoonTransit"}, "MoonTransit" )
      if ( grep ( /^MoonTransit/, @schedsch ) );
    AddToSchedule( $S, $A->{".MoonRise"}, "MoonRise" )
      if ( grep ( /^MoonRise/, @schedsch ) );
    AddToSchedule( $S, $A->{".MoonSet"}, "MoonSet" )
      if ( grep ( /^MoonSet/, @schedsch ) );
    AddToSchedule( $S, 0, "ObsDate " . $A->{ObsDate} )
      if ( grep ( /^ObsDate/, @schedsch ) );

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
          if ( grep ( /^DaySeasonalHr/, @schedsch ) );
        AddToSchedule( $S, $d, "Daytime " . $tt->{ $dayphases[ 13. + $idp ] } )
          if ( grep ( /^Daytime/, @schedsch ) && $nightparts == 12. );
        AddToSchedule( $S, $d,
            "Daytime Vigilia "
              . UConv::arabic2roman( $idp + $nightparts + 2. ) )
          if ( grep ( /^Daytime/, @schedsch ) && $nightparts == 4. );

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
          if ( grep ( /^DaySeasonalHr/, @schedsch ) );
        AddToSchedule( $S, $d, "Daytime " . $tt->{ $dayphases[ 12. + $idp ] } )
          if ( grep ( /^Daytime/, @schedsch )
            && $dayparts == 12.
            && !$daypartsIsRoman );
        AddToSchedule( $S, $d,
            "Daytime Hora " . UConv::arabic2roman( $idp + 1. ) )
          if ( grep ( /^Daytime/, @schedsch ) && $daypartsIsRoman );

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

    $S->{".DaySeasonalHrTNext"} = $daypartnext;
    $S->{DaySeasonalHrTNext} =
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

    # check meteorological season
    for ( my $i = 0 ; $i < 4 ; $i++ ) {
        my $key = $FHEM::Astro::seasons[$i];
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
            $S->{SeasonMeteo}  = $astrott->{$key};
            $S->{SeasonMeteoN} = $i;
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

        $S->{SeasonPheno}  = $tt->{ $seasonsp[$pheno] };
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
        ( $A->{"-2"}, $S->{"-2"} ) =
          Compute( $hash, -2, $params );

        # today-1, has tomorrow and yesterday
        ( $A->{"-1"}, $S->{"-1"} ) =
          Compute( $hash, -1, $params );
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
    $S->{DayChangeSeasonPheno} = 0 unless ( $S->{DayChangeSeasonPheno} );
    $S->{DayChangeSunSign}     = 0 unless ( $S->{DayChangeSunSign} );
    $S->{DayChangeMoonSign}    = 0 unless ( $S->{DayChangeMoonSign} );
    $S->{DayChangeMoonPhaseS}  = 0 unless ( $S->{DayChangeMoonPhaseS} );
    $S->{DayChangeIsDST}       = 0 unless ( $S->{DayChangeIsDST} );

    #  Astronomical season is going to change tomorrow
    if (   ref($At)
        && ref($St)
        && !$St->{DayChangeSeason}
        && defined( $At->{ObsSeasonN} )
        && $At->{ObsSeasonN} != $A->{ObsSeasonN} )
    {
        $S->{DayChangeSeason}  = 2;
        $St->{DayChangeSeason} = 1;
        AddToSchedule( $S, 0, "ObsSeason " . $At->{ObsSeason} )
          if ( grep ( /^ObsSeason/, @schedsch ) );
    }

    #  Astronomical season changed since yesterday
    elsif (ref($Ay)
        && ref($Sy)
        && !$Sy->{DayChangeSeason}
        && defined( $Ay->{ObsSeasonN} )
        && $Ay->{ObsSeasonN} != $A->{ObsSeasonN} )
    {
        $Sy->{DayChangeSeason} = 2;
        $S->{DayChangeSeason}  = 1;
        AddToSchedule( $S, 0, "ObsSeason " . $A->{ObsSeason} )
          if ( grep ( /^ObsSeason/, @schedsch ) );
    }

    #  Meteorological season is going to change tomorrow
    if (   ref($St)
        && !$St->{DayChangeSeasonMeteo}
        && defined( $St->{SeasonMeteoN} )
        && $St->{SeasonMeteoN} != $S->{SeasonMeteoN} )
    {
        $S->{DayChangeSeasonMeteo}  = 2;
        $St->{DayChangeSeasonMeteo} = 1;
        AddToSchedule( $St, 0, "SeasonMeteo " . $St->{SeasonMeteo} )
          if ( grep ( /^SeasonMeteo/, @schedsch ) );
    }

    #  Meteorological season changed since yesterday
    elsif (ref($Sy)
        && !$Sy->{DayChangeSeasonMeteo}
        && defined( $Sy->{SeasonMeteoN} )
        && $Sy->{SeasonMeteoN} != $S->{SeasonMeteoN} )
    {
        $Sy->{DayChangeSeasonMeteo} = 2;
        $S->{DayChangeSeasonMeteo}  = 1;
        AddToSchedule( $S, 0, "SeasonMeteo " . $S->{SeasonMeteo} )
          if ( grep ( /^SeasonMeteo/, @schedsch ) );
    }

    #  Phenological season is going to change tomorrow
    if (   ref($St)
        && !$St->{DayChangeSeasonPheno}
        && defined( $St->{SeasonPhenoN} )
        && $St->{SeasonPhenoN} != $S->{SeasonPhenoN} )
    {
        $S->{DayChangeSeasonPheno}  = 2;
        $St->{DayChangeSeasonPheno} = 1;
        AddToSchedule( $St, 0, "SeasonPheno " . $St->{SeasonPheno} )
          if ( grep ( /^SeasonPheno/, @schedsch ) );
    }

    #  Phenological season changed since yesterday
    elsif (ref($Sy)
        && !$Sy->{DayChangeSeasonPheno}
        && defined( $Sy->{SeasonPhenoN} )
        && $Sy->{SeasonPhenoN} != $S->{SeasonPhenoN} )
    {
        $Sy->{DayChangeSeasonPheno} = 2;
        $S->{DayChangeSeasonPheno}  = 1;
        AddToSchedule( $S, 0, "SeasonPheno " . $S->{SeasonPheno} )
          if ( grep ( /^SeasonPheno/, @schedsch ) );
    }

    #  SunSign is going to change tomorrow
    if (   ref($At)
        && ref($St)
        && !$St->{DayChangeSunSign}
        && defined( $At->{SunSign} )
        && $At->{SunSign} ne $A->{SunSign} )
    {
        $S->{DayChangeSunSign}  = 2;
        $St->{DayChangeSunSign} = 1;
        AddToSchedule( $St, 0, "SunSign " . $At->{SunSign} )
          if ( grep ( /^SunSign/, @schedsch ) );
    }

    #  SunSign changed since yesterday
    elsif (ref($Ay)
        && ref($Sy)
        && !$Sy->{DayChangeSunSign}
        && defined( $Ay->{SunSign} )
        && $Ay->{SunSign} ne $A->{SunSign} )
    {
        $Sy->{DayChangeSunSign} = 2;
        $S->{DayChangeSunSign}  = 1;
        AddToSchedule( $S, 0, "SunSign " . $A->{SunSign} )
          if ( grep ( /^SunSign/, @schedsch ) );
    }

    #  MoonSign is going to change tomorrow
    if (   ref($At)
        && ref($St)
        && !$St->{DayChangeMoonSign}
        && defined( $At->{MoonSign} )
        && $At->{MoonSign} ne $A->{MoonSign} )
    {
        $S->{DayChangeMoonSign}  = 2;
        $St->{DayChangeMoonSign} = 1;
        AddToSchedule( $St, 0, "MoonSign " . $At->{MoonSign} )
          if ( grep ( /^MoonSign/, @schedsch ) );
    }

    #  MoonSign changed since yesterday
    elsif (ref($Ay)
        && ref($Sy)
        && !$Sy->{DayChangeMoonSign}
        && defined( $Ay->{MoonSign} )
        && $Ay->{MoonSign} ne $A->{MoonSign} )
    {
        $Sy->{DayChangeMoonSign} = 2;
        $S->{DayChangeMoonSign}  = 1;
        AddToSchedule( $S, 0, "MoonSign " . $A->{MoonSign} )
          if ( grep ( /^MoonSign/, @schedsch ) );
    }

    #  MoonPhase is going to change tomorrow
    if (   ref($At)
        && ref($St)
        && !$St->{DayChangeMoonPhaseS}
        && defined( $At->{MoonPhaseS} )
        && $At->{MoonPhaseI} != $A->{MoonPhaseI} )
    {
        $S->{DayChangeMoonPhaseS}  = 2;
        $St->{DayChangeMoonPhaseS} = 1;
        AddToSchedule( $St, 0, "MoonPhaseS " . $At->{MoonPhaseS} )
          if ( grep ( /^MoonPhaseS/, @schedsch ) );
    }

    #  MoonPhase changed since yesterday
    elsif (ref($Ay)
        && ref($Sy)
        && !$Sy->{DayChangeMoonPhaseS}
        && defined( $Ay->{MoonPhaseS} )
        && $Ay->{MoonPhaseI} != $A->{MoonPhaseI} )
    {
        $Sy->{DayChangeMoonPhaseS} = 2;
        $S->{DayChangeMoonPhaseS}  = 1;
        AddToSchedule( $S, 0, "MoonPhaseS " . $A->{MoonPhaseS} )
          if ( grep ( /^MoonPhaseS/, @schedsch ) );
    }

    #  DST is going to change tomorrow
    if (   ref($St)
        && !$St->{DayChangeIsDST}
        && defined( $St->{".isdstnoon"} )
        && $St->{".isdstnoon"} != $S->{".isdstnoon"} )
    {
        $S->{DayChangeIsDST}  = 2;
        $St->{DayChangeIsDST} = 1;
        AddToSchedule( $St, 0, "ObsIsDST " . $St->{".isdstnoon"} )
          if ( grep ( /^ObsIsDST/, @schedsch ) );
    }

    #  DST is going to change somewhere today
    elsif (ref($Sy)
        && !$Sy->{DayChangeIsDST}
        && defined( $Sy->{".isdstnoon"} )
        && $Sy->{".isdstnoon"} != $S->{".isdstnoon"} )
    {
        $Sy->{DayChangeIsDST} = 2;
        $S->{DayChangeIsDST}  = 1;
        AddToSchedule( $S, 0, "ObsIsDST " . $S->{".isdstnoon"} )
          if ( grep ( /^ObsIsDST/, @schedsch ) );
    }

    # schedule
    if ( defined( $S->{".schedule"} ) ) {

        # future of tomorrow
        if ( ref($St) ) {
            foreach my $e ( sort { $a <=> $b } keys %{ $St->{".schedule"} } ) {
                foreach ( @{ $St->{".schedule"}{$e} } ) {
                    AddToSchedule( $S, 24, $_ );
                }
                last;    # only add first event of next day
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
    }
    else {
        $S->{SchedLast}     = "---";
        $S->{SchedLastT}    = "---";
        $S->{SchedNext}     = "---";
        $S->{SchedNextT}    = "---";
        $S->{SchedRecent}   = "---";
        $S->{SchedUpcoming} = "---";
    }

    delete local $ENV{TZ};
    tzset();

    return $A, $S
      if ($dayOffset);
    return (undef);
}

sub AddToSchedule {
    my ( $h, $e, $n ) = @_;
    push @{ $h->{".schedule"}{$e} }, $n
      if ( defined($e) && $e =~ m/^\d+(?:\.\d+)?$/ );
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
              timelocal( 0, 0, 0, ( localtime( $now + 86400. ) )[ 3, 4, 5 ] );
            next;
        }
        my $k = ".$comp";
        $k = '.DaySeasonalHrTNext' if ( $comp eq 'SeasonalHr' );
        my $t;
        if ( defined( $Schedule{$k} )
            && $Schedule{$k} =~ /^\d+(?:\.\d+)?$/ )
        {
            $t =
              timelocal( 0, 0, 0, ( localtime($now) )[ 3, 4, 5 ] ) +
              $Schedule{$k} * 3600.;
            $t += 86400. if ( $t < $now );    # that is for tomorrow
        }
        elsif ( defined( $Astro{$k} ) && $Astro{$k} =~ /^\d+(?:\.\d+)?$/ ) {
            $t =
              timelocal( 0, 0, 0, ( localtime($now) )[ 3, 4, 5 ] ) +
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
            if ( defined( $Astro{$key} ) && $Astro{$key} ne "" ) {
                readingsBulkUpdateIfChanged( $hash, $key,
                    encode_utf8( $Astro{$key} ) );
            }
            else {
                Log3 $name, 3, "$name: ERROR: empty value for $key in hash";
            }
        }
    }
    foreach my $key ( keys %Schedule ) {
        next if ( ref( $Schedule{$key} ) );
        if ( defined( $Schedule{$key} ) && $Schedule{$key} ne "" ) {
            readingsBulkUpdateIfChanged( $hash, $key,
                encode_utf8( $Schedule{$key} ) );
        }
        else {
            Log3 $name, 3, "$name: ERROR: empty value for $key in hash";
        }
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
        <li>As the relative daytime is based on temporal hours, it can only be emerged if seasonalHrs is set to 12 (which is the default setting).
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
          <a name="DaySchedule_earlyfall" id="DaySchedule_earlyfall"></a> <code>&lt;earlyfall&gt;</code><br>
          The early beginning of fall will set a marker to calculate all following phenological seasons until winter time. This defaults to 08-20 to begin early fall on August 20th.
        </li>
        <li>
          <a name="DaySchedule_earlyspring" id="DaySchedule_earlyspring"></a> <code>&lt;earlyspring&gt;</code><br>
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
          <a name="DaySchedule_seasonalHrs" id="DaySchedule_seasonalHrs"></a> <code>&lt;seasonalHrs&gt;</code><br>
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
