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
  String get resetPassword;
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
  String get noTeachersAvailable;
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
  
  // Students
  String get studentsList;
  String get noStudentsFound;
  String get sendChatRequest;
  String get chatRequestSent;
  String get alreadyChatting;
  
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
  
  // Notifications
  String get notifications;
  String get notificationSettings;
  String get noNotifications;
  String get markAllRead;
  String get enableNotifications;
  String get sessionReminders;
  String get chatMessages;
  String get practiceReminders;
  
  // Days of week
  String get monday;
  String get tuesday;
  String get wednesday;
  String get thursday;
  String get friday;
  String get saturday;
  String get sunday;
  
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

