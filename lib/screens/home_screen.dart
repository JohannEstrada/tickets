import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Contenedor del Icono de bienvenida
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0A2E5C).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.support_agent_rounded, // Icono representativo de Soporte
                size: 80,
                color: Color(0xFF0A2E5C),
              ),
            ),
            const SizedBox(height: 24),
            // Mensaje de bienvenida principal
            const Text(
              '¡Bienvenido a Tickets SSP!',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B), // Gris Slate elegante
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            // Subtexto
            Text(
              'Esta pantalla está lista para ser configurada.\nAquí gestionaremos los reportes de soporte técnico.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
