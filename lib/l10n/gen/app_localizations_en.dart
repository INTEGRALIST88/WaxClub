// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get flipTheRecord => 'FLIP THE RECORD';

  @override
  String get micStopListening => 'Stop listening (microphone off)';

  @override
  String get micListenToRoom => 'Listen to the room';

  @override
  String get lyricsEmptyHint =>
      'Tap the microphone to listen to your vinyl and sync the lyrics, with turntable speed compensation.';

  @override
  String get resume => 'Resume';

  @override
  String get pause => 'Pause';

  @override
  String get stopListening => 'Stop listening';

  @override
  String get adjustTiming => 'Adjust timing:';

  @override
  String get microphoneListening => 'Microphone listening';

  @override
  String get microphoneOff => 'Microphone off';

  @override
  String calibratingIn(int seconds) {
    return 'Calibrating in ${seconds}s';
  }

  @override
  String get statusPaused => 'PAUSED';

  @override
  String sideEndFlip(String side) {
    return '$side — FLIP THE RECORD';
  }

  @override
  String get endOfSideFlip => 'END OF SIDE — FLIP THE RECORD';

  @override
  String get statusNextTrack => 'NEXT TRACK';

  @override
  String get statusConfirming => 'confirming...';

  @override
  String rpmValue(String rpm) {
    return '$rpm RPM';
  }

  @override
  String greetingWelcome(String appName) {
    return 'Welcome to $appName!';
  }

  @override
  String get greetingWelcomeSubtitle =>
      'Drop the needle and tap the microphone to start.';

  @override
  String get goodMorning => 'Good morning';

  @override
  String get goodAfternoon => 'Good afternoon';

  @override
  String get goodEvening => 'Good evening';

  @override
  String greetingTimeOfDay(String timeOfDay, String name) {
    return '$timeOfDay, $name!';
  }

  @override
  String greetingLetsGo(String name) {
    return 'Let\'s go, $name!';
  }

  @override
  String greetingLetsSpin(String name) {
    return 'Let\'s spin, $name!';
  }

  @override
  String greetingGreatDay(String name) {
    return '$name, today is a great day to listen to some music.';
  }

  @override
  String get greetingWhichRecord => 'Which record is on the platter today?';

  @override
  String get greetingDropNeedle => 'Drop the needle and tap the microphone.';

  @override
  String get greetingPickSide => 'Pick a side, and the lyrics follow along.';

  @override
  String get whatShouldWeCallYou => 'What should we call you?';

  @override
  String get sortRecentlyPlayed => 'Recently played';

  @override
  String get sortMostPlayed => 'Most played';

  @override
  String get sortRecentlyAdded => 'Recently added';

  @override
  String get sortAlphabetical => 'A–Z';

  @override
  String get whenNever => 'never';

  @override
  String get whenJustNow => 'just now';

  @override
  String whenMinutesAgo(int minutes) {
    return '$minutes min ago';
  }

  @override
  String whenToday(String time) {
    return 'today $time';
  }

  @override
  String whenYesterday(String time) {
    return 'yesterday $time';
  }

  @override
  String get myCollection => 'My Collection';

  @override
  String recordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count records',
      one: '1 record',
    );
    return '$_temp0';
  }

  @override
  String get sort => 'Sort';

  @override
  String get collectionEmpty => 'Your collection is empty';

  @override
  String get collectionEmptyHint =>
      'While a record is playing, tap its cover at the top of the screen and choose \"Add to collection\".';

  @override
  String get notPlayedYet => 'Not played yet';

  @override
  String playedTimesLast(int count, String when) {
    return 'Played $count× · last $when';
  }

  @override
  String get plays => 'Plays';

  @override
  String get firstPlayed => 'First played';

  @override
  String get lastPlayed => 'Last played';

  @override
  String addedWhen(String when) {
    return 'Added $when';
  }

  @override
  String get tracklist => 'Tracklist';

  @override
  String get listeningHistory => 'Listening history';

  @override
  String get noPlaysYet => 'No plays recorded yet.';

  @override
  String get removeFromCollection => 'Remove from collection';

  @override
  String get signInToDiscogs => 'Sign in to Discogs';

  @override
  String get reload => 'Reload';

  @override
  String get tryAgain => 'Try again';

  @override
  String get discogsTokenHint =>
      'Sign in to your account above, tap \"Generate new token\" and paste the token here:';

  @override
  String get discogsTokenField => 'Discogs personal token';

  @override
  String get save => 'Save';

  @override
  String get helpGettingStarted => 'Getting started';

  @override
  String get helpGettingStarted1 =>
      'Put a record on your turntable, drop the needle and tap the microphone button. WaxClub listens for a few seconds, identifies the song and shows the lyrics in sync with the music.';

  @override
  String get helpGettingStarted2 =>
      'Keep the phone close to the speakers and avoid talking near it while it listens.';

  @override
  String get helpListening => 'Listening and syncing';

  @override
  String get helpListening1 =>
      'The first listen is quick (4 seconds); harder songs get up to 12 seconds automatically.';

  @override
  String get helpListening2 =>
      'While a song plays, WaxClub checks the sync now and then through the microphone and corrects the timing.';

  @override
  String get helpListening3 =>
      'At the end of each track it predicts the next one from the record\'s tracklist and confirms it by listening.';

  @override
  String get helpFlipping => 'Flipping the record';

  @override
  String get helpFlipping1 =>
      'When a side ends, the button turns into \"Flip the record\". Tap it before or after you flip: the lyrics of the first track of the new side appear right away and start as soon as the needle hits the music.';

  @override
  String get helpSpeed => 'Turntable speed';

  @override
  String get helpSpeed1 =>
      'Turntables rarely spin at exactly 33⅓ RPM. WaxClub measures your turntable\'s real speed while songs play and keeps the lyrics on time.';

  @override
  String get helpSpeed2 =>
      'In the controls you can fine-tune the speed, reset it or lock it.';

  @override
  String get helpTiming => 'Lyrics running early or late';

  @override
  String get helpTiming1 =>
      'Use the −0.5s / +0.5s buttons to nudge the lyrics. The offset is remembered for that song.';

  @override
  String get helpChangeRecord => 'Change record and Discogs';

  @override
  String get helpChangeRecord1 =>
      'Songs often appear on several records (albums, compilations, soundtracks). Tap the cover at the top left of the screen, then \"Change record\" to pick the exact record on your turntable; it becomes the default for those songs. Only vinyl records (LP and EP) are listed.';

  @override
  String get helpChangeRecord2 =>
      'Tick \"Search Discogs\" to search the largest vinyl database. Your Discogs sign-in stays on this phone only.';

  @override
  String get helpCollection => 'Your collection';

  @override
  String get helpCollection1 =>
      'Tap My Collection (the bookshelf button) to open your records. Add the record that is playing by tapping its cover and choosing \"Add to collection\", or add any record with Identify.';

  @override
  String get helpCollection2 =>
      'WaxClub counts how many times each record was played and when: any track heard counts the record once per listening session.';

  @override
  String get helpTv => 'Showing the lyrics on the TV';

  @override
  String get helpTv1 =>
      'Tap the cast icon. Chromecast and Google TV devices appear automatically.';

  @override
  String get helpTv2 =>
      'Fire TV: open the WaxClub app on the TV first; it appears in the list. If it does not, use \"Add by IP\" with the address shown on the TV.';

  @override
  String get helpTv3 =>
      'Samsung, LG and other TVs without Chromecast: mirror your phone with Smart View, Cast or Wireless display (Miracast). WaxClub turns the TV into a second screen with only the lyrics, and the phone becomes the control panel.';

  @override
  String get helpTv4 => 'The phone and the TV must be on the same Wi-Fi.';

  @override
  String get helpTroubleshooting => 'Troubleshooting';

  @override
  String get helpTroubleshooting1 =>
      'Song not recognized: move the phone closer to the speakers and try again. Some rare records are not in the recognition catalog.';

  @override
  String get helpTroubleshooting2 =>
      'Nothing is ever recognized: another app may be using the microphone (voice assistants, accessibility or call apps). WaxClub warns you when this happens. Close that app and try again.';

  @override
  String get helpTroubleshooting3 =>
      'TV not found: check that it is on and on the same Wi-Fi, and tap \"Search again\". After a TV update it may take a few minutes to show up again.';

  @override
  String get help => 'Help';

  @override
  String get helpCopyLogsHint =>
      'Long-press the version to copy the session logs.';

  @override
  String get castingToTv => 'Casting to TV';

  @override
  String castScreenName(String name) {
    return 'Screen: $name';
  }

  @override
  String get defaultTvName => 'Living room TV';

  @override
  String get disconnectFromTv => 'Disconnect from TV';

  @override
  String get yourName => 'Your name';

  @override
  String get cancel => 'Cancel';

  @override
  String removedFromCollection(String album) {
    return '\"$album\" removed from your collection.';
  }

  @override
  String addedToCollection(String album) {
    return '\"$album\" added to your collection.';
  }

  @override
  String get noEventsLogged => 'No events logged in this session.';

  @override
  String get logsCopied => 'Session logs copied to the clipboard!';

  @override
  String get noRecordYet => 'No record identified yet.';

  @override
  String tracksOnRecord(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks on this record',
      one: '1 track on this record',
    );
    return '$_temp0';
  }

  @override
  String get inCollection => 'In collection';

  @override
  String get addToCollection => 'Add to collection';

  @override
  String get changeRecord => 'Change record';

  @override
  String get noTracklistYet => 'No tracklist for this album yet.';

  @override
  String get tracklistFetchedHint =>
      'The tracklist is fetched automatically from the official catalog (MusicBrainz) while the song plays.';

  @override
  String get playing => 'PLAYING';

  @override
  String get upNextCaps => 'UP NEXT';

  @override
  String sideLabel(String side) {
    return 'Side $side';
  }

  @override
  String get unknownAlbum => 'Unknown Album';

  @override
  String upNextTitle(String title) {
    return 'Up next: $title';
  }

  @override
  String get discogsExplanation =>
      'Discogs is the world\'s largest vinyl database, maintained by collectors: every pressing, local and imported edition, compilation, A/B side, cover and tracklist.\n\nWith your account connected, WaxClub searches it to find the exact record that is on your turntable — with the right track order, sides and cover.\n\nYour sign-in is stored securely on this phone only, for next time. The app only reads the catalog (it never changes your collection) and you can disconnect at any time.';

  @override
  String get searchFailed =>
      'Could not search for records right now. Check your internet connection.';

  @override
  String get connectDiscogs => 'Connect your Discogs account';

  @override
  String get ok => 'OK';

  @override
  String discogsConnectedAs(String name) {
    return 'Discogs connected as $name.';
  }

  @override
  String get you => 'you';

  @override
  String get loadTracksFailed =>
      'Could not load this record\'s tracks. Try another record or source.';

  @override
  String get songNotOnRecord => 'Song not found on this record';

  @override
  String songNotOnRecordBody(String title, String album) {
    return '\"$title\" is not in the tracklist of \"$album\". Use this record anyway?';
  }

  @override
  String get back => 'Back';

  @override
  String get use => 'Use';

  @override
  String recordChanged(String album) {
    return 'Record changed to \"$album\". It is now the default for these songs.';
  }

  @override
  String useRecordFailed(String error) {
    return 'Could not use this record: $error';
  }

  @override
  String recordsWithSong(String title, String artist) {
    return 'Records with \"$title\" — $artist';
  }

  @override
  String get searchDiscogs => 'Search Discogs';

  @override
  String connectedAs(String name) {
    return 'Connected as $name';
  }

  @override
  String get yourAccount => 'your account';

  @override
  String get discogsSearchSubtitle =>
      'The most complete vinyl and compilation database (requires your account)';

  @override
  String get signOut => 'Sign out';

  @override
  String get searchAnotherRecord =>
      'Search for another record (artist, title...)';

  @override
  String get noRecordsFound =>
      'No records found. Try searching by the record name.';

  @override
  String recordsFromSource(int count, String source) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count records',
      one: '1 record',
    );
    return '$_temp0 • $source';
  }

  @override
  String get chipCurrent => 'Current';

  @override
  String get chipVinyl => 'Vinyl';

  @override
  String get chipCompilation => 'Compilation';

  @override
  String get chipLive => 'Live';

  @override
  String editionsCount(int count) {
    return '$count editions';
  }

  @override
  String get castWaitingConfirm => 'Waiting for the screen to confirm...';

  @override
  String get castScreenConfirmed => 'Screen confirmed! Connection established.';

  @override
  String castConnectingTo(String name) {
    return 'Connecting to $name...';
  }

  @override
  String get castNoResponse => 'The TV did not respond or refused the cast.';

  @override
  String castLookingAtIp(String ip) {
    return 'Looking for a Chromecast or WaxClub TV app at $ip...';
  }

  @override
  String castNothingAtIp(String ip) {
    return 'No Chromecast or WaxClub TV app found at $ip.';
  }

  @override
  String get castToTv => 'CAST TO TV';

  @override
  String get searchAgain => 'Search again';

  @override
  String castSearching(int count) {
    return 'Searching... $count found';
  }

  @override
  String castDevicesAvailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count devices available',
      one: '1 device available',
    );
    return '$_temp0';
  }

  @override
  String get castNoTvFound => 'No TV found on the local network';

  @override
  String get castIdlePrefix => 'Idle • ';

  @override
  String get connectCaps => 'CONNECT';

  @override
  String get noScreenFound => 'No screen found';

  @override
  String get sameWifiHint =>
      'Make sure the TV and the phone are on the same Wi-Fi.';

  @override
  String get searchNetwork => 'Search network';

  @override
  String get hideIp => 'Hide IP';

  @override
  String get addByIp => 'Add by IP';

  @override
  String get ipExample => 'Ex: 192.168.1.105';

  @override
  String get add => 'Add';

  @override
  String get openAddressInBrowser => 'Open the address in your TV\'s browser.';

  @override
  String get castViaBrowser => 'No Chromecast? Cast via browser';

  @override
  String get close => 'Close';

  @override
  String get tvBrowser => 'TV browser';

  @override
  String get screenConnected => 'SCREEN CONNECTED';

  @override
  String get connectionFailed => 'CONNECTION FAILED';

  @override
  String get syncingWithTv => 'SYNCING WITH THE TV';

  @override
  String get openThisAddress => 'Open this address in your TV\'s browser:';

  @override
  String get tryAgainCaps => 'Try Again';

  @override
  String get changeTv => 'Change TV';

  @override
  String get cancelAndGoBack => 'Cancel and go back';

  @override
  String get nowPlaying => 'Now playing';

  @override
  String get settings => 'Settings';

  @override
  String get tv => 'TV';

  @override
  String get reconnectingToTv => 'Reconnecting to the TV...';

  @override
  String get lyricsOnTv => 'Lyrics showing on the TV';

  @override
  String get disconnect => 'Disconnect';

  @override
  String sideCaps(String side) {
    return 'SIDE $side';
  }

  @override
  String get tracksBadge => 'tracks ▸';

  @override
  String get noSongIdentified => 'No song identified';

  @override
  String get tapListenHint => 'Tap Listen while the record plays';

  @override
  String trackOfTotal(int number, int total) {
    return ' · track $number of $total';
  }

  @override
  String get upNext => 'Up next';

  @override
  String nextSideStartsWith(String title) {
    return 'Next side starts with: $title';
  }

  @override
  String get flipToContinue => 'Flip the record to continue';

  @override
  String get lyricsReady => '⚡ lyrics ready';

  @override
  String get rpmSuffix => ' RPM';

  @override
  String measuredOverListens(int count) {
    return 'measured over $count listens';
  }

  @override
  String get knownSpeed => 'known speed';

  @override
  String get calibrating => 'calibrating...';

  @override
  String get fineSpeedAdjustment => 'Fine speed adjustment';

  @override
  String get reset => 'Reset';

  @override
  String get speedLocked => 'Speed locked';

  @override
  String get lockSpeed => 'Lock speed';

  @override
  String get lyricsSync => 'Lyrics sync';

  @override
  String get lyricsSyncHint => 'if the lyrics run early or late';

  @override
  String get offset => 'offset';

  @override
  String get endOfSide => 'End of side';

  @override
  String tapAfterFlipping(String side) {
    return '$side · tap after flipping the record';
  }

  @override
  String get listeningToRecord => 'Listening to the record...';

  @override
  String inSyncNextCheck(int seconds) {
    return 'In sync · next check in ${seconds}s';
  }

  @override
  String get listeningTapToStop => 'LISTENING... (TAP TO STOP)';

  @override
  String get listenResync => 'LISTEN / RESYNC';

  @override
  String statusPitchLocked(String speed) {
    return 'Pitch locked at ${speed}x';
  }

  @override
  String get statusPitchUnlocked => 'Pitch unlocked for continuous calibration';

  @override
  String get statusListeningMic => 'Listening through the microphone...';

  @override
  String statusFaintSignal(int seconds) {
    return 'Faint signal or noise: listening longer (${seconds}s)...';
  }

  @override
  String get statusIdentifying => 'Identifying song and position...';

  @override
  String statusRecognitionFailed(String reason) {
    return 'Recognition request failed ($reason). Check your internet connection and tap the microphone again.';
  }

  @override
  String get statusSongNotIdentified =>
      'Song not identified. Move the phone closer to the speakers and tap the microphone again.';

  @override
  String statusFetchingLyricsAndTracklist(String title) {
    return 'Fetching lyrics and tracklist for \"$title\"...';
  }

  @override
  String statusIdentificationError(String error) {
    return 'Identification error: $error';
  }

  @override
  String endOfSideLabel(String side) {
    return 'End of side $side';
  }

  @override
  String statusLikelyNext(String title) {
    return 'Likely next track: \"$title\"';
  }

  @override
  String statusLastTrackOfSide(String side) {
    return 'Last track of side $side';
  }

  @override
  String get statusTracklistLoaded => 'Tracklist loaded';

  @override
  String statusInSync(String speed) {
    return 'In sync • $speed';
  }

  @override
  String get statusCheckingSync => 'Checking sync through the microphone...';

  @override
  String statusSyncRealigned(String drift, String speed) {
    return 'Sync realigned (${drift}ms) • $speed';
  }

  @override
  String statusConfirmingNext(String title) {
    return '▶ $title — confirming through the microphone...';
  }

  @override
  String statusConfirmingAttempt(int attempt, int total) {
    return 'Confirming prediction (attempt $attempt/$total)...';
  }

  @override
  String statusNotConfirmedFor(int seconds) {
    return 'Not confirmed for ${seconds}s...';
  }

  @override
  String statusConfirmed(String title, String speed) {
    return '$title — Confirmed ✓ ($speed)';
  }

  @override
  String get statusPlaybackEnded => 'Playback ended. Microphone off.';

  @override
  String statusListeningNextAttempt(int attempt, int total) {
    return 'Listening for the next track (attempt $attempt/$total)...';
  }

  @override
  String statusSilenceWaitingNeedle(int seconds) {
    return 'Silence detected — waiting for the needle (${seconds}s)...';
  }

  @override
  String get statusPlaybackEndedOrStopped =>
      'Playback ended or record stopped. Microphone off.';

  @override
  String statusFetchingLyrics(String title) {
    return 'Fetching lyrics for \"$title\"...';
  }

  @override
  String statusEndOfSideFlip(String side) {
    return 'End of side $side. Flip the record to continue.';
  }

  @override
  String statusWaitingNeedle(String title) {
    return '▶ $title — waiting for the needle...';
  }

  @override
  String statusNotConfirmed(String title) {
    return '▶ $title (not confirmed)';
  }

  @override
  String get statusFlipTimeout =>
      'Timed out waiting for the record to be flipped. Tap to listen.';

  @override
  String get statusListeningNewSide => 'Listening to the new side...';

  @override
  String statusNotIdentifiedSideEnded(String side) {
    return 'Not identified yet (side $side ended). Flip the record or try again.';
  }

  @override
  String get statusNotIdentifiedFlip =>
      'Not identified yet (the record ended). Flip the record or try again.';

  @override
  String statusSyncPaused(String position) {
    return 'Sync paused at $position';
  }

  @override
  String statusSpeedCalibrated(String speed) {
    return 'Speed calibrated: ${speed}x (+1.8%)';
  }

  @override
  String get statusMicOffStopped => 'Microphone off. Listening stopped.';

  @override
  String get noticeDiscogsNoVinyl =>
      'Discogs found no vinyl records; showing MusicBrainz results.';

  @override
  String get noticeDiscogsUnavailable =>
      'Discogs is unavailable right now; showing MusicBrainz results.';

  @override
  String get builtInMicrophone => 'Built-in microphone';

  @override
  String get micPermissionDeniedHint =>
      '🎤 Microphone permission denied.\n\nTo enable it manually:\n  Settings → Apps → WaxClub → Permissions → Microphone → Allow\n\nThen try again.';

  @override
  String get micPermissionNotGranted => 'Microphone permission not granted.';

  @override
  String discogsSignInRejected(int code) {
    return 'Discogs rejected the sign-in request (HTTP $code).';
  }

  @override
  String get discogsUnexpectedResponse => 'Unexpected response from Discogs.';

  @override
  String discogsSignInNotConfirmed(int code) {
    return 'Discogs did not confirm the sign-in (HTTP $code).';
  }

  @override
  String get discogsPasteToken =>
      'Paste the token generated in your Discogs account.';

  @override
  String get discogsInvalidCredentials => 'Invalid Discogs credentials.';

  @override
  String discogsUnavailableHttp(int code) {
    return 'Discogs unavailable (HTTP $code).';
  }

  @override
  String get discogsTooManyRequests =>
      'Discogs: too many requests, try again in a few seconds.';

  @override
  String get castDisconnected => 'Disconnected';

  @override
  String castConnectingTls(String address) {
    return 'Connecting to Chromecast over TLS ($address)...';
  }

  @override
  String castTlsTimeout(String host, String error) {
    return 'Timed out connecting to the TV over TLS ($host): $error';
  }

  @override
  String get castTlsEstablished =>
      'TLS connection established. Negotiating channels...';

  @override
  String castChannelError(String error) {
    return 'TV communication channel error: $error';
  }

  @override
  String get castTvClosed => 'The TV closed the connection.';

  @override
  String get castCheckingStatus => 'Checking TV status...';

  @override
  String castStartupTimeout(int seconds) {
    return 'Startup timed out (${seconds}s). The TV did not finish opening the app.';
  }

  @override
  String castStartingApp(String appId) {
    return 'Starting app ID $appId on the TV...';
  }

  @override
  String castLaunchFailure(String host, String error) {
    return 'Unexpected Cast launch failure ($host): $error';
  }

  @override
  String castReceiverRunning(String id) {
    return 'Web receiver running on the TV (transport ID: $id)';
  }

  @override
  String castTvRefused(String reason) {
    return 'The TV refused the app: $reason';
  }

  @override
  String get noLogEntries => 'No log entries yet.';

  @override
  String get logFileEmpty => 'Log file is empty.';

  @override
  String couldNotReadLogs(String error) {
    return 'Could not read logs: $error';
  }

  @override
  String get statusMicBusy =>
      'Another app is using the microphone (voice assistant, accessibility or call app), so WaxClub can\'t hear the record. Close that app and tap the microphone again.';

  @override
  String get cameraTooltip => 'Identify a record';

  @override
  String get scanTitle => 'Identify your record';

  @override
  String get scanHowTo => 'Where to point the camera';

  @override
  String get scanModeBarcode => 'Barcode';

  @override
  String get scanModeCatalog => 'Catalog no.';

  @override
  String get scanModeTyped => 'Type it';

  @override
  String get scanBarcodeHint =>
      'Point at the barcode on the back cover (usually in a bottom corner)';

  @override
  String get scanBarcodeTryCatalog =>
      'No barcode? Older records usually have none. Try the catalog number.';

  @override
  String get scanTorch => 'Flashlight';

  @override
  String get scanCameraUnavailable =>
      'Camera unavailable. Allow camera access in Settings → Apps → WaxClub → Permissions, or type the record.';

  @override
  String get scanCatalogHint =>
      'Photograph the spine, the record label or the top corner of the back cover, where the catalog number is printed (e.g. 6349 123, SHVL 804).';

  @override
  String get scanTakePhoto => 'Take a photo';

  @override
  String get scanReadingPhoto => 'Reading the photo...';

  @override
  String get scanCatalogFound => 'Catalog numbers found — tap the right one:';

  @override
  String get scanCatalogNoneFound =>
      'No catalog number found in the photo. Type it below or take another photo closer to the text.';

  @override
  String get scanCatalogField => 'Catalog number';

  @override
  String get scanTypedField => 'Artist and album';

  @override
  String get search => 'Search';

  @override
  String scanSearching(String query) {
    return 'Looking for \"$query\"...';
  }

  @override
  String get scanPickPressing =>
      'Pick your pressing: year, country, label and catalog number help you find it.';

  @override
  String scanNoResults(String query) {
    return 'No vinyl pressing found for \"$query\". Try another mode or type the record.';
  }

  @override
  String get scanAgain => 'Scan again';

  @override
  String get foundAddToCollectionTitle => 'Add to collection?';

  @override
  String get foundAlreadyInCollection => 'Already in your collection.';

  @override
  String get no => 'No';

  @override
  String get yes => 'Yes';

  @override
  String get entryTitle => 'Add to collection';

  @override
  String get entryRating => 'Rating';

  @override
  String get entryMediaCondition => 'Record condition';

  @override
  String get entrySleeveCondition => 'Sleeve condition';

  @override
  String get entryNotes => 'Notes';

  @override
  String get entryNotSet => 'Not set';

  @override
  String get entryAlsoDiscogs => 'Also add to my Discogs collection';

  @override
  String get entryDiscogsAdded => 'Also added to your Discogs collection.';

  @override
  String get entryDiscogsFailed =>
      'Could not add it to your Discogs collection right now.';

  @override
  String get letsListenTitle => 'Let\'s listen?';

  @override
  String letsListenBody(String album) {
    return 'Drop the needle on \"$album\" and tap Yes: WaxClub will listen and follow along.';
  }

  @override
  String get guideBarcodeTitle => 'Barcode';

  @override
  String get guideBarcodeBody =>
      'Most records from the 80s on have a barcode on the back cover, usually in a bottom corner or on a sticker on the shrink wrap. Hold the phone 10–20 cm away: it reads by itself.';

  @override
  String get guideCatalogTitle => 'Catalog number';

  @override
  String get guideCatalogBody =>
      'Older records: look for the code on the spine, on the record label (near the center hole) or in the top corner of the back cover, e.g. \"6349 123\". Take a photo and tap the right number.';

  @override
  String get guideLightTitle => 'Light and focus';

  @override
  String get guideLightBody =>
      'Use good light and avoid glare on glossy covers. Turn on the flashlight if it is dark. Hold still until the text is sharp.';

  @override
  String get guidePressingTitle => 'Pick your pressing';

  @override
  String get guidePressingBody =>
      'The same album has many pressings. Check year, country, label and catalog number, then add it to your collection and start listening.';

  @override
  String get guideNext => 'Next';

  @override
  String get guideDone => 'Got it';

  @override
  String get helpCamera => 'Identify a record';

  @override
  String get helpCamera1 =>
      'Tap Identify (the camera button). Point at the barcode on the back cover, or take a photo of the catalog number on the spine or label. You can also type the artist and album. The first time, a short guide shows where to point the camera.';

  @override
  String get helpCamera2 =>
      'Pick your exact pressing (only vinyl is listed), add it to your collection with rating, condition and notes if you like, then tap \"Yes\" to listen: WaxClub already knows the record, so the next tracks are right from the first song.';

  @override
  String get jukeboxTitle => 'Plugin Jukebox';

  @override
  String get jukeboxLede =>
      'Every plugin is a 7\" single. The vinyl color tells the kind; the code on the strip selects it. Type a code on the keypad or tap a record.';

  @override
  String get jukeboxChooseSelection => 'Choose a selection: letter + number.';

  @override
  String jukeboxNowNumber(String category) {
    return '$category: now the number.';
  }

  @override
  String get jukeboxPressSelect => 'Press Select.';

  @override
  String get jukeboxStartWithLetter => 'Start with the letter of the category.';

  @override
  String get jukeboxTypeCode => 'Type a letter and a number, e.g. L1.';

  @override
  String jukeboxNoSuchCode(String code) {
    return 'Selection $code does not exist.';
  }

  @override
  String get jukeboxClear => 'Clear';

  @override
  String get jukeboxSelect => 'Select';

  @override
  String get jukeboxOnThePlatter => 'On the platter';

  @override
  String get jukeboxNothingPlaying => 'No record here yet.';

  @override
  String get jukeboxSelectionStrips => 'Selection strips';

  @override
  String get jukeboxAll => 'All';

  @override
  String get jukeboxCrate => 'Record crate';

  @override
  String get jukeboxCrateHint =>
      'Plugins not installed yet. Each one shows its source and license before going into the jukebox.';

  @override
  String get jukeboxComingSoon => 'Coming soon';

  @override
  String get jukeboxOnPlatter => 'On the platter';

  @override
  String get jukeboxComingSoonHint =>
      'Coming soon: this plugin is not available yet.';

  @override
  String get jukeboxLockedHint => 'Built in and always on for now.';

  @override
  String jukeboxExclusiveHint(String category) {
    return 'In use. Only one $category plugin plays at a time: choose another to switch.';
  }

  @override
  String get jukeboxIsOn => 'On the platter: this plugin is on.';

  @override
  String get jukeboxIsOff => 'Off: tap the button to put it on the platter.';

  @override
  String get jukeboxTurnOn => 'Put on the platter';

  @override
  String get jukeboxTurnOff => 'Take off the platter';

  @override
  String get jukeboxLicense => 'License';

  @override
  String get jukeboxAiNotice =>
      'AI content is always marked as AI-generated. Audio never leaves your phone without your consent.';

  @override
  String get pluginCatLanguage => 'Language';

  @override
  String get pluginCatDisplay => 'Display';

  @override
  String get pluginCatAi => 'AI';

  @override
  String get pluginRuleLanguage => 'One at a time';

  @override
  String get pluginRuleDisplay => 'Several at once';

  @override
  String get pluginRuleAi => 'Several; marked as AI-generated';

  @override
  String get pluginAuthorBuiltIn => 'Built in';

  @override
  String get pluginAuthorWaxClub => 'WaxClub';

  @override
  String get pluginLicenseOfficial => 'Official translation';

  @override
  String get pluginLicenseLyrics => 'Lyrics from the sources you enable';

  @override
  String get pluginLicenseCuriosities =>
      'Sources cited: Wikipedia (CC BY-SA), Discogs, news outlets';

  @override
  String get pluginLicenseAi => 'AI-generated text, always marked';

  @override
  String get pluginEnglishName => 'English';

  @override
  String get pluginEnglishDesc =>
      'Preinstalled. Provides all the menus and texts of the app in English. Other languages will be available as plugins on the official WaxClub website.';

  @override
  String get pluginLyricsName => 'Synced lyrics';

  @override
  String get pluginLyricsDesc =>
      'Shows the lyrics in sync with the record, on the phone and on the TV, in the same style on both.';

  @override
  String get pluginCuriositiesName => 'Record curiosities';

  @override
  String get pluginCuriositiesDesc =>
      'Short facts about the record and each track, plus recent news about the artist, always in English with the source (Wikipedia, Discogs pressing notes, news outlets), rising and fading as the music plays. Shown when there are no lyrics.';

  @override
  String get pluginAiCuriositiesName => 'AI curiosities';

  @override
  String get pluginAiCuriositiesDesc =>
      'Summarizes facts about the record and its tracks from Discogs and Wikipedia, always with the source.';

  @override
  String get pluginAiTranslateName => 'AI translation';

  @override
  String get pluginAiTranslateDesc =>
      'Translates the news and curiosities (always in English) into your language. Will be available on the official WaxClub website.';

  @override
  String get helpPlugins => 'Plugins (jukebox)';

  @override
  String get helpPlugins1 =>
      'Tap Plugins (the jack plug button) to open the Plugin Jukebox. Each plugin is a colored 7\" single: green for languages, cyan for display and lilac for AI. English comes preinstalled; other languages will be available on the official WaxClub website.';

  @override
  String get helpPlugins2 =>
      'Tap a record or type its code (e.g. L1) on the keypad and press Select to see details and turn it on or off. Records on the platter are the ones in use; the ones in the crate are coming soon.';

  @override
  String get plugins => 'Plugins';

  @override
  String get camera => 'Identify';

  @override
  String get helpTopBar => 'The top bar';

  @override
  String get helpTopBar1 =>
      'At the top left is the WaxClub logo, or the cover of the record that is playing: tap it to see the tracklist. With the phone sideways, the record name, the song and what comes next appear beside it.';

  @override
  String get helpTopBar2 =>
      'The wooden buttons, from left to right: Identify (camera), Manual (on/off switch), My Collection (bookshelf), Plugins (jack plug) and Help (question mark). Their names show up one by one when the app opens. The last button shows the lyrics on your TV.';

  @override
  String get manual => 'Manual';

  @override
  String get manualOnHint =>
      'Manual mode on. Tap ▶ to choose where the needle starts; the lyrics follow the track timing. The switch turns off by itself when the record ends.';

  @override
  String get manualOffHint =>
      'Manual mode off: WaxClub recognizes the songs automatically.';

  @override
  String get helpManual => 'Manual mode';

  @override
  String get helpManual1 =>
      'For records the recognition system does not know. With the Manual switch on, the microphone button becomes a chrome ▶: tap it, pick the track where the needle starts and drop the needle. The microphone only measures the volume to find the start; then the lyrics and track changes follow the record\'s track timing.';

  @override
  String get helpManual2 =>
      'At the end of a side, flip the record and tap ▶. In the tracklist you can tap a track to jump to it. After Identify, WaxClub checks the recognition system and turns Manual mode on by itself when the record is not there. The switch starts off and turns off when the record ends (last song of the last side).';

  @override
  String get manualModeOffStatus => 'Manual mode off.';

  @override
  String manualWaitingNeedle(String number, String title) {
    return '▶ $number $title — drop the needle: the lyrics start with the music.';
  }

  @override
  String get manualNeedleTimeout =>
      'The music did not start. Tap ▶ when the needle is on the record.';

  @override
  String manualPlaying(String number, String title) {
    return 'Manual • $number $title';
  }

  @override
  String get manualNoDuration =>
      'Manual • track length unknown: tap the next track in the tracklist when it starts.';

  @override
  String get manualRecordEnded => 'End of the record. Manual mode off.';

  @override
  String manualFlipAndPlay(String side) {
    return 'End of side $side. Flip the record and tap ▶.';
  }

  @override
  String get manualStartTitle => 'Where does the needle start?';

  @override
  String get manualUseMic => 'Detect the start with the microphone';

  @override
  String get manualUseMicHint =>
      'The microphone only measures the volume to find where the music starts. No song recognition.';

  @override
  String get manualNoMicHint =>
      'The lyrics start as soon as you pick the track.';

  @override
  String manualMissingDurations(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count tracks have no length: tap them in the tracklist when they start.',
      one: '1 track has no length: tap it in the tracklist when it starts.',
    );
    return '$_temp0';
  }

  @override
  String get manualNoRecord =>
      'Identify the record first: Manual mode follows its tracklist.';

  @override
  String get manualPlayTooltip => 'Start (Manual mode)';

  @override
  String get manualStopTooltip => 'Stop (Manual mode)';

  @override
  String get manualNextSideTooltip => 'Start the next side';

  @override
  String get catalogChecking => 'Checking the recognition system...';

  @override
  String get catalogNotFoundTitle => 'Not in the recognition system';

  @override
  String get catalogNotFoundBody =>
      'This record was not found in the recognition system. Switching to Manual mode: the lyrics will follow the track timing of the record.';

  @override
  String get curiosityAboutRecord => 'About the record';

  @override
  String get curiosityAboutTrack => 'About this track';

  @override
  String curiositySource(String source) {
    return 'Source: $source';
  }

  @override
  String get helpCuriosities => 'Curiosities';

  @override
  String get helpCuriosities1 =>
      'When a song has no lyrics, WaxClub shows short facts about the record and recent news about the artist (at the start of a side), and facts about the track, rising and fading as the music plays, on the phone and on the TV. Everything is in English and shows its source (Wikipedia, the Discogs pressing notes, or the news outlet and date).';

  @override
  String get helpCuriosities2 =>
      'Facts are saved on the phone, so they also work offline next time. Turn them off in Plugins (D2 Record curiosities).';

  @override
  String get curiosityLatestNews => 'Latest news';

  @override
  String newsSourceDate(String source, String date) {
    return '$source · $date';
  }

  @override
  String get jukeboxMoreLanguages =>
      'More languages will be available as plugins on the official WaxClub website.';

  @override
  String get secondScreenMirror =>
      'No Chromecast? Mirror with Smart View / Miracast';

  @override
  String secondScreenShowOn(String name) {
    return 'Show the lyrics on $name';
  }

  @override
  String get secondScreenDefaultName => 'Smart View';

  @override
  String get secondScreenHint =>
      'Pick your TV in the system screen (Smart View, Cast or Wireless display). WaxClub shows only the lyrics on the TV and keeps the controls on your phone.';

  @override
  String get manualSuggestion =>
      'Not recognized for a while. This record may not be in the recognition system: switch to Manual mode?';

  @override
  String get manualSuggestionAction => 'Manual mode';

  @override
  String get accountTitle => 'WaxClub account';

  @override
  String get accountTooltip => 'WaxClub account';

  @override
  String get accountEmailLabel => 'Email';

  @override
  String get accountSendCode => 'Send code';

  @override
  String get accountCodeLabel => '6-digit code';

  @override
  String get accountSignIn => 'Sign in';

  @override
  String get accountResend => 'Send a new code';

  @override
  String get accountSignedInAs => 'Signed in as';

  @override
  String accountLastSync(String when) {
    return 'Last synced: $when';
  }

  @override
  String get accountNeverSynced => 'Not synced yet';

  @override
  String get accountSyncing => 'Syncing...';

  @override
  String get accountSyncNow => 'Sync now';

  @override
  String get accountSyncFailed =>
      'The last sync failed. Tap Sync now to try again.';

  @override
  String get accountSyncInfo =>
      'Your collection syncs automatically when it changes. Listening history is backed up to your account.';

  @override
  String get accountSignOut => 'Sign out';

  @override
  String get accountDelete => 'Delete account';

  @override
  String get accountDeleteConfirmTitle => 'Delete your WaxClub account?';

  @override
  String get accountDeleteConfirmBody =>
      'This removes your account, your synced collection and your listening history from the WaxClub server. The records on this phone stay.';

  @override
  String get accountDeleteConfirm => 'Delete';

  @override
  String get accountErrorEmail => 'Enter a valid email address.';

  @override
  String get accountErrorCode => 'Wrong code. Check the email and try again.';

  @override
  String get accountErrorExpired =>
      'This code has expired or was used too many times. Ask for a new one.';

  @override
  String get accountErrorTooMany =>
      'Too many codes requested. Try again in an hour.';

  @override
  String get accountErrorNetwork =>
      'No connection to the WaxClub server. Check your internet.';

  @override
  String get accountErrorGeneric => 'Something went wrong. Please try again.';

  @override
  String get authWelcome => 'Welcome to WaxClub';

  @override
  String get authSubtitle =>
      'Sign in to join the club: your records, your city and your listening history, always in sync.';

  @override
  String get authPassword => 'Password';

  @override
  String get authShowPassword => 'Show password';

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authNoAccount => 'New to WaxClub?';

  @override
  String get authCreateAccount => 'Create account';

  @override
  String get authContinueWithGoogle => 'Continue with Google';

  @override
  String get authOr => 'or';

  @override
  String get signUpTitle => 'Create your account';

  @override
  String get signUpUsername => 'Username';

  @override
  String get signUpUsernameHint =>
      '3 to 20 characters: letters, numbers, dot or underscore.';

  @override
  String get signUpUsernameTaken => 'This username is taken.';

  @override
  String get signUpUsernameAvailable => 'Available';

  @override
  String get signUpPasswordHint => 'At least 8 characters.';

  @override
  String get signUpCountry => 'Country';

  @override
  String get signUpState => 'State / province';

  @override
  String get signUpCity => 'City';

  @override
  String get signUpSearch => 'Search';

  @override
  String get signUpPickCountryFirst => 'Choose the country first';

  @override
  String get signUpPickStateFirst => 'Choose the state first';

  @override
  String get signUpCityHint => 'Type to search your city';

  @override
  String get signUpNoResults => 'Nothing found';

  @override
  String get signUpLocationWhy =>
      'Your city is used to show concerts near you.';

  @override
  String get verifyTitle => 'Confirm your email';

  @override
  String verifyBody(String email) {
    return 'We sent a 6-digit code to $email. Enter it below to activate your account. Check your spam folder if it does not arrive.';
  }

  @override
  String get verifyConfirm => 'Confirm';

  @override
  String get verifyResent => 'A new code is on its way.';

  @override
  String get forgotTitle => 'Reset password';

  @override
  String get forgotBody =>
      'Enter the email of your account. We will send you a code to choose a new password.';

  @override
  String forgotCodeSent(String email) {
    return 'If $email has a WaxClub account, a 6-digit code is on its way.';
  }

  @override
  String get forgotNewPassword => 'New password';

  @override
  String get forgotSave => 'Save and sign in';

  @override
  String get profileCompleteTitle => 'Complete your profile';

  @override
  String get profileCompleteBody =>
      'Choose a username and tell us where you are.';

  @override
  String get profileSave => 'Save';

  @override
  String get accountEditProfile => 'Edit profile';

  @override
  String get authErrorCredentials => 'Wrong email or password.';

  @override
  String get authErrorNoPassword =>
      'This account has no password yet. Tap \"Forgot password?\" to create one.';

  @override
  String get authErrorEmailTaken =>
      'This email already has an account. Sign in or reset the password.';

  @override
  String get authErrorWeakPassword =>
      'The password needs at least 8 characters.';

  @override
  String get authErrorUsername => 'Choose a valid username.';

  @override
  String get authErrorLocation => 'Choose your country, state and city.';

  @override
  String get authErrorTooManyAttempts =>
      'Too many attempts. Wait 15 minutes and try again.';

  @override
  String get authErrorRequired => 'Fill in all the fields.';

  @override
  String get geoAttribution =>
      'Location data © GeoNames (geonames.org), CC BY 4.0.';
}
