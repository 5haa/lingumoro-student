import 'app_localizations.dart';

class AppLocalizationsEn extends AppLocalizations {
  // Common
  @override
  String get appName => 'Lingumoro';
  @override
  String get ok => 'OK';
  @override
  String get cancel => 'Cancel';
  @override
  String get yes => 'Yes';
  @override
  String get no => 'No';
  @override
  String get error => 'Error';
  @override
  String get success => 'Success';
  @override
  String get loading => 'Loading...';
  @override
  String get retry => 'Retry';
  @override
  String get save => 'Save';
  @override
  String get delete => 'Delete';
  @override
  String get edit => 'Edit';
  @override
  String get search => 'Search';
  @override
  String get filter => 'Filter';
  @override
  String get close => 'Close';
  @override
  String get next => 'Next';
  @override
  String get previous => 'Previous';
  @override
  String get done => 'Done';
  @override
  String get skip => 'Skip';
  @override
  String get and => 'and';
  @override
  String get or => 'or';
  
  // Navigation
  @override
  String get navHome => 'Home';
  @override
  String get navClasses => 'Classes';
  @override
  String get navPractice => 'Practice';
  @override
  String get navChat => 'Chat';
  @override
  String get navProfile => 'Profile';
  
  // Drawer/Settings
  @override
  String get settings => 'SETTINGS';
  @override
  String get contactUs => 'CONTACT US';
  @override
  String get aboutUs => 'ABOUT US';
  @override
  String get privacyPolicy => 'PRIVACY POLICY';
  @override
  String get termsConditions => 'TERMS & CONDITIONS';
  @override
  String get changeLanguage => 'CHANGE LANGUAGE';
  @override
  String get selectLanguage => 'Select Language';
  @override
  String get languageChanged => 'Language changed to English';
  @override
  String get version => 'Version 1.0.0';
  
  // Auth
  @override
  String get login => 'Login';
  @override
  String get signup => 'Sign Up';
  @override
  String get logout => 'Logout';
  @override
  String get email => 'Email';
  @override
  String get password => 'Password';
  @override
  String get confirmPassword => 'Confirm Password';
  @override
  String get fullName => 'Full Name';
  @override
  String get forgotPassword => 'Forgot Password?';
  @override
  String get resetPassword => 'Reset Password';
  @override
  String get dontHaveAccount => "Don't have an account?";
  @override
  String get alreadyHaveAccount => 'Already have an account?';
  @override
  String get enterEmail => 'Enter your email';
  @override
  String get enterPassword => 'Enter your password';
  @override
  String get enterFullName => 'Enter your full name';
  @override
  String get passwordMismatch => 'Passwords do not match';
  @override
  String get emailRequired => 'Email is required';
  @override
  String get passwordRequired => 'Password is required';
  @override
  String get fullNameRequired => 'Full name is required';
  @override
  String get invalidEmail => 'Invalid email address';
  @override
  String get passwordTooShort => 'Password must be at least 6 characters';
  @override
  String get loginSuccess => 'Login successful';
  @override
  String get loginFailed => 'Login failed';
  @override
  String get signupSuccess => 'Signup successful';
  @override
  String get signupFailed => 'Signup failed';
  @override
  String get logoutConfirm => 'Logout';
  @override
  String get areYouSureLogout => 'Are you sure you want to logout?';
  @override
  String get phoneNumber => 'Phone Number';
  @override
  String get enterPhoneNumber => 'Enter your phone number';
  @override
  String get phoneNumberRequired => 'Phone number is required';
  @override
  String get bio => 'Bio';
  @override
  String get enterBio => 'Tell us about yourself';
  @override
  String get createAccount => 'Create Account';
  @override
  String get welcomeBack => 'Welcome Back';
  @override
  String get getStarted => 'Get Started';
  
  // Home
  @override
  String get chooseYourClass => 'CHOOSE YOUR CLASS';
  @override
  String get students => 'Students';
  @override
  String get teachers => 'Teachers';
  @override
  String get noLanguagesAvailable => 'No languages available';
  @override
  String get selectLanguageFirst => 'Please select a language first';
  
  // Profile
  @override
  String get profile => 'PROFILE';
  @override
  String get editProfile => 'Edit Profile';
  @override
  String get personalInformation => 'Personal Information';
  @override
  String get security => 'Security';
  @override
  String get changePassword => 'Change Password';
  @override
  String get updatePassword => 'Update your password';
  @override
  String get currentLevel => 'Current Level';
  @override
  String get proMember => 'PRO Member';
  @override
  String get freeMember => 'Free Member';
  @override
  String get upgrade => 'Upgrade';
  @override
  String get upgradeToPro => 'Upgrade to PRO';
  @override
  String get redeemVoucher => 'Redeem your voucher code';
  @override
  String get voucherCode => 'Voucher Code';
  @override
  String get enterCodeHere => 'Enter code here';
  @override
  String get redeem => 'Redeem';
  @override
  String get proBenefits => 'PRO Benefits';
  @override
  String get unlimitedAccess => 'Unlimited Access';
  @override
  String get unlimitedAccessDesc => 'Access all features without restrictions';
  @override
  String get connectWithStudents => 'Connect with Students';
  @override
  String get connectWithStudentsDesc => 'Chat and connect with other language learners';
  @override
  String get practiceWithAI => 'Practice with AI';
  @override
  String get practiceWithAIDesc => 'Interactive AI-powered language practice sessions';
  @override
  String get enterVoucherCode => 'Please enter a voucher code';
  @override
  String get voucherRedeemed => 'PRO subscription activated!';
  @override
  String get voucherRedeemedDesc => 'days added';
  @override
  String get invalidVoucher => 'Invalid voucher code';
  @override
  String get expiresPro => 'Expires';
  @override
  String get unlimitedFeatures => 'Unlimited access to all features';
  @override
  String get limitedFeatures => 'Limited features available';
  @override
  String get languageLearner => 'Language Learner';
  @override
  String get xpPoints => 'XP';
  @override
  String get xpToNextLevel => 'XP to Level';
  @override
  String get maxLevelReached => 'Max Level Reached!';
  
  // Level statuses
  @override
  String get levelBeginner => 'Beginner';
  @override
  String get levelIntermediate => 'Intermediate';
  @override
  String get levelAdvanced => 'Advanced';
  @override
  String get levelExpert => 'Expert';
  @override
  String get levelMaster => 'Master';
  @override
  String get levelGrandMaster => 'Grand Master';
  @override
  String get levelLegend => 'Legend';
  @override
  String get levelMythic => 'Mythic';
  @override
  String get levelTranscendent => 'Transcendent';
  @override
  String get levelSupreme => 'Supreme';
  
  // Classes
  @override
  String get classes => 'CLASSES';
  @override
  String get upcoming => 'Upcoming';
  @override
  String get finished => 'Finished';
  @override
  String get joinSession => 'Join Session';
  @override
  String get sessionDetails => 'Session Details';
  @override
  String get meetingLinkNotAvailable => 'Meeting link not available yet. Please wait for the teacher to set it up.';
  @override
  String get waitForTeacher => 'Wait for teacher';
  @override
  String get noUpcomingSessions => 'No upcoming sessions';
  @override
  String get noFinishedSessions => 'No finished sessions';
  @override
  String get sessionWith => 'Session with';
  @override
  String get packageType => 'Package';
  @override
  String get date => 'Date';
  @override
  String get time => 'Time';
  @override
  String get duration => 'Duration';
  @override
  String get minutes => 'minutes';
  
  // Practice
  @override
  String get practice => 'PRACTICE';
  @override
  String get videos => 'Videos';
  @override
  String get quizPractice => 'Quiz Practice';
  @override
  String get reading => 'Reading';
  @override
  String get aiVoice => 'AI Voice';
  @override
  String get watchedVideos => 'Watched';
  @override
  String get totalVideos => 'Total';
  @override
  String get questionsAnswered => 'Questions';
  @override
  String get accuracy => 'Accuracy';
  @override
  String get storiesGenerated => 'Generated';
  @override
  String get storiesRemaining => 'Remaining';
  @override
  String get startPractice => 'Start Practice';
  @override
  String get continueWatching => 'Continue Watching';
  @override
  String get markAsWatched => 'Mark as Watched';
  @override
  String get completedVideos => 'Completed';
  @override
  String get noPracticeAvailable => 'No practice available';
  @override
  String get proFeature => 'PRO Feature';
  @override
  String get upgradeToAccess => 'Upgrade to PRO to access this feature';
  
  // Chat
  @override
  String get chat => 'CHAT';
  @override
  String get messages => 'Messages';
  @override
  String get online => 'Online';
  @override
  String get offline => 'Offline';
  @override
  String get typing => 'typing...';
  @override
  String get typeMessage => 'Type a message';
  @override
  String get sendMessage => 'Send';
  @override
  String get noMessages => 'No messages yet';
  @override
  String get startConversation => 'Start a conversation';
  @override
  String get chatRequests => 'Chat Requests';
  @override
  String get noChatRequests => 'No chat requests';
  @override
  String get accept => 'Accept';
  @override
  String get decline => 'Decline';
  @override
  String get blocked => 'Blocked';
  @override
  String get unblock => 'Unblock';
  @override
  String get block => 'Block';
  @override
  String get report => 'Report';
  
  // Teachers
  @override
  String get teachersList => 'TEACHERS';
  @override
  String get noTeachersAvailable => 'No Teachers Available';
  @override
  String get noTeachersForLanguage => 'No teachers found for';
  @override
  String get selectPackage => 'Select Package';
  @override
  String get selectDayTime => 'Select Day & Time';
  @override
  String get bookSession => 'Book Session';
  @override
  String get sessionBooked => 'Session booked successfully';
  @override
  String get bookingFailed => 'Booking failed';
  @override
  String get availableSlots => 'Available Slots';
  @override
  String get noAvailableSlots => 'No available slots';
  @override
  String get selectTimeSlot => 'Select a time slot';
  @override
  String get teacherDetails => 'Teacher Details';
  @override
  String get rating => 'Rating';
  @override
  String get reviews => 'Reviews';
  @override
  String get about => 'About';
  @override
  String get experience => 'Experience';
  @override
  String get languages => 'Languages';
  @override
  String get hourlyRate => 'Hourly Rate';
  @override
  String get perSession => 'per session';
  
  // Students
  @override
  String get studentsList => 'STUDENTS';
  @override
  String get noStudentsFound => 'No students found';
  @override
  String get sendChatRequest => 'Send Chat Request';
  @override
  String get chatRequestSent => 'Chat request sent';
  @override
  String get alreadyChatting => 'Already chatting';
  
  // Packages
  @override
  String get packages => 'PACKAGES';
  @override
  String get selectYourPackage => 'Select Your Package';
  @override
  String get packageDetails => 'Package Details';
  @override
  String get sessionsPerWeek => 'sessions per week';
  @override
  String get totalSessions => 'Total Sessions';
  @override
  String get price => 'Price';
  @override
  String get subscribe => 'Subscribe';
  @override
  String get subscriptionActive => 'Subscription Active';
  @override
  String get subscriptionExpired => 'Subscription Expired';
  
  // Notifications
  @override
  String get notifications => 'NOTIFICATIONS';
  @override
  String get notificationSettings => 'Notification Settings';
  @override
  String get noNotifications => 'No notifications';
  @override
  String get markAllRead => 'Mark all as read';
  @override
  String get enableNotifications => 'Enable Notifications';
  @override
  String get sessionReminders => 'Session Reminders';
  @override
  String get chatMessages => 'Chat Messages';
  @override
  String get practiceReminders => 'Practice Reminders';
  
  // Days of week
  @override
  String get monday => 'Monday';
  @override
  String get tuesday => 'Tuesday';
  @override
  String get wednesday => 'Wednesday';
  @override
  String get thursday => 'Thursday';
  @override
  String get friday => 'Friday';
  @override
  String get saturday => 'Saturday';
  @override
  String get sunday => 'Sunday';
  
  // Months
  @override
  String get january => 'January';
  @override
  String get february => 'February';
  @override
  String get march => 'March';
  @override
  String get april => 'April';
  @override
  String get may => 'May';
  @override
  String get june => 'June';
  @override
  String get july => 'July';
  @override
  String get august => 'August';
  @override
  String get september => 'September';
  @override
  String get october => 'October';
  @override
  String get november => 'November';
  @override
  String get december => 'December';
  
  // Error messages
  @override
  String get errorLoadingData => 'Error loading data';
  @override
  String get errorSavingData => 'Error saving data';
  @override
  String get errorNoInternet => 'No internet connection';
  @override
  String get errorTryAgain => 'Please try again';
  @override
  String get errorUnknown => 'An unknown error occurred';
  
  // Success messages
  @override
  String get successSaved => 'Saved successfully';
  @override
  String get successUpdated => 'Updated successfully';
  @override
  String get successDeleted => 'Deleted successfully';
  
  // Validation
  @override
  String get fieldRequired => 'This field is required';
  @override
  String get invalidInput => 'Invalid input';
  @override
  String get tooShort => 'Too short';
  @override
  String get tooLong => 'Too long';
  
  // Settings screens
  @override
  String get aboutUsContent => 'Lingumoro is a language learning platform that connects students with teachers.';
  @override
  String get privacyPolicyContent => 'Your privacy is important to us. We collect and use your data to provide better services.';
  @override
  String get termsConditionsContent => 'By using this application, you agree to our terms and conditions.';
  
  // Contact
  @override
  String get couldNotOpenWhatsApp => 'Could not open WhatsApp';
  @override
  String get errorOpeningWhatsApp => 'Error opening WhatsApp';
  
  // Province/City selection
  @override
  String get chooseCity => 'Choose City';
  @override
  String get selectProvince => 'Select Province';
  @override
  String get searchProvince => 'Search province...';
  @override
  String get pleaseSelectProvince => 'Please select your province';
  @override
  String get fillAllFields => 'Please fill in all required fields';
  @override
  String get confirmAccount => 'CONFIRM ACCOUNT';
}

