import 'package:material_ui/material_ui.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'citas_screen.dart';
import 'services/appointment_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AppointmentNotificationService.instance.initialize();

  runApp(const CitasMedicasApp());
}

class CitasMedicasApp extends StatelessWidget {
  const CitasMedicasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Citas Médicas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        scaffoldBackgroundColor: Colors.white,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

// Comprueba si el usuario tiene una sesión activa.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return const CitasScreen();
        }

        return const AuthScreen();
      },
    );
  }
}

// Pantalla de inicio de sesión y registro.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nombreController = TextEditingController();
  final _correoController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmarController = TextEditingController();

  bool _esRegistro = false;
  bool _cargando = false;
  bool _ocultarPassword = true;

  @override
  void dispose() {
    _nombreController.dispose();
    _correoController.dispose();
    _passwordController.dispose();
    _confirmarController.dispose();
    super.dispose();
  }

  Future<void> _autenticar() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _cargando = true;
    });

    try {
      final correo = _correoController.text.trim();
      final password = _passwordController.text.trim();

      if (_esRegistro) {
        // Crear usuario en Firebase Authentication.
        final resultado = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: correo, password: password);

        final usuario = resultado.user!;

        final nombre = _nombreController.text.trim();

        // Guardar el perfil del usuario en Firestore.
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(usuario.uid)
            .set({
              'nombre': nombre,
              'correo': correo,
              'fechaRegistro': FieldValue.serverTimestamp(),
            });

        await usuario.updateDisplayName(nombre);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Registro exitoso! Bienvenido.')),
        );
      } else {
        // Iniciar sesión.
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: correo,
          password: password,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String mensaje;

      switch (e.code) {
        case 'email-already-in-use':
          mensaje = 'Este correo ya está registrado.';
          break;
        case 'invalid-email':
          mensaje = 'El correo electrónico no es válido.';
          break;
        case 'weak-password':
          mensaje = 'La contraseña es demasiado débil.';
          break;
        case 'user-not-found':
        case 'invalid-credential':
          mensaje = 'Correo o contraseña incorrectos.';
          break;
        case 'network-request-failed':
          mensaje = 'Revisa tu conexión a Internet.';
          break;
        case 'too-many-requests':
          mensaje = 'Demasiados intentos. Inténtalo más tarde.';
          break;
        default:
          mensaje = 'No fue posible completar la operación.';
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mensaje)));
    } on FirebaseException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar el perfil: ${e.message ?? e.code}'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ocurrió un error: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _cargando = false;
        });
      }
    }
  }

  String? _validarCorreo(String? valor) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Ingresa tu correo electrónico.';
    }

    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(valor.trim())) {
      return 'Ingresa un correo válido.';
    }

    return null;
  }

  String? _validarPassword(String? valor) {
    if (valor == null || valor.isEmpty) {
      return 'Ingresa tu contraseña.';
    }

    if (_esRegistro && valor.length < 8) {
      return 'Utiliza al menos 8 caracteres.';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Citas Médicas'), centerTitle: true),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.calendar_month,
                      size: 76,
                      color: Colors.teal,
                    ),
                    const SizedBox(height: 20),

                    Text(
                      _esRegistro ? 'Crear una cuenta' : 'Bienvenido',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      _esRegistro
                          ? 'Regístrate para gestionar tus citas médicas.'
                          : 'Ingresa para consultar tus citas médicas.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18),
                    ),

                    const SizedBox(height: 30),

                    if (_esRegistro) ...[
                      TextFormField(
                        controller: _nombreController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre completo',
                          prefixIcon: Icon(Icons.person),
                        ),
                        style: const TextStyle(fontSize: 18),
                        textCapitalization: TextCapitalization.words,
                        validator: (valor) {
                          if (valor == null || valor.trim().length < 3) {
                            return 'Ingresa tu nombre completo.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                    ],

                    TextFormField(
                      controller: _correoController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico',
                        prefixIcon: Icon(Icons.email),
                      ),
                      style: const TextStyle(fontSize: 18),
                      validator: _validarCorreo,
                    ),

                    const SizedBox(height: 20),

                    TextFormField(
                      controller: _passwordController,
                      obscureText: _ocultarPassword,
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _ocultarPassword = !_ocultarPassword;
                            });
                          },
                          icon: Icon(
                            _ocultarPassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          tooltip: 'Mostrar u ocultar contraseña',
                        ),
                      ),
                      style: const TextStyle(fontSize: 18),
                      validator: _validarPassword,
                    ),

                    if (_esRegistro) ...[
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _confirmarController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Confirmar contraseña',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        style: const TextStyle(fontSize: 18),
                        validator: (valor) {
                          if (valor != _passwordController.text) {
                            return 'Las contraseñas no coinciden.';
                          }
                          return null;
                        },
                      ),
                    ],

                    const SizedBox(height: 30),

                    SizedBox(
                      height: 58,
                      child: ElevatedButton(
                        onPressed: _cargando ? null : _autenticar,
                        child: _cargando
                            ? const CircularProgressIndicator()
                            : Text(
                                _esRegistro ? 'Registrarme' : 'Iniciar sesión',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    TextButton(
                      onPressed: _cargando
                          ? null
                          : () {
                              setState(() {
                                _esRegistro = !_esRegistro;
                                _formKey.currentState?.reset();
                              });
                            },
                      child: Text(
                        _esRegistro
                            ? '¿Ya tienes una cuenta? Inicia sesión'
                            : '¿No tienes cuenta? Regístrate',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 17),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Pantalla principal después de iniciar sesión.
class InicioScreen extends StatelessWidget {
  const InicioScreen({super.key});

  Future<void> _cerrarSesion() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final usuario = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Citas Médicas'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _cerrarSesion,
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.account_circle, size: 90, color: Colors.teal),
              const SizedBox(height: 20),
              Text(
                '¡Bienvenido, ${usuario?.displayName ?? 'usuario'}!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(usuario?.email ?? '', style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 30),
              const Text(
                'Tu cuenta está activa. Próximamente podrás gestionar tus citas médicas.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 19),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton.icon(
                  onPressed: _cerrarSesion,
                  icon: const Icon(Icons.logout),
                  label: const Text(
                    'Cerrar sesión',
                    style: TextStyle(fontSize: 19),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
