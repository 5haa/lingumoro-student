import 'app_localizations.dart';

class AppLocalizationsAr extends AppLocalizations {
  // Common
  @override
  String get appName => 'لينجومورو';
  @override
  String get ok => 'حسناً';
  @override
  String get cancel => 'إلغاء';
  @override
  String get yes => 'نعم';
  @override
  String get no => 'لا';
  @override
  String get error => 'خطأ';
  @override
  String get success => 'نجح';
  @override
  String get loading => 'جاري التحميل...';
  @override
  String get retry => 'إعادة المحاولة';
  @override
  String get save => 'حفظ';
  @override
  String get delete => 'حذف';
  @override
  String get edit => 'تعديل';
  @override
  String get search => 'بحث';
  @override
  String get filter => 'تصفية';
  @override
  String get close => 'إغلاق';
  @override
  String get next => 'التالي';
  @override
  String get previous => 'السابق';
  @override
  String get done => 'تم';
  @override
  String get skip => 'تخطي';
  @override
  String get and => 'و';
  @override
  String get or => 'أو';
  
  // Navigation
  @override
  String get navHome => 'الرئيسية';
  @override
  String get navClasses => 'الفصول';
  @override
  String get navPractice => 'التمرين';
  @override
  String get navChat => 'المحادثة';
  @override
  String get navProfile => 'الملف الشخصي';
  
  // Drawer/Settings
  @override
  String get settings => 'الإعدادات';
  @override
  String get contactUs => 'اتصل بنا';
  @override
  String get aboutUs => 'من نحن';
  @override
  String get privacyPolicy => 'سياسة الخصوصية';
  @override
  String get termsConditions => 'الشروط والأحكام';
  @override
  String get changeLanguage => 'تغيير اللغة';
  @override
  String get selectLanguage => 'اختر اللغة';
  @override
  String get languageChanged => 'تم تغيير اللغة إلى العربية';
  @override
  String get version => 'الإصدار 1.0.0';
  
  // Auth
  @override
  String get login => 'تسجيل الدخول';
  @override
  String get signup => 'إنشاء حساب';
  @override
  String get logout => 'تسجيل الخروج';
  @override
  String get email => 'البريد الإلكتروني';
  @override
  String get password => 'كلمة المرور';
  @override
  String get confirmPassword => 'تأكيد كلمة المرور';
  @override
  String get fullName => 'الاسم الكامل';
  @override
  String get forgotPassword => 'نسيت كلمة المرور؟';
  @override
  String get forgotPasswordTitle => 'نسيت كلمة المرور';
  @override
  String get forgotPasswordDescription => 'أدخل عنوان بريدك الإلكتروني وسنرسل لك رمز التحقق لإعادة تعيين كلمة المرور';
  @override
  String get pleaseEnterYourEmail => 'الرجاء إدخال بريدك الإلكتروني';
  @override
  String get verificationCodeSentToEmail => 'تم إرسال رمز التحقق إلى بريدك الإلكتروني';
  @override
  String get failedToSendCode => 'فشل إرسال الرمز';
  @override
  String get sendCode => 'إرسال الرمز';
  @override
  String get resetPassword => 'إعادة تعيين كلمة المرور';
  @override
  String get resetPasswordTitle => 'إعادة تعيين كلمة المرور';
  @override
  String get resetPasswordDescription => 'أدخل كلمة المرور الجديدة أدناه';
  @override
  String get enterNewPasswordBelow => 'أدخل كلمة المرور الجديدة أدناه';
  @override
  String get newPassword => 'كلمة المرور الجديدة';
  @override
  String get confirmNewPassword => 'تأكيد كلمة المرور الجديدة';
  @override
  String get passwordResetSuccessfully => 'تم إعادة تعيين كلمة المرور بنجاح!';
  @override
  String get failedToResetPassword => 'فشل إعادة تعيين كلمة المرور';
  @override
  String get userNotLoggedIn => 'المستخدم غير مسجل الدخول';
  @override
  String get dontHaveAccount => 'ليس لديك حساب؟';
  @override
  String get alreadyHaveAccount => 'لديك حساب بالفعل؟';
  @override
  String get enterEmail => 'أدخل بريدك الإلكتروني';
  @override
  String get enterPassword => 'أدخل كلمة المرور';
  @override
  String get enterFullName => 'أدخل اسمك الكامل';
  @override
  String get passwordMismatch => 'كلمات المرور غير متطابقة';
  @override
  String get emailRequired => 'البريد الإلكتروني مطلوب';
  @override
  String get passwordRequired => 'كلمة المرور مطلوبة';
  @override
  String get fullNameRequired => 'الاسم الكامل مطلوب';
  @override
  String get invalidEmail => 'عنوان البريد الإلكتروني غير صالح';
  @override
  String get passwordTooShort => 'يجب أن تكون كلمة المرور 6 أحرف على الأقل';
  @override
  String get loginSuccess => 'تم تسجيل الدخول بنجاح';
  @override
  String get loginFailed => 'فشل تسجيل الدخول';
  @override
  String get signupSuccess => 'تم إنشاء الحساب بنجاح';
  @override
  String get signupFailed => 'فشل إنشاء الحساب';
  @override
  String get logoutConfirm => 'تسجيل الخروج';
  @override
  String get areYouSureLogout => 'هل أنت متأكد من تسجيل الخروج؟';
  @override
  String get phoneNumber => 'رقم الهاتف';
  @override
  String get enterPhoneNumber => 'أدخل رقم هاتفك';
  @override
  String get phoneNumberRequired => 'رقم الهاتف مطلوب';
  @override
  String get bio => 'نبذة عني';
  @override
  String get enterBio => 'أخبرنا عن نفسك';
  @override
  String get createAccount => 'إنشاء حساب';
  @override
  String get welcomeBack => 'مرحباً بعودتك';
  @override
  String get getStarted => 'ابدأ الآن';
  
  // Home
  @override
  String get chooseYourClass => 'اختر صفك';
  @override
  String get students => 'الطلاب';
  @override
  String get teachers => 'المعلمون';
  @override
  String get noLanguagesAvailable => 'لا توجد لغات متاحة';
  @override
  String get selectLanguageFirst => 'الرجاء اختيار لغة أولاً';
  @override
  String get comingSoon => 'قريباً';
  
  // Profile
  @override
  String get profile => 'الملف الشخصي';
  @override
  String get editProfile => 'تعديل الملف الشخصي';
  @override
  String get personalInformation => 'المعلومات الشخصية';
  @override
  String get security => 'الأمان';
  @override
  String get changePassword => 'تغيير كلمة المرور';
  @override
  String get changePasswordTitle => 'تغيير كلمة المرور';
  @override
  String changePasswordDescription(String email) => 'لتغيير كلمة المرور، نحتاج للتحقق من هويتك. سنرسل رمز التحقق إلى $email';
  @override
  String get sendVerificationCode => 'إرسال رمز التحقق';
  @override
  String get updatePassword => 'تحديث كلمة المرور';
  @override
  String get currentLevel => 'المستوى الحالي';
  @override
  String get proMember => 'عضو محترف';
  @override
  String get freeMember => 'عضو مجاني';
  @override
  String get upgrade => 'ترقية';
  @override
  String get upgradeToPro => 'الترقية إلى محترف';
  @override
  String get redeemVoucher => 'استخدم رمز القسيمة';
  @override
  String get voucherCode => 'رمز القسيمة';
  @override
  String get enterCodeHere => 'أدخل الرمز هنا';
  @override
  String get redeem => 'استخدام';
  @override
  String get proBenefits => 'مزايا العضوية المحترفة';
  @override
  String get unlimitedAccess => 'وصول غير محدود';
  @override
  String get unlimitedAccessDesc => 'الوصول إلى جميع الميزات دون قيود';
  @override
  String get connectWithStudents => 'تواصل مع الطلاب';
  @override
  String get connectWithStudentsDesc => 'تحدث وتواصل مع متعلمي اللغات الآخرين';
  @override
  String get practiceWithAI => 'تمرن مع الذكاء الاصطناعي';
  @override
  String get practiceWithAIDesc => 'جلسات تمرين لغوي تفاعلية بالذكاء الاصطناعي';
  @override
  String get enterVoucherCode => 'الرجاء إدخال رمز القسيمة';
  @override
  String get voucherRedeemed => 'تم تفعيل الاشتراك المحترف!';
  @override
  String get voucherRedeemedDesc => 'أيام مضافة';
  @override
  String get invalidVoucher => 'رمز القسيمة غير صالح';
  @override
  String get expiresPro => 'تنتهي في';
  @override
  String get unlimitedFeatures => 'وصول غير محدود لجميع الميزات';
  @override
  String get limitedFeatures => 'ميزات محدودة متاحة';
  @override
  String get languageLearner => 'متعلم لغة';
  @override
  String get xpPoints => 'نقطة خبرة';
  @override
  String get xpToNextLevel => 'نقطة خبرة للمستوى';
  @override
  String get maxLevelReached => 'تم الوصول للمستوى الأقصى!';
  
  // Level statuses
  @override
  String get levelBeginner => 'مبتدئ';
  @override
  String get levelIntermediate => 'متوسط';
  @override
  String get levelAdvanced => 'متقدم';
  @override
  String get levelExpert => 'خبير';
  @override
  String get levelMaster => 'ماهر';
  @override
  String get levelGrandMaster => 'ماهر كبير';
  @override
  String get levelLegend => 'أسطوري';
  @override
  String get levelMythic => 'خرافي';
  @override
  String get levelTranscendent => 'متسامي';
  @override
  String get levelSupreme => 'أعلى';
  
  // Classes
  @override
  String get classes => 'الفصول';
  @override
  String get upcoming => 'القادمة';
  @override
  String get finished => 'المنتهية';
  @override
  String get joinSession => 'انضم للجلسة';
  @override
  String get sessionDetails => 'تفاصيل الجلسة';
  @override
  String get meetingLinkNotAvailable => 'رابط الاجتماع غير متاح حالياً. الرجاء الانتظار حتى يقوم المعلم بإعداده.';
  @override
  String get waitForTeacher => 'انتظر المعلم';
  @override
  String get noUpcomingSessions => 'لا توجد جلسات قادمة';
  @override
  String get noFinishedSessions => 'لا توجد جلسات منتهية';
  @override
  String get sessionWith => 'جلسة مع';
  @override
  String get packageType => 'الباقة';
  @override
  String get date => 'التاريخ';
  @override
  String get time => 'الوقت';
  @override
  String get duration => 'المدة';
  @override
  String get minutes => 'دقيقة';
  
  // Practice
  @override
  String get practice => 'التمرين';
  @override
  String get videos => 'تمرين الاستماع';
  @override
  String get quizPractice => 'تمرين الاختبار';
  @override
  String get reading => 'القراءة';
  @override
  String get aiVoice => 'الصوت الذكي';
  @override
  String get watchedVideos => 'المشاهدة';
  @override
  String get totalVideos => 'الإجمالي';
  @override
  String get questionsAnswered => 'الأسئلة';
  @override
  String get accuracy => 'الدقة';
  @override
  String get storiesGenerated => 'المولدة';
  @override
  String get storiesRemaining => 'المتبقية';
  @override
  String get startPractice => 'ابدأ التمرين';
  @override
  String get continueWatching => 'متابعة المشاهدة';
  @override
  String get markAsWatched => 'وضع علامة كمشاهد';
  @override
  String get completedVideos => 'مكتمل';
  @override
  String get noPracticeAvailable => 'لا يوجد تمرين متاح';
  @override
  String get proFeature => 'ميزة محترفة';
  @override
  String get upgradeToAccess => 'قم بالترقية للوصول إلى هذه الميزة';
  @override
  String get videoPracticeTitle => 'تمرين الفيديو';
  @override
  String get overallProgress => 'التقدم الكلي';
  @override
  String get lessonPlaylist => 'قائمة الدروس';
  @override
  String get noVideosYet => 'لا توجد فيديوهات بعد';
  @override
  String get videosComingSoon => 'ستظهر فيديوهات التمرين هنا.\nتحقق مرة أخرى قريباً لمحتوى جديد!';
  @override
  String get videoLockedTitle => 'الفيديو مقفل';
  @override
  String get completePreviousVideoToUnlock => 'يرجى مشاهدة الفيديو السابق أولاً لفتح هذا الفيديو.';
  @override
  String get aboutThisLesson => 'حول هذا الدرس';
  @override
  String get watchFullVideoToUnlock => 'شاهد الفيديو بالكامل لفتح الدرس التالي والحصول على النقاط!';
  
  // Chat
  @override
  String get chat => 'المحادثة';
  @override
  String get messages => 'الرسائل';
  @override
  String get online => 'متصل';
  @override
  String get offline => 'غير متصل';
  @override
  String get typing => 'يكتب...';
  @override
  String get typeMessage => 'اكتب رسالة';
  @override
  String get sendMessage => 'إرسال';
  @override
  String get noMessages => 'لا توجد رسائل بعد';
  @override
  String get startConversation => 'ابدأ محادثة';
  @override
  String get tapToOpenChat => 'اضغط لفتح المحادثة';
  @override
  String get startToSeeConversation => 'ابدأ التحدث لرؤية المحادثة';
  @override
  String get chatRequests => 'طلبات المحادثة';
  @override
  String get noChatRequests => 'لا توجد طلبات محادثة';
  @override
  String get accept => 'قبول';
  @override
  String get decline => 'رفض';
  @override
  String get blocked => 'محظور';
  @override
  String get unblock => 'إلغاء الحظر';
  @override
  String get block => 'حظر';
  @override
  String get report => 'إبلاغ';
  
  // Teachers
  @override
  String get teachersList => 'المعلمون';
  @override
  String get noTeachersForLanguage => 'لم يتم العثور على معلمين لـ';
  @override
  String get selectPackage => 'اختر الباقة';
  @override
  String get selectDayTime => 'اختر اليوم والوقت';
  @override
  String get bookSession => 'احجز جلسة';
  @override
  String get sessionBooked => 'تم حجز الجلسة بنجاح';
  @override
  String get bookingFailed => 'فشل الحجز';
  @override
  String get availableSlots => 'الأوقات المتاحة';
  @override
  String get noAvailableSlots => 'لا توجد أوقات متاحة';
  @override
  String get selectTimeSlot => 'اختر وقتاً';
  @override
  String get teacherDetails => 'تفاصيل المعلم';
  @override
  String get rating => 'التقييم';
  @override
  String get reviews => 'المراجعات';
  @override
  String get about => 'نبذة';
  @override
  String get experience => 'الخبرة';
  @override
  String get languages => 'اللغات';
  @override
  String get hourlyRate => 'السعر بالساعة';
  @override
  String get perSession => 'لكل جلسة';
  // Teacher detail/profile
  @override
  String get teacherNotFoundTitle => 'المعلم غير موجود';
  @override
  String get teacherNotFoundMessage => 'المعلم الذي تبحث عنه غير موجود';
  @override
  String get alreadySubscribedMessage => 'لديك بالفعل اشتراك نشط مع هذا المعلم';
  @override
  String get needSubscriptionToChat => 'تحتاج إلى الاشتراك للتحدث مع هذا المعلم';
  @override
  String get availableSchedulesTitle => 'الجداول المتاحة';
  @override
  String get noScheduleAvailable => 'لا توجد جداول متاحة';
  @override
  String get ratingsAndReviewsTitle => 'التقييمات والمراجعات';
  @override
  String get noReviewsYet => 'لا توجد مراجعات بعد';
  @override
  String get rateButton => 'قيّم';
  @override
  String get updateRatingButton => 'تحديث';
  
  // Students
  @override
  String get studentsList => 'الطلاب';
  @override
  String get noStudentsFound => 'لم يتم العثور على طلاب';
  @override
  String get sendChatRequest => 'إرسال طلب محادثة';
  @override
  String get chatRequestSent => 'تم إرسال طلب المحادثة';
  @override
  String get alreadyChatting => 'محادثة جارية بالفعل';
  @override
  String get beFirstInYourLanguage => 'كن الأول في لغتك!';
  @override
  String get enrollToSeeOtherStudents => 'تحتاج إلى التسجيل في دورة لرؤية الطلاب الآخرين';
  
  // Packages
  @override
  String get packages => 'الباقات';
  @override
  String get selectYourPackage => 'اختر باقتك';
  @override
  String get packageDetails => 'تفاصيل الباقة';
  @override
  String get sessionsPerWeek => 'جلسات في الأسبوع';
  @override
  String get totalSessions => 'إجمالي الجلسات';
  @override
  String get price => 'السعر';
  @override
  String get subscribe => 'اشترك';
  @override
  String get subscriptionActive => 'الاشتراك نشط';
  @override
  String get subscriptionExpired => 'انتهى الاشتراك';
  // Subscription & vouchers
  @override
  String get noPackagesAvailable => 'لا توجد باقات متاحة';
  @override
  String teacherNeedsDaysAvailable(int days) =>
      'يحتاج المعلم إلى ما لا يقل عن $days أيام متاحة لهذه الباقة.';
  @override
  String get selectDays => 'اختر الأيام';
  @override
  String get selectTime => 'اختر الوقت';
  @override
  String get noCommonTimeSlots =>
      'لا توجد أوقات مشتركة متاحة للأيام المحددة. الرجاء اختيار أيام أخرى.';
  @override
  String get selectedPackageLabel => 'الباقة المحددة';
  @override
  String selectedDaysLabel(int days) => 'الأيام المحددة ($days أيام)';
  @override
  String get change => 'تغيير';
  @override
  String get yourSchedule => 'جدولك';
  @override
  String voucherCodeMustBeLength(int length) =>
      'يجب أن يتكون رمز القسيمة من $length حرفاً';
  @override
  String get voucherCodeValidForPackage =>
      'تأكد من أن رمز القسيمة صالح للباقة المحددة.';
  @override
  String subscriptionActivatedSessions(int sessions) =>
      'تم تفعيل الاشتراك! لديك $sessions جلسة.';
  @override
  String get redeemingVoucher => 'جارٍ استرداد القسيمة...';
  @override
  String get stepPackage => 'الباقة';
  @override
  String get stepDays => 'الأيام';
  @override
  String get stepTime => 'الوقت';
  @override
  String get perMonth => '/الشهر';
  @override
  String get subscribeTo => 'اشترك مع';
  
  // Notifications
  @override
  String get notifications => 'الإشعارات';
  @override
  String get notificationSettings => 'إعدادات الإشعارات';
  @override
  String get noNotifications => 'لا توجد إشعارات';
  @override
  String get markAllRead => 'وضع علامة كمقروء للكل';
  @override
  String get enableNotifications => 'تفعيل الإشعارات';
  @override
  String get sessionReminders => 'تذكيرات الجلسة';
  @override
  String get chatMessages => 'رسائل المحادثة';
  @override
  String get practiceReminders => 'تذكيرات التمرين';
  @override
  String get allNotificationsMarkedRead => 'تم وضع علامة مقروء على جميع الإشعارات';
  @override
  String get clearAllNotificationsTitle => 'مسح جميع الإشعارات';
  @override
  String get clearAllNotificationsMessage => 'هل أنت متأكد من مسح جميع الإشعارات؟ لا يمكن التراجع عن هذا الإجراء.';
  @override
  String get clearAllButton => 'مسح الكل';
  @override
  String notificationsCleared(int count) => 'تم مسح $count من الإشعارات';
  @override
  String get readAll => 'قراءة الكل';
  @override
  String get clear => 'مسح';
  @override
  String get youreAllCaughtUp => 'لقد اطلعت على كل شيء!';
  
  // Days of week
  @override
  String get monday => 'الاثنين';
  @override
  String get tuesday => 'الثلاثاء';
  @override
  String get wednesday => 'الأربعاء';
  @override
  String get thursday => 'الخميس';
  @override
  String get friday => 'الجمعة';
  @override
  String get saturday => 'السبت';
  @override
  String get sunday => 'الأحد';
  @override
  String get mon => 'إثنين';
  @override
  String get tue => 'ثلاثاء';
  @override
  String get wed => 'أربعاء';
  @override
  String get thu => 'خميس';
  @override
  String get fri => 'جمعة';
  @override
  String get sat => 'سبت';
  @override
  String get sun => 'أحد';
  
  // Months
  @override
  String get january => 'يناير';
  @override
  String get february => 'فبراير';
  @override
  String get march => 'مارس';
  @override
  String get april => 'أبريل';
  @override
  String get may => 'مايو';
  @override
  String get june => 'يونيو';
  @override
  String get july => 'يوليو';
  @override
  String get august => 'أغسطس';
  @override
  String get september => 'سبتمبر';
  @override
  String get october => 'أكتوبر';
  @override
  String get november => 'نوفمبر';
  @override
  String get december => 'ديسمبر';
  
  // Error messages
  @override
  String get errorLoadingData => 'خطأ في تحميل البيانات';
  @override
  String get errorSavingData => 'خطأ في حفظ البيانات';
  @override
  String get errorNoInternet => 'لا يوجد اتصال بالإنترنت';
  @override
  String get errorTryAgain => 'الرجاء المحاولة مرة أخرى';
  @override
  String get errorUnknown => 'حدث خطأ غير معروف';
  
  // Success messages
  @override
  String get successSaved => 'تم الحفظ بنجاح';
  @override
  String get successUpdated => 'تم التحديث بنجاح';
  @override
  String get successDeleted => 'تم الحذف بنجاح';
  
  // Validation
  @override
  String get fieldRequired => 'هذا الحقل مطلوب';
  @override
  String get invalidInput => 'إدخال غير صالح';
  @override
  String get tooShort => 'قصير جداً';
  @override
  String get tooLong => 'طويل جداً';
  
  // Settings screens
  @override
  String get aboutUsContent => 'لينجومورو هي منصة لتعلم اللغات تربط الطلاب بالمعلمين.';
  @override
  String get privacyPolicyContent => 'خصوصيتك مهمة بالنسبة لنا. نحن نجمع بياناتك ونستخدمها لتقديم خدمات أفضل.';
  @override
  String get termsConditionsContent => 'باستخدام هذا التطبيق، فإنك توافق على شروطنا وأحكامنا.';
  
  // Contact
  @override
  String get couldNotOpenWhatsApp => 'تعذر فتح واتساب';
  @override
  String get errorOpeningWhatsApp => 'خطأ في فتح واتساب';
  
  // Province/City selection
  @override
  String get chooseCity => 'اختر المدينة';
  @override
  String get selectProvince => 'اختر المحافظة';
  @override
  String get searchProvince => 'ابحث عن محافظة...';
  @override
  String get pleaseSelectProvince => 'الرجاء اختيار محافظتك';
  @override
  String get fillAllFields => 'الرجاء ملء جميع الحقول المطلوبة';
  @override
  String get confirmAccount => 'تأكيد الحساب';
  
  // Mother Language selection
  @override
  String get selectMotherLanguage => 'اختر لغتك الأم';
  @override
  String get pleaseSelectMotherLanguage => 'الرجاء اختيار لغتك الأم';
  @override
  String get motherLanguage => 'اللغة الأم';
  
  // Quiz Practice
  @override
  String get languageQuiz => 'اختبار';
  @override
  String get yourStatistics => 'إحصائياتك';
  @override
  String get quizzes => 'الاختبارات';
  @override
  String get points => 'النقاط';
  @override
  String get recentQuizzes => 'الاختبارات الأخيرة';
  @override
  String get proSubscriptionRequired => 'الاشتراك المحترف مطلوب';
  @override
  String get languageQuizProOnly => 'اختبار اللغة متاح لأعضاء المحترفين فقط.';
  @override
  String get goBack => 'العودة';
  @override
  String get levelElementary => 'ابتدائي';
  @override
  String get levelPreIntermediate => 'ما قبل المتوسط';
  @override
  String get levelUpperIntermediate => 'فوق المتوسط';
  @override
  String get startNewQuiz => 'بدء اختبار جديد';
  @override
  String get questionNumber => 'السؤال';
  @override
  String get exitQuiz => 'الخروج من الاختبار؟';
  @override
  String get exitQuizMessage => 'سيتم فقدان تقدمك. هل أنت متأكد؟';
  @override
  String get exit => 'خروج';
  @override
  String get quizComplete => 'اكتمل الاختبار!';
  @override
  String get score => 'النتيجة';
  @override
  String get reviewAnswers => 'مراجعة الإجابات';
  @override
  String get back => 'رجوع';
  @override
  String get retryQuiz => 'إعادة الاختبار';
  @override
  String get totalQuestions => 'إجمالي الأسئلة';
  @override
  String get timePerQuestion => 'الوقت لكل سؤال';
  @override
  String get pointsAvailable => 'النقاط المتاحة';
  @override
  String get quizInstructions => 'أجب على كل سؤال خلال 15 ثانية. تنتقل الأسئلة تلقائياً عند انتهاء الوقت!';
  @override
  String get startQuiz => 'بدء الاختبار';
  @override
  String get correct => 'صحيح! ✓';
  @override
  String get yourAnswer => 'إجابتك:';
  @override
  String get noAnswerTimeout => 'لا توجد إجابة (انتهى الوقت)';
  @override
  String get correctAnswer => 'الصحيح:';
  @override
  String get failedToGenerateQuiz => 'فشل إنشاء الاختبار. الرجاء المحاولة مرة أخرى.';
  @override
  String get pleaseTryAgain => 'الرجاء المحاولة مرة أخرى';
  @override
  String get hoursAgo => 'ساعة مضت';
  
  // AI Voice Practice
  @override
  String get aiVoicePractice => 'تمرين التحدث';
  @override
  String get voiceSettings => 'إعدادات الصوت';
  @override
  String get voice => 'الصوت';
  @override
  String get speed => 'السرعة';
  @override
  String get start => 'بدء';
  @override
  String get stop => 'إيقاف';
  @override
  String get sessionNumber => 'الجلسة';
  @override
  String get timesUp => 'انتهى الوقت!';
  @override
  String get sessionEndedMessage => 'انتهت جلستك التي مدتها {minutes} دقيقة. عمل رائع!';
  @override
  String get gotIt => 'حسناً';
  @override
  String get greatJob => 'عمل رائع!';
  @override
  String get practicedForMinutes => 'لقد تمرنت لمدة {minutes} دقيقة{plural}!';
  @override
  String get sessionsRemaining => 'الجلسات المتبقية:';
  @override
  String get awesome => 'رائع!';
  @override
  String get sessionLimitReached => 'تم الوصول إلى حد الجلسات';
  @override
  String get notConnected => 'غير متصل';
  @override
  String get preparingVoiceSession => '⏳ جاري إعداد جلسة الصوت...';
  @override
  String get listening => '🎙️ جاري الاستماع...';
  @override
  String get pleaseLoginToUseAI => 'الرجاء تسجيل الدخول لاستخدام تمرين الصوت بالذكاء الاصطناعي';
  @override
  String get microphonePermissionRequired => 'إذن الميكروفون مطلوب';
  @override
  String get failedToStartSession => 'فشل بدء الجلسة';
  @override
  String get connectionError => 'خطأ في الاتصال:';
  @override
  String get recorderPermissionDenied => 'تم رفض إذن المسجل';
  @override
  String get failedToStart => 'فشل البدء:';
  @override
  String get proFeaturesActiveOnAnotherDevice => '⚠️ الميزات المحترفة نشطة على جهاز آخر. قم بالتفعيل في الملف الشخصي للاستخدام.';
  @override
  String get activateInProfile => 'التفعيل في الملف الشخصي';
  
  // Reading
  @override
  String get readings => 'تمرين القراءة';
  @override
  String get yourProgress => 'تقدمك';
  @override
  String get completed => 'مكتمل';
  @override
  String get allReadings => 'جميع القراءات';
  @override
  String get completePreviousToUnlock => 'أكمل القراءة السابقة لفتحها';
  @override
  String get noReadingsAvailable => 'لا توجد قراءات متاحة';
  @override
  String get checkBackLater => 'تحقق لاحقاً للحصول على محتوى قراءة جديد';
  @override
  String get completePreviousReading => 'أكمل القراءة السابقة لفتح هذه';
  @override
  String get errorLoadingReadings => 'خطأ في تحميل القراءات:';
  @override
  String get errorLoadingQuestions => 'خطأ في تحميل الأسئلة:';
  @override
  String get readingProgress => 'تقدمك';
  @override
  String get completedReadings => 'مكتمل';
  @override
  String get totalReadings => 'الإجمالي';
  @override
  String get percentComplete => 'مكتمل';
  
  // OTP Verification
  @override
  String get verificationCode => 'رمز التحقق';
  @override
  String get otpSentToEmail => 'تم إرسال رمز التحقق إلى بريدك الإلكتروني أدخل الرمز للتحقق من حسابك';
  @override
  String get otpSentToEmailPasswordReset => 'تم إرسال رمز التحقق إلى بريدك الإلكتروني أدخل الرمز لتتمكن من تغيير كلمة المرور';
  @override
  String get confirm => 'تأكيد';
  @override
  String get resend => 'إعادة الإرسال';
  @override
  String get resendWithTimer => 'إعادة الإرسال ({time})';
  @override
  String get codeResentSuccessfully => 'تم إعادة إرسال الرمز بنجاح';
  @override
  String get failedToResendCode => 'فشل إعادة إرسال الرمز:';
  @override
  String get enterCompleteCode => 'الرجاء إدخال رمز التحقق الكامل';
  @override
  String get verificationFailed => 'فشل التحقق:';
  
  // Chat
  @override
  String get today => 'اليوم';
  @override
  String get yesterday => 'أمس';
  @override
  String get blockUser => 'حظر المستخدم';
  @override
  String get tapToRetry => 'اضغط لإعادة المحاولة';
  @override
  String get failedToLoadImage => 'فشل تحميل الصورة';
  @override
  String get couldNotPlayAudio => 'تعذر تشغيل الصوت';
  @override
  String get downloading => 'جاري التنزيل';
  @override
  String get downloadedTo => 'تم التنزيل إلى:';
  @override
  String get downloadFailed => 'فشل التنزيل:';
  @override
  String get failedToSendMessage => 'فشل إرسال الرسالة';
  @override
  String get errorSendingMessage => 'خطأ في إرسال الرسالة:';
  @override
  String get failedToCaptureImage => 'فشل التقاط الصورة:';
  @override
  String get failedToPickImage => 'فشل اختيار الصورة:';
  @override
  String get failedToStartRecording => 'فشل بدء التسجيل. الرجاء التحقق من أذونات الميكروفون.';
  @override
  String get checkMicrophonePermissions => 'الرجاء التحقق من أذونات الميكروفون';
  @override
  String get failedToSendVoiceMessage => 'فشل إرسال رسالة الصوت';
  @override
  String get errorSendingVoiceMessage => 'خطأ في إرسال رسالة الصوت:';
  
  // Common additional
  @override
  String get level => 'المستوى';
  @override
  String get pts => 'نقطة';
  @override
  String get session => 'جلسة';
  @override
  String get sessions => 'جلسات';
  @override
  String get minute => 'دقيقة';
  @override
  String get minutesPlural => 'دقائق';
  @override
  String get loginRequired => 'الرجاء تسجيل الدخول للوصول إلى تمرين الاختبار';
  
  // Chat additional
  @override
  String get chatDeletedSuccessfully => 'تم حذف المحادثة بنجاح';
  @override
  String get failedToDeleteChat => 'فشل حذف المحادثة. يرجى المحاولة مرة أخرى.';
  @override
  String get messageUnsent => 'تم إلغاء إرسال الرسالة';
  @override
  String get downloadedToUnableToOpen => 'تم التنزيل إلى: {filePath}\nتعذر فتح الملف: {message}';
  
  // Profile additional
  @override
  String get activateOnThisDevice => 'تفعيل على هذا الجهاز';
  @override
  String get blockedUsers => 'المستخدمون المحظورون';
  @override
  String get manageBlockedUsers => 'إدارة المستخدمين المحظورين';
  @override
  String get studentPlaceholder => 'طالب';
  @override
  String get editProfileButton => 'تعديل الملف الشخصي';
  @override
  String get proActiveOnAnotherDevice => 'برو نشط على جهاز آخر';
  @override
  String get proSubscriptionActiveMessage => 'اشتراكك المحترف نشط حالياً على جهاز آخر. قم بتفعيله هنا لاستخدام ميزات برو.';
  @override
  String get proFeaturesActivated => '✅ تم تفعيل ميزات برو على هذا الجهاز!';
  @override
  String get failedToActivate => '❌ فشل التفعيل';
  @override
  String get errorActivation => '❌ خطأ';
  @override
  String get unknownError => 'خطأ غير معروف';
  @override
  String get logoutFailed => 'فشل تسجيل الخروج';
  
  // Classes additional
  @override
  String get errorLoadingSessions => 'خطأ في تحميل الجلسات:';
  @override
  String get errorJoiningSession => 'خطأ في الانضمام إلى الجلسة:';
  @override
  String get teacherInformationNotAvailable => 'معلومات المعلم غير متاحة';
  @override
  String get unableToStartChat => 'تعذر بدء المحادثة. يرجى المحاولة مرة أخرى.';
  @override
  String get errorOpeningChat => 'خطأ في فتح المحادثة:';
  @override
  String get unableToLoadTeacherDetails => 'تعذر تحميل تفاصيل المعلم';
  @override
  String get myClasses => 'فصولي';
  @override
  String get noUpcomingClasses => 'لا توجد فصول قادمة';
  @override
  String get noFinishedClasses => 'لا توجد فصول منتهية';
  @override
  String get subscribeToSeeClasses => 'اشترك مع معلم لترى فصولك هنا';
  @override
  String get pullDownToRefresh => 'اسحب لأسفل للتحديث';
  @override
  String get makeupClass => 'فصل تعويضي';
  @override
  String get cancelled => 'ملغى';
  @override
  String get extraClass => 'فصل إضافي';
  @override
  String get liveNow => 'مباشر الآن';
  @override
  String get languageClass => 'فصل';
  @override
  String get teacherNamePlaceholder => 'المعلم';
  @override
  String get yourTime => 'توقيتك';
  @override
  String get classDuration => 'مدة الفصل';
  @override
  String get join => 'انضم';
  @override
  String get waitingForMeetingLink => 'في انتظار رابط الاجتماع';
  @override
  String get waitingForTeacherToStart => 'في انتظار بدء المعلم';
  @override
  String get startsIn => 'يبدأ خلال';
  @override
  String get classWasCancelled => 'تم إلغاء هذا الفصل';
  @override
  String get tapToViewTeacherAndRate => 'اضغط لعرض المعلم والتقييم';
  @override
  String get min => 'دقيقة';
  
  // Quiz additional
  @override
  String get questionCounter => 'السؤال {current}/{total}';
  @override
  String get accuracyPercentage => '{accuracy}% دقة';
  @override
  String get correctCheck => 'صحيح! ✓';
  @override
  String get answerEachQuestionWithinSeconds => 'أجب على كل سؤال خلال 15 ثانية. تتقدم الأسئلة تلقائياً عند انتهاء الوقت!';
  @override
  String get questionsAutoAdvance => 'تتقدم الأسئلة تلقائياً عند انتهاء الوقت!';
  @override
  String get yourProgressWillBeLost => 'سيتم فقدان تقدمك. هل أنت متأكد؟';
  @override
  String get sec => 'ثانية';
  @override
  String get ten => '10';
  @override
  String get fifteenSec => '15 ثانية';
  @override
  String get loginRequiredQuizPractice => 'الرجاء تسجيل الدخول للوصول إلى تمرين الاختبار';
  
  // Profile/Edit Profile
  @override
  String get editProfileTitle => 'تعديل الملف الشخصي';
  @override
  String get photoAddedSuccessfully => 'تمت إضافة الصورة بنجاح!';
  @override
  String get failedToUploadPhoto => 'فشل تحميل الصورة:';
  @override
  String get mainPhotoUpdated => 'تم تحديث الصورة الرئيسية!';
  @override
  String get failedToSetMainPhoto => 'فشل تعيين الصورة الرئيسية:';
  @override
  String get photoDeleted => 'تم حذف الصورة!';
  @override
  String get failedToDeletePhoto => 'فشل حذف الصورة:';
  @override
  String get profileUpdatedSuccessfully => 'تم تحديث الملف الشخصي بنجاح!';
  @override
  String get failedToUpdateProfile => 'فشل تحديث الملف الشخصي:';
  @override
  String get pleaseEnterYourName => 'الرجاء إدخال اسمك';
  @override
  String get tellUsAboutYourself => 'أخبرنا عن نفسك...';
  
  // Blocked Users
  @override
  String get blockedUsersTitle => 'المستخدمون المحظورون';
  @override
  String get unblockUser => 'إلغاء حظر المستخدم';
  @override
  String get unblockUserConfirm => 'إلغاء الحظر';
  @override
  String get unblockUserMessage => 'هل أنت متأكد أنك تريد إلغاء حظر {name}؟ ستتمكنان من رؤية بعضكما البعض مرة أخرى.';
  @override
  String get noBlockedUsers => 'لا يوجد مستخدمون محظورون';
  @override
  String get noBlockedUsersMessage => 'لم تحظر أي شخص بعد';
  @override
  String get failedToLoadBlockedUsers => 'فشل تحميل المستخدمين المحظورين:';
  @override
  String get userHasBeenUnblocked => 'تم إلغاء حظر {name}';
  @override
  String get failedToUnblockUser => 'فشل إلغاء حظر المستخدم';
  @override
  String get blockUserMessage => 'سيؤدي حظر هذا المستخدم إلى إخفاء ملفه الشخصي ومنعه من التواصل معك.';
  @override
  String get userBlocked => 'تم حظر المستخدم';
  
  // Search/Input hints
  @override
  String get searchMessages => 'البحث في الرسائل...';
  @override
  String get messageHint => 'رسالة';
  
  // Chat errors
  @override
  String get failedToUnsendMessage => 'فشل إلغاء إرسال الرسالة. يرجى المحاولة مرة أخرى.';
  @override
  String get failedToBlockUserTryAgain => 'فشل حظر المستخدم. يرجى المحاولة مرة أخرى.';
  
  // Chat list screen
  @override
  String get messagesTitle => 'الرسائل';
  @override
  String get showConversations => 'عرض المحادثات';
  @override
  String get startNewChat => 'بدء محادثة جديدة';
  @override
  String get requestAccepted => 'تم قبول الطلب!';
  @override
  String get failedToAcceptRequest => 'فشل قبول الطلب';
  @override
  String get requestRejected => 'تم رفض الطلب';
  @override
  String get failedToRejectRequest => 'فشل رفض الطلب';
  @override
  String get justNow => 'الآن';
  @override
  String minutesAgo(int minutes) => 'منذ ${minutes} د';
  @override
  String get oneDayAgo => 'منذ يوم';
  @override
  String daysAgo(int days) => 'منذ ${days} أيام';
  @override
  String get noResultsFound => 'لا توجد نتائج';
  @override
  String get noMessagesYet => 'لا توجد رسائل بعد';
  @override
  String get tryDifferentKeywords => 'جرب البحث بكلمات مفتاحية مختلفة';
  @override
  String get startConversationWithTeachers => 'ابدأ محادثة مع معلميك';
  @override
  String get chatRequestTitle => 'طلب محادثة';
  @override
  String get noMessageProvided => 'لم يتم تقديم رسالة';
  @override
  String get sentChatRequest => 'أرسل طلب محادثة';
  @override
  String get chatRequestsReceived => 'الواردة';
  @override
  String get chatRequestsSent => 'المرسلة';
  @override
  String get chatRequestPendingStatus => 'قيد الانتظار';
  @override
  String get deleteChat => 'حذف المحادثة';
  @override
  String get deleteChatQuestion => 'حذف المحادثة؟';
  @override
  String deleteChatConfirmation(String name) => 'هل أنت متأكد من حذف هذه المحادثة مع $name؟ لا يمكن التراجع عن هذا الإجراء.';
  @override
  String get noTeachersAvailable => 'لا يوجد معلمون متاحون';
  @override
  String get subscribeToChatWithTeachers => 'اشترك في دورة للدردشة مع المعلمين';
  @override
  String get imageAttachment => '🖼️ صورة';
  @override
  String get voiceMessage => '🎤 رسالة صوتية';
  @override
  String get fileAttachment => '📎 ملف';
  @override
  String get attachmentGeneric => '📎 مرفق';
  @override
  String get startChatting => 'ابدأ المحادثة...';
  @override
  String get user => 'مستخدم';
}

