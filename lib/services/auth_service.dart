import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

class AuthUser {
  final String uid;
  final String email;
  final bool isEmailVerified;

  const AuthUser({
    required this.uid,
    required this.email,
    this.isEmailVerified = true,
  });
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal() {
    _init();
  }

  final _authStreamController = StreamController<AuthUser?>.broadcast();
  AuthUser? _currentSandboxUser;
  bool _initialized = false;

  bool get isSandboxMode => Firebase.apps.isEmpty;

  void _init() {
    if (_initialized) return;
    _initialized = true;
    
    if (!isSandboxMode) {
      fb.FirebaseAuth.instance.authStateChanges().listen((fbUser) {
        if (fbUser != null) {
          _authStreamController.add(AuthUser(
            uid: fbUser.uid,
            email: fbUser.email ?? '',
            isEmailVerified: fbUser.emailVerified,
          ));
        } else {
          _authStreamController.add(null);
        }
      });
    } else {
      // Default sandbox state: not logged in
      _authStreamController.add(null);
    }
  }

  Stream<AuthUser?> get onAuthStateChanged {
    if (!isSandboxMode) {
      return _authStreamController.stream;
    } else {
      // In sandbox mode, return stream with initial state and subsequent updates
      return _authStreamController.stream;
    }
  }

  AuthUser? get currentUser {
    if (!isSandboxMode) {
      final fbUser = fb.FirebaseAuth.instance.currentUser;
      if (fbUser != null) {
        return AuthUser(
          uid: fbUser.uid,
          email: fbUser.email ?? '',
          isEmailVerified: fbUser.emailVerified,
        );
      }
      return null;
    } else {
      return _currentSandboxUser;
    }
  }

  Future<String?> signIn({required String email, required String password}) async {
    if (!isSandboxMode) {
      try {
        await fb.FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        return null;
      } on fb.FirebaseAuthException catch (e) {
        return e.message ?? 'An unknown error occurred.';
      } catch (e) {
        return e.toString();
      }
    } else {
      // Sandbox validation: Allow any email ending with @example.com or any pre-auth check
      await Future.delayed(const Duration(milliseconds: 800));
      if (password.length < 6) {
        return 'Password must be at least 6 characters.';
      }
      _currentSandboxUser = AuthUser(
        uid: 'sandbox_uid_${email.hashCode}',
        email: email,
      );
      _authStreamController.add(_currentSandboxUser);
      return null;
    }
  }

  Future<String?> signUp({required String email, required String password}) async {
    if (!isSandboxMode) {
      try {
        await fb.FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        return null;
      } on fb.FirebaseAuthException catch (e) {
        return e.message ?? 'An unknown error occurred.';
      } catch (e) {
        return e.toString();
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 800));
      if (password.length < 6) {
        return 'Password must be at least 6 characters.';
      }
      _currentSandboxUser = AuthUser(
        uid: 'sandbox_uid_${email.hashCode}',
        email: email,
      );
      _authStreamController.add(_currentSandboxUser);
      return null;
    }
  }

  Future<String?> sendPasswordResetEmail({required String email}) async {
    if (!isSandboxMode) {
      try {
        await fb.FirebaseAuth.instance.sendPasswordResetEmail(email: email);
        return null;
      } on fb.FirebaseAuthException catch (e) {
        return e.message ?? 'An unknown error occurred.';
      } catch (e) {
        return e.toString();
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 500));
      return null; // Simulate success
    }
  }

  Future<void> signOut() async {
    if (!isSandboxMode) {
      await fb.FirebaseAuth.instance.signOut();
    } else {
      _currentSandboxUser = null;
      _authStreamController.add(null);
    }
  }

  Future<String?> deleteAccount() async {
    if (!isSandboxMode) {
      try {
        final user = fb.FirebaseAuth.instance.currentUser;
        if (user != null) {
          await user.delete();
          return null;
        }
        return 'No user currently logged in.';
      } on fb.FirebaseAuthException catch (e) {
        if (e.code == 'requires-recent-login') {
          return 'This operation is sensitive and requires recent authentication. Please log in again.';
        }
        return e.message ?? 'An unknown error occurred.';
      } catch (e) {
        return e.toString();
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 800));
      _currentSandboxUser = null;
      _authStreamController.add(null);
      return null;
    }
  }

  // Helper trigger to broadcast current state for initial UI listeners
  void triggerInitialState() {
    _authStreamController.add(currentUser);
  }
}
