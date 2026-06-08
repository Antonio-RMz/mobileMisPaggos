import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Inicia sesión con correo y contraseña.
  /// Retorna un mapa con los datos del usuario si es exitoso, o lanza una excepción.
  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      // 1. Autenticar con Firebase Auth
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = userCredential.user;
      if (user == null) {
        throw Exception('Error al obtener el usuario después del login.');
      }

      // 2. Obtener datos del usuario desde Firestore usando su UID
      DocumentSnapshot userDoc = await _firestore.collection('usuarios').doc(user.uid).get();

      if (!userDoc.exists) {
        // Por seguridad, cerramos sesión si no tiene documento en la DB
        await _auth.signOut();
        throw Exception('El usuario no tiene un perfil registrado en la base de datos.');
      }

      final data = userDoc.data() as Map<String, dynamic>;

      // 3. Verificar si está activo
      if (data['activo'] == false) {
        await _auth.signOut();
        throw Exception('El usuario está inactivo. Contacte al administrador.');
      }

      // 4. Retornar los datos combinados
      return {
        'uid': user.uid,
        'empresaId': data['empresaId'] ?? '',
        'rol': data['rol'] ?? '',
        'nombre': data['username'] ?? data['nombre'] ?? '',
      };
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-email') {
        throw Exception('Usuario no encontrado o correo inválido.');
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw Exception('Credenciales incorrectas.');
      }
      throw Exception('Error de autenticación: ${e.message}');
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  static Future<void> logout() async {
    await _auth.signOut();
  }

  static User? get currentUser => _auth.currentUser;
}
