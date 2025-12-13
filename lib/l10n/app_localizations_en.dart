import 'app_localizations.dart';

class AppLocalizationsEn extends AppLocalizations {
  // Common
  @override
  String get appName => 'LinguMoro';
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
  String get forgotPasswordTitle => 'FORGOT PASSWORD';
  @override
  String get forgotPasswordDescription => 'Enter your email address and we will send you a verification code to reset your password';
  @override
  String get pleaseEnterYourEmail => 'Please enter your email';
  @override
  String get verificationCodeSentToEmail => 'Verification code sent to your email';
  @override
  String get failedToSendCode => 'Failed to send code';
  @override
  String get sendCode => 'SEND CODE';
  @override
  String get resetPassword => 'Reset Password';
  @override
  String get resetPasswordTitle => 'RESET PASSWORD';
  @override
  String get resetPasswordDescription => 'Enter your new password below';
  @override
  String get enterNewPasswordBelow => 'Enter your new password below';
  @override
  String get newPassword => 'New Password';
  @override
  String get confirmNewPassword => 'Confirm New Password';
  @override
  String get passwordResetSuccessfully => 'Password reset successfully!';
  @override
  String get failedToResetPassword => 'Failed to reset password';
  @override
  String get userNotLoggedIn => 'User not logged in';
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
  @override
  String get comingSoon => 'Soon';
  
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
  String get changePasswordTitle => 'CHANGE PASSWORD';
  @override
  String changePasswordDescription(String email) => 'To change your password, we need to verify your identity. We will send a verification code to $email';
  @override
  String get sendVerificationCode => 'SEND VERIFICATION CODE';
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
  String get videos => 'Practice Listening';
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
  @override
  String get videoPracticeTitle => 'Video Practice';
  @override
  String get overallProgress => 'Overall Progress';
  @override
  String get lessonPlaylist => 'Lesson Playlist';
  @override
  String get noVideosYet => 'No Videos Yet';
  @override
  String get videosComingSoon => 'Practice videos will appear here.\nCheck back soon for new content!';
  @override
  String get videoLockedTitle => 'Video Locked';
  @override
  String get completePreviousVideoToUnlock => 'Please watch the previous video first to unlock this one.';
  @override
  String get aboutThisLesson => 'About this lesson';
  @override
  String get watchFullVideoToUnlock => 'Watch the entire video to unlock the next lesson and earn points!';
  
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
  // Teacher detail/profile
  @override
  String get teacherNotFoundTitle => 'Teacher Not Found';
  @override
  String get teacherNotFoundMessage => 'The teacher you are looking for does not exist';
  @override
  String get alreadySubscribedMessage => 'You already have an active subscription with this teacher';
  @override
  String get needSubscriptionToChat => 'You need to subscribe to chat with this teacher';
  @override
  String get availableSchedulesTitle => 'AVAILABLE SCHEDULES';
  @override
  String get noScheduleAvailable => 'No schedule available';
  @override
  String get ratingsAndReviewsTitle => 'Ratings & Reviews';
  @override
  String get noReviewsYet => 'No reviews yet';
  @override
  String get rateButton => 'Rate';
  @override
  String get updateRatingButton => 'Update';
  
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
   @override
  String get beFirstInYourLanguage => 'Be the first in your language!';
  @override
  String get enrollToSeeOtherStudents => 'You need to enroll in a course to see other students';
  
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
  // Subscription & vouchers
  @override
  String get noPackagesAvailable => 'No packages available';
  @override
  String teacherNeedsDaysAvailable(int days) =>
      'Teacher needs at least $days days available for this package.';
  @override
  String get selectDays => 'Select Days';
  @override
  String get selectTime => 'Select Time';
  @override
  String get noCommonTimeSlots =>
      'No common time slots available for the selected days. Please select different days.';
  @override
  String get selectedPackageLabel => 'Selected Package';
  @override
  String selectedDaysLabel(int days) => 'Selected Days ($days days)';
  @override
  String get change => 'Change';
  @override
  String get yourSchedule => 'Your Schedule';
  @override
  String voucherCodeMustBeLength(int length) =>
      'Voucher code must be $length characters';
  @override
  String get voucherCodeValidForPackage =>
      'Make sure the voucher code is valid for the selected package.';
  @override
  String subscriptionActivatedSessions(int sessions) =>
      'Subscription activated! You have $sessions sessions.';
  @override
  String get redeemingVoucher => 'Redeeming...';
  @override
  String get stepPackage => 'Package';
  @override
  String get stepDays => 'Days';
  @override
  String get stepTime => 'Time';
  @override
  String get perMonth => '/month';
  @override
  String get subscribeTo => 'Subscribe to';
  
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
  @override
  String get allNotificationsMarkedRead => 'All notifications marked as read';
  @override
  String get clearAllNotificationsTitle => 'Clear All Notifications';
  @override
  String get clearAllNotificationsMessage => 'Are you sure you want to clear all notifications? This action cannot be undone.';
  @override
  String get clearAllButton => 'Clear All';
  @override
  String notificationsCleared(int count) => '$count notification${count == 1 ? '' : 's'} cleared';
  @override
  String get readAll => 'Read all';
  @override
  String get clear => 'Clear';
  @override
  String get youreAllCaughtUp => "You're all caught up!";
  
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
  @override
  String get mon => 'Mon';
  @override
  String get tue => 'Tue';
  @override
  String get wed => 'Wed';
  @override
  String get thu => 'Thu';
  @override
  String get fri => 'Fri';
  @override
  String get sat => 'Sat';
  @override
  String get sun => 'Sun';
  
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
  
  // Quiz Practice
  @override
  String get languageQuiz => 'Take a Quiz';
  @override
  String get yourStatistics => 'Your Statistics';
  @override
  String get quizzes => 'Quizzes';
  @override
  String get points => 'Points';
  @override
  String get recentQuizzes => 'Recent Quizzes';
  @override
  String get proSubscriptionRequired => 'PRO Subscription Required';
  @override
  String get languageQuizProOnly => 'Language Quiz is available for PRO members only.';
  @override
  String get goBack => 'Go Back';
  @override
  String get levelElementary => 'Elementary';
  @override
  String get levelPreIntermediate => 'Pre-Intermediate';
  @override
  String get levelUpperIntermediate => 'Upper-Intermediate';
  @override
  String get startNewQuiz => 'START NEW QUIZ';
  @override
  String get questionNumber => 'Question';
  @override
  String get exitQuiz => 'Exit Quiz?';
  @override
  String get exitQuizMessage => 'Your progress will be lost. Are you sure?';
  @override
  String get exit => 'Exit';
  @override
  String get quizComplete => 'Quiz Complete!';
  @override
  String get score => 'Score';
  @override
  String get reviewAnswers => 'Review Answers';
  @override
  String get back => 'BACK';
  @override
  String get retryQuiz => 'RETRY QUIZ';
  @override
  String get totalQuestions => 'Total Questions';
  @override
  String get timePerQuestion => 'Time per Question';
  @override
  String get pointsAvailable => 'Points Available';
  @override
  String get quizInstructions => 'Answer each question within 15 seconds. Questions auto-advance when time runs out!';
  @override
  String get startQuiz => 'START QUIZ';
  @override
  String get correct => 'Correct! ✓';
  @override
  String get yourAnswer => 'Your answer:';
  @override
  String get noAnswerTimeout => 'No answer (timeout)';
  @override
  String get correctAnswer => 'Correct:';
  @override
  String get failedToGenerateQuiz => 'Failed to generate quiz. Please try again.';
  @override
  String get pleaseTryAgain => 'Please try again';
  @override
  String get hoursAgo => 'h ago';
  
  // AI Voice Practice
  @override
  String get aiVoicePractice => 'Practice Speaking';
  @override
  String get voiceSettings => 'Voice Settings';
  @override
  String get voice => 'Voice';
  @override
  String get speed => 'Speed';
  @override
  String get start => 'Start';
  @override
  String get stop => 'Stop';
  @override
  String get sessionNumber => 'Session';
  @override
  String get timesUp => 'Time\'s Up!';
  @override
  String get sessionEndedMessage => 'Your {minutes}-minute session has ended. Great job practicing!';
  @override
  String get gotIt => 'Got it';
  @override
  String get greatJob => 'Great Job!';
  @override
  String get practicedForMinutes => 'You practiced for {minutes} minute{plural}!';
  @override
  String get sessionsRemaining => 'Sessions remaining:';
  @override
  String get awesome => 'Awesome!';
  @override
  String get sessionLimitReached => 'Session Limit Reached';
  @override
  String get notConnected => 'Not connected';
  @override
  String get preparingVoiceSession => '⏳ Preparing voice session...';
  @override
  String get listening => '🎙️ Listening...';
  @override
  String get pleaseLoginToUseAI => 'Please log in to use AI Voice Practice';
  @override
  String get microphonePermissionRequired => 'Microphone permission required';
  @override
  String get failedToStartSession => 'Failed to start session';
  @override
  String get connectionError => 'Connection error:';
  @override
  String get recorderPermissionDenied => 'Recorder permission denied';
  @override
  String get failedToStart => 'Failed to start:';
  @override
  String get proFeaturesActiveOnAnotherDevice => '⚠️ Pro features are active on another device. Activate in Profile to use.';
  @override
  String get activateInProfile => 'Activate in Profile';
  
  // Reading
  @override
  String get readings => 'Practice Reading';
  @override
  String get yourProgress => 'Your Progress';
  @override
  String get completed => 'Completed';
  @override
  String get allReadings => 'All Readings';
  @override
  String get completePreviousToUnlock => 'Complete previous reading to unlock';
  @override
  String get noReadingsAvailable => 'No readings available';
  @override
  String get checkBackLater => 'Check back later for new reading content';
  @override
  String get completePreviousReading => 'Complete the previous reading to unlock this one';
  @override
  String get errorLoadingReadings => 'Error loading readings:';
  @override
  String get errorLoadingQuestions => 'Error loading questions:';
  @override
  String get readingProgress => 'Your Progress';
  @override
  String get completedReadings => 'Completed';
  @override
  String get totalReadings => 'Total';
  @override
  String get percentComplete => 'Complete';
  
  // OTP Verification
  @override
  String get verificationCode => 'VERIFICATION CODE';
  @override
  String get otpSentToEmail => 'A verification code was sent to your MAIL enter the code to verify your account';
  @override
  String get otpSentToEmailPasswordReset => 'A verification code was sent to your MAIL enter the code to be able to change the password';
  @override
  String get confirm => 'CONFIRM';
  @override
  String get resend => 'RESEND';
  @override
  String get resendWithTimer => 'RESEND ({time})';
  @override
  String get codeResentSuccessfully => 'Code resent successfully';
  @override
  String get failedToResendCode => 'Failed to resend code:';
  @override
  String get enterCompleteCode => 'Please enter the complete verification code';
  @override
  String get verificationFailed => 'Verification failed:';
  
  // Chat
  @override
  String get today => 'Today';
  @override
  String get yesterday => 'Yesterday';
  @override
  String get blockUser => 'Block User';
  @override
  String get tapToRetry => 'Tap to retry';
  @override
  String get failedToLoadImage => 'Failed to load image';
  @override
  String get couldNotPlayAudio => 'Could not play audio';
  @override
  String get downloading => 'Downloading';
  @override
  String get downloadedTo => 'Downloaded to:';
  @override
  String get downloadFailed => 'Download failed:';
  @override
  String get failedToSendMessage => 'Failed to send message';
  @override
  String get errorSendingMessage => 'Error sending message:';
  @override
  String get failedToCaptureImage => 'Failed to capture image:';
  @override
  String get failedToPickImage => 'Failed to pick image:';
  @override
  String get failedToStartRecording => 'Failed to start recording. Please check microphone permissions.';
  @override
  String get checkMicrophonePermissions => 'Please check microphone permissions';
  @override
  String get failedToSendVoiceMessage => 'Failed to send voice message';
  @override
  String get errorSendingVoiceMessage => 'Error sending voice message:';
  
  // Common additional
  @override
  String get level => 'Level';
  @override
  String get pts => 'pts';
  @override
  String get session => 'Session';
  @override
  String get sessions => 'Sessions';
  @override
  String get minute => 'minute';
  @override
  String get minutesPlural => 'minutes';
  @override
  String get loginRequired => 'Please log in to access quiz practice';
  
  // Chat additional
  @override
  String get chatDeletedSuccessfully => 'Chat deleted successfully';
  @override
  String get failedToDeleteChat => 'Failed to delete chat. Please try again.';
  @override
  String get messageUnsent => 'Message unsent';
  @override
  String get downloadedToUnableToOpen => 'Downloaded to: {filePath}\nUnable to open file: {message}';
  
  // Profile additional
  @override
  String get activateOnThisDevice => 'Activate on This Device';
  @override
  String get blockedUsers => 'Blocked Users';
  @override
  String get manageBlockedUsers => 'Manage your blocked users';
  @override
  String get studentPlaceholder => 'Student';
  @override
  String get editProfileButton => 'Edit Profile';
  @override
  String get proActiveOnAnotherDevice => 'Pro active on another device';
  @override
  String get proSubscriptionActiveMessage => 'Your PRO subscription is currently active on another device. Activate it here to use PRO features.';
  @override
  String get proFeaturesActivated => '✅ PRO features activated on this device!';
  @override
  String get failedToActivate => '❌ Failed to activate';
  @override
  String get errorActivation => '❌ Error';
  @override
  String get unknownError => 'Unknown error';
  @override
  String get logoutFailed => 'Logout failed';
  
  // Classes additional
  @override
  String get errorLoadingSessions => 'Error loading sessions:';
  @override
  String get errorJoiningSession => 'Error joining session:';
  @override
  String get teacherInformationNotAvailable => 'Teacher information not available';
  @override
  String get unableToStartChat => 'Unable to start chat. Please try again.';
  @override
  String get errorOpeningChat => 'Error opening chat:';
  @override
  String get unableToLoadTeacherDetails => 'Unable to load teacher details';
  @override
  String get myClasses => 'MY CLASSES';
  @override
  String get noUpcomingClasses => 'No upcoming classes';
  @override
  String get noFinishedClasses => 'No finished classes';
  @override
  String get subscribeToSeeClasses => 'Subscribe to a teacher to see your classes here';
  @override
  String get pullDownToRefresh => 'Pull down to refresh';
  @override
  String get makeupClass => 'MAKEUP CLASS';
  @override
  String get cancelled => 'CANCELLED';
  @override
  String get extraClass => 'EXTRA CLASS';
  @override
  String get liveNow => 'LIVE NOW';
  @override
  String get languageClass => 'Class';
  @override
  String get teacherNamePlaceholder => 'Teacher';
  @override
  String get yourTime => 'Your time';
  @override
  String get classDuration => 'Class Duration';
  @override
  String get join => 'JOIN';
  @override
  String get waitingForMeetingLink => 'Waiting for meeting link';
  @override
  String get waitingForTeacherToStart => 'Waiting for teacher to start';
  @override
  String get startsIn => 'Starts in';
  @override
  String get classWasCancelled => 'This class was cancelled';
  @override
  String get tapToViewTeacherAndRate => 'Tap to view teacher & rate';
  @override
  String get min => 'min';
  
  // Quiz additional
  @override
  String get questionCounter => 'Question {current}/{total}';
  @override
  String get accuracyPercentage => '{accuracy}% Accuracy';
  @override
  String get correctCheck => 'Correct! ✓';
  @override
  String get answerEachQuestionWithinSeconds => 'Answer each question within 15 seconds. Questions auto-advance when time runs out!';
  @override
  String get questionsAutoAdvance => 'Questions auto-advance when time runs out!';
  @override
  String get yourProgressWillBeLost => 'Your progress will be lost. Are you sure?';
  @override
  String get sec => 'sec';
  @override
  String get ten => '10';
  @override
  String get fifteenSec => '15 sec';
  @override
  String get loginRequiredQuizPractice => 'Please log in to access quiz practice';
  
  // Profile/Edit Profile
  @override
  String get editProfileTitle => 'EDIT PROFILE';
  @override
  String get photoAddedSuccessfully => 'Photo added successfully!';
  @override
  String get failedToUploadPhoto => 'Failed to upload photo:';
  @override
  String get mainPhotoUpdated => 'Main photo updated!';
  @override
  String get failedToSetMainPhoto => 'Failed to set main photo:';
  @override
  String get photoDeleted => 'Photo deleted!';
  @override
  String get failedToDeletePhoto => 'Failed to delete photo:';
  @override
  String get profileUpdatedSuccessfully => 'Profile updated successfully!';
  @override
  String get failedToUpdateProfile => 'Failed to update profile:';
  @override
  String get pleaseEnterYourName => 'Please enter your name';
  @override
  String get tellUsAboutYourself => 'Tell us about yourself...';
  
  // Blocked Users
  @override
  String get blockedUsersTitle => 'BLOCKED USERS';
  @override
  String get unblockUser => 'Unblock User';
  @override
  String get unblockUserConfirm => 'Unblock';
  @override
  String get unblockUserMessage => 'Are you sure you want to unblock {name}? You will be able to see each other again.';
  @override
  String get noBlockedUsers => 'No Blocked Users';
  @override
  String get noBlockedUsersMessage => 'You haven\'t blocked anyone yet';
  @override
  String get failedToLoadBlockedUsers => 'Failed to load blocked users:';
  @override
  String get userHasBeenUnblocked => '{name} has been unblocked';
  @override
  String get failedToUnblockUser => 'Failed to unblock user';
  @override
  String get blockUserMessage => 'Blocking this user will hide their profile and prevent them from contacting you.';
  @override
  String get userBlocked => 'User blocked';
  
  // Search/Input hints
  @override
  String get searchMessages => 'Search messages...';
  @override
  String get messageHint => 'Message';
  
  // Chat errors
  @override
  String get failedToUnsendMessage => 'Failed to unsend message. Please try again.';
  @override
  String get failedToBlockUserTryAgain => 'Failed to block user. Please try again.';
  
  // Chat list screen
  @override
  String get messagesTitle => 'MESSAGES';
  @override
  String get showConversations => 'Show Conversations';
  @override
  String get startNewChat => 'Start New Chat';
  @override
  String get requestAccepted => 'Request accepted!';
  @override
  String get failedToAcceptRequest => 'Failed to accept request';
  @override
  String get requestRejected => 'Request rejected';
  @override
  String get failedToRejectRequest => 'Failed to reject request';
  @override
  String get justNow => 'just now';
  @override
  String minutesAgo(int minutes) => '${minutes}m ago';
  @override
  String get oneDayAgo => '1d ago';
  @override
  String daysAgo(int days) => '${days}d ago';
  @override
  String get noResultsFound => 'No results found';
  @override
  String get noMessagesYet => 'No messages yet';
  @override
  String get tryDifferentKeywords => 'Try searching with different keywords';
  @override
  String get startConversationWithTeachers => 'Start a conversation with your teachers';
  @override
  String get chatRequestTitle => 'Chat Request';
  @override
  String get noMessageProvided => 'No message provided';
  @override
  String get sentChatRequest => 'Sent a chat request';
  @override
  String get chatRequestsReceived => 'Received';
  @override
  String get chatRequestsSent => 'Sent';
  @override
  String get chatRequestPendingStatus => 'Pending';
  @override
  String get deleteChat => 'Delete Chat';
  @override
  String get deleteChatQuestion => 'Delete Chat?';
  @override
  String deleteChatConfirmation(String name) => 'Are you sure you want to delete this chat with $name? This action cannot be undone.';
  @override
  String get noTeachersAvailable => 'No teachers available';
  @override
  String get subscribeToChatWithTeachers => 'Subscribe to a course to chat with teachers';
  @override
  String get imageAttachment => '🖼️ Image';
  @override
  String get voiceMessage => '🎤 Voice message';
  @override
  String get fileAttachment => '📎 File';
  @override
  String get attachmentGeneric => '📎 Attachment';
  @override
  String get startChatting => 'Start chatting...';
  @override
  String get user => 'User';
}

