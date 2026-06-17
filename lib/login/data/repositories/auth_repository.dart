import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/user_entity.dart';

class AuthRepository {
  final _auth = FirebaseAuth.instance;

  Future<UserEntity> signInWithEmail(
      String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user!;
    return UserEntity(
      uid: user.uid,
      displayName: user.displayName ?? '',
      email: user.email ?? '',
    );
  }
}