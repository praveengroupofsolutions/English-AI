import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'api_service.dart';

const _ink = Color(0xFF202820);
const _muted = Color(0xFF778078);
const _paper = Color(0xFFFFFEFA);
const _canvas = Color(0xFFF7F7F2);
const _green = Color(0xFF1D513E);
const _coral = Color(0xFFE98970);
const _googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LingoApp());
}

class LingoApp extends StatelessWidget {
  const LingoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lingo — Find your voice',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _canvas,
        colorScheme: ColorScheme.fromSeed(seedColor: _green, surface: _paper),
        fontFamily: 'Arial',
        snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      ),
      home: const LingoHome(),
    );
  }
}

enum _Page { login, register, forgot, verify, reset, account }

class LingoHome extends StatefulWidget {
  const LingoHome({super.key});

  @override
  State<LingoHome> createState() => _LingoHomeState();
}

class _LingoHomeState extends State<LingoHome> {
  final _api = ApiService.instance;
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _otp = TextEditingController();
  final _photo = TextEditingController();
  final _baseUrl = TextEditingController();

  _Page _page = _Page.login;
  Map<String, dynamic>? _user;
  bool _demo = true;
  bool _busy = false;
  bool _showPassword = false;
  bool _backendOnline = false;
  bool _healthKnown = false;
  bool _editing = false;
  String _emailForReset = '';
  String _resetToken = '';
  String? _notice;
  bool _noticeError = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _otp.dispose();
    _photo.dispose();
    _baseUrl.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    final results = await Future.wait([_api.getDemoMode(), _api.getBaseUrl(), _api.hasSession()]);
    if (!mounted) return;
    setState(() {
      _demo = results[0] as bool;
      _baseUrl.text = results[1] as String;
    });
    if (_demo) {
      if (mounted) setState(() { _healthKnown = true; _backendOnline = false; });
    } else {
      await _checkHealth();
    }
    if (results[2] as bool) {
      try {
        final profile = await _api.getProfile(_demo);
        if (mounted) setState(() { _user = Map<String, dynamic>.from(profile['user'] as Map); _page = _Page.account; });
      } catch (_) {
        await _api.clearSession();
      }
    }
  }

  Future<void> _checkHealth() async {
    final health = await _api.health();
    if (mounted) setState(() { _backendOnline = health['online'] == true; _healthKnown = true; });
  }

  void _go(_Page page) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() { _page = page; _notice = null; _noticeError = false; });
  }

  void _notify(String text, {bool error = false}) {
    if (!mounted) return;
    setState(() { _notice = text; _noticeError = error; });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() { _busy = true; _notice = null; });
    try {
      await action();
    } on ApiException catch (error) {
      _notify(error.message, error: true);
    } catch (_) {
      _notify('Something went wrong. Please try again.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await _run(() async {
      final result = await _api.login(_email.text.trim(), _password.text, _demo);
      if (!mounted) return;
      setState(() { _user = Map<String, dynamic>.from(result['user'] as Map); _page = _Page.account; _editing = false; });
      if (!_demo) {
        try {
          final profile = await _api.getProfile(false);
          if (mounted) setState(() => _user = Map<String, dynamic>.from(profile['user'] as Map));
        } catch (_) {}
      }
      if (!_demo) await _checkHealth();
    });
  }

  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await _run(() async {
      final result = await _api.register(_name.text.trim(), _email.text.trim(), _password.text, _demo);
      _emailForReset = _email.text.trim();
      _password.clear();
      _go(_Page.login);
      _notify(result['message']?.toString() ?? 'Account created. Sign in to continue.');
    });
  }

  Future<void> _sendResetCode() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await _run(() async {
      final result = await _api.forgotPassword(_email.text.trim(), _demo);
      _emailForReset = _email.text.trim();
      _go(_Page.verify);
      final demoOtp = result['demoOtp'];
      _notify(demoOtp == null ? 'If the account exists, a reset code will be sent.' : 'Demo reset code: $demoOtp');
    });
  }

  Future<void> _verifyOtp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await _run(() async {
      final result = await _api.verifyOtp(_emailForReset, _otp.text.trim(), _demo);
      _resetToken = result['resetToken']?.toString() ?? '';
      _go(_Page.reset);
      _notify('Code verified. Choose a new password.');
    });
  }

  Future<void> _resetPassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await _run(() async {
      final result = await _api.resetPassword(_resetToken, _password.text, _demo);
      _password.clear();
      _go(_Page.login);
      _notify(result['message']?.toString() ?? 'Password updated. Sign in again.');
    });
  }

  Future<void> _saveProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await _run(() async {
      final result = await _api.updateProfile(_name.text.trim(), _photo.text.trim(), _demo);
      setState(() { _user = Map<String, dynamic>.from(result['user'] as Map); _editing = false; });
      _notify(result['message']?.toString() ?? 'Profile updated successfully.');
    });
  }

  Future<void> _logout() async {
    await _run(() async {
      try {
        await _api.logout(_demo);
      } catch (_) {
        await _api.clearSession();
      }
      if (!mounted) return;
      _password.clear();
      setState(() { _user = null; _page = _Page.login; _editing = false; });
      _notify('You’re signed out. See you next time.');
    });
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text('Your profile and account data will be permanently removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep account')),
          FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: const Text('Delete account')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() async {
      await _api.deleteAccount(_demo);
      await _api.clearSession();
      if (!mounted) return;
      setState(() { _user = null; _page = _Page.login; _editing = false; });
      _notify('Your account has been deleted.');
    });
  }

  Future<void> _toggleMode(bool demo) async {
    await _api.setDemoMode(demo);
    if (mounted) setState(() { _demo = demo; _notice = demo ? 'Demo mode is on. Changes stay on this device.' : 'Live API mode is on.'; _noticeError = false; });
    if (demo) {
      if (mounted) setState(() { _healthKnown = true; _backendOnline = false; });
    } else {
      await _checkHealth();
    }
  }

  Future<void> _openSettings() async {
    _baseUrl.text = await _api.getBaseUrl();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _paper,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (context) => StatefulBuilder(builder: (context, setSheetState) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(22, 12, 22, MediaQuery.of(context).viewInsets.bottom + 22),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: const Color(0xFFD5D9D0), borderRadius: BorderRadius.circular(4)))),
              const SizedBox(height: 22),
              const Text('Connection settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _ink)),
              const SizedBox(height: 6),
              const Text('Choose where account requests should go.', style: TextStyle(color: _muted, fontSize: 13)),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: _modeChoice('Live API', !_demo, () async { await _toggleMode(false); setSheetState(() {}); })),
                const SizedBox(width: 10),
                Expanded(child: _modeChoice('Demo', _demo, () async { await _toggleMode(true); setSheetState(() {}); })),
              ]),
              const SizedBox(height: 17),
              _textField(controller: _baseUrl, label: 'Backend URL', hint: 'http://localhost:5000', icon: Icons.link_rounded, keyboardType: TextInputType.url),
              const SizedBox(height: 7),
              Text('Android emulator default: ${_api.defaultBaseUrl}', style: const TextStyle(color: _muted, fontSize: 10)),
              const SizedBox(height: 17),
              SizedBox(width: double.infinity, child: FilledButton.icon(
                onPressed: () async {
                  await _api.setBaseUrl(_baseUrl.text);
                  await _checkHealth();
                  if (context.mounted) Navigator.pop(context);
                  _notify(_backendOnline ? 'Connected to backend.' : 'Saved URL. Backend is not reachable yet.', error: !_backendOnline);
                },
                icon: const Icon(Icons.wifi_tethering_rounded, size: 17),
                label: const Text('Save and test connection'),
                style: FilledButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white, minimumSize: const Size(0, 46)),
              )),
              const SizedBox(height: 8),
              const Text('Google sign-in requires a configured Google client ID on the backend.', style: TextStyle(color: _muted, fontSize: 10)),
            ]),
          ),
        );
      }),
    );
  }

  Widget _modeChoice(String label, bool selected, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? _green : _muted,
        backgroundColor: selected ? const Color(0xFFEDF3E9) : _paper,
        side: BorderSide(color: selected ? const Color(0xFFB9CFB9) : const Color(0xFFE2E4DC)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [if (selected) const Icon(Icons.check_circle_rounded, size: 15), if (selected) const SizedBox(width: 6), Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))]),
    );
  }

  Future<void> _googleSignIn() async {
    if (!_demo) {
      if (_googleClientId.isEmpty) {
        _notify('Add a Google OAuth client ID with --dart-define=GOOGLE_CLIENT_ID=… to enable Google sign-in.', error: true);
        return;
      }
      await _run(() async {
        await GoogleSignIn.instance.initialize(
          clientId: kIsWeb ? _googleClientId : null,
          serverClientId: kIsWeb ? null : _googleClientId,
        );
        final account = await GoogleSignIn.instance.authenticate();
        final idToken = account.authentication.idToken;
        if (idToken == null) throw const ApiException('Google did not return an ID token.');
        final result = await _api.googleLogin(idToken, false);
        if (mounted) setState(() { _user = Map<String, dynamic>.from(result['user'] as Map); _page = _Page.account; });
      });
      return;
    }
    await _run(() async {
      final result = await _api.googleLogin('', true);
      if (mounted) setState(() { _user = Map<String, dynamic>.from(result['user'] as Map); _page = _Page.account; });
      _notify('Signed in with the demo Google account.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final showAccount = _page == _Page.account;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          _buildTopbar(),
          if (_notice != null) _buildNotice(),
          Expanded(child: showAccount ? _buildAccount() : _buildAuth()),
        ]),
      ),
    );
  }

  Widget _buildTopbar() {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(color: _paper, border: Border(bottom: BorderSide(color: Color(0xFFEEEFE8)))),
      child: Row(children: [
        InkWell(
          onTap: () => _go(_Page.login),
          borderRadius: BorderRadius.circular(8),
          child: const Row(children: [
            _BrandMark(size: 32),
            SizedBox(width: 9),
            Text('lingo', style: TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 21, letterSpacing: -.7)),
            Text('.', style: TextStyle(color: _coral, fontWeight: FontWeight.w800, fontSize: 23)),
          ]),
        ),
        const Spacer(),
        if (_healthKnown && !_demo) ...[
          _StatusLabel(online: _backendOnline),
          const SizedBox(width: 14),
        ],
        if (_healthKnown && _demo) ...[
          const _DemoLabel(),
          const SizedBox(width: 10),
        ],
        IconButton(onPressed: _openSettings, tooltip: 'Connection settings', icon: const Icon(Icons.tune_rounded, color: Color(0xFF526456), size: 20)),
      ]),
    );
  }

  Widget _buildNotice() {
    final color = _noticeError ? const Color(0xFF9D4935) : const Color(0xFF285C3E);
    final background = _noticeError ? const Color(0xFFFFF5EF) : const Color(0xFFF0F7ED);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: background,
      child: Row(children: [Icon(_noticeError ? Icons.info_outline_rounded : Icons.check_circle_outline_rounded, color: color, size: 17), const SizedBox(width: 9), Expanded(child: Text(_notice!, style: TextStyle(color: color, fontSize: 12))), IconButton(visualDensity: VisualDensity.compact, onPressed: () => setState(() => _notice = null), icon: Icon(Icons.close, color: color, size: 16))]),
    );
  }

  Widget _buildAuth() {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth > 900 && constraints.maxHeight > 630;
      if (wide) {
        return Row(children: [
          const Expanded(flex: 9, child: _StoryPanel()),
          Expanded(flex: 11, child: _authForm(wide: true)),
        ]);
      }
      return _authForm(wide: false);
    });
  }

  Widget _authForm({required bool wide}) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 470),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(wide ? 40 : 24, wide ? 42 : 27, wide ? 40 : 24, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (!wide) const _MobileKicker(),
            if (_page == _Page.login) _buildLogin(),
            if (_page == _Page.register) _buildRegister(),
            if (_page == _Page.forgot) _buildForgot(),
            if (_page == _Page.verify) _buildVerify(),
            if (_page == _Page.reset) _buildReset(),
            const SizedBox(height: 28),
            const _PageFooter(),
          ]),
        ),
      ),
    );
  }

  Widget _buildLogin() {
    return Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _Eyebrow('WELCOME BACK'),
      const SizedBox(height: 13),
      const _DisplayTitle('Pick up where\nyou left off.'),
      const SizedBox(height: 9),
      const _Intro('Your next great conversation is just ahead.'),
      const SizedBox(height: 26),
      _textField(controller: _email, label: 'Email address', hint: 'you@example.com', icon: Icons.mail_outline_rounded, keyboardType: TextInputType.emailAddress, validator: _validateEmail),
      const SizedBox(height: 16),
      _textField(controller: _password, label: 'Password', hint: 'Enter your password', icon: Icons.lock_outline_rounded, obscure: !_showPassword, validator: (value) => value == null || value.isEmpty ? 'Enter your password' : null, trailing: IconButton(visualDensity: VisualDensity.compact, tooltip: _showPassword ? 'Hide password' : 'Show password', onPressed: () => setState(() => _showPassword = !_showPassword), icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 19, color: _muted))),
      const SizedBox(height: 11),
      Row(children: [const Icon(Icons.verified_user_outlined, size: 14, color: Color(0xFF8A928A)), const SizedBox(width: 5), const Expanded(child: Text('Your account is secure', style: TextStyle(color: Color(0xFF8A928A), fontSize: 10))), TextButton(onPressed: () => _go(_Page.forgot), style: _quietButtonStyle, child: const Text('Forgot password?'))]),
      const SizedBox(height: 9),
      _primaryButton('Sign in', Icons.arrow_forward_rounded, _login),
      const SizedBox(height: 13),
      _googleButton(),
      const SizedBox(height: 20),
      Center(child: Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [const Text('New around here? ', style: TextStyle(color: _muted, fontSize: 12)), TextButton(onPressed: () => _go(_Page.register), style: _quietButtonStyle, child: const Text('Create an account  →'))])),
    ]));
  }

  Widget _buildRegister() {
    return Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _Eyebrow('A FRESH START'),
      const SizedBox(height: 13),
      const _DisplayTitle('Make room\nfor more.'),
      const SizedBox(height: 9),
      const _Intro('Create your account and start finding your flow.'),
      const SizedBox(height: 25),
      _textField(controller: _name, label: 'Your name', hint: 'How should we call you?', icon: Icons.person_outline_rounded, validator: (value) => value == null || value.trim().length < 2 ? 'Name must be at least 2 characters' : null),
      const SizedBox(height: 15),
      _textField(controller: _email, label: 'Email address', hint: 'you@example.com', icon: Icons.mail_outline_rounded, keyboardType: TextInputType.emailAddress, validator: _validateEmail),
      const SizedBox(height: 15),
      _textField(controller: _password, label: 'Create a password', hint: 'At least 8 characters', icon: Icons.lock_outline_rounded, obscure: !_showPassword, validator: (value) => value == null || value.length < 8 ? 'Use at least 8 characters' : null, trailing: IconButton(visualDensity: VisualDensity.compact, onPressed: () => setState(() => _showPassword = !_showPassword), icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 19, color: _muted))),
      const SizedBox(height: 11),
      const Row(children: [Icon(Icons.check_circle_outline, size: 14, color: _green), SizedBox(width: 5), Text('Use at least 8 characters', style: TextStyle(color: _muted, fontSize: 10))]),
      const SizedBox(height: 17),
      _primaryButton('Create account', Icons.arrow_forward_rounded, _register),
      const SizedBox(height: 18),
      Center(child: Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [const Text('Already have an account? ', style: TextStyle(color: _muted, fontSize: 12)), TextButton(onPressed: () => _go(_Page.login), style: _quietButtonStyle, child: const Text('Sign in  →'))])),
    ]));
  }

  Widget _buildForgot() {
    return Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _backButton('Back to sign in', () => _go(_Page.login)),
      const SizedBox(height: 14),
      const _StepIcon(Icons.key_rounded),
      const SizedBox(height: 20),
      const _Eyebrow('ACCOUNT RECOVERY  ·  01 / 03'),
      const SizedBox(height: 13),
      const _DisplayTitle('Let’s get you\nback in.'),
      const SizedBox(height: 9),
      const _Intro('Enter your account email. We’ll send a one-time code if there’s a match.'),
      const SizedBox(height: 25),
      _textField(controller: _email, label: 'Email address', hint: 'you@example.com', icon: Icons.mail_outline_rounded, keyboardType: TextInputType.emailAddress, validator: _validateEmail),
      const SizedBox(height: 18),
      _primaryButton('Send reset code', Icons.arrow_forward_rounded, _sendResetCode),
    ]));
  }

  Widget _buildVerify() {
    return Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _backButton('Change email', () => _go(_Page.forgot)),
      const SizedBox(height: 14),
      const _StepIcon(Icons.mail_outline_rounded),
      const SizedBox(height: 20),
      const _Eyebrow('ACCOUNT RECOVERY  ·  02 / 03'),
      const SizedBox(height: 13),
      const _DisplayTitle('Check your\ninbox.'),
      const SizedBox(height: 9),
      Text.rich(TextSpan(style: const TextStyle(color: _muted, fontSize: 13, height: 1.6), children: [const TextSpan(text: 'Enter the six-digit code sent to '), TextSpan(text: _emailForReset, style: const TextStyle(color: Color(0xFF394D3F), fontWeight: FontWeight.w700)), const TextSpan(text: '. It expires in 10 minutes.') ])),
      const SizedBox(height: 25),
      _textField(controller: _otp, label: '6-digit code', hint: '000000', icon: Icons.pin_outlined, keyboardType: TextInputType.number, maxLength: 6, validator: (value) => value == null || !RegExp(r'^\d{6}$').hasMatch(value) ? 'Enter the 6-digit code' : null),
      const SizedBox(height: 18),
      _primaryButton('Verify code', Icons.arrow_forward_rounded, _verifyOtp),
      Center(child: TextButton(onPressed: () { _email.text = _emailForReset; _go(_Page.forgot); }, style: _quietButtonStyle, child: const Text('Send a new code'))),
    ]));
  }

  Widget _buildReset() {
    return Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _StepIcon(Icons.verified_user_outlined),
      const SizedBox(height: 20),
      const _Eyebrow('ACCOUNT RECOVERY  ·  03 / 03'),
      const SizedBox(height: 13),
      const _DisplayTitle('A new key.\nA fresh start.'),
      const SizedBox(height: 9),
      const _Intro('Choose a strong password you haven’t used here before.'),
      const SizedBox(height: 25),
      _textField(controller: _password, label: 'New password', hint: 'At least 8 characters', icon: Icons.lock_outline_rounded, obscure: !_showPassword, validator: (value) => value == null || value.length < 8 ? 'Use at least 8 characters' : null, trailing: IconButton(visualDensity: VisualDensity.compact, onPressed: () => setState(() => _showPassword = !_showPassword), icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 19, color: _muted))),
      const SizedBox(height: 18),
      _primaryButton('Update password', Icons.arrow_forward_rounded, _resetPassword),
    ]));
  }

  Widget _googleButton() {
    return OutlinedButton.icon(
      onPressed: _busy ? null : _googleSignIn,
      icon: const Icon(Icons.g_mobiledata_rounded, size: 23),
      label: Text(_demo ? 'Continue with Google · demo' : 'Continue with Google'),
      style: OutlinedButton.styleFrom(foregroundColor: _ink, backgroundColor: _paper, side: const BorderSide(color: Color(0xFFE0E2D9)), minimumSize: const Size(double.infinity, 45), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)), textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11)),
    );
  }

  Widget _textField({required TextEditingController controller, required String label, required String hint, required IconData icon, TextInputType? keyboardType, String? Function(String?)? validator, bool obscure = false, int? maxLength, Widget? trailing}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Color(0xFF354239), fontSize: 12, fontWeight: FontWeight.w700)),
      const SizedBox(height: 7),
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        maxLength: maxLength,
        validator: validator,
        style: const TextStyle(color: _ink, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFFA2A9A0), fontSize: 12),
          prefixIcon: Icon(icon, color: const Color(0xFF879087), size: 18),
          suffixIcon: trailing,
          counterText: '',
          filled: true,
          fillColor: _paper,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: Color(0xFFDEDFD7))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: Color(0xFFDEDFD7))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: Color(0xFF70917B), width: 1.4)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: Color(0xFFD17B66))),
          focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: Color(0xFFD17B66), width: 1.4)),
        ),
      ),
    ]);
  }

  String? _validateEmail(String? value) {
    if (value == null || !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())) return 'Enter a valid email address';
    return null;
  }

  Widget _primaryButton(String label, IconData icon, Future<void> Function() action) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        onPressed: _busy ? null : action,
        style: FilledButton.styleFrom(backgroundColor: _green, foregroundColor: _paper, disabledBackgroundColor: _green.withValues(alpha: .65), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7))),
        child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)), const SizedBox(width: 8), Icon(icon, size: 17)]),
      ),
    );
  }

  Widget _backButton(String label, VoidCallback action) {
    return TextButton.icon(onPressed: action, icon: const Icon(Icons.arrow_back_rounded, size: 16), label: Text(label), style: TextButton.styleFrom(foregroundColor: const Color(0xFF68736A), padding: EdgeInsets.zero, textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)));
  }

  ButtonStyle get _quietButtonStyle => TextButton.styleFrom(foregroundColor: _green, padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4), textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700));

  Widget _buildAccount() {
    final user = _user ?? <String, dynamic>{};
    return LayoutBuilder(builder: (context, constraints) {
      final narrow = constraints.maxWidth < 720;
      return SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: narrow ? 18 : 36, vertical: narrow ? 26 : 42),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1060),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const _Eyebrow('YOUR SPACE'), const SizedBox(height: 9), Text('Good to have you, ${_firstName(user['name']?.toString())}.', style: const TextStyle(fontFamily: 'Georgia', color: _ink, fontSize: 32, height: 1.15)), const SizedBox(height: 6), const Text('Keep your account details up to date.', style: TextStyle(color: _muted, fontSize: 12))])),
                const SizedBox(width: 12),
                OutlinedButton.icon(onPressed: _busy ? null : _logout, icon: const Icon(Icons.logout_rounded, size: 16), label: const Text('Sign out'), style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF425046), backgroundColor: _paper, side: const BorderSide(color: Color(0xFFDFE2D9)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)), textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
              ]),
              const SizedBox(height: 22),
              if (narrow) ...[
                _profileSummary(user),
                const SizedBox(height: 14),
                _profileSettings(user),
              ] else Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 270, child: _profileSummary(user)),
                const SizedBox(width: 18),
                Expanded(child: _profileSettings(user)),
              ]),
              const SizedBox(height: 26),
              const _PageFooter(),
            ]),
          ),
        ),
      );
    });
  }

  String _firstName(String? value) => value?.trim().split(RegExp(r'\s+')).first ?? 'friend';

  Widget _profileSummary(Map<String, dynamic> user) {
    final photo = user['photo']?.toString() ?? '';
    final name = user['name']?.toString() ?? 'Learner';
    final verified = user['isEmailVerified'] == true;
    return _Panel(child: Column(children: [
      Stack(alignment: Alignment.bottomRight, children: [
        CircleAvatar(radius: 39, backgroundColor: const Color(0xFFDBE8D9), foregroundImage: photo.startsWith('http') ? NetworkImage(photo) : null, child: photo.startsWith('http') ? null : Text(name.isEmpty ? 'L' : name.substring(0, 1).toUpperCase(), style: const TextStyle(fontFamily: 'Georgia', color: _green, fontSize: 30))),
        Container(width: 22, height: 22, decoration: BoxDecoration(color: const Color(0xFF6FA77B), shape: BoxShape.circle, border: Border.all(color: _paper, width: 2)), child: const Icon(Icons.check, size: 13, color: Colors.white)),
      ]),
      const SizedBox(height: 13),
      Text(name, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Georgia', fontSize: 21, color: _ink)),
      const SizedBox(height: 4),
      Text(user['email']?.toString() ?? '', textAlign: TextAlign.center, style: const TextStyle(color: _muted, fontSize: 11)),
      const SizedBox(height: 13),
      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: const Color(0xFFEFF4EB), borderRadius: BorderRadius.circular(5)), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.auto_awesome, color: Color(0xFF587354), size: 14), SizedBox(width: 6), Text('YOUR LEARNING SPACE', style: TextStyle(color: Color(0xFF49654C), fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: .4))])),
      const SizedBox(height: 20),
      const Divider(height: 1, color: Color(0xFFECEEE7)),
      const SizedBox(height: 15),
      _statusRow('Account status', 'Active', active: true),
      const SizedBox(height: 13),
      _statusRow('Email verified', verified ? 'Yes' : 'Pending', active: verified),
    ]));
  }

  Widget _statusRow(String label, String value, {required bool active}) {
    return Row(children: [Expanded(child: Text(label, style: const TextStyle(color: _muted, fontSize: 10))), if (active) Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF65A77D), shape: BoxShape.circle)), if (active) const SizedBox(width: 6), Text(value, style: const TextStyle(color: Color(0xFF3C4C40), fontSize: 10, fontWeight: FontWeight.w700))]);
  }

  Widget _profileSettings(Map<String, dynamic> user) {
    return _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ _Eyebrow('PERSONAL DETAILS'), SizedBox(height: 7), Text('Profile settings', style: TextStyle(fontFamily: 'Georgia', fontSize: 23, color: _ink)) ])),
        if (!_editing) OutlinedButton.icon(onPressed: () { _name.text = user['name']?.toString() ?? ''; _photo.text = user['photo']?.toString() ?? ''; setState(() { _editing = true; }); }, icon: const Icon(Icons.edit_outlined, size: 15), label: const Text('Edit profile'), style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF425046), backgroundColor: _paper, side: const BorderSide(color: Color(0xFFDFE2D9)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)), textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700))),
      ]),
      const SizedBox(height: 17),
      const Divider(height: 1, color: Color(0xFFECEEE7)),
      if (_editing) ...[
        const SizedBox(height: 19),
        Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _textField(controller: _name, label: 'Display name', hint: 'Your name', icon: Icons.person_outline_rounded, validator: (value) => value == null || value.trim().length < 2 ? 'Name must be at least 2 characters' : null),
          const SizedBox(height: 15),
          _textField(controller: _photo, label: 'Photo URL', hint: 'https://example.com/photo.jpg', icon: Icons.link_rounded, keyboardType: TextInputType.url, validator: (value) => value != null && value.isNotEmpty && !value.startsWith('http') ? 'Use a valid HTTP(S) photo URL' : null),
          const Padding(padding: EdgeInsets.only(top: 6), child: Text('Use a public image URL, or leave empty for your initials.', style: TextStyle(color: _muted, fontSize: 10))),
          const SizedBox(height: 18),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [TextButton(onPressed: () => setState(() => _editing = false), child: const Text('Cancel')), const SizedBox(width: 7), FilledButton.icon(onPressed: _busy ? null : _saveProfile, icon: _busy ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check, size: 16), label: const Text('Save changes'), style: FilledButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white))]),
        ])),
      ] else ...[
        _detail('Full name', user['name']?.toString() ?? '—'),
        _detail('Email address', user['email']?.toString() ?? '—'),
        _detail('Member since', _memberSince(user['createdAt']?.toString())),
        _detail('Profile photo', (user['photo']?.toString().isNotEmpty ?? false) ? 'Added' : 'Not set', last: true),
      ],
      const SizedBox(height: 14),
      Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: const Color(0xFFF7F9F3), border: Border.all(color: const Color(0xFFE5EBDF)), borderRadius: BorderRadius.circular(6)), child: const Row(children: [Icon(Icons.shield_outlined, color: Color(0xFF527051), size: 19), SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Your details are yours.', style: TextStyle(color: Color(0xFF435345), fontSize: 11, fontWeight: FontWeight.w700)), SizedBox(height: 3), Text('We only use this information to keep your account up to date.', style: TextStyle(color: _muted, fontSize: 10, height: 1.4))]))])),
      const SizedBox(height: 20),
      const Divider(height: 1, color: Color(0xFFECEEE7)),
      const SizedBox(height: 15),
      Wrap(alignment: WrapAlignment.spaceBetween, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Delete account', style: TextStyle(color: Color(0xFF59433E), fontSize: 11, fontWeight: FontWeight.w700)), SizedBox(height: 4), Text('Permanently remove your profile and account data.', style: TextStyle(color: Color(0xFF8B8D85), fontSize: 9))]),
        OutlinedButton.icon(onPressed: _busy ? null : _deleteAccount, icon: const Icon(Icons.delete_outline_rounded, size: 15), label: const Text('Delete account'), style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFA25542), backgroundColor: const Color(0xFFFFFAF7), side: const BorderSide(color: Color(0xFFF0DBD3)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)), textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700))),
      ]),
    ]));
  }

  Widget _detail(String label, String value, {bool last = false}) {
    return Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 13), decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: Color(0xFFF0F0EB)))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Color(0xFF858E85), fontSize: 10)), const SizedBox(height: 5), Text(value, style: const TextStyle(color: Color(0xFF37453A), fontSize: 12, fontWeight: FontWeight.w600))]));
  }

  String _memberSince(String? value) {
    if (value == null) return 'Recently joined';
    final date = DateTime.tryParse(value);
    if (date == null) return 'Recently joined';
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${months[date.month - 1]} ${date.year}';
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => Container(width: size, height: size, decoration: const BoxDecoration(color: _green, borderRadius: BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10), bottomRight: Radius.circular(10), bottomLeft: Radius.circular(3))), child: Icon(Icons.language_rounded, size: size * .58, color: _paper));
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.online});
  final bool online;

  @override
  Widget build(BuildContext context) => Row(children: [Container(width: 7, height: 7, decoration: BoxDecoration(color: online ? const Color(0xFF65A77D) : const Color(0xFFD89764), shape: BoxShape.circle)), const SizedBox(width: 7), Text(online ? 'API connected' : 'API unavailable', style: const TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.w600))]);
}

class _DemoLabel extends StatelessWidget {
  const _DemoLabel();

  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: const Color(0xFFF1F4E9), borderRadius: BorderRadius.circular(5)), child: const Row(children: [Icon(Icons.auto_awesome, size: 12, color: _green), SizedBox(width: 5), Text('DEMO', style: TextStyle(color: _green, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: .5))]));
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(color: Color(0xFF7F8980), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.2));
}

class _DisplayTitle extends StatelessWidget {
  const _DisplayTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(fontFamily: 'Georgia', color: _ink, fontSize: 39, height: 1.08, fontWeight: FontWeight.w400, letterSpacing: -.6));
}

class _Intro extends StatelessWidget {
  const _Intro(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(color: _muted, fontSize: 12, height: 1.6));
}

class _StepIcon extends StatelessWidget {
  const _StepIcon(this.icon);
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(width: 47, height: 47, decoration: const BoxDecoration(color: Color(0xFFEAF1E7), borderRadius: BorderRadius.only(topLeft: Radius.circular(13), topRight: Radius.circular(13), bottomRight: Radius.circular(13), bottomLeft: Radius.circular(4))), child: Icon(icon, color: _green, size: 22));
}

class _PageFooter extends StatelessWidget {
  const _PageFooter();

  @override
  Widget build(BuildContext context) => const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('© 2026 Lingo', style: TextStyle(color: Color(0xFF969C94), fontSize: 9)), Flexible(child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [Icon(Icons.shield_outlined, color: Color(0xFF969C94), size: 12), SizedBox(width: 5), Flexible(child: Text('Thoughtful practice. Private by design.', textAlign: TextAlign.right, style: TextStyle(color: Color(0xFF969C94), fontSize: 9))) ]))]);
}

class _MobileKicker extends StatelessWidget {
  const _MobileKicker();

  @override
  Widget build(BuildContext context) => const Padding(padding: EdgeInsets.only(bottom: 31), child: Row(children: [Icon(Icons.auto_awesome, size: 15, color: _coral), SizedBox(width: 7), Text('A better way to practice', style: TextStyle(color: Color(0xFF708173), fontSize: 11, fontWeight: FontWeight.w700))]));
}

class _StoryPanel extends StatelessWidget {
  const _StoryPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 650),
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(color: _green),
      child: Stack(children: [
        Positioned(right: -170, top: 30, child: _CircleDecoration(size: 300)),
        Positioned(right: 40, bottom: -260, child: _CircleDecoration(size: 380, coral: true)),
        Positioned.fill(child: Opacity(opacity: .08, child: CustomPaint(painter: _DotPainter()))),
        Padding(padding: const EdgeInsets.fromLTRB(52, 58, 42, 38), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          const Row(children: [SizedBox(width: 20, child: Divider(color: _coral, thickness: 1)), SizedBox(width: 9), Text('YOUR NEXT CHAPTER STARTS HERE', style: TextStyle(color: Color(0xFFB8CDB8), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.1))]),
          const SizedBox(height: 27),
          Text.rich(const TextSpan(style: TextStyle(fontFamily: 'Georgia', fontSize: 51, height: 1.06, color: Color(0xFFF4F4E9)), children: [TextSpan(text: 'Find your voice.\n'), TextSpan(text: 'In any language.', style: TextStyle(color: Color(0xFFF0A08A), fontStyle: FontStyle.italic))])),
          const SizedBox(height: 17),
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 340), child: const Text('A little practice every day can change the way the world hears you.', style: TextStyle(color: Color(0xFFD0DED2), fontSize: 13, height: 1.7))),
          const SizedBox(height: 53),
          const Text('“', style: TextStyle(fontFamily: 'Georgia', color: _coral, fontSize: 56, height: .7)),
          const SizedBox(height: 11),
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 340), child: const Text('Confidence isn’t found. It’s built, one conversation at a time.', style: TextStyle(fontFamily: 'Georgia', color: Color(0xFFE9EEE5), fontSize: 19, height: 1.45))),
          const SizedBox(height: 31),
          Row(children: [
            _avatar('M', const Color(0xFFEDB6A4)),
            Transform.translate(offset: const Offset(-5, 0), child: _avatar('A', const Color(0xFFD9C795))),
            Transform.translate(offset: const Offset(-10, 0), child: _avatar('J', const Color(0xFFA9C3B1))),
            const SizedBox(width: 3),
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Made for curious minds', style: TextStyle(color: Color(0xFFB9CDBD), fontSize: 9)), Text('Ready for what’s next', style: TextStyle(color: Color(0xFFF3F4E9), fontSize: 9, fontWeight: FontWeight.w700))]),
            const Spacer(),
            Container(width: 34, height: 34, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0x66A8C1A5))), child: const Icon(Icons.auto_awesome, color: Color(0xFFEFaa92), size: 17)),
          ]),
        ])),
      ]),
    );
  }

  Widget _avatar(String letter, Color color) => Container(width: 26, height: 26, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: _green, width: 2)), alignment: Alignment.center, child: Text(letter, style: const TextStyle(color: Color(0xFF4C4137), fontSize: 9, fontWeight: FontWeight.w800)));
}

class _CircleDecoration extends StatelessWidget {
  const _CircleDecoration({required this.size, this.coral = false});
  final double size;
  final bool coral;

  @override
  Widget build(BuildContext context) => Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: coral ? const Color(0x20F3BE9E) : const Color(0x20C5D8C5)), boxShadow: [BoxShadow(color: coral ? const Color(0x08F3BE9E) : const Color(0x08C5D8C5), spreadRadius: 35)]));
}

class _DotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFBBD0B6);
    for (var x = 12.0; x < size.width; x += 19) {
      for (var y = 12.0; y < size.height; y += 19) {
        canvas.drawCircle(Offset(x, y), .7, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(23), decoration: BoxDecoration(color: _paper, border: Border.all(color: const Color(0xFFE6E7DF)), borderRadius: BorderRadius.circular(8)), child: child);
}