import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ignore: unused_element
  void _showStatusSnackBar({
    required String title,
    required String message,
    required IconData icon,
    bool isError = true,
  }) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 6,
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E293B),
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
            width: 1.5,
          ),
        ),
        duration: const Duration(seconds: 2),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(
                8,
              ), // Espacio interno alrededor del icono
              decoration: BoxDecoration(
                color: isError
                    ? const Color(0xFFFEE2E2)
                    : const Color(0xFFD1FAE5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                // Color del icono: Rojo o Verde según corresponda
                color: isError
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF10B981),
                size: 24,
              ),
            ),

            const SizedBox(
              width: 16,
            ), // Separador horizontal entre el icono y los textos
            // B) Columna para los Textos
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize
                    .min, // Ajusta la columna al tamaño mínimo requerido por su contenido
                crossAxisAlignment: CrossAxisAlignment
                    .start, // Alinea los textos a la izquierda
                children: [
                  // Título principal en negrita y color blanco
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 4,
                  ), // Separación vertical de entre título y mensaje

                  Text(
                    message,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('http://tickets.sspmichoacanlocal.gob.mx/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        
        // El token usualmente viene como 'token' o 'access_token'
        final String? token = data['token'] ?? data['access_token'];
        
        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', token);
          
          // También podemos guardar el correo o datos del usuario
          await prefs.setString('user_email', _emailController.text.trim());
          if (data['user'] != null && data['user']['nombre'] != null) {
            await prefs.setString('user_name', data['user']['nombre']);
          }
        }

        if (mounted) {
          setState(() {
            _isLoading = false;
          });

          // Mostrar mensaje de éxito
          _showStatusSnackBar(
            title: '¡Bienvenido!',
            message: 'Sesión iniciada con éxito',
            icon: Icons.check_circle_rounded,
            isError: false,
          );

          // Navega directamente a la pantalla MainScreen reemplazando el Login
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const MainScreen()),
          );
        }
      } else {
        setState(() {
          _isLoading = false;
        });

        // Intentar parsear el mensaje de error del servidor
        String errorMessage = 'Verifica tus credenciales e intenta de nuevo.';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData['message'] != null) {
            errorMessage = errorData['message'];
          } else if (errorData['error'] != null) {
            errorMessage = errorData['error'];
          }
        } catch (_) {}

        _showStatusSnackBar(
          title: 'Error de Autenticación',
          message: errorMessage,
          icon: Icons.error_outline_rounded,
          isError: true,
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      _showStatusSnackBar(
        title: 'Error de Conexión',
        message: 'No se pudo conectar al servidor. Verifica tu internet.',
        icon: Icons.wifi_off_rounded,
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Efecto Halftone (Círculos que se desvanecen)
          Positioned.fill(
            child: CustomPaint(
              painter: HalftonePainter(dotColor: const Color(0xFF0A2E5C)),
            ),
          ),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  // Logo Container con Sombra
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF0A2E5C,
                          ).withValues(alpha: 0.15),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(18),
                    child: Image.asset(
                      'assets/images/Estrella.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.security_rounded,
                        size: 60,
                        color: Color(0xFF0A2E5C),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'TICKETS SSP',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0A2E5C),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Tarjeta de Formulario con Glassmorphism ligero
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 450),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: const Color(0xFF0A2E5C).withValues(alpha: 0.05),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 40,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Bienvenido',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Por favor, ingresa tus datos',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 32),
                          _buildTextField(
                            controller: _emailController,
                            label: 'Correo Electrónico',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Ingresa tu correo';
                              }
                              // Validación del correo
                              if (!RegExp(
                                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                              ).hasMatch(value)) {
                                return 'Correo inválido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          _buildTextField(
                            controller: _passwordController,
                            label: 'Contraseña',
                            icon: Icons.lock_outline,
                            isPassword: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Ingresa tu contraseña';
                              }
                              if (value.length < 6) {
                                return 'Mínimo 6 caracteres';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0A2E5C),
                                foregroundColor: Colors.white,
                                elevation: 4,
                                shadowColor: const Color(
                                  0xFF0A2E5C,
                                ).withValues(alpha: 0.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'INICIAR SESIÓN',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Evita duplicar código repetitivo de diseño para el correo electrónico y la contraseña.
  Widget _buildTextField({
    required TextEditingController
    controller, // El controlador para leer y modificar el texto del campo
    required String
    label, // El texto de la etiqueta flotante (ej: "Correo Electrónico")
    required IconData
    icon, // El icono de la izquierda (ej: Icons.email_outlined)
    bool isPassword =
        false, // Indica si este campo debe comportarse como contraseña (ocultar texto)
    TextInputType?
    keyboardType, // El tipo de teclado móvil a mostrar (ej: teclado con '@' para correos)
    String? Function(String?)?
    validator, // Función que valida si el contenido escrito cumple con los requisitos
  }) {
    return TextFormField(
      controller: controller, // Vincula el controlador de texto
      obscureText:
          isPassword && _obscurePassword, // _obscurePassword está activo
      keyboardType: keyboardType,
      style: const TextStyle(color: Color(0xFF1E293B)),

      // Decoración visual
      decoration: InputDecoration(
        labelText: label, // Etiqueta flotante informativa
        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        prefixIcon: Icon(icon, color: const Color(0xFF0A2E5C), size: 22),

        // Icono a la derecha: se muestra SÓLO si es un campo de tipo contraseña
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  // El icono cambia dinámicamente según si la contraseña está oculta o visible
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: Colors.grey,
                  size: 20,
                ),
                // Al hacer clic, alterna el booleano y redibuja la interfaz con setState()
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              )
            : null, // Si no es contraseña, no muestra nada a la derecha

        filled: true, // Activa el color de fondo para la caja
        fillColor: const Color(0xFFF8FAFC),

        // 1. Diseño del borde cuando el campo está inactivo / habilitado
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),

        // 2. Diseño del borde cuando el usuario hace clic (se enfoca) en el campo
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFF0A2E5C), width: 1.5),
        ),

        // 3. Diseño del borde cuando hay un error de validación
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),

        // 4. Diseño del borde cuando hay un error y el usuario está enfocado corrigiendo su entrada
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),

        contentPadding: const EdgeInsets.symmetric(vertical: 18),
      ),
      validator: validator,
    );
  }
}

class HalftonePainter extends CustomPainter {
  final Color dotColor; // Color principal que tendrán los círculos

  // Constructor que recibe el color que tendrán los puntos
  HalftonePainter({required this.dotColor});

  @override
  void paint(Canvas canvas, Size size) {
    // Definimos el objeto Paint
    final paint = Paint()..style = PaintingStyle.fill;
    // Centro de la pantalla para el efecto radial
    final center = Offset(size.width / 2, size.height / 2.2);
    const double spacing = 20.0;
    // Distancia máxima para normalizar el ratio
    final double maxDistance = size.shortestSide * 0.8;

    for (double y = 0; y < size.height; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        final currentPos = Offset(x + (spacing / 2), y + (spacing / 2));

        double distance = (currentPos - center).distance;
        double ratio = (distance / maxDistance).clamp(0.0, 1.0);
        ratio = Curves.easeInQuint.transform(ratio);
        double maxRadius = spacing * 0.75;
        double currentRadius = maxRadius * ratio;

        // Opacidad proporcional al tamaño
        paint.color = dotColor.withValues(alpha: 0.05 + (0.6 * ratio));

        if (currentRadius > 0.5) {
          canvas.drawCircle(currentPos, currentRadius, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
