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
      'Songs often appear on several records (albums, compilations, soundtracks). Tap the cover at the top of the screen, then \"Change record\" to pick the exact record on your turntable; it becomes the default for those songs. Only vinyl records (LP and EP) are listed.';

  @override
  String get helpChangeRecord2 =>
      'Tick \"Search Discogs\" to search the largest vinyl database. Your Discogs sign-in stays on this phone only.';

  @override
  String get helpCollection => 'Your collection';

  @override
  String get helpCollection1 =>
      'Tap the cover of the record that is playing and choose \"Add to collection\". Open your collection with the records icon at the top of the screen.';

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
      'No Chromecast? Choose \"Cast via browser\" and open the address shown in your TV\'s browser.';

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
}
