import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/colors.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

//signup screen, same pattern as login but with extra fields and stricter validation
//note the redirect issue from login applies here too, after signup screen doesnt auto move
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  //form key lets us validate every field at once when user taps create account
  final _formKey = GlobalKey<FormState>();

  //one controller per field so we can read what the user typed
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  //two separate flags since password and confirm password have their own eye toggles
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;

  //dispose controllers when screen is removed so we dont leak memory
  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  //called when user taps create account
  void _handleSignup() async {
    //runs every validator below, returns true only if all fields pass
    if (_formKey.currentState!.validate()) {
      //listen false because we just want to call a method not rebuild on auth changes
      final authService = Provider.of<AuthService>(context, listen: false);
      //signUp handles firebase auth account creation AND writing the user doc to firestore
      //returns null on success or an error message string on failure
      final error = await authService.signUp(
        email: _emailController.text,
        password: _passwordController.text,
        username: _usernameController.text,
      );
      //mounted check since we awaited firebase, screen might have been closed in the meantime
      if (error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      //appbar with a back arrow so user can return to login
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.dark),
          //pop instead of go, since we pushed here from login we want to unstack back to it
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          //scrollable so fields stay reachable when keyboard opens on smaller screens
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [

                  //title and subtitle at the top of the form
                  const Text(
                    'Create Account',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.dark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Join NestlyQuick',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.subtext,
                    ),
                  ),
                  const SizedBox(height: 36),

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
                    //gives user the @ symbol on the keyboard
                    keyboardType: TextInputType.emailAddress,
                    //off so it doesnt try to "fix" their email address
                    autocorrect: false,
                    decoration: const InputDecoration(
                      hintText: 'you@email.com',
                      hintStyle: TextStyle(color: AppColors.subtext),
                    ),
                    //regex checks for something@something.something, basic email shape
                    //firebase also validates on its end so this is just an early check
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  //username field
                  const Text(
                    'Username',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.dark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _usernameController,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Amanda',
                      hintStyle: TextStyle(color: AppColors.subtext),
                    ),
                    //basic validation only, uniqueness check happens in auth_service signUp
                    //against firestore so we dont duplicate the network call here
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a username';
                      }
                      if (value.length < 4) {
                        return 'Username must be at least 4 characters';
                      }
                      //no spaces allowed so @mentions and search work cleanly
                      if (value.contains(' ')) {
                        return 'Username cannot contain spaces';
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
                    //obscureText hides the password as dots unless eye toggle is on
                    obscureText: !_passwordVisible,
                    decoration: InputDecoration(
                      hintText: 'Minimum 6 characters',
                      hintStyle: const TextStyle(color: AppColors.subtext),
                      //eye toggle button on the right side of the field
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
                    //6 char minimum matches firebase auths weak-password threshold
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  //confirm password field, makes sure user didnt typo their password
                  const Text(
                    'Confirm Password',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.dark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: !_confirmPasswordVisible,
                    decoration: InputDecoration(
                      hintText: 'Re-enter your password',
                      hintStyle: const TextStyle(color: AppColors.subtext),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _confirmPasswordVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.subtext,
                        ),
                        onPressed: () {
                          setState(() {
                            _confirmPasswordVisible = !_confirmPasswordVisible;
                          });
                        },
                      ),
                    ),
                    //compares against the main password controllers current text
                    //important to reference _passwordController.text here not a stored value
                    //so we get whatever they typed most recently
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 28),

                  //create account button, style comes from the app wide theme in main.dart
                  ElevatedButton(
                    onPressed: _handleSignup,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  //back to login link at the bottom for users who already have an account
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Already have an account? ',
                        style: TextStyle(
                          color: AppColors.subtext,
                          fontSize: 13,
                        ),
                      ),
                      GestureDetector(
                        //pop unstacks back to login instead of pushing a new login screen on top
                        onTap: () => context.pop(),
                        child: const Text(
                          'Log In',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
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