import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../services/auth_service.dart';
//stuff to fix after login screen doesnt redirect have to click different button for it to work
//router probably messed up
//same with create accoutn  and logout

//stateful because we need to track password visibility toggle and form state
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  //form key lets us validate all fields at once when the user taps log in
  final _formKey = GlobalKey<FormState>();

  //controllers let us read what the user typed in each field
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  //tracks if password field shows dots or plain text
  bool _passwordVisible = false;

  //dispose controllers when screen is removed so we dont leak memory
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  //called when user taps log in
  //login itself works redirect isnt working yet
  void _handleLogin() async {
    //validate runs every validator on the form, returns true if all pass
    if (_formKey.currentState!.validate()) {
      //lists false because were just calling a method not rebuilding on auth changes here
      final authService = Provider.of<AuthService>(context, listen: false);
      final error = await authService.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );
      // check in case the screen was disposed while we awaited firebase
      if (error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
    }
  }

  //opens the forgot password dialog popup
  void _showForgotPasswordDialog(BuildContext context) {
    //controller lives inside this function so it gets cleaned up when dialog closes
    final resetEmailController = TextEditingController();
    showDialog(
      context: context,
      //dialogContext is separate from the screen context so we can pop just the dialog
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Reset Password',
          style: TextStyle(color: AppColors.dark, fontSize: 16),
        ),
        content: TextField(
          controller: resetEmailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            hintText: 'Enter your email',
          ),
        ),
        actions: [
          TextButton(
            //pop just closes the dialog doesnt navigate anywhere
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.subtext),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final authService = Provider.of<AuthService>(context, listen: false);
              //firebase sends the reset email error comes back as a string or null
              final error = await authService.sendPasswordReset(
                email: resetEmailController.text,
              );
              //close dialog first then show the snackbar on the screen behind it
              Navigator.pop(dialogContext);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(// those lil medssages that fade away
                    //?? means if error is null use the success message instead
                    content: Text(error ?? 'Password reset link sent — check your email'),
                  ),
                );
              }
            },
            child: const Text('Send Link'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      //safearea keeps the content out from under the status bar and notch got it working
      body: SafeArea(
        child: Center(
          //scroll view so the form still works when keyboard pops up
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            //form wraps the fields so the _formKey can validate them all together
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                //stretch makes buttons and fields fill the horizontal space
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [

                  //app logo image
                  const SizedBox(height: 20),
                  Image.asset(
                    'assets/nestlyquickWithWriting.png',
                    height: 200,
                  ),
                  const SizedBox(height: 48),

                  //email field
                  const Text(
                    'Email',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.dark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _emailController,
                    //this gives the user the @ symbol on their keyboard automatically
                    keyboardType: TextInputType.emailAddress,
                    //autocorrect off so it doesnt try to fix their email address lol
                    autocorrect: false,
                    decoration: const InputDecoration(
                      hintText: 'your@email.com',
                      hintStyle: TextStyle(color: AppColors.subtext),
                    ),
                    //validator runs when _formKey.currentState.validate() is called
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  //password field
                  const Text(
                    'Password',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.dark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _passwordController,
                    //obscureText hides the password as dots unless the eye is toggled
                    obscureText: !_passwordVisible,
                    decoration: InputDecoration(
                      hintText: '••••••••',
                      hintStyle: const TextStyle(color: AppColors.subtext),
                      //eyeball button on the right side of the field
                      suffixIcon: IconButton(
                        icon: Icon(
                          _passwordVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.subtext,
                        ),
                        //setState triggers a rebuild so the icon and text swap
                        onPressed: () {
                          setState(() {
                            _passwordVisible = !_passwordVisible;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),

                  //forgot password link right aligned under the password field
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => _showForgotPasswordDialog(context),
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  //log in button, style comes from the app wide theme in main.dart
                  ElevatedButton(
                    onPressed: _handleLogin,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Log In',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  //or divider between log in and create account
                  Row(
                    children: [
                      //expanded makes each divider take up equal space on either side of the text
                      const Expanded(child: Divider(color: AppColors.border)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'or',
                          style: TextStyle(
                            color: AppColors.subtext,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider(color: AppColors.border)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  //create account button push not go so the user can back button to login
                  OutlinedButton(
                    onPressed: () => context.push('/signup'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.border),
                      foregroundColor: AppColors.dark,
                    ),
                    child: const Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}