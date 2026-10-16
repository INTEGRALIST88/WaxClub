import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @flipTheRecord.
  ///
  /// In en, this message translates to:
  /// **'FLIP THE RECORD'**
  String get flipTheRecord;

  /// No description provided for @micStopListening.
  ///
  /// In en, this message translates to:
  /// **'Stop listening (microphone off)'**
  String get micStopListening;

  /// No description provided for @micListenToRoom.
  ///
  /// In en, this message translates to:
  /// **'Listen to the room'**
  String get micListenToRoom;

  /// No description provided for @lyricsEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the microphone to listen to your vinyl and sync the lyrics, with turntable speed compensation.'**
  String get lyricsEmptyHint;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @stopListening.
  ///
  /// In en, this message translates to:
  /// **'Stop listening'**
  String get stopListening;

  /// No description provided for @adjustTiming.
  ///
  /// In en, this message translates to:
  /// **'Adjust timing:'**
  String get adjustTiming;

  /// No description provided for @microphoneListening.
  ///
  /// In en, this message translates to:
  /// **'Microphone listening'**
  String get microphoneListening;

  /// No description provided for @microphoneOff.
  ///
  /// In en, this message translates to:
  /// **'Microphone off'**
  String get microphoneOff;

  /// No description provided for @calibratingIn.
  ///
  /// In en, this message translates to:
  /// **'Calibrating in {seconds}s'**
  String calibratingIn(int seconds);

  /// No description provided for @statusPaused.
  ///
  /// In en, this message translates to:
  /// **'PAUSED'**
  String get statusPaused;

  /// No description provided for @sideEndFlip.
  ///
  /// In en, this message translates to:
  /// **'{side} — FLIP THE RECORD'**
  String sideEndFlip(String side);

  /// No description provided for @endOfSideFlip.
  ///
  /// In en, this message translates to:
  /// **'END OF SIDE — FLIP THE RECORD'**
  String get endOfSideFlip;

  /// No description provided for @statusNextTrack.
  ///
  /// In en, this message translates to:
  /// **'NEXT TRACK'**
  String get statusNextTrack;

  /// No description provided for @statusConfirming.
  ///
  /// In en, this message translates to:
  /// **'confirming...'**
  String get statusConfirming;

  /// No description provided for @rpmValue.
  ///
  /// In en, this message translates to:
  /// **'{rpm} RPM'**
  String rpmValue(String rpm);

  /// No description provided for @greetingWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to {appName}!'**
  String greetingWelcome(String appName);

  /// No description provided for @greetingWelcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Drop the needle and tap the microphone to start.'**
  String get greetingWelcomeSubtitle;

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get goodMorning;

  /// No description provided for @goodAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get goodAfternoon;

  /// No description provided for @goodEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get goodEvening;

  /// No description provided for @greetingTimeOfDay.
  ///
  /// In en, this message translates to:
  /// **'{timeOfDay}, {name}!'**
  String greetingTimeOfDay(String timeOfDay, String name);

  /// No description provided for @greetingLetsGo.
  ///
  /// In en, this message translates to:
  /// **'Let\'s go, {name}!'**
  String greetingLetsGo(String name);

  /// No description provided for @greetingLetsSpin.
  ///
  /// In en, this message translates to:
  /// **'Let\'s spin, {name}!'**
  String greetingLetsSpin(String name);

  /// No description provided for @greetingGreatDay.
  ///
  /// In en, this message translates to:
  /// **'{name}, today is a great day to listen to some music.'**
  String greetingGreatDay(String name);

  /// No description provided for @greetingWhichRecord.
  ///
  /// In en, this message translates to:
  /// **'Which record is on the platter today?'**
  String get greetingWhichRecord;

  /// No description provided for @greetingDropNeedle.
  ///
  /// In en, this message translates to:
  /// **'Drop the needle and tap the microphone.'**
  String get greetingDropNeedle;

  /// No description provided for @greetingPickSide.
  ///
  /// In en, this message translates to:
  /// **'Pick a side, and the lyrics follow along.'**
  String get greetingPickSide;

  /// No description provided for @whatShouldWeCallYou.
  ///
  /// In en, this message translates to:
  /// **'What should we call you?'**
  String get whatShouldWeCallYou;

  /// No description provided for @sortRecentlyPlayed.
  ///
  /// In en, this message translates to:
  /// **'Recently played'**
  String get sortRecentlyPlayed;

  /// No description provided for @sortMostPlayed.
  ///
  /// In en, this message translates to:
  /// **'Most played'**
  String get sortMostPlayed;

  /// No description provided for @sortRecentlyAdded.
  ///
  /// In en, this message translates to:
  /// **'Recently added'**
  String get sortRecentlyAdded;

  /// No description provided for @sortAlphabetical.
  ///
  /// In en, this message translates to:
  /// **'A–Z'**
  String get sortAlphabetical;

  /// No description provided for @whenNever.
  ///
  /// In en, this message translates to:
  /// **'never'**
  String get whenNever;

  /// No description provided for @whenJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get whenJustNow;

  /// No description provided for @whenMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min ago'**
  String whenMinutesAgo(int minutes);

  /// No description provided for @whenToday.
  ///
  /// In en, this message translates to:
  /// **'today {time}'**
  String whenToday(String time);

  /// No description provided for @whenYesterday.
  ///
  /// In en, this message translates to:
  /// **'yesterday {time}'**
  String whenYesterday(String time);

  /// No description provided for @myCollection.
  ///
  /// In en, this message translates to:
  /// **'My Collection'**
  String get myCollection;

  /// No description provided for @recordCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 record} other{{count} records}}'**
  String recordCount(int count);

  /// No description provided for @sort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sort;

  /// No description provided for @collectionEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your collection is empty'**
  String get collectionEmpty;

  /// No description provided for @collectionEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'While a record is playing, tap its cover at the top of the screen and choose \"Add to collection\".'**
  String get collectionEmptyHint;

  /// No description provided for @notPlayedYet.
  ///
  /// In en, this message translates to:
  /// **'Not played yet'**
  String get notPlayedYet;

  /// No description provided for @playedTimesLast.
  ///
  /// In en, this message translates to:
  /// **'Played {count}× · last {when}'**
  String playedTimesLast(int count, String when);

  /// No description provided for @plays.
  ///
  /// In en, this message translates to:
  /// **'Plays'**
  String get plays;

  /// No description provided for @firstPlayed.
  ///
  /// In en, this message translates to:
  /// **'First played'**
  String get firstPlayed;

  /// No description provided for @lastPlayed.
  ///
  /// In en, this message translates to:
  /// **'Last played'**
  String get lastPlayed;

  /// No description provided for @addedWhen.
  ///
  /// In en, this message translates to:
  /// **'Added {when}'**
  String addedWhen(String when);

  /// No description provided for @tracklist.
  ///
  /// In en, this message translates to:
  /// **'Tracklist'**
  String get tracklist;

  /// No description provided for @listeningHistory.
  ///
  /// In en, this message translates to:
  /// **'Listening history'**
  String get listeningHistory;

  /// No description provided for @noPlaysYet.
  ///
  /// In en, this message translates to:
  /// **'No plays recorded yet.'**
  String get noPlaysYet;

  /// No description provided for @removeFromCollection.
  ///
  /// In en, this message translates to:
  /// **'Remove from collection'**
  String get removeFromCollection;

  /// No description provided for @signInToDiscogs.
  ///
  /// In en, this message translates to:
  /// **'Sign in to Discogs'**
  String get signInToDiscogs;

  /// No description provided for @reload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get reload;

  /// No description provided for @browserForward.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get browserForward;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @discogsTokenHint.
  ///
  /// In en, this message translates to:
  /// **'Sign in above: WaxClub picks up your token from the page by itself. If it doesn\'t, copy the token and paste it here:'**
  String get discogsTokenHint;

  /// No description provided for @discogsTokenField.
  ///
  /// In en, this message translates to:
  /// **'Discogs personal token'**
  String get discogsTokenField;

  /// No description provided for @discogsTokenCaptured.
  ///
  /// In en, this message translates to:
  /// **'Token found on the page. Connecting…'**
  String get discogsTokenCaptured;

  /// No description provided for @discogsConnectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Discogs connected'**
  String get discogsConnectedTitle;

  /// No description provided for @discogsTokenCapturedBody.
  ///
  /// In en, this message translates to:
  /// **'Your Discogs token was captured successfully.'**
  String get discogsTokenCapturedBody;

  /// No description provided for @discogsConnectedBody.
  ///
  /// In en, this message translates to:
  /// **'Your Discogs account was connected successfully.'**
  String get discogsConnectedBody;

  /// No description provided for @discogsTokenHelpTitle.
  ///
  /// In en, this message translates to:
  /// **'Generate your token'**
  String get discogsTokenHelpTitle;

  /// No description provided for @discogsTokenHelpBody.
  ///
  /// In en, this message translates to:
  /// **'Your Discogs account has no personal token yet.\n\n1. Tick \"I have read and agree to the Discogs API Terms of Use\" (highlighted in orange).\n2. Tap \"Generate new token\".\n\nWaxClub will pick it up as soon as it appears on the page. If it doesn\'t, copy the token shown after \"Current token\" and paste it in the field below.'**
  String get discogsTokenHelpBody;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @helpGettingStarted.
  ///
  /// In en, this message translates to:
  /// **'Getting started'**
  String get helpGettingStarted;

  /// No description provided for @helpGettingStarted1.
  ///
  /// In en, this message translates to:
  /// **'Put a record on your turntable, drop the needle and tap the microphone button. WaxClub listens for a few seconds, identifies the song and shows the lyrics in sync with the music.'**
  String get helpGettingStarted1;

  /// No description provided for @helpGettingStarted2.
  ///
  /// In en, this message translates to:
  /// **'Keep the phone close to the speakers and avoid talking near it while it listens.'**
  String get helpGettingStarted2;

  /// No description provided for @helpListening.
  ///
  /// In en, this message translates to:
  /// **'Listening and syncing'**
  String get helpListening;

  /// No description provided for @helpListening1.
  ///
  /// In en, this message translates to:
  /// **'The first listen is quick (4 seconds); harder songs get up to 12 seconds automatically.'**
  String get helpListening1;

  /// No description provided for @helpListening2.
  ///
  /// In en, this message translates to:
  /// **'While a song plays, WaxClub checks the sync now and then through the microphone and corrects the timing.'**
  String get helpListening2;

  /// No description provided for @helpListening3.
  ///
  /// In en, this message translates to:
  /// **'At the end of each track it predicts the next one from the record\'s tracklist and confirms it by listening.'**
  String get helpListening3;

  /// No description provided for @helpFlipping.
  ///
  /// In en, this message translates to:
  /// **'Flipping the record'**
  String get helpFlipping;

  /// No description provided for @helpFlipping1.
  ///
  /// In en, this message translates to:
  /// **'When a side ends, the button turns into \"Flip the record\". Tap it before or after you flip: the lyrics of the first track of the new side appear right away and start as soon as the needle hits the music.'**
  String get helpFlipping1;

  /// No description provided for @helpSpeed.
  ///
  /// In en, this message translates to:
  /// **'Turntable speed'**
  String get helpSpeed;

  /// No description provided for @helpSpeed1.
  ///
  /// In en, this message translates to:
  /// **'Turntables rarely spin at exactly 33⅓ RPM. WaxClub measures your turntable\'s real speed while songs play and keeps the lyrics on time.'**
  String get helpSpeed1;

  /// No description provided for @helpSpeed2.
  ///
  /// In en, this message translates to:
  /// **'In the controls you can fine-tune the speed, reset it or lock it.'**
  String get helpSpeed2;

  /// No description provided for @helpTiming.
  ///
  /// In en, this message translates to:
  /// **'Lyrics running early or late'**
  String get helpTiming;

  /// No description provided for @helpTiming1.
  ///
  /// In en, this message translates to:
  /// **'Lyrics a few seconds off? Tap the line that is being sung: the lyrics jump to it on the phone and on the TV. While casting, the phone panel shows the previous, current and next lines to tap. For small corrections use −0.5 s / +0.5 s; the offset is remembered for that song (in Manual mode it moves the whole side).'**
  String get helpTiming1;

  /// No description provided for @helpChangeRecord.
  ///
  /// In en, this message translates to:
  /// **'Change record and Discogs'**
  String get helpChangeRecord;

  /// No description provided for @helpChangeRecord1.
  ///
  /// In en, this message translates to:
  /// **'Songs often appear on several records (albums, compilations, soundtracks). Tap the cover at the top left of the screen, then \"Change record\" to pick the exact record on your turntable; it becomes the default for those songs. Only vinyl records (LP and EP) are listed.'**
  String get helpChangeRecord1;

  /// No description provided for @helpChangeRecord2.
  ///
  /// In en, this message translates to:
  /// **'Tick \"Search Discogs\" to search the largest vinyl database. It is the same switch as the Discogs plugin (C1) in Plugins, where you also connect or disconnect your Discogs account. Your Discogs sign-in stays on this phone only.'**
  String get helpChangeRecord2;

  /// No description provided for @helpCollection.
  ///
  /// In en, this message translates to:
  /// **'Your collection'**
  String get helpCollection;

  /// No description provided for @helpCollection1.
  ///
  /// In en, this message translates to:
  /// **'Tap My Collection (the bookshelf button) to open your records. Add a record with the + button (it opens Identify), or tap the cover of the record that is playing and choose \"Add to collection\". The cloud button shows the sync with your WaxClub account and your Discogs connection.'**
  String get helpCollection1;

  /// No description provided for @helpCollection2.
  ///
  /// In en, this message translates to:
  /// **'WaxClub counts how many times each record was played and when: any track heard counts the record once per listening session. Your collection and listening history are saved to your WaxClub account and sync between your phones. Open a record and tap Play to get it ready to play.'**
  String get helpCollection2;

  /// No description provided for @helpTv.
  ///
  /// In en, this message translates to:
  /// **'Showing the lyrics on the TV'**
  String get helpTv;

  /// No description provided for @helpTv1.
  ///
  /// In en, this message translates to:
  /// **'Tap the cast icon. Chromecast and Google TV devices appear automatically.'**
  String get helpTv1;

  /// No description provided for @helpTv2.
  ///
  /// In en, this message translates to:
  /// **'Fire TV: open the WaxClub app on the TV first; it appears in the list. If it does not, use \"Add by IP\" with the address shown on the TV.'**
  String get helpTv2;

  /// No description provided for @helpTv3.
  ///
  /// In en, this message translates to:
  /// **'Samsung, LG and other TVs without Chromecast: mirror your phone with Smart View, Cast or Wireless display (Miracast). WaxClub turns the TV into a second screen with only the lyrics, and the phone becomes the control panel.'**
  String get helpTv3;

  /// No description provided for @helpTv4.
  ///
  /// In en, this message translates to:
  /// **'The phone and the TV must be on the same Wi-Fi.'**
  String get helpTv4;

  /// No description provided for @helpTroubleshooting.
  ///
  /// In en, this message translates to:
  /// **'Troubleshooting'**
  String get helpTroubleshooting;

  /// No description provided for @helpTroubleshooting1.
  ///
  /// In en, this message translates to:
  /// **'Song not recognized: move the phone closer to the speakers and try again. Some rare records are not in the recognition catalog.'**
  String get helpTroubleshooting1;

  /// No description provided for @helpTroubleshooting2.
  ///
  /// In en, this message translates to:
  /// **'Nothing is ever recognized: another app may be using the microphone (voice assistants, accessibility or call apps). WaxClub warns you when this happens. Close that app and try again.'**
  String get helpTroubleshooting2;

  /// No description provided for @helpTroubleshooting3.
  ///
  /// In en, this message translates to:
  /// **'TV not found: check that it is on and on the same Wi-Fi, and tap \"Search again\". After a TV update it may take a few minutes to show up again.'**
  String get helpTroubleshooting3;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// No description provided for @helpCopyLogsHint.
  ///
  /// In en, this message translates to:
  /// **'Long-press the version to copy the session logs.'**
  String get helpCopyLogsHint;

  /// No description provided for @castingToTv.
  ///
  /// In en, this message translates to:
  /// **'Casting to TV'**
  String get castingToTv;

  /// No description provided for @castScreenName.
  ///
  /// In en, this message translates to:
  /// **'Screen: {name}'**
  String castScreenName(String name);

  /// No description provided for @defaultTvName.
  ///
  /// In en, this message translates to:
  /// **'Living room TV'**
  String get defaultTvName;

  /// No description provided for @disconnectFromTv.
  ///
  /// In en, this message translates to:
  /// **'Disconnect from TV'**
  String get disconnectFromTv;

  /// No description provided for @yourName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get yourName;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @removedFromCollection.
  ///
  /// In en, this message translates to:
  /// **'\"{album}\" removed from your collection.'**
  String removedFromCollection(String album);

  /// No description provided for @addedToCollection.
  ///
  /// In en, this message translates to:
  /// **'\"{album}\" added to your collection.'**
  String addedToCollection(String album);

  /// No description provided for @noEventsLogged.
  ///
  /// In en, this message translates to:
  /// **'No events logged in this session.'**
  String get noEventsLogged;

  /// No description provided for @logsCopied.
  ///
  /// In en, this message translates to:
  /// **'Session logs copied to the clipboard!'**
  String get logsCopied;

  /// No description provided for @noRecordYet.
  ///
  /// In en, this message translates to:
  /// **'No record identified yet.'**
  String get noRecordYet;

  /// No description provided for @tracksOnRecord.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 track on this record} other{{count} tracks on this record}}'**
  String tracksOnRecord(int count);

  /// No description provided for @inCollection.
  ///
  /// In en, this message translates to:
  /// **'In collection'**
  String get inCollection;

  /// No description provided for @addToCollection.
  ///
  /// In en, this message translates to:
  /// **'Add to collection'**
  String get addToCollection;

  /// No description provided for @changeRecord.
  ///
  /// In en, this message translates to:
  /// **'Change record'**
  String get changeRecord;

  /// No description provided for @noTracklistYet.
  ///
  /// In en, this message translates to:
  /// **'No tracklist for this album yet.'**
  String get noTracklistYet;

  /// No description provided for @tracklistFetchedHint.
  ///
  /// In en, this message translates to:
  /// **'The tracklist is fetched automatically from the official catalog (MusicBrainz) while the song plays.'**
  String get tracklistFetchedHint;

  /// No description provided for @playing.
  ///
  /// In en, this message translates to:
  /// **'PLAYING'**
  String get playing;

  /// No description provided for @upNextCaps.
  ///
  /// In en, this message translates to:
  /// **'UP NEXT'**
  String get upNextCaps;

  /// No description provided for @sideLabel.
  ///
  /// In en, this message translates to:
  /// **'Side {side}'**
  String sideLabel(String side);

  /// No description provided for @unknownAlbum.
  ///
  /// In en, this message translates to:
  /// **'Unknown Album'**
  String get unknownAlbum;

  /// No description provided for @upNextTitle.
  ///
  /// In en, this message translates to:
  /// **'Up next: {title}'**
  String upNextTitle(String title);

  /// No description provided for @discogsExplanation.
  ///
  /// In en, this message translates to:
  /// **'Discogs is the world\'s largest vinyl database, maintained by collectors: every pressing, local and imported edition, compilation, A/B side, cover and tracklist.\n\nWith your account connected, WaxClub searches it to find the exact record that is on your turntable — with the right track order, sides and cover.\n\nYour sign-in is stored securely on this phone only, for next time. The app only reads the catalog (it never changes your collection) and you can disconnect at any time.'**
  String get discogsExplanation;

  /// No description provided for @searchFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not search for records right now. Check your internet connection.'**
  String get searchFailed;

  /// No description provided for @connectDiscogs.
  ///
  /// In en, this message translates to:
  /// **'Connect your Discogs account'**
  String get connectDiscogs;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @discogsConnectedAs.
  ///
  /// In en, this message translates to:
  /// **'Discogs connected as {name}.'**
  String discogsConnectedAs(String name);

  /// No description provided for @you.
  ///
  /// In en, this message translates to:
  /// **'you'**
  String get you;

  /// No description provided for @loadTracksFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load this record\'s tracks. Try another record or source.'**
  String get loadTracksFailed;

  /// No description provided for @songNotOnRecord.
  ///
  /// In en, this message translates to:
  /// **'Song not found on this record'**
  String get songNotOnRecord;

  /// No description provided for @songNotOnRecordBody.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" is not in the tracklist of \"{album}\". Use this record anyway?'**
  String songNotOnRecordBody(String title, String album);

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @use.
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get use;

  /// No description provided for @recordChanged.
  ///
  /// In en, this message translates to:
  /// **'Record changed to \"{album}\". It is now the default for these songs.'**
  String recordChanged(String album);

  /// No description provided for @useRecordFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not use this record: {error}'**
  String useRecordFailed(String error);

  /// No description provided for @recordsWithSong.
  ///
  /// In en, this message translates to:
  /// **'Records with \"{title}\" — {artist}'**
  String recordsWithSong(String title, String artist);

  /// No description provided for @searchDiscogs.
  ///
  /// In en, this message translates to:
  /// **'Search Discogs'**
  String get searchDiscogs;

  /// No description provided for @connectedAs.
  ///
  /// In en, this message translates to:
  /// **'Connected as {name}'**
  String connectedAs(String name);

  /// No description provided for @yourAccount.
  ///
  /// In en, this message translates to:
  /// **'your account'**
  String get yourAccount;

  /// No description provided for @discogsSearchSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The most complete vinyl and compilation database (requires your account)'**
  String get discogsSearchSubtitle;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @searchAnotherRecord.
  ///
  /// In en, this message translates to:
  /// **'Search for another record (artist, title...)'**
  String get searchAnotherRecord;

  /// No description provided for @noRecordsFound.
  ///
  /// In en, this message translates to:
  /// **'No records found. Try searching by the record name.'**
  String get noRecordsFound;

  /// No description provided for @recordsFromSource.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 record} other{{count} records}} • {source}'**
  String recordsFromSource(int count, String source);

  /// No description provided for @chipCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get chipCurrent;

  /// No description provided for @chipVinyl.
  ///
  /// In en, this message translates to:
  /// **'Vinyl'**
  String get chipVinyl;

  /// No description provided for @chipCompilation.
  ///
  /// In en, this message translates to:
  /// **'Compilation'**
  String get chipCompilation;

  /// No description provided for @chipLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get chipLive;

  /// No description provided for @editionsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} editions'**
  String editionsCount(int count);

  /// No description provided for @castWaitingConfirm.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the screen to confirm...'**
  String get castWaitingConfirm;

  /// No description provided for @castScreenConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Screen confirmed! Connection established.'**
  String get castScreenConfirmed;

  /// No description provided for @castConnectingTo.
  ///
  /// In en, this message translates to:
  /// **'Connecting to {name}...'**
  String castConnectingTo(String name);

  /// No description provided for @castNoResponse.
  ///
  /// In en, this message translates to:
  /// **'The TV did not respond or refused the cast.'**
  String get castNoResponse;

  /// No description provided for @castLookingAtIp.
  ///
  /// In en, this message translates to:
  /// **'Looking for a Chromecast or WaxClub TV app at {ip}...'**
  String castLookingAtIp(String ip);

  /// No description provided for @castNothingAtIp.
  ///
  /// In en, this message translates to:
  /// **'No Chromecast or WaxClub TV app found at {ip}.'**
  String castNothingAtIp(String ip);

  /// No description provided for @castToTv.
  ///
  /// In en, this message translates to:
  /// **'CAST TO TV'**
  String get castToTv;

  /// No description provided for @searchAgain.
  ///
  /// In en, this message translates to:
  /// **'Search again'**
  String get searchAgain;

  /// No description provided for @castSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching... {count} found'**
  String castSearching(int count);

  /// No description provided for @castDevicesAvailable.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 device available} other{{count} devices available}}'**
  String castDevicesAvailable(int count);

  /// No description provided for @castNoTvFound.
  ///
  /// In en, this message translates to:
  /// **'No TV found on the local network'**
  String get castNoTvFound;

  /// No description provided for @castIdlePrefix.
  ///
  /// In en, this message translates to:
  /// **'Idle • '**
  String get castIdlePrefix;

  /// No description provided for @connectCaps.
  ///
  /// In en, this message translates to:
  /// **'CONNECT'**
  String get connectCaps;

  /// No description provided for @noScreenFound.
  ///
  /// In en, this message translates to:
  /// **'No screen found'**
  String get noScreenFound;

  /// No description provided for @sameWifiHint.
  ///
  /// In en, this message translates to:
  /// **'Make sure the TV and the phone are on the same Wi-Fi.'**
  String get sameWifiHint;

  /// No description provided for @searchNetwork.
  ///
  /// In en, this message translates to:
  /// **'Search network'**
  String get searchNetwork;

  /// No description provided for @hideIp.
  ///
  /// In en, this message translates to:
  /// **'Hide IP'**
  String get hideIp;

  /// No description provided for @addByIp.
  ///
  /// In en, this message translates to:
  /// **'Add by IP'**
  String get addByIp;

  /// No description provided for @ipExample.
  ///
  /// In en, this message translates to:
  /// **'Ex: 192.168.1.105'**
  String get ipExample;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @openAddressInBrowser.
  ///
  /// In en, this message translates to:
  /// **'Open the address in your TV\'s browser.'**
  String get openAddressInBrowser;

  /// No description provided for @castViaBrowser.
  ///
  /// In en, this message translates to:
  /// **'No Chromecast? Cast via browser'**
  String get castViaBrowser;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @tvBrowser.
  ///
  /// In en, this message translates to:
  /// **'TV browser'**
  String get tvBrowser;

  /// No description provided for @screenConnected.
  ///
  /// In en, this message translates to:
  /// **'SCREEN CONNECTED'**
  String get screenConnected;

  /// No description provided for @connectionFailed.
  ///
  /// In en, this message translates to:
  /// **'CONNECTION FAILED'**
  String get connectionFailed;

  /// No description provided for @syncingWithTv.
  ///
  /// In en, this message translates to:
  /// **'SYNCING WITH THE TV'**
  String get syncingWithTv;

  /// No description provided for @openThisAddress.
  ///
  /// In en, this message translates to:
  /// **'Open this address in your TV\'s browser:'**
  String get openThisAddress;

  /// No description provided for @tryAgainCaps.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgainCaps;

  /// No description provided for @changeTv.
  ///
  /// In en, this message translates to:
  /// **'Change TV'**
  String get changeTv;

  /// No description provided for @cancelAndGoBack.
  ///
  /// In en, this message translates to:
  /// **'Cancel and go back'**
  String get cancelAndGoBack;

  /// No description provided for @nowPlaying.
  ///
  /// In en, this message translates to:
  /// **'Now playing'**
  String get nowPlaying;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @tv.
  ///
  /// In en, this message translates to:
  /// **'TV'**
  String get tv;

  /// No description provided for @reconnectingToTv.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting to the TV...'**
  String get reconnectingToTv;

  /// No description provided for @lyricsOnTv.
  ///
  /// In en, this message translates to:
  /// **'Lyrics showing on the TV'**
  String get lyricsOnTv;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @sideCaps.
  ///
  /// In en, this message translates to:
  /// **'SIDE {side}'**
  String sideCaps(String side);

  /// No description provided for @tracksBadge.
  ///
  /// In en, this message translates to:
  /// **'tracks ▸'**
  String get tracksBadge;

  /// No description provided for @noSongIdentified.
  ///
  /// In en, this message translates to:
  /// **'No song identified'**
  String get noSongIdentified;

  /// No description provided for @tapListenHint.
  ///
  /// In en, this message translates to:
  /// **'Tap Listen while the record plays'**
  String get tapListenHint;

  /// No description provided for @trackOfTotal.
  ///
  /// In en, this message translates to:
  /// **' · track {number} of {total}'**
  String trackOfTotal(int number, int total);

  /// No description provided for @upNext.
  ///
  /// In en, this message translates to:
  /// **'Up next'**
  String get upNext;

  /// No description provided for @nextSideStartsWith.
  ///
  /// In en, this message translates to:
  /// **'Next side starts with: {title}'**
  String nextSideStartsWith(String title);

  /// No description provided for @flipToContinue.
  ///
  /// In en, this message translates to:
  /// **'Flip the record to continue'**
  String get flipToContinue;

  /// No description provided for @lyricsReady.
  ///
  /// In en, this message translates to:
  /// **'⚡ lyrics ready'**
  String get lyricsReady;

  /// No description provided for @rpmSuffix.
  ///
  /// In en, this message translates to:
  /// **' RPM'**
  String get rpmSuffix;

  /// No description provided for @measuredOverListens.
  ///
  /// In en, this message translates to:
  /// **'measured over {count} listens'**
  String measuredOverListens(int count);

  /// No description provided for @knownSpeed.
  ///
  /// In en, this message translates to:
  /// **'known speed'**
  String get knownSpeed;

  /// No description provided for @calibrating.
  ///
  /// In en, this message translates to:
  /// **'calibrating...'**
  String get calibrating;

  /// No description provided for @fineSpeedAdjustment.
  ///
  /// In en, this message translates to:
  /// **'Fine speed adjustment'**
  String get fineSpeedAdjustment;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @speedLocked.
  ///
  /// In en, this message translates to:
  /// **'Speed locked'**
  String get speedLocked;

  /// No description provided for @lockSpeed.
  ///
  /// In en, this message translates to:
  /// **'Lock speed'**
  String get lockSpeed;

  /// No description provided for @lyricsSync.
  ///
  /// In en, this message translates to:
  /// **'Time sync'**
  String get lyricsSync;

  /// No description provided for @lyricsSyncHint.
  ///
  /// In en, this message translates to:
  /// **'if the lyrics run early or late'**
  String get lyricsSyncHint;

  /// No description provided for @offset.
  ///
  /// In en, this message translates to:
  /// **'offset'**
  String get offset;

  /// No description provided for @endOfSide.
  ///
  /// In en, this message translates to:
  /// **'End of side'**
  String get endOfSide;

  /// No description provided for @tapAfterFlipping.
  ///
  /// In en, this message translates to:
  /// **'{side} · tap after flipping the record'**
  String tapAfterFlipping(String side);

  /// No description provided for @listeningToRecord.
  ///
  /// In en, this message translates to:
  /// **'Listening to the record...'**
  String get listeningToRecord;

  /// No description provided for @inSyncNextCheck.
  ///
  /// In en, this message translates to:
  /// **'In sync · next check in {seconds}s'**
  String inSyncNextCheck(int seconds);

  /// No description provided for @listeningTapToStop.
  ///
  /// In en, this message translates to:
  /// **'LISTENING... (TAP TO STOP)'**
  String get listeningTapToStop;

  /// No description provided for @listenResync.
  ///
  /// In en, this message translates to:
  /// **'LISTEN / RESYNC'**
  String get listenResync;

  /// No description provided for @statusPitchLocked.
  ///
  /// In en, this message translates to:
  /// **'Pitch locked at {speed}x'**
  String statusPitchLocked(String speed);

  /// No description provided for @statusPitchUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Pitch unlocked for continuous calibration'**
  String get statusPitchUnlocked;

  /// No description provided for @statusListeningMic.
  ///
  /// In en, this message translates to:
  /// **'Listening through the microphone...'**
  String get statusListeningMic;

  /// No description provided for @statusFaintSignal.
  ///
  /// In en, this message translates to:
  /// **'Faint signal or noise: listening longer ({seconds}s)...'**
  String statusFaintSignal(int seconds);

  /// No description provided for @statusIdentifying.
  ///
  /// In en, this message translates to:
  /// **'Identifying song and position...'**
  String get statusIdentifying;

  /// No description provided for @statusRecognitionFailed.
  ///
  /// In en, this message translates to:
  /// **'Recognition request failed ({reason}). Check your internet connection and tap the microphone again.'**
  String statusRecognitionFailed(String reason);

  /// No description provided for @statusSongNotIdentified.
  ///
  /// In en, this message translates to:
  /// **'Song not identified. Move the phone closer to the speakers and tap the microphone again.'**
  String get statusSongNotIdentified;

  /// No description provided for @statusFetchingLyricsAndTracklist.
  ///
  /// In en, this message translates to:
  /// **'Fetching lyrics and tracklist for \"{title}\"...'**
  String statusFetchingLyricsAndTracklist(String title);

  /// No description provided for @statusIdentificationError.
  ///
  /// In en, this message translates to:
  /// **'Identification error: {error}'**
  String statusIdentificationError(String error);

  /// No description provided for @endOfSideLabel.
  ///
  /// In en, this message translates to:
  /// **'End of side {side}'**
  String endOfSideLabel(String side);

  /// No description provided for @statusLikelyNext.
  ///
  /// In en, this message translates to:
  /// **'Likely next track: \"{title}\"'**
  String statusLikelyNext(String title);

  /// No description provided for @statusLastTrackOfSide.
  ///
  /// In en, this message translates to:
  /// **'Last track of side {side}'**
  String statusLastTrackOfSide(String side);

  /// No description provided for @statusTracklistLoaded.
  ///
  /// In en, this message translates to:
  /// **'Tracklist loaded'**
  String get statusTracklistLoaded;

  /// No description provided for @statusInSync.
  ///
  /// In en, this message translates to:
  /// **'In sync • {speed}'**
  String statusInSync(String speed);

  /// No description provided for @statusCheckingSync.
  ///
  /// In en, this message translates to:
  /// **'Checking sync through the microphone...'**
  String get statusCheckingSync;

  /// No description provided for @statusSyncRealigned.
  ///
  /// In en, this message translates to:
  /// **'Sync realigned ({drift}ms) • {speed}'**
  String statusSyncRealigned(String drift, String speed);

  /// No description provided for @statusConfirmingNext.
  ///
  /// In en, this message translates to:
  /// **'▶ {title} — confirming through the microphone...'**
  String statusConfirmingNext(String title);

  /// No description provided for @statusConfirmingAttempt.
  ///
  /// In en, this message translates to:
  /// **'Confirming prediction (attempt {attempt}/{total})...'**
  String statusConfirmingAttempt(int attempt, int total);

  /// No description provided for @statusNotConfirmedFor.
  ///
  /// In en, this message translates to:
  /// **'Not confirmed for {seconds}s...'**
  String statusNotConfirmedFor(int seconds);

  /// No description provided for @statusConfirmed.
  ///
  /// In en, this message translates to:
  /// **'{title} — Confirmed ✓ ({speed})'**
  String statusConfirmed(String title, String speed);

  /// No description provided for @statusPlaybackEnded.
  ///
  /// In en, this message translates to:
  /// **'Playback ended. Microphone off.'**
  String get statusPlaybackEnded;

  /// No description provided for @statusListeningNextAttempt.
  ///
  /// In en, this message translates to:
  /// **'Listening for the next track (attempt {attempt}/{total})...'**
  String statusListeningNextAttempt(int attempt, int total);

  /// No description provided for @statusSilenceWaitingNeedle.
  ///
  /// In en, this message translates to:
  /// **'Silence detected — waiting for the needle ({seconds}s)...'**
  String statusSilenceWaitingNeedle(int seconds);

  /// No description provided for @statusPlaybackEndedOrStopped.
  ///
  /// In en, this message translates to:
  /// **'Playback ended or record stopped. Microphone off.'**
  String get statusPlaybackEndedOrStopped;

  /// No description provided for @statusFetchingLyrics.
  ///
  /// In en, this message translates to:
  /// **'Fetching lyrics for \"{title}\"...'**
  String statusFetchingLyrics(String title);

  /// No description provided for @statusEndOfSideFlip.
  ///
  /// In en, this message translates to:
  /// **'End of side {side}. Flip the record to continue.'**
  String statusEndOfSideFlip(String side);

  /// No description provided for @statusWaitingNeedle.
  ///
  /// In en, this message translates to:
  /// **'▶ {title} — waiting for the needle...'**
  String statusWaitingNeedle(String title);

  /// No description provided for @statusNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'▶ {title} (not confirmed)'**
  String statusNotConfirmed(String title);

  /// No description provided for @statusFlipTimeout.
  ///
  /// In en, this message translates to:
  /// **'Timed out waiting for the record to be flipped. Tap to listen.'**
  String get statusFlipTimeout;

  /// No description provided for @statusListeningNewSide.
  ///
  /// In en, this message translates to:
  /// **'Listening to the new side...'**
  String get statusListeningNewSide;

  /// No description provided for @statusNotIdentifiedSideEnded.
  ///
  /// In en, this message translates to:
  /// **'Not identified yet (side {side} ended). Flip the record or try again.'**
  String statusNotIdentifiedSideEnded(String side);

  /// No description provided for @statusNotIdentifiedFlip.
  ///
  /// In en, this message translates to:
  /// **'Not identified yet (the record ended). Flip the record or try again.'**
  String get statusNotIdentifiedFlip;

  /// No description provided for @statusSyncPaused.
  ///
  /// In en, this message translates to:
  /// **'Sync paused at {position}'**
  String statusSyncPaused(String position);

  /// No description provided for @statusSpeedCalibrated.
  ///
  /// In en, this message translates to:
  /// **'Speed calibrated: {speed}x (+1.8%)'**
  String statusSpeedCalibrated(String speed);

  /// No description provided for @statusMicOffStopped.
  ///
  /// In en, this message translates to:
  /// **'Microphone off. Listening stopped.'**
  String get statusMicOffStopped;

  /// No description provided for @noticeDiscogsNoVinyl.
  ///
  /// In en, this message translates to:
  /// **'Discogs found no vinyl records; showing MusicBrainz results.'**
  String get noticeDiscogsNoVinyl;

  /// No description provided for @noticeDiscogsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Discogs is unavailable right now; showing MusicBrainz results.'**
  String get noticeDiscogsUnavailable;

  /// No description provided for @builtInMicrophone.
  ///
  /// In en, this message translates to:
  /// **'Built-in microphone'**
  String get builtInMicrophone;

  /// No description provided for @micPermissionDeniedHint.
  ///
  /// In en, this message translates to:
  /// **'🎤 Microphone permission denied.\n\nTo enable it manually:\n  Settings → Apps → WaxClub → Permissions → Microphone → Allow\n\nThen try again.'**
  String get micPermissionDeniedHint;

  /// No description provided for @micPermissionNotGranted.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission not granted.'**
  String get micPermissionNotGranted;

  /// No description provided for @discogsSignInRejected.
  ///
  /// In en, this message translates to:
  /// **'Discogs rejected the sign-in request (HTTP {code}).'**
  String discogsSignInRejected(int code);

  /// No description provided for @discogsUnexpectedResponse.
  ///
  /// In en, this message translates to:
  /// **'Unexpected response from Discogs.'**
  String get discogsUnexpectedResponse;

  /// No description provided for @discogsSignInNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Discogs did not confirm the sign-in (HTTP {code}).'**
  String discogsSignInNotConfirmed(int code);

  /// No description provided for @discogsPasteToken.
  ///
  /// In en, this message translates to:
  /// **'Paste the token generated in your Discogs account.'**
  String get discogsPasteToken;

  /// No description provided for @discogsInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid Discogs credentials.'**
  String get discogsInvalidCredentials;

  /// No description provided for @discogsUnavailableHttp.
  ///
  /// In en, this message translates to:
  /// **'Discogs unavailable (HTTP {code}).'**
  String discogsUnavailableHttp(int code);

  /// No description provided for @discogsTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Discogs: too many requests, try again in a few seconds.'**
  String get discogsTooManyRequests;

  /// No description provided for @castDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get castDisconnected;

  /// No description provided for @castConnectingTls.
  ///
  /// In en, this message translates to:
  /// **'Connecting to Chromecast over TLS ({address})...'**
  String castConnectingTls(String address);

  /// No description provided for @castTlsTimeout.
  ///
  /// In en, this message translates to:
  /// **'Timed out connecting to the TV over TLS ({host}): {error}'**
  String castTlsTimeout(String host, String error);

  /// No description provided for @castTlsEstablished.
  ///
  /// In en, this message translates to:
  /// **'TLS connection established. Negotiating channels...'**
  String get castTlsEstablished;

  /// No description provided for @castChannelError.
  ///
  /// In en, this message translates to:
  /// **'TV communication channel error: {error}'**
  String castChannelError(String error);

  /// No description provided for @castTvClosed.
  ///
  /// In en, this message translates to:
  /// **'The TV closed the connection.'**
  String get castTvClosed;

  /// No description provided for @castCheckingStatus.
  ///
  /// In en, this message translates to:
  /// **'Checking TV status...'**
  String get castCheckingStatus;

  /// No description provided for @castStartupTimeout.
  ///
  /// In en, this message translates to:
  /// **'Startup timed out ({seconds}s). The TV did not finish opening the app.'**
  String castStartupTimeout(int seconds);

  /// No description provided for @castStartingApp.
  ///
  /// In en, this message translates to:
  /// **'Starting app ID {appId} on the TV...'**
  String castStartingApp(String appId);

  /// No description provided for @castLaunchFailure.
  ///
  /// In en, this message translates to:
  /// **'Unexpected Cast launch failure ({host}): {error}'**
  String castLaunchFailure(String host, String error);

  /// No description provided for @castReceiverRunning.
  ///
  /// In en, this message translates to:
  /// **'Web receiver running on the TV (transport ID: {id})'**
  String castReceiverRunning(String id);

  /// No description provided for @castTvRefused.
  ///
  /// In en, this message translates to:
  /// **'The TV refused the app: {reason}'**
  String castTvRefused(String reason);

  /// No description provided for @noLogEntries.
  ///
  /// In en, this message translates to:
  /// **'No log entries yet.'**
  String get noLogEntries;

  /// No description provided for @logFileEmpty.
  ///
  /// In en, this message translates to:
  /// **'Log file is empty.'**
  String get logFileEmpty;

  /// No description provided for @couldNotReadLogs.
  ///
  /// In en, this message translates to:
  /// **'Could not read logs: {error}'**
  String couldNotReadLogs(String error);

  /// No description provided for @statusMicBusy.
  ///
  /// In en, this message translates to:
  /// **'Another app is using the microphone (voice assistant, accessibility or call app), so WaxClub can\'t hear the record. Close that app and tap the microphone again.'**
  String get statusMicBusy;

  /// No description provided for @cameraTooltip.
  ///
  /// In en, this message translates to:
  /// **'Identify a record'**
  String get cameraTooltip;

  /// No description provided for @scanTitle.
  ///
  /// In en, this message translates to:
  /// **'Identify your record'**
  String get scanTitle;

  /// No description provided for @scanHowTo.
  ///
  /// In en, this message translates to:
  /// **'Where to point the camera'**
  String get scanHowTo;

  /// No description provided for @scanModeBarcode.
  ///
  /// In en, this message translates to:
  /// **'Barcode'**
  String get scanModeBarcode;

  /// No description provided for @scanModeCatalog.
  ///
  /// In en, this message translates to:
  /// **'Catalog no.'**
  String get scanModeCatalog;

  /// No description provided for @scanModeTyped.
  ///
  /// In en, this message translates to:
  /// **'Type it'**
  String get scanModeTyped;

  /// No description provided for @scanBarcodeHint.
  ///
  /// In en, this message translates to:
  /// **'Point at the barcode on the back cover (usually in a bottom corner)'**
  String get scanBarcodeHint;

  /// No description provided for @scanBarcodeTryCatalog.
  ///
  /// In en, this message translates to:
  /// **'No barcode? Older records usually have none. Try the catalog number.'**
  String get scanBarcodeTryCatalog;

  /// No description provided for @scanTorch.
  ///
  /// In en, this message translates to:
  /// **'Flashlight'**
  String get scanTorch;

  /// No description provided for @scanCameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Camera unavailable. Allow camera access in Settings → Apps → WaxClub → Permissions, or type the record.'**
  String get scanCameraUnavailable;

  /// No description provided for @scanCatalogHint.
  ///
  /// In en, this message translates to:
  /// **'Photograph the spine, the record label or the top corner of the back cover, where the catalog number is printed (e.g. 6349 123, SHVL 804).'**
  String get scanCatalogHint;

  /// No description provided for @scanTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get scanTakePhoto;

  /// No description provided for @scanReadingPhoto.
  ///
  /// In en, this message translates to:
  /// **'Reading the photo...'**
  String get scanReadingPhoto;

  /// No description provided for @scanCatalogFound.
  ///
  /// In en, this message translates to:
  /// **'Catalog numbers found — tap the right one:'**
  String get scanCatalogFound;

  /// No description provided for @scanCatalogNoneFound.
  ///
  /// In en, this message translates to:
  /// **'No catalog number found in the photo. Type it below or take another photo closer to the text.'**
  String get scanCatalogNoneFound;

  /// No description provided for @scanCatalogField.
  ///
  /// In en, this message translates to:
  /// **'Catalog number or barcode'**
  String get scanCatalogField;

  /// No description provided for @scanTypedField.
  ///
  /// In en, this message translates to:
  /// **'Artist and album, or Discogs link'**
  String get scanTypedField;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @scanSearching.
  ///
  /// In en, this message translates to:
  /// **'Looking for \"{query}\"...'**
  String scanSearching(String query);

  /// No description provided for @scanPickPressing.
  ///
  /// In en, this message translates to:
  /// **'Pick your pressing: year, country, label and catalog number help you find it.'**
  String get scanPickPressing;

  /// No description provided for @scanNoResults.
  ///
  /// In en, this message translates to:
  /// **'No vinyl pressing found for \"{query}\". Try another mode or type the record.'**
  String scanNoResults(String query);

  /// No description provided for @scanAgain.
  ///
  /// In en, this message translates to:
  /// **'Scan again'**
  String get scanAgain;

  /// No description provided for @foundAddToCollectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Add to collection?'**
  String get foundAddToCollectionTitle;

  /// No description provided for @foundAlreadyInCollection.
  ///
  /// In en, this message translates to:
  /// **'Already in your collection.'**
  String get foundAlreadyInCollection;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @entryTitle.
  ///
  /// In en, this message translates to:
  /// **'Add to collection'**
  String get entryTitle;

  /// No description provided for @entryRating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get entryRating;

  /// No description provided for @entryMediaCondition.
  ///
  /// In en, this message translates to:
  /// **'Record condition'**
  String get entryMediaCondition;

  /// No description provided for @entrySleeveCondition.
  ///
  /// In en, this message translates to:
  /// **'Sleeve condition'**
  String get entrySleeveCondition;

  /// No description provided for @entryNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get entryNotes;

  /// No description provided for @entryNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get entryNotSet;

  /// No description provided for @entryAlsoDiscogs.
  ///
  /// In en, this message translates to:
  /// **'Also add to my Discogs collection'**
  String get entryAlsoDiscogs;

  /// No description provided for @entryDiscogsAdded.
  ///
  /// In en, this message translates to:
  /// **'Also added to your Discogs collection.'**
  String get entryDiscogsAdded;

  /// No description provided for @entryDiscogsFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not add it to your Discogs collection right now.'**
  String get entryDiscogsFailed;

  /// No description provided for @letsListenTitle.
  ///
  /// In en, this message translates to:
  /// **'Let\'s listen?'**
  String get letsListenTitle;

  /// No description provided for @letsListenBody.
  ///
  /// In en, this message translates to:
  /// **'Drop the needle on \"{album}\" and tap Yes: WaxClub will listen and follow along.'**
  String letsListenBody(String album);

  /// No description provided for @guideBarcodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Barcode'**
  String get guideBarcodeTitle;

  /// No description provided for @guideBarcodeBody.
  ///
  /// In en, this message translates to:
  /// **'Most records from the 80s on have a barcode on the back cover, usually in a bottom corner or on a sticker on the shrink wrap. Hold the phone 10–20 cm away: it reads by itself.'**
  String get guideBarcodeBody;

  /// No description provided for @guideCatalogTitle.
  ///
  /// In en, this message translates to:
  /// **'Catalog number'**
  String get guideCatalogTitle;

  /// No description provided for @guideCatalogBody.
  ///
  /// In en, this message translates to:
  /// **'Older records: look for the code on the spine, on the record label (near the center hole) or in the top corner of the back cover, e.g. \"6349 123\". Take a photo and tap the right number.'**
  String get guideCatalogBody;

  /// No description provided for @guideLightTitle.
  ///
  /// In en, this message translates to:
  /// **'Light and focus'**
  String get guideLightTitle;

  /// No description provided for @guideLightBody.
  ///
  /// In en, this message translates to:
  /// **'Use good light and avoid glare on glossy covers. Turn on the flashlight if it is dark. Hold still until the text is sharp.'**
  String get guideLightBody;

  /// No description provided for @guidePressingTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick your pressing'**
  String get guidePressingTitle;

  /// No description provided for @guidePressingBody.
  ///
  /// In en, this message translates to:
  /// **'The same album has many pressings. Check year, country, label and catalog number, then add it to your collection and start listening.'**
  String get guidePressingBody;

  /// No description provided for @guideNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get guideNext;

  /// No description provided for @guideDone.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get guideDone;

  /// No description provided for @helpCamera.
  ///
  /// In en, this message translates to:
  /// **'Identify a record'**
  String get helpCamera;

  /// No description provided for @helpCamera1.
  ///
  /// In en, this message translates to:
  /// **'Tap Identify (the camera button). Point at the barcode on the back cover, or take a photo of the catalog number on the spine or label. You can also type the artist and album. The first time, a short guide shows where to point the camera.'**
  String get helpCamera1;

  /// No description provided for @helpCamera2.
  ///
  /// In en, this message translates to:
  /// **'Pick your exact pressing (only vinyl is listed), add it to your collection with rating, condition and notes if you like, then tap \"Yes\" to listen: WaxClub prepares the record and shows the steps. Drop the needle and tap the microphone; the next tracks are right from the first song.'**
  String get helpCamera2;

  /// No description provided for @jukeboxTitle.
  ///
  /// In en, this message translates to:
  /// **'Plugin Jukebox'**
  String get jukeboxTitle;

  /// No description provided for @jukeboxLede.
  ///
  /// In en, this message translates to:
  /// **'Every plugin is a 7\" single. The vinyl color tells the kind; the code on the strip selects it. Type a code on the keypad or tap a record.'**
  String get jukeboxLede;

  /// No description provided for @jukeboxChooseSelection.
  ///
  /// In en, this message translates to:
  /// **'Choose a selection: letter + number.'**
  String get jukeboxChooseSelection;

  /// No description provided for @jukeboxNowNumber.
  ///
  /// In en, this message translates to:
  /// **'{category}: now the number.'**
  String jukeboxNowNumber(String category);

  /// No description provided for @jukeboxPressSelect.
  ///
  /// In en, this message translates to:
  /// **'Press Select.'**
  String get jukeboxPressSelect;

  /// No description provided for @jukeboxStartWithLetter.
  ///
  /// In en, this message translates to:
  /// **'Start with the letter of the category.'**
  String get jukeboxStartWithLetter;

  /// No description provided for @jukeboxTypeCode.
  ///
  /// In en, this message translates to:
  /// **'Type a letter and a number, e.g. L1.'**
  String get jukeboxTypeCode;

  /// No description provided for @jukeboxNoSuchCode.
  ///
  /// In en, this message translates to:
  /// **'Selection {code} does not exist.'**
  String jukeboxNoSuchCode(String code);

  /// No description provided for @jukeboxClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get jukeboxClear;

  /// No description provided for @jukeboxSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get jukeboxSelect;

  /// No description provided for @jukeboxOnThePlatter.
  ///
  /// In en, this message translates to:
  /// **'On the platter'**
  String get jukeboxOnThePlatter;

  /// No description provided for @jukeboxNothingPlaying.
  ///
  /// In en, this message translates to:
  /// **'No record here yet.'**
  String get jukeboxNothingPlaying;

  /// No description provided for @jukeboxSelectionStrips.
  ///
  /// In en, this message translates to:
  /// **'Selection strips'**
  String get jukeboxSelectionStrips;

  /// No description provided for @jukeboxAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get jukeboxAll;

  /// No description provided for @jukeboxCrate.
  ///
  /// In en, this message translates to:
  /// **'Record crate'**
  String get jukeboxCrate;

  /// No description provided for @jukeboxCrateHint.
  ///
  /// In en, this message translates to:
  /// **'Plugins not installed yet. Each one shows its source and license before going into the jukebox.'**
  String get jukeboxCrateHint;

  /// No description provided for @jukeboxComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get jukeboxComingSoon;

  /// No description provided for @jukeboxOnPlatter.
  ///
  /// In en, this message translates to:
  /// **'On the platter'**
  String get jukeboxOnPlatter;

  /// No description provided for @jukeboxComingSoonHint.
  ///
  /// In en, this message translates to:
  /// **'Coming soon: this plugin is not available yet.'**
  String get jukeboxComingSoonHint;

  /// No description provided for @jukeboxLockedHint.
  ///
  /// In en, this message translates to:
  /// **'Built in and always on for now.'**
  String get jukeboxLockedHint;

  /// No description provided for @jukeboxExclusiveHint.
  ///
  /// In en, this message translates to:
  /// **'In use. Only one {category} plugin plays at a time: choose another to switch.'**
  String jukeboxExclusiveHint(String category);

  /// No description provided for @jukeboxIsOn.
  ///
  /// In en, this message translates to:
  /// **'On the platter: this plugin is on.'**
  String get jukeboxIsOn;

  /// No description provided for @jukeboxIsOff.
  ///
  /// In en, this message translates to:
  /// **'Off: tap the button to put it on the platter.'**
  String get jukeboxIsOff;

  /// No description provided for @jukeboxTurnOn.
  ///
  /// In en, this message translates to:
  /// **'Put on the platter'**
  String get jukeboxTurnOn;

  /// No description provided for @jukeboxTurnOff.
  ///
  /// In en, this message translates to:
  /// **'Take off the platter'**
  String get jukeboxTurnOff;

  /// No description provided for @jukeboxLicense.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get jukeboxLicense;

  /// No description provided for @jukeboxAiNotice.
  ///
  /// In en, this message translates to:
  /// **'AI content is always marked as AI-generated. Audio never leaves your phone without your consent.'**
  String get jukeboxAiNotice;

  /// No description provided for @pluginCatLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get pluginCatLanguage;

  /// No description provided for @pluginCatDisplay.
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get pluginCatDisplay;

  /// No description provided for @pluginCatAi.
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get pluginCatAi;

  /// No description provided for @pluginRuleLanguage.
  ///
  /// In en, this message translates to:
  /// **'One at a time'**
  String get pluginRuleLanguage;

  /// No description provided for @pluginRuleDisplay.
  ///
  /// In en, this message translates to:
  /// **'Several at once'**
  String get pluginRuleDisplay;

  /// No description provided for @pluginRuleAi.
  ///
  /// In en, this message translates to:
  /// **'Several; marked as AI-generated'**
  String get pluginRuleAi;

  /// No description provided for @pluginAuthorBuiltIn.
  ///
  /// In en, this message translates to:
  /// **'Built in'**
  String get pluginAuthorBuiltIn;

  /// No description provided for @pluginAuthorWaxClub.
  ///
  /// In en, this message translates to:
  /// **'WaxClub'**
  String get pluginAuthorWaxClub;

  /// No description provided for @pluginLicenseOfficial.
  ///
  /// In en, this message translates to:
  /// **'Official translation'**
  String get pluginLicenseOfficial;

  /// No description provided for @pluginLicenseLyrics.
  ///
  /// In en, this message translates to:
  /// **'Lyrics from the sources you enable'**
  String get pluginLicenseLyrics;

  /// No description provided for @pluginLicenseCuriosities.
  ///
  /// In en, this message translates to:
  /// **'Sources cited: Wikipedia (CC BY-SA), Discogs, news outlets'**
  String get pluginLicenseCuriosities;

  /// No description provided for @pluginLicenseAi.
  ///
  /// In en, this message translates to:
  /// **'AI-generated text, always marked'**
  String get pluginLicenseAi;

  /// No description provided for @pluginEnglishName.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get pluginEnglishName;

  /// No description provided for @pluginEnglishDesc.
  ///
  /// In en, this message translates to:
  /// **'Preinstalled. Provides all the menus and texts of the app in English. Other languages will be available as plugins on the official WaxClub website.'**
  String get pluginEnglishDesc;

  /// No description provided for @pluginLyricsName.
  ///
  /// In en, this message translates to:
  /// **'Synced lyrics'**
  String get pluginLyricsName;

  /// No description provided for @pluginLyricsDesc.
  ///
  /// In en, this message translates to:
  /// **'Shows the lyrics in sync with the record, on the phone and on the TV, in the same style on both.'**
  String get pluginLyricsDesc;

  /// No description provided for @pluginCuriositiesName.
  ///
  /// In en, this message translates to:
  /// **'Record curiosities'**
  String get pluginCuriositiesName;

  /// No description provided for @pluginCuriositiesDesc.
  ///
  /// In en, this message translates to:
  /// **'Short facts about the record and each track, plus recent news about the artist, always in English with the source (Wikipedia, Discogs pressing notes, news outlets), rising and fading as the music plays. Shown when there are no lyrics.'**
  String get pluginCuriositiesDesc;

  /// No description provided for @pluginAiCuriositiesName.
  ///
  /// In en, this message translates to:
  /// **'AI curiosities'**
  String get pluginAiCuriositiesName;

  /// No description provided for @pluginAiCuriositiesDesc.
  ///
  /// In en, this message translates to:
  /// **'Summarizes facts about the record and its tracks from Discogs and Wikipedia, always with the source.'**
  String get pluginAiCuriositiesDesc;

  /// No description provided for @pluginAiTranslateName.
  ///
  /// In en, this message translates to:
  /// **'AI translator'**
  String get pluginAiTranslateName;

  /// No description provided for @pluginAiTranslateDesc.
  ///
  /// In en, this message translates to:
  /// **'Translates everything that isn\'t a menu: song lyrics (each line with its translation below it, on the phone and on the TV), curiosities and news about the record, into the language you choose. Uses a chip from your WaxBrain; translations stay on your phone.'**
  String get pluginAiTranslateDesc;

  /// No description provided for @helpPlugins.
  ///
  /// In en, this message translates to:
  /// **'Plugins (jukebox)'**
  String get helpPlugins;

  /// No description provided for @helpPlugins1.
  ///
  /// In en, this message translates to:
  /// **'Tap Plugins (the jack plug button) to open the Plugin Jukebox. Each plugin is a colored 7\" single: green for languages, cyan for display, lilac for AI and orange for connections to other services (C1 Discogs comes preinstalled). English comes preinstalled; other languages will be available on the official WaxClub website.'**
  String get helpPlugins1;

  /// No description provided for @helpPlugins2.
  ///
  /// In en, this message translates to:
  /// **'Tap a record or type its code (e.g. L1) on the keypad and press Select to see details and turn it on or off. Records on the platter are the ones in use; the ones in the crate are coming soon.'**
  String get helpPlugins2;

  /// No description provided for @plugins.
  ///
  /// In en, this message translates to:
  /// **'Plugins'**
  String get plugins;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Identify'**
  String get camera;

  /// No description provided for @helpTopBar.
  ///
  /// In en, this message translates to:
  /// **'The top bar'**
  String get helpTopBar;

  /// No description provided for @helpTopBar1.
  ///
  /// In en, this message translates to:
  /// **'At the top left is the WaxClub logo, or the cover of the record that is playing. With nothing playing, tap the logo to pick a record to play: type an artist and/or album, your collection comes first, then Discogs. While a record plays, tap the cover to see the tracklist. With the phone sideways, the record name, the song and what comes next appear beside it.'**
  String get helpTopBar1;

  /// No description provided for @helpTopBar2.
  ///
  /// In en, this message translates to:
  /// **'Below the top bar, on the right, the wooden buttons from left to right: Profile (user), Identify (camera), Manual (on/off switch), My Collection (bookshelf), Plugins (jack plug) and Help (question mark). Their names show up one by one when the app opens. The button at the top right shows the lyrics on your TV.'**
  String get helpTopBar2;

  /// No description provided for @manual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get manual;

  /// No description provided for @manualOnHint.
  ///
  /// In en, this message translates to:
  /// **'Manual mode on. Tap ▶ to choose where the needle starts; the lyrics follow the track timing. The switch turns off by itself when the record ends.'**
  String get manualOnHint;

  /// No description provided for @manualOffHint.
  ///
  /// In en, this message translates to:
  /// **'Manual mode off: WaxClub recognizes the songs automatically.'**
  String get manualOffHint;

  /// No description provided for @helpManual.
  ///
  /// In en, this message translates to:
  /// **'Manual mode'**
  String get helpManual;

  /// No description provided for @helpManual1.
  ///
  /// In en, this message translates to:
  /// **'For records the recognition system does not know. With the Manual switch on, the microphone button becomes a chrome ▶: tap it, pick the track where the needle starts and drop the needle. The microphone only measures the volume to find the start; then the lyrics and track changes follow the record\'s track timing.'**
  String get helpManual1;

  /// No description provided for @helpManual2.
  ///
  /// In en, this message translates to:
  /// **'At the end of a side, flip the record and tap ▶. In the tracklist you can tap a track to jump to it. After Identify, WaxClub checks the recognition system and turns Manual mode on by itself when the record is not there. The switch starts off and turns off when the record ends (last song of the last side).'**
  String get helpManual2;

  /// No description provided for @manualModeOffStatus.
  ///
  /// In en, this message translates to:
  /// **'Manual mode off.'**
  String get manualModeOffStatus;

  /// No description provided for @manualWaitingNeedle.
  ///
  /// In en, this message translates to:
  /// **'▶ {number} {title} — drop the needle: the lyrics start with the music.'**
  String manualWaitingNeedle(String number, String title);

  /// No description provided for @manualNeedleTimeout.
  ///
  /// In en, this message translates to:
  /// **'The music did not start. Tap ▶ when the needle is on the record.'**
  String get manualNeedleTimeout;

  /// No description provided for @manualPlaying.
  ///
  /// In en, this message translates to:
  /// **'Manual • {number} {title}'**
  String manualPlaying(String number, String title);

  /// No description provided for @manualNoDuration.
  ///
  /// In en, this message translates to:
  /// **'Manual • track length unknown: tap the next track in the tracklist when it starts.'**
  String get manualNoDuration;

  /// No description provided for @manualRecordEnded.
  ///
  /// In en, this message translates to:
  /// **'End of the record. Manual mode off.'**
  String get manualRecordEnded;

  /// No description provided for @manualFlipAndPlay.
  ///
  /// In en, this message translates to:
  /// **'End of side {side}. Flip the record and tap ▶.'**
  String manualFlipAndPlay(String side);

  /// No description provided for @manualStartTitle.
  ///
  /// In en, this message translates to:
  /// **'Where does the needle start?'**
  String get manualStartTitle;

  /// No description provided for @manualUseMic.
  ///
  /// In en, this message translates to:
  /// **'Detect the start with the microphone'**
  String get manualUseMic;

  /// No description provided for @manualUseMicHint.
  ///
  /// In en, this message translates to:
  /// **'The microphone finds the start of the music, then listens to the end of each track to change to the next one right on time.'**
  String get manualUseMicHint;

  /// No description provided for @manualNoMicHint.
  ///
  /// In en, this message translates to:
  /// **'The lyrics start as soon as you pick the track.'**
  String get manualNoMicHint;

  /// No description provided for @manualMissingDurations.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 track has no length: tap it in the tracklist when it starts.} other{{count} tracks have no length: tap them in the tracklist when they start.}}'**
  String manualMissingDurations(int count);

  /// No description provided for @manualNoRecord.
  ///
  /// In en, this message translates to:
  /// **'Identify the record first: Manual mode follows its tracklist.'**
  String get manualNoRecord;

  /// No description provided for @manualPlayTooltip.
  ///
  /// In en, this message translates to:
  /// **'Start (Manual mode)'**
  String get manualPlayTooltip;

  /// No description provided for @manualStopTooltip.
  ///
  /// In en, this message translates to:
  /// **'Stop (Manual mode)'**
  String get manualStopTooltip;

  /// No description provided for @manualNextSideTooltip.
  ///
  /// In en, this message translates to:
  /// **'Start the next side'**
  String get manualNextSideTooltip;

  /// No description provided for @catalogChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking the recognition system...'**
  String get catalogChecking;

  /// No description provided for @catalogNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Not in the recognition system'**
  String get catalogNotFoundTitle;

  /// No description provided for @catalogNotFoundBody.
  ///
  /// In en, this message translates to:
  /// **'This record was not found in the recognition system. Switching to Manual mode: the lyrics will follow the track timing of the record.'**
  String get catalogNotFoundBody;

  /// No description provided for @curiosityAboutRecord.
  ///
  /// In en, this message translates to:
  /// **'About the record'**
  String get curiosityAboutRecord;

  /// No description provided for @curiosityAboutTrack.
  ///
  /// In en, this message translates to:
  /// **'About this track'**
  String get curiosityAboutTrack;

  /// No description provided for @curiositySource.
  ///
  /// In en, this message translates to:
  /// **'Source: {source}'**
  String curiositySource(String source);

  /// No description provided for @helpCuriosities.
  ///
  /// In en, this message translates to:
  /// **'Curiosities'**
  String get helpCuriosities;

  /// No description provided for @helpCuriosities1.
  ///
  /// In en, this message translates to:
  /// **'When a song has no lyrics, WaxClub shows short facts about the record and recent news about the artist (at the start of a side), and facts about the track, rising and fading as the music plays, on the phone and on the TV. Everything is in English and shows its source (Wikipedia, the Discogs pressing notes, or the news outlet and date).'**
  String get helpCuriosities1;

  /// No description provided for @helpCuriosities2.
  ///
  /// In en, this message translates to:
  /// **'Facts are saved on the phone, so they also work offline next time. Turn them off in Plugins (D2 Record curiosities).'**
  String get helpCuriosities2;

  /// No description provided for @curiosityLatestNews.
  ///
  /// In en, this message translates to:
  /// **'Latest news'**
  String get curiosityLatestNews;

  /// No description provided for @newsSourceDate.
  ///
  /// In en, this message translates to:
  /// **'{source} · {date}'**
  String newsSourceDate(String source, String date);

  /// No description provided for @jukeboxMoreLanguages.
  ///
  /// In en, this message translates to:
  /// **'More languages will be available as plugins on the official WaxClub website.'**
  String get jukeboxMoreLanguages;

  /// No description provided for @secondScreenMirror.
  ///
  /// In en, this message translates to:
  /// **'No Chromecast? Mirror with Smart View / Miracast'**
  String get secondScreenMirror;

  /// No description provided for @secondScreenShowOn.
  ///
  /// In en, this message translates to:
  /// **'Show the lyrics on {name}'**
  String secondScreenShowOn(String name);

  /// No description provided for @secondScreenDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Smart View'**
  String get secondScreenDefaultName;

  /// No description provided for @secondScreenHint.
  ///
  /// In en, this message translates to:
  /// **'Pick your TV in the system screen (Smart View, Cast or Wireless display). WaxClub shows only the lyrics on the TV and keeps the controls on your phone.'**
  String get secondScreenHint;

  /// No description provided for @manualSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Not recognized for a while. This record may not be in the recognition system: switch to Manual mode?'**
  String get manualSuggestion;

  /// No description provided for @manualSuggestionAction.
  ///
  /// In en, this message translates to:
  /// **'Manual mode'**
  String get manualSuggestionAction;

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'WaxClub account'**
  String get accountTitle;

  /// No description provided for @accountTooltip.
  ///
  /// In en, this message translates to:
  /// **'WaxClub account'**
  String get accountTooltip;

  /// No description provided for @accountEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get accountEmailLabel;

  /// No description provided for @accountSendCode.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get accountSendCode;

  /// No description provided for @accountCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get accountCodeLabel;

  /// No description provided for @accountSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get accountSignIn;

  /// No description provided for @accountResend.
  ///
  /// In en, this message translates to:
  /// **'Send a new code'**
  String get accountResend;

  /// No description provided for @accountSignedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as'**
  String get accountSignedInAs;

  /// No description provided for @accountLastSync.
  ///
  /// In en, this message translates to:
  /// **'Last synced: {when}'**
  String accountLastSync(String when);

  /// No description provided for @accountNeverSynced.
  ///
  /// In en, this message translates to:
  /// **'Not synced yet'**
  String get accountNeverSynced;

  /// No description provided for @accountSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing...'**
  String get accountSyncing;

  /// No description provided for @accountSyncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get accountSyncNow;

  /// No description provided for @accountSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'The last sync failed. Tap Sync now to try again.'**
  String get accountSyncFailed;

  /// No description provided for @accountSyncInfo.
  ///
  /// In en, this message translates to:
  /// **'Your collection syncs automatically when it changes. Listening history is backed up to your account.'**
  String get accountSyncInfo;

  /// No description provided for @accountSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get accountSignOut;

  /// No description provided for @accountDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get accountDelete;

  /// No description provided for @accountDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your WaxClub account?'**
  String get accountDeleteConfirmTitle;

  /// No description provided for @accountDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes your WaxClub account, your synced collection and your listening history from the WaxClub server. It cannot be undone.\n\nYour Discogs collection is NOT affected: records you added to Discogs stay in your Discogs account. The records saved on this phone also stay.'**
  String get accountDeleteConfirmBody;

  /// No description provided for @accountDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get accountDeleteConfirm;

  /// No description provided for @accountErrorEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get accountErrorEmail;

  /// No description provided for @accountErrorCode.
  ///
  /// In en, this message translates to:
  /// **'Wrong code. Check the email and try again.'**
  String get accountErrorCode;

  /// No description provided for @accountErrorExpired.
  ///
  /// In en, this message translates to:
  /// **'This code has expired or was used too many times. Ask for a new one.'**
  String get accountErrorExpired;

  /// No description provided for @accountErrorTooMany.
  ///
  /// In en, this message translates to:
  /// **'Too many codes requested. Try again in an hour.'**
  String get accountErrorTooMany;

  /// No description provided for @accountErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'No connection to the WaxClub server. Check your internet.'**
  String get accountErrorNetwork;

  /// No description provided for @accountErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get accountErrorGeneric;

  /// No description provided for @authWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to WaxClub'**
  String get authWelcome;

  /// No description provided for @authSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to join the club: your records, your city and your listening history, always in sync.'**
  String get authSubtitle;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get authShowPassword;

  /// No description provided for @authForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgotPassword;

  /// No description provided for @authNoAccount.
  ///
  /// In en, this message translates to:
  /// **'New to WaxClub?'**
  String get authNoAccount;

  /// No description provided for @authCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authCreateAccount;

  /// No description provided for @authContinueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get authContinueWithGoogle;

  /// No description provided for @authOr.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get authOr;

  /// No description provided for @signUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get signUpTitle;

  /// No description provided for @signUpUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get signUpUsername;

  /// No description provided for @signUpUsernameHint.
  ///
  /// In en, this message translates to:
  /// **'3 to 20 characters: letters, numbers, dot or underscore.'**
  String get signUpUsernameHint;

  /// No description provided for @signUpUsernameTaken.
  ///
  /// In en, this message translates to:
  /// **'This username is taken.'**
  String get signUpUsernameTaken;

  /// No description provided for @signUpUsernameAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get signUpUsernameAvailable;

  /// No description provided for @signUpPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters.'**
  String get signUpPasswordHint;

  /// No description provided for @signUpCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get signUpCountry;

  /// No description provided for @signUpState.
  ///
  /// In en, this message translates to:
  /// **'State / province'**
  String get signUpState;

  /// No description provided for @signUpCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get signUpCity;

  /// No description provided for @signUpSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get signUpSearch;

  /// No description provided for @signUpPickCountryFirst.
  ///
  /// In en, this message translates to:
  /// **'Choose the country first'**
  String get signUpPickCountryFirst;

  /// No description provided for @signUpPickStateFirst.
  ///
  /// In en, this message translates to:
  /// **'Choose the state first'**
  String get signUpPickStateFirst;

  /// No description provided for @signUpCityHint.
  ///
  /// In en, this message translates to:
  /// **'Type to search your city'**
  String get signUpCityHint;

  /// No description provided for @signUpNoResults.
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get signUpNoResults;

  /// No description provided for @signUpLocationWhy.
  ///
  /// In en, this message translates to:
  /// **'Your city is used to show concerts near you.'**
  String get signUpLocationWhy;

  /// No description provided for @verifyTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm your email'**
  String get verifyTitle;

  /// No description provided for @verifyBody.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to {email}. Enter it below to activate your account. Check your spam folder if it does not arrive.'**
  String verifyBody(String email);

  /// No description provided for @verifyConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get verifyConfirm;

  /// No description provided for @verifyResent.
  ///
  /// In en, this message translates to:
  /// **'A new code is on its way.'**
  String get verifyResent;

  /// No description provided for @forgotTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get forgotTitle;

  /// No description provided for @forgotBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the email of your account. We will send you a code to choose a new password.'**
  String get forgotBody;

  /// No description provided for @forgotCodeSent.
  ///
  /// In en, this message translates to:
  /// **'If {email} has a WaxClub account, a 6-digit code is on its way.'**
  String forgotCodeSent(String email);

  /// No description provided for @forgotNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get forgotNewPassword;

  /// No description provided for @forgotSave.
  ///
  /// In en, this message translates to:
  /// **'Save and sign in'**
  String get forgotSave;

  /// No description provided for @profileCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Complete your profile'**
  String get profileCompleteTitle;

  /// No description provided for @profileCompleteBody.
  ///
  /// In en, this message translates to:
  /// **'Choose a username and tell us where you are.'**
  String get profileCompleteBody;

  /// No description provided for @profileSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get profileSave;

  /// No description provided for @accountEditProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get accountEditProfile;

  /// No description provided for @authErrorCredentials.
  ///
  /// In en, this message translates to:
  /// **'Wrong email or password.'**
  String get authErrorCredentials;

  /// No description provided for @authErrorNoPassword.
  ///
  /// In en, this message translates to:
  /// **'This account has no password yet. Tap \"Forgot password?\" to create one.'**
  String get authErrorNoPassword;

  /// No description provided for @authErrorEmailTaken.
  ///
  /// In en, this message translates to:
  /// **'This email already has an account. Sign in or reset the password.'**
  String get authErrorEmailTaken;

  /// No description provided for @authErrorWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'The password needs at least 8 characters.'**
  String get authErrorWeakPassword;

  /// No description provided for @authErrorUsername.
  ///
  /// In en, this message translates to:
  /// **'Choose a valid username.'**
  String get authErrorUsername;

  /// No description provided for @authErrorLocation.
  ///
  /// In en, this message translates to:
  /// **'Choose your country, state and city.'**
  String get authErrorLocation;

  /// No description provided for @authErrorTooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait 15 minutes and try again.'**
  String get authErrorTooManyAttempts;

  /// No description provided for @authErrorRequired.
  ///
  /// In en, this message translates to:
  /// **'Fill in all the fields.'**
  String get authErrorRequired;

  /// No description provided for @geoAttribution.
  ///
  /// In en, this message translates to:
  /// **'Location data © GeoNames (geonames.org), CC BY 4.0.'**
  String get geoAttribution;

  /// No description provided for @pluginCatConnections.
  ///
  /// In en, this message translates to:
  /// **'Connections'**
  String get pluginCatConnections;

  /// No description provided for @pluginRuleConnections.
  ///
  /// In en, this message translates to:
  /// **'Link WaxClub to other music services. Each connection signs in to that service; you can turn it off or disconnect at any time.'**
  String get pluginRuleConnections;

  /// No description provided for @pluginDiscogsName.
  ///
  /// In en, this message translates to:
  /// **'Discogs'**
  String get pluginDiscogsName;

  /// No description provided for @pluginDiscogsDesc.
  ///
  /// In en, this message translates to:
  /// **'Connect your Discogs account to search the exact pressing of your records, add the records you identify to your Discogs collection and read the pressing notes in the curiosities.'**
  String get pluginDiscogsDesc;

  /// No description provided for @pluginLicenseDiscogs.
  ///
  /// In en, this message translates to:
  /// **'Discogs API (data © Discogs). Your Discogs sign-in stays on this phone.'**
  String get pluginLicenseDiscogs;

  /// No description provided for @jukeboxNotConnected.
  ///
  /// In en, this message translates to:
  /// **'No account connected yet.'**
  String get jukeboxNotConnected;

  /// No description provided for @jukeboxDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get jukeboxDisconnect;

  /// No description provided for @jukeboxConnectAccount.
  ///
  /// In en, this message translates to:
  /// **'Connect your {service} account'**
  String jukeboxConnectAccount(String service);

  /// No description provided for @helpAccount.
  ///
  /// In en, this message translates to:
  /// **'Your WaxClub account'**
  String get helpAccount;

  /// No description provided for @helpAccount1.
  ///
  /// In en, this message translates to:
  /// **'WaxClub opens with the sign-in screen: Continue with Google, or create an account with your email and a password (a 6-digit code sent to your email confirms it). Then choose a @username and your country, state or province and city. Your city will be used for concerts near you.'**
  String get helpAccount1;

  /// No description provided for @helpAccount2.
  ///
  /// In en, this message translates to:
  /// **'You stay signed in on this phone. Forgot your password? Tap \"Forgot password?\" on the sign-in screen and use the code sent to your email. The Profile button (the first wooden button) shows your details and lets you edit your profile, sign out or delete the account.'**
  String get helpAccount2;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Your profile'**
  String get profileTitle;

  /// No description provided for @profileUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get profileUsername;

  /// No description provided for @profileLocation.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get profileLocation;

  /// No description provided for @profileSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign-in'**
  String get profileSignIn;

  /// No description provided for @profileSignInGoogle.
  ///
  /// In en, this message translates to:
  /// **'Google'**
  String get profileSignInGoogle;

  /// No description provided for @profileSignInEmail.
  ///
  /// In en, this message translates to:
  /// **'Email and password'**
  String get profileSignInEmail;

  /// No description provided for @profileSignInBoth.
  ///
  /// In en, this message translates to:
  /// **'Google and email'**
  String get profileSignInBoth;

  /// No description provided for @syncTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get syncTitle;

  /// No description provided for @syncTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sync your collection'**
  String get syncTooltip;

  /// No description provided for @syncAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'WaxClub account'**
  String get syncAccountTitle;

  /// No description provided for @syncDiscogsTitle.
  ///
  /// In en, this message translates to:
  /// **'Discogs'**
  String get syncDiscogsTitle;

  /// No description provided for @syncDiscogsNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected. Connect your Discogs account to add the records you identify to your Discogs collection.'**
  String get syncDiscogsNotConnected;

  /// No description provided for @syncDiscogsConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect Discogs'**
  String get syncDiscogsConnect;

  /// No description provided for @syncDiscogsPluginOff.
  ///
  /// In en, this message translates to:
  /// **'The Discogs plugin (C1) is off. Turn it on in Plugins to use Discogs.'**
  String get syncDiscogsPluginOff;

  /// No description provided for @collectionAddRecord.
  ///
  /// In en, this message translates to:
  /// **'Add a record'**
  String get collectionAddRecord;

  /// No description provided for @readyTitle.
  ///
  /// In en, this message translates to:
  /// **'Ready to play'**
  String get readyTitle;

  /// No description provided for @readyStepsAuto.
  ///
  /// In en, this message translates to:
  /// **'1. Put side A on the turntable.\n2. Drop the needle.\n3. Tap the microphone button: WaxClub listens and the lyrics start in sync.'**
  String get readyStepsAuto;

  /// No description provided for @readyStepsManual.
  ///
  /// In en, this message translates to:
  /// **'1. Put side A on the turntable.\n2. Tap the chrome ▶ and pick the first track.\n3. Drop the needle: the lyrics start with the music.\n\nTo calibrate, tap the line being sung: the lyrics jump to it (on the TV too). Do it whenever the lyrics run early or late, or the needle skips.'**
  String get readyStepsManual;

  /// No description provided for @readyGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get readyGotIt;

  /// No description provided for @lyricSyncTooltip.
  ///
  /// In en, this message translates to:
  /// **'Lyrics timing: tap − or + if the lyrics run late or early. In Manual mode it also moves the track changes.'**
  String get lyricSyncTooltip;

  /// No description provided for @manualNeedleSkipWarning.
  ///
  /// In en, this message translates to:
  /// **'If the needle skips or you lift it, the lyrics can go out of sync. Tap the line being sung to calibrate, or tap the right track in the list.'**
  String get manualNeedleSkipWarning;

  /// No description provided for @helpManual3.
  ///
  /// In en, this message translates to:
  /// **'With the microphone on, WaxClub listens to the last 10 seconds of each track until the next one starts, so it finds the gap between tracks (usually 1 to 3 seconds) and changes tracks right on time. When the track timing comes from a trusted source (the pressing on Discogs or MusicBrainz), it also estimates your turntable\'s speed. Two lyric adjustments (−0.5 s / +0.5 s) more than a minute apart also estimate the speed for this session.'**
  String get helpManual3;

  /// No description provided for @helpManual4.
  ///
  /// In en, this message translates to:
  /// **'If the needle skips or you lift it, the lyrics can go out of sync. Fix it with −0.5 s / +0.5 s (just above the ▶, or on the phone panel while casting), or tap the right track in the list.'**
  String get helpManual4;

  /// No description provided for @playRecordTitle.
  ///
  /// In en, this message translates to:
  /// **'Play a record'**
  String get playRecordTitle;

  /// No description provided for @playRecordTooltip.
  ///
  /// In en, this message translates to:
  /// **'Play a record'**
  String get playRecordTooltip;

  /// No description provided for @playRecordSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Artist and/or album'**
  String get playRecordSearchHint;

  /// No description provided for @playRecordMyCollection.
  ///
  /// In en, this message translates to:
  /// **'My Collection'**
  String get playRecordMyCollection;

  /// No description provided for @playRecordFrom.
  ///
  /// In en, this message translates to:
  /// **'From {source}'**
  String playRecordFrom(String source);

  /// No description provided for @playRecordNoCollectionMatch.
  ///
  /// In en, this message translates to:
  /// **'No records in your collection match.'**
  String get playRecordNoCollectionMatch;

  /// No description provided for @playRecordEmptyCollection.
  ///
  /// In en, this message translates to:
  /// **'Your collection is empty. Search for a record above.'**
  String get playRecordEmptyCollection;

  /// No description provided for @playRecordSearchMore.
  ///
  /// In en, this message translates to:
  /// **'Search Discogs'**
  String get playRecordSearchMore;

  /// No description provided for @playRecordPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get playRecordPlay;

  /// No description provided for @playRecordPlayAndAdd.
  ///
  /// In en, this message translates to:
  /// **'Play and add to collection'**
  String get playRecordPlayAndAdd;

  /// No description provided for @playRecordJustPlay.
  ///
  /// In en, this message translates to:
  /// **'Just play'**
  String get playRecordJustPlay;

  /// No description provided for @playRecordInCollection.
  ///
  /// In en, this message translates to:
  /// **'In your collection'**
  String get playRecordInCollection;

  /// No description provided for @playRecordNoTracks.
  ///
  /// In en, this message translates to:
  /// **'The track list of this record was not found. Try another pressing.'**
  String get playRecordNoTracks;

  /// No description provided for @curiositiesTooltip.
  ///
  /// In en, this message translates to:
  /// **'Curiosities about this record'**
  String get curiositiesTooltip;

  /// No description provided for @curiositiesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No curiosities found for this record yet.'**
  String get curiositiesEmpty;

  /// No description provided for @curiositiesSource.
  ///
  /// In en, this message translates to:
  /// **'Source: {source}'**
  String curiositiesSource(String source);

  /// No description provided for @lyricsTapLine.
  ///
  /// In en, this message translates to:
  /// **'Or tap the line being sung'**
  String get lyricsTapLine;

  /// No description provided for @groupByArtist.
  ///
  /// In en, this message translates to:
  /// **'Artist / Band'**
  String get groupByArtist;

  /// No description provided for @groupByAlbum.
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get groupByAlbum;

  /// No description provided for @lyricsTapToCalibrate.
  ///
  /// In en, this message translates to:
  /// **'Tap the line being sung to calibrate'**
  String get lyricsTapToCalibrate;

  /// No description provided for @timeSyncTapHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to shift the timing'**
  String get timeSyncTapHint;

  /// No description provided for @manualNextWaiting.
  ///
  /// In en, this message translates to:
  /// **'Next: {number} {title} — starts with the music.'**
  String manualNextWaiting(String number, String title);

  /// No description provided for @manualSwitchingToAuto.
  ///
  /// In en, this message translates to:
  /// **'Listening to switch to automatic…'**
  String get manualSwitchingToAuto;

  /// No description provided for @removeRecordConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this record?'**
  String get removeRecordConfirmTitle;

  /// No description provided for @removeRecordConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove this record from your collection?'**
  String get removeRecordConfirm;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @syncDiscogsDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect Discogs account'**
  String get syncDiscogsDisconnect;

  /// No description provided for @discogsImportButton.
  ///
  /// In en, this message translates to:
  /// **'Bring my Discogs collection'**
  String get discogsImportButton;

  /// No description provided for @discogsImportHint.
  ///
  /// In en, this message translates to:
  /// **'Adds the records from your Discogs collection to My Collection. Records you removed from My Collection stay out.'**
  String get discogsImportHint;

  /// No description provided for @discogsImporting.
  ///
  /// In en, this message translates to:
  /// **'Bringing your Discogs collection…'**
  String get discogsImporting;

  /// No description provided for @discogsImported.
  ///
  /// In en, this message translates to:
  /// **'{count} records came from your Discogs collection.'**
  String discogsImported(int count);

  /// No description provided for @discogsImportNothingNew.
  ///
  /// In en, this message translates to:
  /// **'Your Discogs collection is already in My Collection.'**
  String get discogsImportNothingNew;

  /// No description provided for @discogsImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read your Discogs collection. Try again in a moment.'**
  String get discogsImportFailed;

  /// No description provided for @syncDiscogsDisconnectTitle.
  ///
  /// In en, this message translates to:
  /// **'Disconnect Discogs?'**
  String get syncDiscogsDisconnectTitle;

  /// No description provided for @syncDiscogsDisconnectConfirm.
  ///
  /// In en, this message translates to:
  /// **'WaxClub will stop using your Discogs account on this phone. Your records stay in My Collection and nothing is deleted on Discogs. To connect again later, tap \"Connect Discogs\" and sign in.'**
  String get syncDiscogsDisconnectConfirm;

  /// No description provided for @syncDiscogsDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Discogs disconnected. You can connect again at any time.'**
  String get syncDiscogsDisconnected;

  /// No description provided for @manualKeptNotRecognized.
  ///
  /// In en, this message translates to:
  /// **'Not recognized: Manual mode keeps going.'**
  String get manualKeptNotRecognized;

  /// No description provided for @manualContinueHint.
  ///
  /// In en, this message translates to:
  /// **'Manual mode on: the song keeps going by the record\'s timing. Tap the line being sung to calibrate.'**
  String get manualContinueHint;

  /// No description provided for @manualAlreadyPlaying.
  ///
  /// In en, this message translates to:
  /// **'The music was already playing: tap the line being sung to calibrate.'**
  String get manualAlreadyPlaying;

  /// No description provided for @manualPlayButton.
  ///
  /// In en, this message translates to:
  /// **'PLAY'**
  String get manualPlayButton;

  /// No description provided for @manualStopButton.
  ///
  /// In en, this message translates to:
  /// **'STOP'**
  String get manualStopButton;

  /// No description provided for @manualPlaySide.
  ///
  /// In en, this message translates to:
  /// **'FLIPPED? PLAY SIDE {side}'**
  String manualPlaySide(String side);

  /// No description provided for @pluginCatSources.
  ///
  /// In en, this message translates to:
  /// **'Lyrics sources'**
  String get pluginCatSources;

  /// No description provided for @pluginRuleSources.
  ///
  /// In en, this message translates to:
  /// **'Several at once: WaxClub tries them in order (S1 first) until it finds the lyrics'**
  String get pluginRuleSources;

  /// No description provided for @pluginLrclibName.
  ///
  /// In en, this message translates to:
  /// **'LRCLIB'**
  String get pluginLrclibName;

  /// No description provided for @pluginLrclibAuthor.
  ///
  /// In en, this message translates to:
  /// **'lrclib.net'**
  String get pluginLrclibAuthor;

  /// No description provided for @pluginLrclibLicense.
  ///
  /// In en, this message translates to:
  /// **'Open lyrics database (lrclib.net)'**
  String get pluginLrclibLicense;

  /// No description provided for @pluginLrclibDesc.
  ///
  /// In en, this message translates to:
  /// **'Free, open-source database of synced lyrics, built and corrected by its community (lrclib.net). Independent project; no country of origin stated.'**
  String get pluginLrclibDesc;

  /// No description provided for @pluginNeteaseName.
  ///
  /// In en, this message translates to:
  /// **'NetEase Cloud Music'**
  String get pluginNeteaseName;

  /// No description provided for @pluginNeteaseAuthor.
  ///
  /// In en, this message translates to:
  /// **'music.163.com'**
  String get pluginNeteaseAuthor;

  /// No description provided for @pluginNeteaseDesc.
  ///
  /// In en, this message translates to:
  /// **'Synced lyrics from NetEase Cloud Music, the streaming service of NetEase, Inc. (Hangzhou, China, since 2013). Huge catalog, strong on Asian and international releases.'**
  String get pluginNeteaseDesc;

  /// No description provided for @pluginMegalobizName.
  ///
  /// In en, this message translates to:
  /// **'Megalobiz'**
  String get pluginMegalobizName;

  /// No description provided for @pluginMegalobizAuthor.
  ///
  /// In en, this message translates to:
  /// **'megalobiz.com'**
  String get pluginMegalobizAuthor;

  /// No description provided for @pluginMegalobizDesc.
  ///
  /// In en, this message translates to:
  /// **'Community website where listeners make and share LRC files (synced lyrics) with its online LRC maker; strong on J-pop and K-pop. Country of origin not disclosed.'**
  String get pluginMegalobizDesc;

  /// No description provided for @pluginSourceLicense.
  ///
  /// In en, this message translates to:
  /// **'Lyrics © their authors and publishers; fetched from the site for personal listening'**
  String get pluginSourceLicense;

  /// No description provided for @pluginInstallAfterSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in or create your WaxClub account to install the plugin {plugin}.'**
  String pluginInstallAfterSignIn(String plugin);

  /// No description provided for @pluginInstalling.
  ///
  /// In en, this message translates to:
  /// **'Installing {plugin}…'**
  String pluginInstalling(String plugin);

  /// No description provided for @pluginInstalledTitle.
  ///
  /// In en, this message translates to:
  /// **'Plugin installed'**
  String get pluginInstalledTitle;

  /// No description provided for @pluginInstalledMsg.
  ///
  /// In en, this message translates to:
  /// **'{plugin} is installed and on the platter.'**
  String pluginInstalledMsg(String plugin);

  /// No description provided for @pluginAlreadyInstalled.
  ///
  /// In en, this message translates to:
  /// **'{plugin} is already installed.'**
  String pluginAlreadyInstalled(String plugin);

  /// No description provided for @pluginBuiltInMsg.
  ///
  /// In en, this message translates to:
  /// **'{plugin} comes with WaxClub: it is already installed.'**
  String pluginBuiltInMsg(String plugin);

  /// No description provided for @pluginNeedsUpdate.
  ///
  /// In en, this message translates to:
  /// **'This plugin needs a newer version of WaxClub. Update the app and tap Install again.'**
  String get pluginNeedsUpdate;

  /// No description provided for @pluginNotFound.
  ///
  /// In en, this message translates to:
  /// **'Plugin not found on waxclub.com.br.'**
  String get pluginNotFound;

  /// No description provided for @pluginInvalid.
  ///
  /// In en, this message translates to:
  /// **'This plugin file is not valid.'**
  String get pluginInvalid;

  /// No description provided for @pluginNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach waxclub.com.br. Check your internet and try again.'**
  String get pluginNetworkError;

  /// No description provided for @pluginOpenJukebox.
  ///
  /// In en, this message translates to:
  /// **'Open plugins'**
  String get pluginOpenJukebox;

  /// No description provided for @jukeboxMoreOnSiteTitle.
  ///
  /// In en, this message translates to:
  /// **'More plugins on waxclub.com.br'**
  String get jukeboxMoreOnSiteTitle;

  /// No description provided for @jukeboxMoreOnSite.
  ///
  /// In en, this message translates to:
  /// **'Open the site on your phone and tap Install on a plugin: WaxClub opens and installs it by itself. Plugins carry no code: they only switch on features that come with the app.'**
  String get jukeboxMoreOnSite;

  /// No description provided for @jukeboxOpenSite.
  ///
  /// In en, this message translates to:
  /// **'Open the plugin page'**
  String get jukeboxOpenSite;

  /// No description provided for @jukeboxInstall.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get jukeboxInstall;

  /// No description provided for @jukeboxUninstall.
  ///
  /// In en, this message translates to:
  /// **'Uninstall'**
  String get jukeboxUninstall;

  /// No description provided for @jukeboxNotInstalledHint.
  ///
  /// In en, this message translates to:
  /// **'Not installed yet. Install it here or from waxclub.com.br.'**
  String get jukeboxNotInstalledHint;

  /// No description provided for @pluginMyLyricsName.
  ///
  /// In en, this message translates to:
  /// **'My lyrics files'**
  String get pluginMyLyricsName;

  /// No description provided for @pluginMyLyricsAuthor.
  ///
  /// In en, this message translates to:
  /// **'You (your own files)'**
  String get pluginMyLyricsAuthor;

  /// No description provided for @pluginMyLyricsLicense.
  ///
  /// In en, this message translates to:
  /// **'Your files, your rights: only lyrics you are allowed to use; they stay on your phone and are never shared'**
  String get pluginMyLyricsLicense;

  /// No description provided for @pluginMyLyricsDesc.
  ///
  /// In en, this message translates to:
  /// **'Shows lyrics you obtained legally (bought or licensed, written by you, in the public domain or used with permission) as synced .lrc files (with timestamps). Keep them in a Dropbox, OneDrive or Google Drive folder (updated automatically) or pick them from your phone.'**
  String get pluginMyLyricsDesc;

  /// No description provided for @myLyricsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No lyrics files yet} =1{1 lyrics file on this phone} other{{count} lyrics files on this phone}}'**
  String myLyricsCount(int count);

  /// No description provided for @myLyricsHowTo.
  ///
  /// In en, this message translates to:
  /// **'Use synced .lrc files (UTF-8) with a timestamp on each line, like [01:23.45], and the tags [ar:Artist] and [ti:Song], or name each file \"Artist - Song.lrc\". Lyrics without timestamps are not used.'**
  String get myLyricsHowTo;

  /// No description provided for @myLyricsRights.
  ///
  /// In en, this message translates to:
  /// **'Lyrics are protected by copyright. Only add files you have the right to use; WaxClub just shows them to you while the record plays and never uploads or shares them.'**
  String get myLyricsRights;

  /// No description provided for @myLyricsImport.
  ///
  /// In en, this message translates to:
  /// **'Add lyrics files'**
  String get myLyricsImport;

  /// No description provided for @myLyricsImported.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No lyrics added.} =1{1 lyrics file added.} other{{count} lyrics files added.}}'**
  String myLyricsImported(int count);

  /// No description provided for @myLyricsSkipped.
  ///
  /// In en, this message translates to:
  /// **'Not used (missing artist/song, no timestamps or not .lrc): {files}'**
  String myLyricsSkipped(String files);

  /// No description provided for @myLyricsClear.
  ///
  /// In en, this message translates to:
  /// **'Remove all'**
  String get myLyricsClear;

  /// No description provided for @cloudAppFolderHint.
  ///
  /// In en, this message translates to:
  /// **'Keep your lyrics files in {folder} (on your computer too) and WaxClub keeps them up to date by itself. WaxClub can only see that folder of your {service}.'**
  String cloudAppFolderHint(String folder, String service);

  /// No description provided for @gdriveHint.
  ///
  /// In en, this message translates to:
  /// **'Keep your lyrics files in a Google Drive folder named \"{folder}\" (on your computer too) and WaxClub keeps them up to date by itself. Google asks to let WaxClub read your Drive; WaxClub only opens that folder.'**
  String gdriveHint(String folder);

  /// No description provided for @cloudConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect {service}'**
  String cloudConnect(String service);

  /// No description provided for @cloudConnectedAs.
  ///
  /// In en, this message translates to:
  /// **'{service}: {name}'**
  String cloudConnectedAs(String service, String name);

  /// No description provided for @cloudFolderStatus.
  ///
  /// In en, this message translates to:
  /// **'Folder {folder} · {count} files · last sync {when}'**
  String cloudFolderStatus(String folder, int count, String when);

  /// No description provided for @cloudNeverSynced.
  ///
  /// In en, this message translates to:
  /// **'never'**
  String get cloudNeverSynced;

  /// No description provided for @cloudSyncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get cloudSyncNow;

  /// No description provided for @cloudSynced.
  ///
  /// In en, this message translates to:
  /// **'{service}: {added} new, {updated} updated, {removed} removed.'**
  String cloudSynced(String service, int added, int updated, int removed);

  /// No description provided for @cloudSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read your {service} folder. Check your internet and try again (or connect again).'**
  String cloudSyncFailed(String service);

  /// No description provided for @cloudLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t connect to {service}. Try again.'**
  String cloudLoginFailed(String service);

  /// No description provided for @panelPluginOn.
  ///
  /// In en, this message translates to:
  /// **'on — tap to turn off, hold and drag to reorder'**
  String get panelPluginOn;

  /// No description provided for @panelToggledOn.
  ///
  /// In en, this message translates to:
  /// **'{name} on'**
  String panelToggledOn(String name);

  /// No description provided for @panelToggledOff.
  ///
  /// In en, this message translates to:
  /// **'{name} off'**
  String panelToggledOff(String name);

  /// No description provided for @panelPluginOff.
  ///
  /// In en, this message translates to:
  /// **'off — tap to turn on, hold and drag to reorder'**
  String get panelPluginOff;

  /// No description provided for @ejectPluginTitle.
  ///
  /// In en, this message translates to:
  /// **'Eject this plugin?'**
  String get ejectPluginTitle;

  /// No description provided for @ejectPluginConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to eject {plugin}? It leaves your phone; you can install it again from the jukebox or waxclub.com.br.'**
  String ejectPluginConfirm(String plugin);

  /// No description provided for @ejectPlugin.
  ///
  /// In en, this message translates to:
  /// **'Eject'**
  String get ejectPlugin;

  /// No description provided for @ejectBuiltInTitle.
  ///
  /// In en, this message translates to:
  /// **'Built-in plugin'**
  String get ejectBuiltInTitle;

  /// No description provided for @ejectBuiltInInfo.
  ///
  /// In en, this message translates to:
  /// **'{plugin} comes with WaxClub and can\'t be ejected. Tap it in the panel to turn it off.'**
  String ejectBuiltInInfo(String plugin);

  /// No description provided for @photosTitle.
  ///
  /// In en, this message translates to:
  /// **'Photos of your record'**
  String get photosTitle;

  /// No description provided for @photosEmpty.
  ///
  /// In en, this message translates to:
  /// **'No photos yet. Take up to 7: covers, labels, inserts, the vinyl itself.'**
  String get photosEmpty;

  /// No description provided for @photosTake.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get photosTake;

  /// No description provided for @photosFromGallery.
  ///
  /// In en, this message translates to:
  /// **'From gallery'**
  String get photosFromGallery;

  /// No description provided for @photosLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the photos. Check your internet.'**
  String get photosLoadFailed;

  /// No description provided for @photosUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the photo. Check your internet and try again.'**
  String get photosUploadFailed;

  /// No description provided for @photosTooMany.
  ///
  /// In en, this message translates to:
  /// **'Up to {max} photos per record. Delete one to add another.'**
  String photosTooMany(int max);

  /// No description provided for @photosCameraFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the camera or the gallery.'**
  String get photosCameraFailed;

  /// No description provided for @photosDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete photo'**
  String get photosDelete;

  /// No description provided for @photosDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this photo?'**
  String get photosDeleteTitle;

  /// No description provided for @photosDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete the photo. Try again.'**
  String get photosDeleteFailed;

  /// No description provided for @photosCount.
  ///
  /// In en, this message translates to:
  /// **'{count} of {max} photos'**
  String photosCount(int count, int max);

  /// No description provided for @photosDeleteInfo.
  ///
  /// In en, this message translates to:
  /// **'The photo is deleted from your WaxClub account. This cannot be undone.'**
  String get photosDeleteInfo;

  /// No description provided for @panelPluginNothing.
  ///
  /// In en, this message translates to:
  /// **'found nothing for this song'**
  String get panelPluginNothing;

  /// No description provided for @pluginKugouName.
  ///
  /// In en, this message translates to:
  /// **'Kugou Music'**
  String get pluginKugouName;

  /// No description provided for @pluginKugouAuthor.
  ///
  /// In en, this message translates to:
  /// **'kugou.com'**
  String get pluginKugouAuthor;

  /// No description provided for @pluginKugouDesc.
  ///
  /// In en, this message translates to:
  /// **'Synced lyrics from Kugou (酷狗音乐), one of China\'s largest music services, founded in 2004 in Guangzhou, China, and part of Tencent Music Entertainment. Good on Western rock and Brazilian classics.'**
  String get pluginKugouDesc;

  /// No description provided for @pluginQqMusicName.
  ///
  /// In en, this message translates to:
  /// **'QQ Music'**
  String get pluginQqMusicName;

  /// No description provided for @pluginQqMusicAuthor.
  ///
  /// In en, this message translates to:
  /// **'y.qq.com'**
  String get pluginQqMusicAuthor;

  /// No description provided for @pluginQqMusicDesc.
  ///
  /// In en, this message translates to:
  /// **'Synced lyrics from QQ Music (QQ音乐), Tencent\'s music service (Shenzhen, China, since 2005), part of Tencent Music Entertainment. Often has the songs other sources miss.'**
  String get pluginQqMusicDesc;

  /// No description provided for @pluginMusixmatchName.
  ///
  /// In en, this message translates to:
  /// **'Musixmatch'**
  String get pluginMusixmatchName;

  /// No description provided for @pluginMusixmatchAuthor.
  ///
  /// In en, this message translates to:
  /// **'musixmatch.com'**
  String get pluginMusixmatchAuthor;

  /// No description provided for @pluginMusixmatchLicense.
  ///
  /// In en, this message translates to:
  /// **'Licensed lyrics (commercial license required)'**
  String get pluginMusixmatchLicense;

  /// No description provided for @pluginMusixmatchDesc.
  ///
  /// In en, this message translates to:
  /// **'The world\'s largest lyrics catalog, founded in 2010 in Bologna, Italy. Its lyrics are licensed from publishers; synced lyrics need a paid commercial license, so this plugin is coming soon.'**
  String get pluginMusixmatchDesc;

  /// No description provided for @waxBrain.
  ///
  /// In en, this message translates to:
  /// **'WaxBrain'**
  String get waxBrain;

  /// No description provided for @brainIntro.
  ///
  /// In en, this message translates to:
  /// **'Plug in an AI chip to power WaxClub\'s AI plugins. You use your own key (some providers have free plans), and nothing is plugged in until you choose.'**
  String get brainIntro;

  /// No description provided for @brainPluggedSection.
  ///
  /// In en, this message translates to:
  /// **'Plugged chips'**
  String get brainPluggedSection;

  /// No description provided for @brainOrderHint.
  ///
  /// In en, this message translates to:
  /// **'AI plugins use the first chip that\'s ready. Drag to change the order.'**
  String get brainOrderHint;

  /// No description provided for @brainSocketsSection.
  ///
  /// In en, this message translates to:
  /// **'Chip sockets'**
  String get brainSocketsSection;

  /// No description provided for @brainSocketsHintEmpty.
  ///
  /// In en, this message translates to:
  /// **'No chip plugged in yet. Free chips need no credit card — Gemini is the easiest one to start with.'**
  String get brainSocketsHintEmpty;

  /// No description provided for @brainSocketsHint.
  ///
  /// In en, this message translates to:
  /// **'Plug in more chips: when one reaches its usage limit, the next one takes over.'**
  String get brainSocketsHint;

  /// No description provided for @brainTapToPlug.
  ///
  /// In en, this message translates to:
  /// **'Tap to plug in'**
  String get brainTapToPlug;

  /// No description provided for @brainFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get brainFree;

  /// No description provided for @brainPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get brainPaid;

  /// No description provided for @brainPlugTitle.
  ///
  /// In en, this message translates to:
  /// **'Plug in {name}'**
  String brainPlugTitle(String name);

  /// No description provided for @brainPaidWarning.
  ///
  /// In en, this message translates to:
  /// **'{vendor} charges for API use: you need to add credit (card) to your account there. The free ChatGPT and Grok chat apps don\'t include API access.'**
  String brainPaidWarning(String vendor);

  /// No description provided for @brainStep1.
  ///
  /// In en, this message translates to:
  /// **'Sign in to {vendor} (you can use your Google account where it\'s offered).'**
  String brainStep1(String vendor);

  /// No description provided for @brainStep2.
  ///
  /// In en, this message translates to:
  /// **'Tap “Create API key” (or “Create new key”).'**
  String get brainStep2;

  /// No description provided for @brainStep3.
  ///
  /// In en, this message translates to:
  /// **'Tap “Copy” and come back to WaxClub — the key is picked up automatically.'**
  String get brainStep3;

  /// No description provided for @brainOpenKeyPage.
  ///
  /// In en, this message translates to:
  /// **'Open {vendor}'**
  String brainOpenKeyPage(String vendor);

  /// No description provided for @brainPasteHint.
  ///
  /// In en, this message translates to:
  /// **'Already have the key? Paste it here:'**
  String get brainPasteHint;

  /// No description provided for @brainPasteField.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get brainPasteField;

  /// No description provided for @brainPasteButton.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get brainPasteButton;

  /// No description provided for @brainPlugButton.
  ///
  /// In en, this message translates to:
  /// **'Plug in'**
  String get brainPlugButton;

  /// No description provided for @brainNoKeyCopied.
  ///
  /// In en, this message translates to:
  /// **'No {name} key found in what you copied. Copy the key and come back, or paste it by hand.'**
  String brainNoKeyCopied(String name);

  /// No description provided for @brainTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get brainTryAgain;

  /// No description provided for @brainKeyFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Key found'**
  String get brainKeyFoundTitle;

  /// No description provided for @brainKeyFoundBody.
  ///
  /// In en, this message translates to:
  /// **'Plug in this {name} key (ending in …{hint})?'**
  String brainKeyFoundBody(String name, String hint);

  /// No description provided for @brainPluggedTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} plugged in'**
  String brainPluggedTitle(String name);

  /// No description provided for @brainPluggedBody.
  ///
  /// In en, this message translates to:
  /// **'The key was tested and the {name} chip is ready for the AI plugins.'**
  String brainPluggedBody(String name);

  /// No description provided for @brainPluggedLimitBody.
  ///
  /// In en, this message translates to:
  /// **'The key works, but its {name} usage limit is reached right now. The chip stays plugged in and is used again when the limit resets.'**
  String brainPluggedLimitBody(String name);

  /// No description provided for @brainPluggedOfflineBody.
  ///
  /// In en, this message translates to:
  /// **'The {name} chip is plugged in, but the key couldn\'t be tested (no connection). It will be tested again later.'**
  String brainPluggedOfflineBody(String name);

  /// No description provided for @brainRejectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Key not accepted'**
  String get brainRejectedTitle;

  /// No description provided for @brainRejectedBody.
  ///
  /// In en, this message translates to:
  /// **'{vendor} did not accept this key. Check that you copied the whole key, or create a new one.'**
  String brainRejectedBody(String vendor);

  /// No description provided for @brainUnplugTitle.
  ///
  /// In en, this message translates to:
  /// **'Unplug {name}?'**
  String brainUnplugTitle(String name);

  /// No description provided for @brainUnplugBody.
  ///
  /// In en, this message translates to:
  /// **'The key is removed from this phone and from your WaxClub account. You can plug it in again at any time.'**
  String get brainUnplugBody;

  /// No description provided for @brainUnplugButton.
  ///
  /// In en, this message translates to:
  /// **'Unplug'**
  String get brainUnplugButton;

  /// No description provided for @brainTestAgain.
  ///
  /// In en, this message translates to:
  /// **'Test again'**
  String get brainTestAgain;

  /// No description provided for @brainChangeKey.
  ///
  /// In en, this message translates to:
  /// **'Change key'**
  String get brainChangeKey;

  /// No description provided for @brainStatusOk.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get brainStatusOk;

  /// No description provided for @brainStatusLimit.
  ///
  /// In en, this message translates to:
  /// **'Limit reached'**
  String get brainStatusLimit;

  /// No description provided for @brainStatusInvalid.
  ///
  /// In en, this message translates to:
  /// **'Key rejected'**
  String get brainStatusInvalid;

  /// No description provided for @brainStatusOffline.
  ///
  /// In en, this message translates to:
  /// **'Not tested'**
  String get brainStatusOffline;

  /// No description provided for @brainPrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'Your keys are stored encrypted on this phone and in your WaxClub account, and are only sent to their own provider. On free plans, the provider may use what is sent to improve its models.'**
  String get brainPrivacyNote;

  /// No description provided for @jukeboxTapToChoose.
  ///
  /// In en, this message translates to:
  /// **'Tap a record or a strip'**
  String get jukeboxTapToChoose;

  /// No description provided for @jukeboxDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get jukeboxDetails;

  /// No description provided for @menu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menu;

  /// No description provided for @jukeboxOn.
  ///
  /// In en, this message translates to:
  /// **'ON'**
  String get jukeboxOn;

  /// No description provided for @jukeboxOff.
  ///
  /// In en, this message translates to:
  /// **'OFF'**
  String get jukeboxOff;

  /// No description provided for @aiTranslatedTag.
  ///
  /// In en, this message translates to:
  /// **'AI translation'**
  String get aiTranslatedTag;

  /// No description provided for @translatorLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'Translate into'**
  String get translatorLanguageLabel;

  /// No description provided for @translatorChooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose a language'**
  String get translatorChooseLanguage;

  /// No description provided for @translatorUsesChip.
  ///
  /// In en, this message translates to:
  /// **'Translating with your {name} chip from the WaxBrain.'**
  String translatorUsesChip(String name);

  /// No description provided for @translatorNeedsChip.
  ///
  /// In en, this message translates to:
  /// **'The translator needs an AI chip. Tap to open the WaxBrain.'**
  String get translatorNeedsChip;

  /// No description provided for @translatorOpenBrain.
  ///
  /// In en, this message translates to:
  /// **'Open the WaxBrain'**
  String get translatorOpenBrain;

  /// No description provided for @translatorPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Lyrics, curiosities and news are sent only to the AI chip you plugged in, with your own key. Translations are marked as AI translations, stay on this phone and are never shared. On free plans, the AI provider may use what is sent to improve its models.'**
  String get translatorPrivacy;

  /// No description provided for @pluginImaginedName.
  ///
  /// In en, this message translates to:
  /// **'Imagined Music'**
  String get pluginImaginedName;

  /// No description provided for @pluginImaginedLicense.
  ///
  /// In en, this message translates to:
  /// **'Photos from Unsplash, credited to each photographer; scenes chosen by your AI chip'**
  String get pluginImaginedLicense;

  /// No description provided for @pluginImaginedDesc.
  ///
  /// In en, this message translates to:
  /// **'An AI visual director reads the lyrics and imagines the song: a slow, cinematic slideshow of photos that follow its verses, moods and colors, behind the lyrics on your TV. In Immersive mode, only the images play, with a striking line of the lyrics fading in now and then. Uses an AI chip from your WaxBrain; photos come from Unsplash.'**
  String get pluginImaginedDesc;

  /// No description provided for @imagineWorking.
  ///
  /// In en, this message translates to:
  /// **'Imagining this song…'**
  String get imagineWorking;

  /// No description provided for @translatorWorking.
  ///
  /// In en, this message translates to:
  /// **'Translating the lyrics…'**
  String get translatorWorking;

  /// No description provided for @translatorChipFailed.
  ///
  /// In en, this message translates to:
  /// **'Your AI chip didn\'t answer. Trying again in a moment — tap to check the WaxBrain.'**
  String get translatorChipFailed;

  /// No description provided for @translatorBadReply.
  ///
  /// In en, this message translates to:
  /// **'The translation came out garbled. Trying again in a moment.'**
  String get translatorBadReply;

  /// No description provided for @imagineNeedsChip.
  ///
  /// In en, this message translates to:
  /// **'Imagined Music needs an AI chip. Tap to open the WaxBrain.'**
  String get imagineNeedsChip;

  /// No description provided for @imagineChipFailed.
  ///
  /// In en, this message translates to:
  /// **'Your AI chip didn\'t answer. Tap to check the WaxBrain.'**
  String get imagineChipFailed;

  /// No description provided for @imagineBadReply.
  ///
  /// In en, this message translates to:
  /// **'The AI\'s scenes came out garbled. Trying again on the next song.'**
  String get imagineBadReply;

  /// No description provided for @imagineNoPhotos.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get images right now. Trying again on the next song.'**
  String get imagineNoPhotos;

  /// No description provided for @imagineModeLyrics.
  ///
  /// In en, this message translates to:
  /// **'Images + lyrics'**
  String get imagineModeLyrics;

  /// No description provided for @imagineModeLyricsHint.
  ///
  /// In en, this message translates to:
  /// **'The photos play behind the scrolling lyrics.'**
  String get imagineModeLyricsHint;

  /// No description provided for @imagineModeImmersive.
  ///
  /// In en, this message translates to:
  /// **'Immersive'**
  String get imagineModeImmersive;

  /// No description provided for @imagineModeImmersiveHint.
  ///
  /// In en, this message translates to:
  /// **'Only the images, with a line of the lyrics appearing right when it is sung.'**
  String get imagineModeImmersiveHint;

  /// No description provided for @imagineUsesChip.
  ///
  /// In en, this message translates to:
  /// **'Imagining with your {name} chip from the WaxBrain.'**
  String imagineUsesChip(String name);

  /// No description provided for @imaginePhotoCredit.
  ///
  /// In en, this message translates to:
  /// **'Photo: {author} · Unsplash'**
  String imaginePhotoCredit(String author);

  /// No description provided for @imaginePrivacy.
  ///
  /// In en, this message translates to:
  /// **'The lyrics are sent only to the AI chip you plugged in, with your own key, to choose the scenes; only the scenes (photo searches, colors and chosen lines) are kept on this phone. Photos are shown from Unsplash, credited to their photographers.'**
  String get imaginePrivacy;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
