// ÜRETİLMİŞ DOSYA: elle düzenlemeyin. Kaynak: mobile/tools/icons/build_icons.py
// Glifler Hugeicons 4.4.0 (MIT, bkz. assets/licenses/hugeicons-MIT.txt) verisinden üretilmiş
// BuIcons.ttf yazı tipindedir; çalışma zamanında SVG ayrıştırması YOKTUR (Lucide ile aynı maliyet).
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Uygulamanın tek ikon kapısı. Anlamsal ad (Lucide adından türetildi) -> Hugeicons glifi.
/// Dolu hâller `<ad>Filled`. Hugeicons'ta karşılığı olmayan iki ikon Lucide'de kalır.
abstract final class BuIcons {
  /// Yazı tipi ailesi (pubspec.yaml `fonts:` ile aynı olmalı).
  static const String fontFamily = 'BuIcons';

  /// Hugeicons AlarmClock; Lucide alarmClock
  static const IconData alarmClock = IconData(0xe000, fontFamily: 'BuIcons');
  /// Hugeicons Archive; Lucide archive
  static const IconData archive = IconData(0xe001, fontFamily: 'BuIcons');
  /// Hugeicons ArchiveRestore; Lucide archiveRestore
  static const IconData archiveRestore = IconData(0xe002, fontFamily: 'BuIcons');
  /// Hugeicons ArrowLeft02; Lucide arrowLeft
  static const IconData arrowLeft = IconData(0xe003, fontFamily: 'BuIcons');
  /// Hugeicons ArrowLeftRight; Lucide arrowLeftRight
  static const IconData arrowLeftRight = IconData(0xe004, fontFamily: 'BuIcons');
  /// Hugeicons ArrowRight02; Lucide arrowRight
  static const IconData arrowRight = IconData(0xe005, fontFamily: 'BuIcons');
  /// Hugeicons ArrowUp02; Lucide arrowUp
  static const IconData arrowUp = IconData(0xe006, fontFamily: 'BuIcons');
  /// Hugeicons ArrowUpRight01; Lucide arrowUpRight
  static const IconData arrowUpRight = IconData(0xe007, fontFamily: 'BuIcons');
  /// Hugeicons AtSign; Lucide atSign
  static const IconData atSign = IconData(0xe008, fontFamily: 'BuIcons');
  /// Hugeicons Atom02; Lucide atom
  static const IconData atom = IconData(0xe009, fontFamily: 'BuIcons');
  /// Hugeicons Backpack01; Lucide backpack
  static const IconData backpack = IconData(0xe00a, fontFamily: 'BuIcons');
  /// Hugeicons Ban; Lucide ban
  static const IconData ban = IconData(0xe00b, fontFamily: 'BuIcons');
  /// Hugeicons Notification01; Lucide bell
  static const IconData bell = IconData(0xe00c, fontFamily: 'BuIcons');
  /// Hugeicons Notification01 (dolu)
  static const IconData bellFilled = IconData(0xe00d, fontFamily: 'BuIcons');
  /// Hugeicons NotificationOff01; Lucide bellOff
  static const IconData bellOff = IconData(0xe00e, fontFamily: 'BuIcons');
  /// Hugeicons BellRing; Lucide bellRing
  static const IconData bellRing = IconData(0xe00f, fontFamily: 'BuIcons');
  /// Hugeicons BookOpen01; Lucide bookOpen
  static const IconData bookOpen = IconData(0xe010, fontFamily: 'BuIcons');
  /// Hugeicons Bookmark01; Lucide bookmark
  static const IconData bookmark = IconData(0xe011, fontFamily: 'BuIcons');
  /// Hugeicons Bookmark01 (dolu); Material bookmark
  static const IconData bookmarkFilled = IconData(0xe012, fontFamily: 'BuIcons');
  /// Hugeicons Building02; Lucide building2
  static const IconData building2 = IconData(0xe013, fontFamily: 'BuIcons');
  /// Hugeicons Calendar04; Lucide calendar
  static const IconData calendar = IconData(0xe014, fontFamily: 'BuIcons');
  /// Hugeicons CalendarCheck01; Lucide calendarCheck
  static const IconData calendarCheck = IconData(0xe015, fontFamily: 'BuIcons');
  /// Hugeicons CalendarClock; Lucide calendarClock
  static const IconData calendarClock = IconData(0xe016, fontFamily: 'BuIcons');
  /// Hugeicons CalendarDays; Lucide calendarDays
  static const IconData calendarDays = IconData(0xe017, fontFamily: 'BuIcons');
  /// Hugeicons CalendarAdd01; Lucide calendarPlus
  static const IconData calendarPlus = IconData(0xe018, fontFamily: 'BuIcons');
  /// Hugeicons CalendarX; Lucide calendarX
  static const IconData calendarX = IconData(0xe019, fontFamily: 'BuIcons');
  /// Hugeicons Camera01; Lucide camera
  static const IconData camera = IconData(0xe01a, fontFamily: 'BuIcons');
  /// Hugeicons CameraOff01; Lucide cameraOff
  static const IconData cameraOff = IconData(0xe01b, fontFamily: 'BuIcons');
  /// Hugeicons Car01
  static const IconData car = IconData(0xe0b6, fontFamily: 'BuIcons');
  /// Hugeicons PieChart; Lucide chartPie
  static const IconData chartPie = IconData(0xe01c, fontFamily: 'BuIcons');
  /// Hugeicons BubbleChat; Material chat_bubble_outline_rounded
  static const IconData chat = IconData(0xe01d, fontFamily: 'BuIcons');
  /// Hugeicons BubbleChat (dolu); Material chat_bubble_rounded
  static const IconData chatFilled = IconData(0xe01e, fontFamily: 'BuIcons');
  /// Hugeicons Tick02; Lucide check; Material check_rounded
  static const IconData check = IconData(0xe01f, fontFamily: 'BuIcons');
  /// Hugeicons TickDouble01; Lucide checkCheck
  static const IconData checkCheck = IconData(0xe020, fontFamily: 'BuIcons');
  /// Hugeicons ChevronDown; Lucide chevronDown
  static const IconData chevronDown = IconData(0xe021, fontFamily: 'BuIcons');
  /// Hugeicons ChevronLeft; Lucide chevronLeft
  static const IconData chevronLeft = IconData(0xe022, fontFamily: 'BuIcons');
  /// Hugeicons ChevronRight; Lucide chevronRight
  static const IconData chevronRight = IconData(0xe023, fontFamily: 'BuIcons');
  /// Hugeicons ChevronUp; Lucide chevronUp
  static const IconData chevronUp = IconData(0xe024, fontFamily: 'BuIcons');
  /// Hugeicons AlertCircle; Lucide circleAlert
  static const IconData circleAlert = IconData(0xe025, fontFamily: 'BuIcons');
  /// Hugeicons AlertCircle (dolu); Material error
  static const IconData circleAlertFilled = IconData(0xe026, fontFamily: 'BuIcons');
  /// Hugeicons CheckmarkCircle02; Lucide circleCheck
  static const IconData circleCheck = IconData(0xe027, fontFamily: 'BuIcons');
  /// Hugeicons CheckmarkCircle02 (dolu); Material check_circle, check_circle_rounded
  static const IconData circleCheckFilled = IconData(0xe028, fontFamily: 'BuIcons');
  /// Hugeicons CircleDot; Lucide circleDot
  static const IconData circleDot = IconData(0xe029, fontFamily: 'BuIcons');
  /// Hugeicons HelpCircle; Lucide circleHelp
  static const IconData circleHelp = IconData(0xe02a, fontFamily: 'BuIcons');
  /// Hugeicons PauseCircle; Lucide circlePause
  static const IconData circlePause = IconData(0xe02b, fontFamily: 'BuIcons');
  /// Hugeicons PlayCircle; Lucide circlePlay
  static const IconData circlePlay = IconData(0xe02c, fontFamily: 'BuIcons');
  /// Hugeicons AddCircle; Lucide circlePlus
  static const IconData circlePlus = IconData(0xe02d, fontFamily: 'BuIcons');
  /// Hugeicons CancelCircle; Lucide circleX
  static const IconData circleX = IconData(0xe02e, fontFamily: 'BuIcons');
  /// Hugeicons Clapperboard; Lucide clapperboard
  static const IconData clapperboard = IconData(0xe02f, fontFamily: 'BuIcons');
  /// Hugeicons ClipboardCheck; Lucide clipboardCheck
  static const IconData clipboardCheck = IconData(0xe030, fontFamily: 'BuIcons');
  /// Hugeicons ClipboardList; Lucide clipboardList
  static const IconData clipboardList = IconData(0xe031, fontFamily: 'BuIcons');
  /// Hugeicons Clock01; Lucide clock
  static const IconData clock = IconData(0xe032, fontFamily: 'BuIcons');
  /// Hugeicons CloudOff; Lucide cloudOff
  static const IconData cloudOff = IconData(0xe033, fontFamily: 'BuIcons');
  /// Hugeicons Coffee02; Lucide coffee
  static const IconData coffee = IconData(0xe034, fontFamily: 'BuIcons');
  /// Hugeicons DiscoverCircle; Lucide compass
  static const IconData compass = IconData(0xe035, fontFamily: 'BuIcons');
  /// Hugeicons Contact01; Lucide contact
  static const IconData contact = IconData(0xe036, fontFamily: 'BuIcons');
  /// Hugeicons Copy01; Lucide copy
  static const IconData copy = IconData(0xe037, fontFamily: 'BuIcons');
  /// Hugeicons CornerUpRight
  static const IconData cornerUpRight = IconData(0xe0b7, fontFamily: 'BuIcons');
  /// Hugeicons Cpu; Lucide cpu
  static const IconData cpu = IconData(0xe038, fontFamily: 'BuIcons');
  /// Hugeicons Crop; Lucide crop
  static const IconData crop = IconData(0xe039, fontFamily: 'BuIcons');
  /// Hugeicons DiscoverCircle; Material explore_outlined
  static const IconData discover = IconData(0xe03a, fontFamily: 'BuIcons');
  /// Hugeicons DiscoverCircle (dolu); Material explore_rounded
  static const IconData discoverFilled = IconData(0xe03b, fontFamily: 'BuIcons');
  /// Hugeicons DoorOpen; Lucide doorOpen
  static const IconData doorOpen = IconData(0xe03c, fontFamily: 'BuIcons');
  /// Hugeicons Download01; Lucide download
  static const IconData download = IconData(0xe03d, fontFamily: 'BuIcons');
  /// Hugeicons Dumbbell01
  static const IconData dumbbell = IconData(0xe0b8, fontFamily: 'BuIcons');
  /// Hugeicons MoreHorizontal; Lucide ellipsis; Material more_horiz
  static const IconData ellipsis = IconData(0xe03e, fontFamily: 'BuIcons');
  /// Hugeicons MoreVertical; Lucide ellipsisVertical
  static const IconData ellipsisVertical = IconData(0xe03f, fontFamily: 'BuIcons');
  /// Hugeicons View; Lucide eye
  static const IconData eye = IconData(0xe040, fontFamily: 'BuIcons');
  /// Hugeicons EyeOff; Lucide eyeOff
  static const IconData eyeOff = IconData(0xe041, fontFamily: 'BuIcons');
  /// Hugeicons FileSearch; Lucide fileSearch
  static const IconData fileSearch = IconData(0xe042, fontFamily: 'BuIcons');
  /// Hugeicons FileText; Lucide fileText
  static const IconData fileText = IconData(0xe043, fontFamily: 'BuIcons');
  /// Hugeicons Flag02; Lucide flag
  static const IconData flag = IconData(0xe044, fontFamily: 'BuIcons');
  /// Hugeicons Flashlight; Lucide flashlight
  static const IconData flashlight = IconData(0xe045, fontFamily: 'BuIcons');
  /// Hugeicons FlashlightOff; Lucide flashlightOff
  static const IconData flashlightOff = IconData(0xe046, fontFamily: 'BuIcons');
  /// Hugeicons FlaskConical
  static const IconData flaskConical = IconData(0xe0b9, fontFamily: 'BuIcons');
  /// Hugeicons Focus; Lucide focus
  static const IconData focus = IconData(0xe047, fontFamily: 'BuIcons');
  /// Hugeicons Footprints
  static const IconData footprints = IconData(0xe0ba, fontFamily: 'BuIcons');
  /// Hugeicons Redo01; Lucide forward
  static const IconData forward = IconData(0xe048, fontFamily: 'BuIcons');
  /// Hugeicons Globe02; Lucide globe
  static const IconData globe = IconData(0xe049, fontFamily: 'BuIcons');
  /// Hugeicons GraduationCap; Lucide graduationCap
  static const IconData graduationCap = IconData(0xe04a, fontFamily: 'BuIcons');
  /// Hugeicons GripVertical; Lucide gripVertical
  static const IconData gripVertical = IconData(0xe04b, fontFamily: 'BuIcons');
  /// Hugeicons Hand; Lucide hand
  static const IconData hand = IconData(0xe04c, fontFamily: 'BuIcons');
  /// Hugeicons Hash; Lucide hash
  static const IconData hash = IconData(0xe04d, fontFamily: 'BuIcons');
  /// Hugeicons Headset; Lucide headset
  static const IconData headset = IconData(0xe04e, fontFamily: 'BuIcons');
  /// Hugeicons Favourite; Lucide heart; Material favorite_border
  static const IconData heart = IconData(0xe04f, fontFamily: 'BuIcons');
  /// Hugeicons Favourite (dolu); Material favorite
  static const IconData heartFilled = IconData(0xe050, fontFamily: 'BuIcons');
  /// Hugeicons History; Lucide history
  static const IconData history = IconData(0xe051, fontFamily: 'BuIcons');
  /// Hugeicons Home01; Material home_outlined
  static const IconData home = IconData(0xe052, fontFamily: 'BuIcons');
  /// Hugeicons Home01 (dolu); Material home_rounded
  static const IconData homeFilled = IconData(0xe053, fontFamily: 'BuIcons');
  /// Hugeicons Hourglass; Lucide hourglass
  static const IconData hourglass = IconData(0xe054, fontFamily: 'BuIcons');
  /// Hugeicons IdCard; Lucide idCard
  static const IconData idCard = IconData(0xe055, fontFamily: 'BuIcons');
  /// Hugeicons Image02; Lucide image; Material image_outlined
  static const IconData image = IconData(0xe056, fontFamily: 'BuIcons');
  /// Hugeicons ImageDown; Lucide imageDown
  static const IconData imageDown = IconData(0xe057, fontFamily: 'BuIcons');
  /// Hugeicons ImageOff; Lucide imageOff
  static const IconData imageOff = IconData(0xe058, fontFamily: 'BuIcons');
  /// Hugeicons ImageAdd01; Lucide imagePlus
  static const IconData imagePlus = IconData(0xe059, fontFamily: 'BuIcons');
  /// Hugeicons Images; Lucide images
  static const IconData images = IconData(0xe05a, fontFamily: 'BuIcons');
  /// Hugeicons Inbox; Lucide inbox
  static const IconData inbox = IconData(0xe05b, fontFamily: 'BuIcons');
  /// Hugeicons InformationCircle; Lucide info; Material info_outline
  static const IconData info = IconData(0xe05c, fontFamily: 'BuIcons');
  /// Hugeicons Landmark; Lucide landmark
  static const IconData landmark = IconData(0xe05d, fontFamily: 'BuIcons');
  /// Hugeicons Laptop; Lucide laptop
  static const IconData laptop = IconData(0xe05e, fontFamily: 'BuIcons');
  /// Hugeicons Layers01
  static const IconData layers = IconData(0xe0bb, fontFamily: 'BuIcons');
  /// Hugeicons Library; Lucide library
  static const IconData library = IconData(0xe05f, fontFamily: 'BuIcons');
  /// Hugeicons Lightbulb; Lucide lightbulb
  static const IconData lightbulb = IconData(0xe060, fontFamily: 'BuIcons');
  /// Hugeicons ListChecks; Lucide listChecks
  static const IconData listChecks = IconData(0xe061, fontFamily: 'BuIcons');
  /// Hugeicons ListOrdered; Lucide listOrdered
  static const IconData listOrdered = IconData(0xe062, fontFamily: 'BuIcons');
  /// Hugeicons LocateFixed
  static const IconData locateFixed = IconData(0xe0bc, fontFamily: 'BuIcons');
  /// Hugeicons LockKeyhole; Lucide lock
  static const IconData lock = IconData(0xe063, fontFamily: 'BuIcons');
  /// Hugeicons LockKeyhole; Lucide lockKeyhole
  static const IconData lockKeyhole = IconData(0xe064, fontFamily: 'BuIcons');
  /// Hugeicons LockOpen; Lucide lockOpen
  static const IconData lockOpen = IconData(0xe065, fontFamily: 'BuIcons');
  /// Hugeicons Logout01; Lucide logOut
  static const IconData logOut = IconData(0xe066, fontFamily: 'BuIcons');
  /// Hugeicons MailCheck; Lucide mailCheck
  static const IconData mailCheck = IconData(0xe067, fontFamily: 'BuIcons');
  /// Hugeicons Map
  static const IconData map = IconData(0xe0bd, fontFamily: 'BuIcons');
  /// Hugeicons Location01; Lucide mapPin
  static const IconData mapPin = IconData(0xe068, fontFamily: 'BuIcons');
  /// Hugeicons Megaphone02; Lucide megaphone
  static const IconData megaphone = IconData(0xe069, fontFamily: 'BuIcons');
  /// Hugeicons MessageCircle; Lucide messageCircle
  static const IconData messageCircle = IconData(0xe06a, fontFamily: 'BuIcons');
  /// Hugeicons MessageSquare; Lucide messageSquare
  static const IconData messageSquare = IconData(0xe06b, fontFamily: 'BuIcons');
  /// Hugeicons MessageSquareText; Lucide messageSquareText
  static const IconData messageSquareText = IconData(0xe06c, fontFamily: 'BuIcons');
  /// Hugeicons Mic01; Lucide mic
  static const IconData mic = IconData(0xe06d, fontFamily: 'BuIcons');
  /// Hugeicons MicOff01; Lucide micOff
  static const IconData micOff = IconData(0xe06e, fontFamily: 'BuIcons');
  /// Hugeicons Minus; Lucide minus
  static const IconData minus = IconData(0xe06f, fontFamily: 'BuIcons');
  /// Hugeicons Music02; Lucide music
  static const IconData music = IconData(0xe070, fontFamily: 'BuIcons');
  /// Hugeicons Navigation03
  static const IconData navigation = IconData(0xe0be, fontFamily: 'BuIcons');
  /// Hugeicons Newspaper; Lucide newspaper
  static const IconData newspaper = IconData(0xe071, fontFamily: 'BuIcons');
  /// Hugeicons NotebookPen; Lucide notebookPen
  static const IconData notebookPen = IconData(0xe072, fontFamily: 'BuIcons');
  /// Hugeicons OctagonAlert; Lucide octagonAlert
  static const IconData octagonAlert = IconData(0xe073, fontFamily: 'BuIcons');
  /// Hugeicons Palette; Lucide palette
  static const IconData palette = IconData(0xe074, fontFamily: 'BuIcons');
  /// Hugeicons ParkingAreaSquare
  static const IconData parking = IconData(0xe0bf, fontFamily: 'BuIcons');
  /// Hugeicons Pause
  static const IconData pause = IconData(0xe075, fontFamily: 'BuIcons');
  /// Hugeicons Pause (dolu); Material pause_rounded
  static const IconData pauseFilled = IconData(0xe076, fontFamily: 'BuIcons');
  /// Hugeicons Pen01; Lucide pencil
  static const IconData pencil = IconData(0xe077, fontFamily: 'BuIcons');
  /// Hugeicons PencilLine; Lucide pencilLine
  static const IconData pencilLine = IconData(0xe078, fontFamily: 'BuIcons');
  /// Hugeicons Pin; Lucide pin
  static const IconData pin = IconData(0xe079, fontFamily: 'BuIcons');
  /// Hugeicons PinOff; Lucide pinOff
  static const IconData pinOff = IconData(0xe07a, fontFamily: 'BuIcons');
  /// Hugeicons Play; Lucide play
  static const IconData play = IconData(0xe07b, fontFamily: 'BuIcons');
  /// Hugeicons Play (dolu); Material play_arrow_rounded
  static const IconData playFilled = IconData(0xe07c, fontFamily: 'BuIcons');
  /// Hugeicons Add01; Lucide plus; Material add
  static const IconData plus = IconData(0xe07d, fontFamily: 'BuIcons');
  /// Hugeicons QrCode; Lucide qrCode
  static const IconData qrCode = IconData(0xe07e, fontFamily: 'BuIcons');
  /// Hugeicons RefreshCcw; Lucide refreshCcw
  static const IconData refreshCcw = IconData(0xe07f, fontFamily: 'BuIcons');
  /// Hugeicons RefreshCw; Lucide refreshCw
  static const IconData refreshCw = IconData(0xe080, fontFamily: 'BuIcons');
  /// Hugeicons Repeat; Lucide repeat
  static const IconData repeat = IconData(0xe081, fontFamily: 'BuIcons');
  /// Hugeicons Repeat; Lucide repeat2
  static const IconData repeat2 = IconData(0xe082, fontFamily: 'BuIcons');
  /// Hugeicons Reply; Lucide reply
  static const IconData reply = IconData(0xe083, fontFamily: 'BuIcons');
  /// Hugeicons Undo; Lucide rotateCcw
  static const IconData rotateCcw = IconData(0xe084, fontFamily: 'BuIcons');
  /// Hugeicons Redo; Lucide rotateCw
  static const IconData rotateCw = IconData(0xe085, fontFamily: 'BuIcons');
  /// Hugeicons Save; Lucide save
  static const IconData save = IconData(0xe086, fontFamily: 'BuIcons');
  /// Hugeicons Search01; Lucide search
  static const IconData search = IconData(0xe087, fontFamily: 'BuIcons');
  /// Hugeicons SearchX; Lucide searchX
  static const IconData searchX = IconData(0xe088, fontFamily: 'BuIcons');
  /// Hugeicons Sent; Lucide send
  static const IconData send = IconData(0xe089, fontFamily: 'BuIcons');
  /// Hugeicons Settings01; Lucide settings
  static const IconData settings = IconData(0xe08a, fontFamily: 'BuIcons');
  /// Hugeicons Share08; Lucide share2
  static const IconData share2 = IconData(0xe08b, fontFamily: 'BuIcons');
  /// Hugeicons Shield01; Lucide shield
  static const IconData shield = IconData(0xe08c, fontFamily: 'BuIcons');
  /// Hugeicons ShieldAlert; Lucide shieldAlert
  static const IconData shieldAlert = IconData(0xe08d, fontFamily: 'BuIcons');
  /// Hugeicons ShieldBan; Lucide shieldBan
  static const IconData shieldBan = IconData(0xe08e, fontFamily: 'BuIcons');
  /// Hugeicons ShieldCheck; Lucide shieldCheck
  static const IconData shieldCheck = IconData(0xe08f, fontFamily: 'BuIcons');
  /// Hugeicons ShieldX; Lucide shieldX
  static const IconData shieldX = IconData(0xe090, fontFamily: 'BuIcons');
  /// Hugeicons SlidersHorizontal; Lucide slidersHorizontal
  static const IconData slidersHorizontal = IconData(0xe091, fontFamily: 'BuIcons');
  /// Hugeicons Smartphone; Lucide smartphone
  static const IconData smartphone = IconData(0xe092, fontFamily: 'BuIcons');
  /// Hugeicons SquareArrowOutUpRight; Lucide squareArrowOutUpRight
  static const IconData squareArrowOutUpRight = IconData(0xe093, fontFamily: 'BuIcons');
  /// Hugeicons SquarePen; Lucide squarePen
  static const IconData squarePen = IconData(0xe094, fontFamily: 'BuIcons');
  /// Hugeicons SquareTerminal; Lucide squareTerminal
  static const IconData squareTerminal = IconData(0xe095, fontFamily: 'BuIcons');
  /// Hugeicons Star; Lucide star; Material star_outline_rounded
  static const IconData star = IconData(0xe096, fontFamily: 'BuIcons');
  /// Hugeicons Star (dolu); Material star_rounded
  static const IconData starFilled = IconData(0xe097, fontFamily: 'BuIcons');
  /// Hugeicons SwitchCamera; Lucide switchCamera
  static const IconData switchCamera = IconData(0xe098, fontFamily: 'BuIcons');
  /// Hugeicons Tag01; Lucide tag
  static const IconData tag = IconData(0xe099, fontFamily: 'BuIcons');
  /// Hugeicons TextAlignStart; Lucide textAlignStart
  static const IconData textAlignStart = IconData(0xe09a, fontFamily: 'BuIcons');
  /// Hugeicons ThumbsUp; Lucide thumbsUp
  static const IconData thumbsUp = IconData(0xe09b, fontFamily: 'BuIcons');
  /// Hugeicons TimerOff; Lucide timerOff
  static const IconData timerOff = IconData(0xe09c, fontFamily: 'BuIcons');
  /// Hugeicons Delete02; Lucide trash2
  static const IconData trash2 = IconData(0xe09d, fontFamily: 'BuIcons');
  /// Hugeicons Alert01; Lucide triangleAlert
  static const IconData triangleAlert = IconData(0xe09e, fontFamily: 'BuIcons');
  /// Hugeicons Alert01 (dolu); Material warning_rounded
  static const IconData triangleAlertFilled = IconData(0xe09f, fontFamily: 'BuIcons');
  /// Hugeicons Trophy; Lucide trophy
  static const IconData trophy = IconData(0xe0a0, fontFamily: 'BuIcons');
  /// Hugeicons Undo03; Lucide undo2
  static const IconData undo2 = IconData(0xe0a1, fontFamily: 'BuIcons');
  /// Hugeicons User; Lucide user
  static const IconData user = IconData(0xe0a2, fontFamily: 'BuIcons');
  /// Hugeicons UserCheck01; Lucide userCheck
  static const IconData userCheck = IconData(0xe0a3, fontFamily: 'BuIcons');
  /// Hugeicons UserCog; Lucide userCog
  static const IconData userCog = IconData(0xe0a4, fontFamily: 'BuIcons');
  /// Hugeicons UserMinus01; Lucide userMinus
  static const IconData userMinus = IconData(0xe0a5, fontFamily: 'BuIcons');
  /// Hugeicons UserAdd01; Lucide userPlus
  static const IconData userPlus = IconData(0xe0a6, fontFamily: 'BuIcons');
  /// Hugeicons UserSearch01; Lucide userSearch
  static const IconData userSearch = IconData(0xe0a7, fontFamily: 'BuIcons');
  /// Hugeicons UserX; Lucide userX
  static const IconData userX = IconData(0xe0a8, fontFamily: 'BuIcons');
  /// Hugeicons UserGroup; Lucide users; Material people_outline_rounded
  static const IconData users = IconData(0xe0a9, fontFamily: 'BuIcons');
  /// Hugeicons UserGroup (dolu); Material people_rounded
  static const IconData usersFilled = IconData(0xe0aa, fontFamily: 'BuIcons');
  /// Hugeicons Utensils; Lucide utensils
  static const IconData utensils = IconData(0xe0ab, fontFamily: 'BuIcons');
  /// Hugeicons Video01; Lucide video
  static const IconData video = IconData(0xe0ac, fontFamily: 'BuIcons');
  /// Hugeicons VideoOff; Lucide videoOff
  static const IconData videoOff = IconData(0xe0ad, fontFamily: 'BuIcons');
  /// Hugeicons Volleyball; Lucide volleyball
  static const IconData volleyball = IconData(0xe0ae, fontFamily: 'BuIcons');
  /// Hugeicons Vote; Lucide vote
  static const IconData vote = IconData(0xe0af, fontFamily: 'BuIcons');
  /// Hugeicons WandSparkles; Lucide wandSparkles
  static const IconData wandSparkles = IconData(0xe0b0, fontFamily: 'BuIcons');
  /// Hugeicons WifiOff01; Lucide wifiOff
  static const IconData wifiOff = IconData(0xe0b1, fontFamily: 'BuIcons');
  /// Hugeicons Wrench01; Lucide wrench; Material construction
  static const IconData wrench = IconData(0xe0b2, fontFamily: 'BuIcons');
  /// Hugeicons Cancel01; Lucide x
  static const IconData x = IconData(0xe0b3, fontFamily: 'BuIcons');
  /// Hugeicons Zap; Lucide zap
  static const IconData zap = IconData(0xe0b4, fontFamily: 'BuIcons');
  /// Hugeicons ZapOff; Lucide zapOff
  static const IconData zapOff = IconData(0xe0b5, fontFamily: 'BuIcons');

  // Hugeicons ücretsiz kümesinde karşılığı olmayanlar: Lucide'de kalır (tek kapı).
  static const IconData delete = LucideIcons.delete;
  static const IconData keyboard = LucideIcons.keyboard;
  static const IconData menu = LucideIcons.menu;
}
