import 'app_localizations.dart';

class AppLocalizationsEs extends AppLocalizations {
  // Common
  @override
  String get appName => 'LinguMoro';
  @override
  String get ok => 'OK';
  @override
  String get cancel => 'Cancelar';
  @override
  String get yes => 'Sí';
  @override
  String get no => 'No';
  @override
  String get error => 'Error';
  @override
  String get success => 'Éxito';
  @override
  String get loading => 'Cargando...';
  @override
  String get retry => 'Reintentar';
  @override
  String get save => 'Guardar';
  @override
  String get delete => 'Eliminar';
  @override
  String get edit => 'Editar';
  @override
  String get search => 'Buscar';
  @override
  String get filter => 'Filtrar';
  @override
  String get close => 'Cerrar';
  @override
  String get next => 'Siguiente';
  @override
  String get previous => 'Anterior';
  @override
  String get done => 'Hecho';
  @override
  String get skip => 'Omitir';
  @override
  String get and => 'y';
  @override
  String get or => 'o';
  
  // Navigation
  @override
  String get navHome => 'Inicio';
  @override
  String get navClasses => 'Clases';
  @override
  String get navPractice => 'Práctica';
  @override
  String get navChat => 'Chat';
  @override
  String get navProfile => 'Perfil';
  
  // Drawer/Settings
  @override
  String get settings => 'AJUSTES';
  @override
  String get contactUs => 'CONTÁCTANOS';
  @override
  String get aboutUs => 'SOBRE NOSOTROS';
  @override
  String get privacyPolicy => 'POLÍTICA DE PRIVACIDAD';
  @override
  String get termsConditions => 'TÉRMINOS Y CONDICIONES';
  @override
  String get changeLanguage => 'CAMBIAR IDIOMA';
  @override
  String get selectLanguage => 'Seleccionar Idioma';
  @override
  String get languageChanged => 'Idioma cambiado a Español';
  @override
  String get version => 'Versión 1.0.0';
  
  // Auth
  @override
  String get login => 'Iniciar Sesión';
  @override
  String get signup => 'Registrarse';
  @override
  String get logout => 'Cerrar Sesión';
  @override
  String get email => 'Correo Electrónico';
  @override
  String get password => 'Contraseña';
  @override
  String get confirmPassword => 'Confirmar Contraseña';
  @override
  String get fullName => 'Nombre Completo';
  @override
  String get forgotPassword => '¿Olvidaste tu contraseña?';
  @override
  String get forgotPasswordTitle => 'OLVIDÉ MI CONTRASEÑA';
  @override
  String get forgotPasswordDescription => 'Ingresa tu dirección de correo electrónico y te enviaremos un código de verificación para restablecer tu contraseña';
  @override
  String get pleaseEnterYourEmail => 'Por favor ingresa tu correo electrónico';
  @override
  String get verificationCodeSentToEmail => 'Código de verificación enviado a tu correo electrónico';
  @override
  String get failedToSendCode => 'Error al enviar código';
  @override
  String get sendCode => 'ENVIAR CÓDIGO';
  @override
  String get resetPassword => 'Restablecer Contraseña';
  @override
  String get resetPasswordTitle => 'RESTABLECER CONTRASEÑA';
  @override
  String get resetPasswordDescription => 'Ingresa tu nueva contraseña a continuación';
  @override
  String get enterNewPasswordBelow => 'Ingresa tu nueva contraseña a continuación';
  @override
  String get newPassword => 'Nueva Contraseña';
  @override
  String get confirmNewPassword => 'Confirmar Nueva Contraseña';
  @override
  String get passwordResetSuccessfully => '¡Contraseña restablecida exitosamente!';
  @override
  String get failedToResetPassword => 'Error al restablecer contraseña';
  @override
  String get userNotLoggedIn => 'Usuario no ha iniciado sesión';
  @override
  String get dontHaveAccount => '¿No tienes una cuenta?';
  @override
  String get alreadyHaveAccount => '¿Ya tienes una cuenta?';
  @override
  String get enterEmail => 'Ingresa tu correo electrónico';
  @override
  String get enterPassword => 'Ingresa tu contraseña';
  @override
  String get enterFullName => 'Ingresa tu nombre completo';
  @override
  String get passwordMismatch => 'Las contraseñas no coinciden';
  @override
  String get emailRequired => 'El correo electrónico es requerido';
  @override
  String get passwordRequired => 'La contraseña es requerida';
  @override
  String get fullNameRequired => 'El nombre completo es requerido';
  @override
  String get invalidEmail => 'Correo electrónico inválido';
  @override
  String get passwordTooShort => 'La contraseña debe tener al menos 6 caracteres';
  @override
  String get loginSuccess => 'Inicio de sesión exitoso';
  @override
  String get loginFailed => 'Error al iniciar sesión';
  @override
  String get signupSuccess => 'Registro exitoso';
  @override
  String get signupFailed => 'Error al registrarse';
  @override
  String get logoutConfirm => 'Cerrar Sesión';
  @override
  String get areYouSureLogout => '¿Estás seguro de que quieres cerrar sesión?';
  @override
  String get phoneNumber => 'Número de Teléfono';
  @override
  String get enterPhoneNumber => 'Ingresa tu número de teléfono';
  @override
  String get phoneNumberRequired => 'El número de teléfono es requerido';
  @override
  String get bio => 'Biografía';
  @override
  String get enterBio => 'Cuéntanos sobre ti';
  @override
  String get createAccount => 'Crear Cuenta';
  @override
  String get welcomeBack => 'Bienvenido de Nuevo';
  @override
  String get getStarted => 'Comenzar';
  
  // Home
  @override
  String get chooseYourClass => 'ELIGE TU CLASE';
  @override
  String get students => 'Estudiantes';
  @override
  String get teachers => 'Profesores';
  @override
  String get noLanguagesAvailable => 'No hay idiomas disponibles';
  @override
  String get selectLanguageFirst => 'Por favor selecciona un idioma primero';
  @override
  String get comingSoon => 'Pronto';
  
  // Profile
  @override
  String get profile => 'PERFIL';
  @override
  String get editProfile => 'Editar Perfil';
  @override
  String get personalInformation => 'Información Personal';
  @override
  String get security => 'Seguridad';
  @override
  String get changePassword => 'Cambiar Contraseña';
  @override
  String get changePasswordTitle => 'CAMBIAR CONTRASEÑA';
  @override
  String changePasswordDescription(String email) => 'Para cambiar tu contraseña, necesitamos verificar tu identidad. Enviaremos un código de verificación a $email';
  @override
  String get sendVerificationCode => 'ENVIAR CÓDIGO DE VERIFICACIÓN';
  @override
  String get updatePassword => 'Actualiza tu contraseña';
  @override
  String get currentLevel => 'Nivel Actual';
  @override
  String get proMember => 'Miembro PRO';
  @override
  String get freeMember => 'Miembro Gratuito';
  @override
  String get upgrade => 'Mejorar';
  @override
  String get upgradeToPro => 'Mejorar a PRO';
  @override
  String get redeemVoucher => 'Canjea tu código de cupón';
  @override
  String get voucherCode => 'Código de Cupón';
  @override
  String get enterCodeHere => 'Ingresa el código aquí';
  @override
  String get redeem => 'Canjear';
  @override
  String get proBenefits => 'Beneficios PRO';
  @override
  String get unlimitedAccess => 'Acceso Ilimitado';
  @override
  String get unlimitedAccessDesc => 'Accede a todas las funciones sin restricciones';
  @override
  String get connectWithStudents => 'Conéctate con Estudiantes';
  @override
  String get connectWithStudentsDesc => 'Chatea y conéctate con otros aprendices de idiomas';
  @override
  String get practiceWithAI => 'Practica con IA';
  @override
  String get practiceWithAIDesc => 'Sesiones de práctica de idiomas interactivas con IA';
  @override
  String get enterVoucherCode => 'Por favor ingresa un código de cupón';
  @override
  String get voucherRedeemed => '¡Suscripción PRO activada!';
  @override
  String get voucherRedeemedDesc => 'días añadidos';
  @override
  String get invalidVoucher => 'Código de cupón inválido';
  @override
  String get expiresPro => 'Expira';
  @override
  String get unlimitedFeatures => 'Acceso ilimitado a todas las funciones';
  @override
  String get limitedFeatures => 'Funciones limitadas disponibles';
  @override
  String get languageLearner => 'Aprendiz de Idiomas';
  @override
  String get xpPoints => 'XP';
  @override
  String get xpToNextLevel => 'XP para Nivel';
  @override
  String get maxLevelReached => '¡Nivel Máximo Alcanzado!';
  
  // Level statuses
  @override
  String get levelBeginner => 'Principiante';
  @override
  String get levelIntermediate => 'Intermedio';
  @override
  String get levelAdvanced => 'Avanzado';
  @override
  String get levelExpert => 'Experto';
  @override
  String get levelMaster => 'Maestro';
  @override
  String get levelGrandMaster => 'Gran Maestro';
  @override
  String get levelLegend => 'Leyenda';
  @override
  String get levelMythic => 'Mítico';
  @override
  String get levelTranscendent => 'Trascendente';
  @override
  String get levelSupreme => 'Supremo';
  
  // Classes
  @override
  String get classes => 'CLASES';
  @override
  String get upcoming => 'Próximas';
  @override
  String get finished => 'Finalizadas';
  @override
  String get joinSession => 'Unirse a Sesión';
  @override
  String get sessionDetails => 'Detalles de Sesión';
  @override
  String get meetingLinkNotAvailable => 'Enlace de reunión no disponible aún. Por favor espera a que el profesor lo configure.';
  @override
  String get waitForTeacher => 'Espera al profesor';
  @override
  String get noUpcomingSessions => 'No hay sesiones próximas';
  @override
  String get noFinishedSessions => 'No hay sesiones finalizadas';
  @override
  String get sessionWith => 'Sesión con';
  @override
  String get packageType => 'Paquete';
  @override
  String get date => 'Fecha';
  @override
  String get time => 'Hora';
  @override
  String get duration => 'Duración';
  @override
  String get minutes => 'minutos';
  
  // Practice
  @override
  String get practice => 'PRÁCTICA';
  @override
  String get videos => 'Practicar Escucha';
  @override
  String get quizPractice => 'Práctica de Cuestionario';
  @override
  String get reading => 'Lectura';
  @override
  String get aiVoice => 'Voz IA';
  @override
  String get watchedVideos => 'Vistos';
  @override
  String get totalVideos => 'Total';
  @override
  String get questionsAnswered => 'Preguntas';
  @override
  String get accuracy => 'Precisión';
  @override
  String get storiesGenerated => 'Generadas';
  @override
  String get storiesRemaining => 'Restantes';
  @override
  String get startPractice => 'Iniciar Práctica';
  @override
  String get continueWatching => 'Continuar Viendo';
  @override
  String get markAsWatched => 'Marcar como Visto';
  @override
  String get completedVideos => 'Completado';
  @override
  String get noPracticeAvailable => 'No hay práctica disponible';
  @override
  String get proFeature => 'Función PRO';
  @override
  String get upgradeToAccess => 'Mejora a PRO para acceder a esta función';
  @override
  String get videoPracticeTitle => 'Práctica en Video';
  @override
  String get overallProgress => 'Progreso General';
  @override
  String get lessonPlaylist => 'Lista de Lecciones';
  @override
  String get noVideosYet => 'Aún no hay videos';
  @override
  String get videosComingSoon => 'Los videos de práctica aparecerán aquí.\n¡Vuelve pronto para ver nuevo contenido!';
  @override
  String get videoLockedTitle => 'Video bloqueado';
  @override
  String get completePreviousVideoToUnlock => 'Mira el video anterior primero para desbloquear este.';
  @override
  String get aboutThisLesson => 'Acerca de esta lección';
  @override
  String get watchFullVideoToUnlock => 'Mira todo el video para desbloquear la siguiente lección y ganar puntos.';
  
  // Chat
  @override
  String get chat => 'CHAT';
  @override
  String get messages => 'Mensajes';
  @override
  String get online => 'En línea';
  @override
  String get offline => 'Desconectado';
  @override
  String get typing => 'escribiendo...';
  @override
  String get typeMessage => 'Escribe un mensaje';
  @override
  String get sendMessage => 'Enviar';
  @override
  String get noMessages => 'No hay mensajes aún';
  @override
  String get startConversation => 'Iniciar una conversación';
  @override
  String get tapToOpenChat => 'Toca para abrir el chat';
  @override
  String get startToSeeConversation => 'Empieza a hablar para ver la conversación';
  @override
  String get chatRequests => 'Solicitudes de Chat';
  @override
  String get noChatRequests => 'No hay solicitudes de chat';
  @override
  String get accept => 'Aceptar';
  @override
  String get decline => 'Rechazar';
  @override
  String get blocked => 'Bloqueado';
  @override
  String get unblock => 'Desbloquear';
  @override
  String get block => 'Bloquear';
  @override
  String get report => 'Reportar';
  
  // Teachers
  @override
  String get teachersList => 'PROFESORES';
  @override
  String get noTeachersForLanguage => 'No se encontraron profesores para';
  @override
  String get selectPackage => 'Seleccionar Paquete';
  @override
  String get selectDayTime => 'Seleccionar Día y Hora';
  @override
  String get bookSession => 'Reservar Sesión';
  @override
  String get sessionBooked => 'Sesión reservada exitosamente';
  @override
  String get bookingFailed => 'Error al reservar';
  @override
  String get availableSlots => 'Horarios Disponibles';
  @override
  String get noAvailableSlots => 'No hay horarios disponibles';
  @override
  String get selectTimeSlot => 'Selecciona un horario';
  @override
  String get teacherDetails => 'Detalles del Profesor';
  @override
  String get rating => 'Calificación';
  @override
  String get reviews => 'Reseñas';
  @override
  String get about => 'Acerca de';
  @override
  String get experience => 'Experiencia';
  @override
  String get languages => 'Idiomas';
  @override
  String get hourlyRate => 'Tarifa por Hora';
  @override
  String get perSession => 'por sesión';
  // Teacher detail/profile
  @override
  String get teacherNotFoundTitle => 'Profesor no encontrado';
  @override
  String get teacherNotFoundMessage => 'El profesor que estás buscando no existe';
  @override
  String get alreadySubscribedMessage => 'Ya tienes una suscripción activa con este profesor';
  @override
  String get needSubscriptionToChat => 'Necesitas suscribirte para chatear con este profesor';
  @override
  String get availableSchedulesTitle => 'HORARIOS DISPONIBLES';
  @override
  String get noScheduleAvailable => 'No hay horarios disponibles';
  @override
  String get ratingsAndReviewsTitle => 'Calificaciones y Reseñas';
  @override
  String get noReviewsYet => 'No hay reseñas aún';
  @override
  String get rateButton => 'Calificar';
  @override
  String get updateRatingButton => 'Actualizar';
  
  // Students
  @override
  String get studentsList => 'ESTUDIANTES';
  @override
  String get noStudentsFound => 'No se encontraron estudiantes';
  @override
  String get sendChatRequest => 'Enviar Solicitud de Chat';
  @override
  String get chatRequestSent => 'Solicitud de chat enviada';
  @override
  String get alreadyChatting => 'Ya estás chateando';
  @override
  String get beFirstInYourLanguage => '¡Sé el primero en tu idioma!';
  @override
  String get enrollToSeeOtherStudents => 'Necesitas inscribirte en un curso para ver a otros estudiantes';
  
  // Packages
  @override
  String get packages => 'PAQUETES';
  @override
  String get selectYourPackage => 'Selecciona tu Paquete';
  @override
  String get packageDetails => 'Detalles del Paquete';
  @override
  String get sessionsPerWeek => 'sesiones por semana';
  @override
  String get totalSessions => 'Total de Sesiones';
  @override
  String get price => 'Precio';
  @override
  String get subscribe => 'Suscribirse';
  @override
  String get subscriptionActive => 'Suscripción Activa';
  @override
  String get subscriptionExpired => 'Suscripción Expirada';
  // Subscription & vouchers
  @override
  String get noPackagesAvailable => 'No hay paquetes disponibles';
  @override
  String teacherNeedsDaysAvailable(int days) =>
      'El profesor necesita al menos $days días disponibles para este paquete.';
  @override
  String get selectDays => 'Seleccionar días';
  @override
  String get selectTime => 'Seleccionar horario';
  @override
  String get noCommonTimeSlots =>
      'No hay horarios comunes disponibles para los días seleccionados. Por favor selecciona días diferentes.';
  @override
  String get selectedPackageLabel => 'Paquete seleccionado';
  @override
  String selectedDaysLabel(int days) => 'Días seleccionados ($days días)';
  @override
  String get change => 'Cambiar';
  @override
  String get yourSchedule => 'Tu horario';
  @override
  String voucherCodeMustBeLength(int length) =>
      'El código de cupón debe tener $length caracteres';
  @override
  String get voucherCodeValidForPackage =>
      'Asegúrate de que el código de cupón sea válido para el paquete seleccionado.';
  @override
  String subscriptionActivatedSessions(int sessions) =>
      '¡Suscripción activada! Tienes $sessions sesiones.';
  @override
  String get redeemingVoucher => 'Canjeando...';
  @override
  String get stepPackage => 'Paquete';
  @override
  String get stepDays => 'Días';
  @override
  String get stepTime => 'Hora';
  @override
  String get perMonth => '/mes';
  @override
  String get subscribeTo => 'Suscríbete a';
  
  // Notifications
  @override
  String get notifications => 'NOTIFICACIONES';
  @override
  String get notificationSettings => 'Ajustes de Notificaciones';
  @override
  String get noNotifications => 'No hay notificaciones';
  @override
  String get markAllRead => 'Marcar todo como leído';
  @override
  String get enableNotifications => 'Habilitar Notificaciones';
  @override
  String get sessionReminders => 'Recordatorios de Sesión';
  @override
  String get chatMessages => 'Mensajes de Chat';
  @override
  String get practiceReminders => 'Recordatorios de Práctica';
  @override
  String get allNotificationsMarkedRead => 'Todas las notificaciones marcadas como leídas';
  @override
  String get clearAllNotificationsTitle => 'Borrar Todas las Notificaciones';
  @override
  String get clearAllNotificationsMessage => '¿Estás seguro de que quieres borrar todas las notificaciones? Esta acción no se puede deshacer.';
  @override
  String get clearAllButton => 'Borrar Todo';
  @override
  String notificationsCleared(int count) => 'Se borraron $count notificaciones';
  @override
  String get readAll => 'Leer todo';
  @override
  String get clear => 'Borrar';
  @override
  String get youreAllCaughtUp => '¡Ya estás al día!';
  
  // Days of week
  @override
  String get monday => 'Lunes';
  @override
  String get tuesday => 'Martes';
  @override
  String get wednesday => 'Miércoles';
  @override
  String get thursday => 'Jueves';
  @override
  String get friday => 'Viernes';
  @override
  String get saturday => 'Sábado';
  @override
  String get sunday => 'Domingo';
  @override
  String get mon => 'Lun';
  @override
  String get tue => 'Mar';
  @override
  String get wed => 'Mié';
  @override
  String get thu => 'Jue';
  @override
  String get fri => 'Vie';
  @override
  String get sat => 'Sáb';
  @override
  String get sun => 'Dom';
  
  // Months
  @override
  String get january => 'Enero';
  @override
  String get february => 'Febrero';
  @override
  String get march => 'Marzo';
  @override
  String get april => 'Abril';
  @override
  String get may => 'Mayo';
  @override
  String get june => 'Junio';
  @override
  String get july => 'Julio';
  @override
  String get august => 'Agosto';
  @override
  String get september => 'Septiembre';
  @override
  String get october => 'Octubre';
  @override
  String get november => 'Noviembre';
  @override
  String get december => 'Diciembre';
  
  // Error messages
  @override
  String get errorLoadingData => 'Error al cargar datos';
  @override
  String get errorSavingData => 'Error al guardar datos';
  @override
  String get errorNoInternet => 'Sin conexión a internet';
  @override
  String get errorTryAgain => 'Por favor intenta de nuevo';
  @override
  String get errorUnknown => 'Ocurrió un error desconocido';
  @override
  String get noInternetConnection => 'Sin Conexión a Internet';
  
  // Success messages
  @override
  String get successSaved => 'Guardado exitosamente';
  @override
  String get successUpdated => 'Actualizado exitosamente';
  @override
  String get successDeleted => 'Eliminado exitosamente';
  
  // Validation
  @override
  String get fieldRequired => 'Este campo es requerido';
  @override
  String get invalidInput => 'Entrada inválida';
  @override
  String get tooShort => 'Demasiado corto';
  @override
  String get tooLong => 'Demasiado largo';
  
  // Settings screens
  @override
  String get aboutUsContent => 'Lingumoro es una plataforma de aprendizaje de idiomas que conecta estudiantes con profesores.';
  @override
  String get privacyPolicyContent => 'Tu privacidad es importante para nosotros. Recopilamos y usamos tus datos para proporcionar mejores servicios.';
  @override
  String get termsConditionsContent => 'Al usar esta aplicación, aceptas nuestros términos y condiciones.';
  
  // Contact
  @override
  String get couldNotOpenWhatsApp => 'No se pudo abrir WhatsApp';
  @override
  String get errorOpeningWhatsApp => 'Error al abrir WhatsApp';
  
  // Province/City selection
  @override
  String get chooseCity => 'Elegir Ciudad';
  @override
  String get selectProvince => 'Seleccionar Provincia';
  @override
  String get searchProvince => 'Buscar provincia...';
  @override
  String get pleaseSelectProvince => 'Por favor selecciona tu provincia';
  @override
  String get fillAllFields => 'Por favor completa todos los campos requeridos';
  @override
  String get confirmAccount => 'CONFIRMAR CUENTA';
  
  // Mother Language selection
  @override
  String get selectMotherLanguage => 'Seleccionar Idioma Materno';
  @override
  String get pleaseSelectMotherLanguage => 'Por favor selecciona tu idioma materno';
  @override
  String get motherLanguage => 'Idioma Materno';
  
  // Quiz Practice
  @override
  String get languageQuiz => 'Tomar Cuestionario';
  @override
  String get yourStatistics => 'Tus Estadísticas';
  @override
  String get quizzes => 'Cuestionarios';
  @override
  String get points => 'Puntos';
  @override
  String get recentQuizzes => 'Cuestionarios Recientes';
  @override
  String get proSubscriptionRequired => 'Suscripción PRO Requerida';
  @override
  String get languageQuizProOnly => 'El Cuestionario de Idiomas está disponible solo para miembros PRO.';
  @override
  String get goBack => 'Volver';
  @override
  String get levelElementary => 'Elemental';
  @override
  String get levelPreIntermediate => 'Pre-Intermedio';
  @override
  String get levelUpperIntermediate => 'Intermedio Superior';
  @override
  String get startNewQuiz => 'INICIAR NUEVO CUESTIONARIO';
  @override
  String get questionNumber => 'Pregunta';
  @override
  String get exitQuiz => '¿Salir del Cuestionario?';
  @override
  String get exitQuizMessage => 'Se perderá tu progreso. ¿Estás seguro?';
  @override
  String get exit => 'Salir';
  @override
  String get quizComplete => '¡Cuestionario Completado!';
  @override
  String get score => 'Puntuación';
  @override
  String get reviewAnswers => 'Revisar Respuestas';
  @override
  String get back => 'ATRÁS';
  @override
  String get retryQuiz => 'REINTENTAR CUESTIONARIO';
  @override
  String get totalQuestions => 'Total de Preguntas';
  @override
  String get timePerQuestion => 'Tiempo por Pregunta';
  @override
  String get pointsAvailable => 'Puntos Disponibles';
  @override
  String get quizInstructions => 'Responde cada pregunta en 15 segundos. ¡Las preguntas avanzan automáticamente cuando se acaba el tiempo!';
  @override
  String get startQuiz => 'INICIAR CUESTIONARIO';
  @override
  String get correct => '¡Correcto! ✓';
  @override
  String get yourAnswer => 'Tu respuesta:';
  @override
  String get noAnswerTimeout => 'Sin respuesta (tiempo agotado)';
  @override
  String get correctAnswer => 'Correcto:';
  @override
  String get failedToGenerateQuiz => 'Error al generar cuestionario. Por favor intenta de nuevo.';
  @override
  String get pleaseTryAgain => 'Por favor intenta de nuevo';
  @override
  String get hoursAgo => 'hace h';
  
  // AI Voice Practice
  @override
  String get aiVoicePractice => 'Practicar Hablando';
  @override
  String get voiceSettings => 'Configuración de Voz';
  @override
  String get voice => 'Voz';
  @override
  String get speed => 'Velocidad';
  @override
  String get start => 'Iniciar';
  @override
  String get stop => 'Detener';
  @override
  String get sessionNumber => 'Sesión';
  @override
  String get timesUp => '¡Se Acabó el Tiempo!';
  @override
  String get sessionEndedMessage => 'Tu sesión de {minutes} minutos ha terminado. ¡Buen trabajo practicando!';
  @override
  String get gotIt => 'Entendido';
  @override
  String get greatJob => '¡Buen Trabajo!';
  @override
  String get practicedForMinutes => '¡Practicaste durante {minutes} minuto{plural}!';
  @override
  String get sessionsRemaining => 'Sesiones restantes:';
  @override
  String get awesome => '¡Genial!';
  @override
  String get sessionLimitReached => 'Límite de Sesión Alcanzado';
  @override
  String get notConnected => 'Desconectado';
  @override
  String get preparingVoiceSession => '⏳ Preparando sesión de voz...';
  @override
  String get listening => '🎙️ Escuchando...';
  @override
  String get holdToSpeak => 'Mantén para hablar';
  @override
  String get releaseToSend => 'Suelta para enviar';
  @override
  String get pleaseLoginToUseAI => 'Por favor inicia sesión para usar Práctica de Voz IA';
  @override
  String get microphonePermissionRequired => 'Se requiere permiso de micrófono';
  @override
  String get failedToStartSession => 'Error al iniciar sesión';
  @override
  String get connectionError => 'Error de conexión:';
  @override
  String get recorderPermissionDenied => 'Permiso de grabador denegado';
  @override
  String get failedToStart => 'Error al iniciar:';
  @override
  String get proFeaturesActiveOnAnotherDevice => '⚠️ Las funciones PRO están activas en otro dispositivo. Activa en Perfil para usar.';
  @override
  String get activateInProfile => 'Activar en Perfil';
  
  // Reading
  @override
  String get readings => 'Practicar Lectura';
  @override
  String get yourProgress => 'Tu Progreso';
  @override
  String get completed => 'Completado';
  @override
  String get allReadings => 'Todas las Lecturas';
  @override
  String get completePreviousToUnlock => 'Completa la lectura anterior para desbloquear';
  @override
  String get noReadingsAvailable => 'No hay lecturas disponibles';
  @override
  String get checkBackLater => 'Vuelve más tarde para nuevo contenido de lectura';
  @override
  String get completePreviousReading => 'Completa la lectura anterior para desbloquear esta';
  @override
  String get errorLoadingReadings => 'Error al cargar lecturas:';
  @override
  String get errorLoadingQuestions => 'Error al cargar preguntas:';
  @override
  String get readingProgress => 'Tu Progreso';
  @override
  String get completedReadings => 'Completado';
  @override
  String get totalReadings => 'Total';
  @override
  String get percentComplete => 'Completado';
  
  // OTP Verification
  @override
  String get verificationCode => 'CÓDIGO DE VERIFICACIÓN';
  @override
  String get otpSentToEmail => 'Se envió un código de verificación a tu CORREO ingresa el código para verificar tu cuenta';
  @override
  String get otpSentToEmailPasswordReset => 'Se envió un código de verificación a tu CORREO ingresa el código para poder cambiar la contraseña';
  @override
  String get confirm => 'CONFIRMAR';
  @override
  String get resend => 'REENVIAR';
  @override
  String get resendWithTimer => 'REENVIAR ({time})';
  @override
  String get codeResentSuccessfully => 'Código reenviado exitosamente';
  @override
  String get failedToResendCode => 'Error al reenviar código:';
  @override
  String get enterCompleteCode => 'Por favor ingresa el código de verificación completo';
  @override
  String get verificationFailed => 'Error en la verificación:';
  
  // Chat
  @override
  String get today => 'Hoy';
  @override
  String get yesterday => 'Ayer';
  @override
  String get blockUser => 'Bloquear Usuario';
  @override
  String get tapToRetry => 'Toca para reintentar';
  @override
  String get failedToLoadImage => 'Error al cargar imagen';
  @override
  String get couldNotPlayAudio => 'No se pudo reproducir audio';
  @override
  String get downloading => 'Descargando';
  @override
  String get downloadedTo => 'Descargado a:';
  @override
  String get downloadFailed => 'Error en la descarga:';
  @override
  String get failedToSendMessage => 'Error al enviar mensaje';
  @override
  String get errorSendingMessage => 'Error al enviar mensaje:';
  @override
  String get failedToCaptureImage => 'Error al capturar imagen:';
  @override
  String get failedToPickImage => 'Error al seleccionar imagen:';
  @override
  String get failedToStartRecording => 'Error al iniciar grabación. Por favor verifica los permisos del micrófono.';
  @override
  String get checkMicrophonePermissions => 'Por favor verifica los permisos del micrófono';
  @override
  String get failedToSendVoiceMessage => 'Error al enviar mensaje de voz';
  @override
  String get errorSendingVoiceMessage => 'Error al enviar mensaje de voz:';
  
  // Common additional
  @override
  String get level => 'Nivel';
  @override
  String get pts => 'pts';
  @override
  String get session => 'Sesión';
  @override
  String get sessions => 'Sesiones';
  @override
  String get minute => 'minuto';
  @override
  String get minutesPlural => 'minutos';
  @override
  String get loginRequired => 'Por favor inicia sesión para acceder a la práctica de cuestionarios';
  
  // Chat additional
  @override
  String get chatDeletedSuccessfully => 'Chat eliminado exitosamente';
  @override
  String get failedToDeleteChat => 'Error al eliminar el chat. Por favor intenta de nuevo.';
  @override
  String get messageUnsent => 'Mensaje no enviado';
  @override
  String get downloadedToUnableToOpen => 'Descargado a: {filePath}\nNo se pudo abrir el archivo: {message}';
  
  // Profile additional
  @override
  String get activateOnThisDevice => 'Activar en este dispositivo';
  @override
  String get blockedUsers => 'Usuarios Bloqueados';
  @override
  String get manageBlockedUsers => 'Administra tus usuarios bloqueados';
  @override
  String get studentPlaceholder => 'Estudiante';
  @override
  String get editProfileButton => 'Editar Perfil';
  @override
  String get proActiveOnAnotherDevice => 'Pro activo en otro dispositivo';
  @override
  String get proSubscriptionActiveMessage => 'Tu suscripción PRO está actualmente activa en otro dispositivo. Actívala aquí para usar las funciones PRO.';
  @override
  String get proFeaturesActivated => '✅ ¡Funciones PRO activadas en este dispositivo!';
  @override
  String get failedToActivate => '❌ Error al activar';
  @override
  String get errorActivation => '❌ Error';
  @override
  String get unknownError => 'Error desconocido';
  @override
  String get logoutFailed => 'Error al cerrar sesión';
  
  // Classes additional
  @override
  String get errorLoadingSessions => 'Error al cargar sesiones:';
  @override
  String get errorJoiningSession => 'Error al unirse a la sesión:';
  @override
  String get teacherInformationNotAvailable => 'Información del profesor no disponible';
  @override
  String get unableToStartChat => 'No se pudo iniciar el chat. Por favor intenta de nuevo.';
  @override
  String get errorOpeningChat => 'Error al abrir el chat:';
  @override
  String get unableToLoadTeacherDetails => 'No se pudieron cargar los detalles del profesor';
  @override
  String get myClasses => 'MIS CLASES';
  @override
  String get noUpcomingClasses => 'No hay clases próximas';
  @override
  String get noFinishedClasses => 'No hay clases finalizadas';
  @override
  String get subscribeToSeeClasses => 'Suscríbete a un profesor para ver tus clases aquí';
  @override
  String get pullDownToRefresh => 'Desliza hacia abajo para actualizar';
  @override
  String get makeupClass => 'CLASE DE RECUPERACIÓN';
  @override
  String get cancelled => 'CANCELADA';
  @override
  String get extraClass => 'CLASE EXTRA';
  @override
  String get liveNow => 'EN VIVO AHORA';
  @override
  String get languageClass => 'Clase de';
  @override
  String get teacherNamePlaceholder => 'Profesor';
  @override
  String get yourTime => 'Tu hora';
  @override
  String get classDuration => 'Duración de la Clase';
  @override
  String get join => 'UNIRSE';
  @override
  String get waitingForMeetingLink => 'Esperando enlace de reunión';
  @override
  String get waitingForTeacherToStart => 'Esperando que el profesor inicie';
  @override
  String get startsIn => 'Comienza en';
  @override
  String get classWasCancelled => 'Esta clase fue cancelada';
  @override
  String get tapToViewTeacherAndRate => 'Toca para ver profesor y calificar';
  @override
  String get min => 'min';
  
  // Quiz additional
  @override
  String get questionCounter => 'Pregunta {current}/{total}';
  @override
  String get accuracyPercentage => '{accuracy}% Precisión';
  @override
  String get correctCheck => '¡Correcto! ✓';
  @override
  String get answerEachQuestionWithinSeconds => 'Responde cada pregunta dentro de 15 segundos. ¡Las preguntas avanzan automáticamente cuando se acaba el tiempo!';
  @override
  String get questionsAutoAdvance => '¡Las preguntas avanzan automáticamente cuando se acaba el tiempo!';
  @override
  String get yourProgressWillBeLost => 'Se perderá tu progreso. ¿Estás seguro?';
  @override
  String get sec => 'seg';
  @override
  String get ten => '10';
  @override
  String get fifteenSec => '15 seg';
  @override
  String get loginRequiredQuizPractice => 'Por favor inicia sesión para acceder a la práctica de cuestionarios';
  
  // Profile/Edit Profile
  @override
  String get editProfileTitle => 'EDITAR PERFIL';
  @override
  String get photoAddedSuccessfully => '¡Foto agregada exitosamente!';
  @override
  String get failedToUploadPhoto => 'Error al subir foto:';
  @override
  String get mainPhotoUpdated => '¡Foto principal actualizada!';
  @override
  String get failedToSetMainPhoto => 'Error al establecer foto principal:';
  @override
  String get photoDeleted => '¡Foto eliminada!';
  @override
  String get failedToDeletePhoto => 'Error al eliminar foto:';
  @override
  String get profileUpdatedSuccessfully => '¡Perfil actualizado exitosamente!';
  @override
  String get failedToUpdateProfile => 'Error al actualizar perfil:';
  @override
  String get pleaseEnterYourName => 'Por favor ingresa tu nombre';
  @override
  String get tellUsAboutYourself => 'Cuéntanos sobre ti...';
  
  // Blocked Users
  @override
  String get blockedUsersTitle => 'USUARIOS BLOQUEADOS';
  @override
  String get unblockUser => 'Desbloquear Usuario';
  @override
  String get unblockUserConfirm => 'Desbloquear';
  @override
  String get unblockUserMessage => '¿Estás seguro de que quieres desbloquear a {name}? Podrán verse nuevamente.';
  @override
  String get noBlockedUsers => 'No Hay Usuarios Bloqueados';
  @override
  String get noBlockedUsersMessage => 'Aún no has bloqueado a nadie';
  @override
  String get failedToLoadBlockedUsers => 'Error al cargar usuarios bloqueados:';
  @override
  String get userHasBeenUnblocked => '{name} ha sido desbloqueado';
  @override
  String get failedToUnblockUser => 'Error al desbloquear usuario';
  @override
  String get blockUserMessage => 'Bloquear a este usuario ocultará su perfil e impedirá que se comunique contigo.';
  @override
  String get userBlocked => 'Usuario bloqueado';
  
  // Search/Input hints
  @override
  String get searchMessages => 'Buscar mensajes...';
  @override
  String get messageHint => 'Mensaje';
  
  // Chat errors
  @override
  String get failedToUnsendMessage => 'Error al cancelar el envío del mensaje. Por favor intenta de nuevo.';
  @override
  String get failedToBlockUserTryAgain => 'Error al bloquear usuario. Por favor intenta de nuevo.';
  
  // Chat list screen
  @override
  String get messagesTitle => 'MENSAJES';
  @override
  String get showConversations => 'Mostrar Conversaciones';
  @override
  String get startNewChat => 'Iniciar Nuevo Chat';
  @override
  String get requestAccepted => '¡Solicitud aceptada!';
  @override
  String get failedToAcceptRequest => 'Error al aceptar solicitud';
  @override
  String get requestRejected => 'Solicitud rechazada';
  @override
  String get failedToRejectRequest => 'Error al rechazar solicitud';
  @override
  String get justNow => 'ahora';
  @override
  String minutesAgo(int minutes) => 'hace ${minutes}m';
  @override
  String get oneDayAgo => 'hace 1d';
  @override
  String daysAgo(int days) => 'hace ${days}d';
  @override
  String get noResultsFound => 'No se encontraron resultados';
  @override
  String get noMessagesYet => 'No hay mensajes aún';
  @override
  String get tryDifferentKeywords => 'Intenta buscar con diferentes palabras clave';
  @override
  String get startConversationWithTeachers => 'Inicia una conversación con tus profesores';
  @override
  String get chatRequestTitle => 'Solicitud de Chat';
  @override
  String get noMessageProvided => 'No se proporcionó mensaje';
  @override
  String get sentChatRequest => 'Envió una solicitud de chat';
  @override
  String get chatRequestsReceived => 'Recibidas';
  @override
  String get chatRequestsSent => 'Enviadas';
  @override
  String get chatRequestPendingStatus => 'Pendiente';
  @override
  String get deleteChat => 'Eliminar Chat';
  @override
  String get deleteChatQuestion => '¿Eliminar Chat?';
  @override
  String deleteChatConfirmation(String name) => '¿Estás seguro de que quieres eliminar este chat con $name? Esta acción no se puede deshacer.';
  @override
  String get noTeachersAvailable => 'No hay profesores disponibles';
  @override
  String get subscribeToChatWithTeachers => 'Suscríbete a un curso para chatear con profesores';
  @override
  String get imageAttachment => '🖼️ Imagen';
  @override
  String get voiceMessage => '🎤 Mensaje de voz';
  @override
  String get fileAttachment => '📎 Archivo';
  @override
  String get attachmentGeneric => '📎 Adjunto';
  @override
  String get startChatting => 'Comienza a chatear...';
  @override
  String get user => 'Usuario';
}

