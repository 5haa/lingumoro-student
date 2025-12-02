import 'package:flutter/material.dart';
import 'app_localizations_en.dart';
import 'app_localizations_ar.dart';
import 'app_localizations_es.dart';

abstract class AppLocalizations {
  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    delegate,
  ];

  static const List<Locale> supportedLocales = [
    Locale('en', ''),
    Locale('ar', ''),
    Locale('es', ''),
  ];

  // Common
  String get appName;
  String get ok;
  String get cancel;
  String get yes;
  String get no;
  String get error;
  String get success;
  String get loading;
  String get retry;
  String get save;
  String get delete;
  String get edit;
  String get search;
  String get filter;
  String get close;
  String get next;
  String get previous;
  String get done;
  String get skip;
  String get and;
  String get or;
  
  // Navigation
  String get navHome;
  String get navClasses;
  String get navPractice;
  String get navChat;
  String get navProfile;
  
  // Drawer/Settings
  String get settings;
  String get contactUs;
  String get aboutUs;
  String get privacyPolicy;
  String get termsConditions;
  String get changeLanguage;
  String get selectLanguage;
  String get languageChanged;
  String get version;
  
  // Auth
  String get login;
  String get signup;
  String get logout;
  String get email;
  String get password;
  String get confirmPassword;
  String get fullName;
  String get forgotPassword;
  String get forgotPasswordTitle;
  String get forgotPasswordDescription;
  String get pleaseEnterYourEmail;
  String get verificationCodeSentToEmail;
  String get failedToSendCode;
  String get sendCode;
  String get resetPassword;
  String get resetPasswordTitle;
  String get resetPasswordDescription;
  String get enterNewPasswordBelow;
  String get newPassword;
  String get confirmNewPassword;
  String get passwordResetSuccessfully;
  String get failedToResetPassword;
  String get userNotLoggedIn;
  String get dontHaveAccount;
  String get alreadyHaveAccount;
  String get enterEmail;
  String get enterPassword;
  String get enterFullName;
  String get passwordMismatch;
  String get emailRequired;
  String get passwordRequired;
  String get fullNameRequired;
  String get invalidEmail;
  String get passwordTooShort;
  String get loginSuccess;
  String get loginFailed;
  String get signupSuccess;
  String get signupFailed;
  String get logoutConfirm;
  String get areYouSureLogout;
  String get phoneNumber;
  String get enterPhoneNumber;
  String get phoneNumberRequired;
  String get bio;
  String get enterBio;
  String get createAccount;
  String get welcomeBack;
  String get getStarted;
  
  // Home
  String get chooseYourClass;
  String get students;
  String get teachers;
  String get noLanguagesAvailable;
  String get selectLanguageFirst;
  
  // Profile
  String get profile;
  String get editProfile;
  String get personalInformation;
  String get security;
  String get changePassword;
  String get changePasswordTitle;
  String changePasswordDescription(String email);
  String get sendVerificationCode;
  String get updatePassword;
  String get currentLevel;
  String get proMember;
  String get freeMember;
  String get upgrade;
  String get upgradeToPro;
  String get redeemVoucher;
  String get voucherCode;
  String get enterCodeHere;
  String get redeem;
  String get proBenefits;
  String get unlimitedAccess;
  String get unlimitedAccessDesc;
  String get connectWithStudents;
  String get connectWithStudentsDesc;
  String get practiceWithAI;
  String get practiceWithAIDesc;
  String get enterVoucherCode;
  String get voucherRedeemed;
  String get voucherRedeemedDesc;
  String get invalidVoucher;
  String get expiresPro;
  String get unlimitedFeatures;
  String get limitedFeatures;
  String get languageLearner;
  String get xpPoints;
  String get xpToNextLevel;
  String get maxLevelReached;
  
  // Level statuses
  String get levelBeginner;
  String get levelIntermediate;
  String get levelAdvanced;
  String get levelExpert;
  String get levelMaster;
  String get levelGrandMaster;
  String get levelLegend;
  String get levelMythic;
  String get levelTranscendent;
  String get levelSupreme;
  
  // Classes
  String get classes;
  String get upcoming;
  String get finished;
  String get joinSession;
  String get sessionDetails;
  String get meetingLinkNotAvailable;
  String get waitForTeacher;
  String get noUpcomingSessions;
  String get noFinishedSessions;
  String get sessionWith;
  String get packageType;
  String get date;
  String get time;
  String get duration;
  String get minutes;
  
  // Practice
  String get practice;
  String get videos;
  String get quizPractice;
  String get reading;
  String get aiVoice;
  String get watchedVideos;
  String get totalVideos;
  String get questionsAnswered;
  String get accuracy;
  String get storiesGenerated;
  String get storiesRemaining;
  String get startPractice;
  String get continueWatching;
  String get markAsWatched;
  String get completedVideos;
  String get noPracticeAvailable;
  String get proFeature;
  String get upgradeToAccess;
  String get videoPracticeTitle;
  String get overallProgress;
  String get lessonPlaylist;
  String get noVideosYet;
  String get videosComingSoon;
  String get videoLockedTitle;
  String get completePreviousVideoToUnlock;
  String get aboutThisLesson;
  String get watchFullVideoToUnlock;
  
  // Chat
  String get chat;
  String get messages;
  String get online;
  String get offline;
  String get typing;
  String get typeMessage;
  String get sendMessage;
  String get noMessages;
  String get startConversation;
  String get chatRequests;
  String get noChatRequests;
  String get accept;
  String get decline;
  String get blocked;
  String get unblock;
  String get block;
  String get report;
  
  // Teachers
  String get teachersList;
  String get noTeachersForLanguage;
  String get selectPackage;
  String get selectDayTime;
  String get bookSession;
  String get sessionBooked;
  String get bookingFailed;
  String get availableSlots;
  String get noAvailableSlots;
  String get selectTimeSlot;
  String get teacherDetails;
  String get rating;
  String get reviews;
  String get about;
  String get experience;
  String get languages;
  String get hourlyRate;
  String get perSession;
  // Teacher detail/profile
  String get teacherNotFoundTitle;
  String get teacherNotFoundMessage;
  String get alreadySubscribedMessage;
  String get needSubscriptionToChat;
  String get availableSchedulesTitle;
  String get noScheduleAvailable;
  String get ratingsAndReviewsTitle;
  String get noReviewsYet;
  String get rateButton;
  String get updateRatingButton;
  
  // Students
  String get studentsList;
  String get noStudentsFound;
  String get sendChatRequest;
  String get chatRequestSent;
  String get alreadyChatting;
  String get beFirstInYourLanguage;
  String get enrollToSeeOtherStudents;
  
  // Packages
  String get packages;
  String get selectYourPackage;
  String get packageDetails;
  String get sessionsPerWeek;
  String get totalSessions;
  String get price;
  String get subscribe;
  String get subscriptionActive;
  String get subscriptionExpired;
  // Subscription & vouchers
  String get noPackagesAvailable;
  String teacherNeedsDaysAvailable(int days);
  String get selectDays;
  String get selectTime;
  String get noCommonTimeSlots;
  String get selectedPackageLabel;
  String selectedDaysLabel(int days);
  String get change;
  String get yourSchedule;
  String voucherCodeMustBeLength(int length);
  String get voucherCodeValidForPackage;
  String subscriptionActivatedSessions(int sessions);
  String get redeemingVoucher;
  String get stepPackage;
  String get stepDays;
  String get stepTime;
  String get perMonth;
  String get subscribeTo;
  
  // Notifications
  String get notifications;
  String get notificationSettings;
  String get noNotifications;
  String get markAllRead;
  String get enableNotifications;
  String get sessionReminders;
  String get chatMessages;
  String get practiceReminders;
  // Notifications - additional
  String get allNotificationsMarkedRead;
  String get clearAllNotificationsTitle;
  String get clearAllNotificationsMessage;
  String get clearAllButton;
  String notificationsCleared(int count);
  String get readAll;
  String get clear;
  String get youreAllCaughtUp;
  
  // Days of week
  String get monday;
  String get tuesday;
  String get wednesday;
  String get thursday;
  String get friday;
  String get saturday;
  String get sunday;
  String get mon;
  String get tue;
  String get wed;
  String get thu;
  String get fri;
  String get sat;
  String get sun;
  
  // Months
  String get january;
  String get february;
  String get march;
  String get april;
  String get may;
  String get june;
  String get july;
  String get august;
  String get september;
  String get october;
  String get november;
  String get december;
  
  // Error messages
  String get errorLoadingData;
  String get errorSavingData;
  String get errorNoInternet;
  String get errorTryAgain;
  String get errorUnknown;
  
  // Success messages
  String get successSaved;
  String get successUpdated;
  String get successDeleted;
  
  // Validation
  String get fieldRequired;
  String get invalidInput;
  String get tooShort;
  String get tooLong;
  
  // Settings screens
  String get aboutUsContent;
  String get privacyPolicyContent;
  String get termsConditionsContent;
  
  // Contact
  String get couldNotOpenWhatsApp;
  String get errorOpeningWhatsApp;
  
  // Province/City selection
  String get chooseCity;
  String get selectProvince;
  String get searchProvince;
  String get pleaseSelectProvince;
  String get fillAllFields;
  String get confirmAccount;
  
  // Quiz Practice
  String get languageQuiz;
  String get yourStatistics;
  String get quizzes;
  String get points;
  String get recentQuizzes;
  String get proSubscriptionRequired;
  String get languageQuizProOnly;
  String get goBack;
  String get levelElementary;
  String get levelPreIntermediate;
  String get levelUpperIntermediate;
  String get startNewQuiz;
  String get questionNumber;
  String get exitQuiz;
  String get exitQuizMessage;
  String get exit;
  String get quizComplete;
  String get score;
  String get reviewAnswers;
  String get back;
  String get retryQuiz;
  String get totalQuestions;
  String get timePerQuestion;
  String get pointsAvailable;
  String get quizInstructions;
  String get startQuiz;
  String get correct;
  String get yourAnswer;
  String get noAnswerTimeout;
  String get correctAnswer;
  String get failedToGenerateQuiz;
  String get pleaseTryAgain;
  String get hoursAgo;
  
  // AI Voice Practice
  String get aiVoicePractice;
  String get voiceSettings;
  String get voice;
  String get speed;
  String get start;
  String get stop;
  String get sessionNumber;
  String get timesUp;
  String get sessionEndedMessage;
  String get gotIt;
  String get greatJob;
  String get practicedForMinutes;
  String get sessionsRemaining;
  String get awesome;
  String get sessionLimitReached;
  String get notConnected;
  String get preparingVoiceSession;
  String get listening;
  String get pleaseLoginToUseAI;
  String get microphonePermissionRequired;
  String get failedToStartSession;
  String get connectionError;
  String get recorderPermissionDenied;
  String get failedToStart;
  String get proFeaturesActiveOnAnotherDevice;
  String get activateInProfile;
  
  // Reading
  String get readings;
  String get yourProgress;
  String get completed;
  String get allReadings;
  String get completePreviousToUnlock;
  String get noReadingsAvailable;
  String get checkBackLater;
  String get completePreviousReading;
  String get errorLoadingReadings;
  String get errorLoadingQuestions;
  String get readingProgress;
  String get completedReadings;
  String get totalReadings;
  String get percentComplete;
  
  // OTP Verification
  String get verificationCode;
  String get otpSentToEmail;
  String get otpSentToEmailPasswordReset;
  String get confirm;
  String get resend;
  String get resendWithTimer;
  String get codeResentSuccessfully;
  String get failedToResendCode;
  String get enterCompleteCode;
  String get verificationFailed;
  
  // Chat
  String get today;
  String get yesterday;
  String get blockUser;
  String get tapToRetry;
  String get failedToLoadImage;
  String get couldNotPlayAudio;
  String get downloading;
  String get downloadedTo;
  String get downloadFailed;
  String get failedToSendMessage;
  String get errorSendingMessage;
  String get failedToCaptureImage;
  String get failedToPickImage;
  String get failedToStartRecording;
  String get checkMicrophonePermissions;
  String get failedToSendVoiceMessage;
  String get errorSendingVoiceMessage;
  
  // Common additional
  String get level;
  String get pts;
  String get session;
  String get sessions;
  String get minute;
  String get minutesPlural;
  String get loginRequired;
  
  // Chat additional
  String get chatDeletedSuccessfully;
  String get failedToDeleteChat;
  String get messageUnsent;
  String get downloadedToUnableToOpen;
  
  // Profile additional
  String get activateOnThisDevice;
  String get blockedUsers;
  String get manageBlockedUsers;
  String get studentPlaceholder;
  String get editProfileButton;
  String get proActiveOnAnotherDevice;
  String get proSubscriptionActiveMessage;
  String get proFeaturesActivated;
  String get failedToActivate;
  String get errorActivation;
  String get unknownError;
  String get logoutFailed;
  
  // Classes additional
  String get errorLoadingSessions;
  String get errorJoiningSession;
  String get teacherInformationNotAvailable;
  String get unableToStartChat;
  String get errorOpeningChat;
  String get unableToLoadTeacherDetails;
  String get myClasses;
  String get noUpcomingClasses;
  String get noFinishedClasses;
  String get subscribeToSeeClasses;
  String get pullDownToRefresh;
  String get makeupClass;
  String get cancelled;
  String get extraClass;
  String get liveNow;
  String get languageClass;
  String get teacherNamePlaceholder;
  String get yourTime;
  String get classDuration;
  String get join;
  String get waitingForMeetingLink;
  String get waitingForTeacherToStart;
  String get startsIn;
  String get classWasCancelled;
  String get tapToViewTeacherAndRate;
  String get min;
  
  // Quiz additional
  String get questionCounter;
  String get accuracyPercentage;
  String get correctCheck;
  String get answerEachQuestionWithinSeconds;
  String get questionsAutoAdvance;
  String get yourProgressWillBeLost;
  String get sec;
  String get ten;
  String get fifteenSec;
  String get loginRequiredQuizPractice;
  
  // Profile/Edit Profile
  String get editProfileTitle;
  String get photoAddedSuccessfully;
  String get failedToUploadPhoto;
  String get mainPhotoUpdated;
  String get failedToSetMainPhoto;
  String get photoDeleted;
  String get failedToDeletePhoto;
  String get profileUpdatedSuccessfully;
  String get failedToUpdateProfile;
  String get pleaseEnterYourName;
  String get tellUsAboutYourself;
  
  // Blocked Users
  String get blockedUsersTitle;
  String get unblockUser;
  String get unblockUserConfirm;
  String get unblockUserMessage;
  String get noBlockedUsers;
  String get noBlockedUsersMessage;
  String get failedToLoadBlockedUsers;
  String get userHasBeenUnblocked;
  String get failedToUnblockUser;
  String get blockUserMessage;
  String get userBlocked;
  
  // Search/Input hints
  String get searchMessages;
  String get messageHint;
  
  // Chat errors
  String get failedToUnsendMessage;
  String get failedToBlockUserTryAgain;
  
  // Chat list screen
  String get messagesTitle;
  String get showConversations;
  String get startNewChat;
  String get requestAccepted;
  String get failedToAcceptRequest;
  String get requestRejected;
  String get failedToRejectRequest;
  String get justNow;
  String minutesAgo(int minutes);
  String get oneDayAgo;
  String daysAgo(int days);
  String get noResultsFound;
  String get noMessagesYet;
  String get tryDifferentKeywords;
  String get startConversationWithTeachers;
  String get chatRequestTitle;
  String get noMessageProvided;
  String get sentChatRequest;
  String get chatRequestsReceived;
  String get chatRequestsSent;
  String get chatRequestPendingStatus;
  String get deleteChat;
  String get deleteChatQuestion;
  String deleteChatConfirmation(String name);
  String get noTeachersAvailable;
  String get subscribeToChatWithTeachers;
  String get imageAttachment;
  String get voiceMessage;
  String get fileAttachment;
  String get attachmentGeneric;
  String get startChatting;
  String get user;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'ar', 'es'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    switch (locale.languageCode) {
      case 'ar':
        return AppLocalizationsAr();
      case 'es':
        return AppLocalizationsEs();
      case 'en':
      default:
        return AppLocalizationsEn();
    }
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

