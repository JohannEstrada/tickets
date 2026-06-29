import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class CloseTicketDialog extends StatefulWidget {
  final Map<String, dynamic> ticket;
  final VoidCallback onSuccess;

  const CloseTicketDialog({
    super.key,
    required this.ticket,
    required this.onSuccess,
  });

  @override
  State<CloseTicketDialog> createState() => _CloseTicketDialogState();
}

class _CloseTicketDialogState extends State<CloseTicketDialog> {
  bool _credencialValidada = false;
  bool _equipoValidado = false;
  String? _nombreConductorValidado;
  String? _vigenciaCredencial;
  bool _isSubmitting = false;

  late final MobileScannerController _scannerController;
  late final TextEditingController _procedimientoController;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController();
    _procedimientoController = TextEditingController();

    final String tipoEquipo = (widget.ticket['tipo_equipo'] ?? '')
        .toString()
        .toUpperCase();
    final bool requiereEquipo =
        !tipoEquipo.contains('LAP') && !tipoEquipo.contains('OTRO');

    _equipoValidado = !requiereEquipo;
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _procedimientoController.dispose();
    super.dispose();
  }

  void _mostrarMensaje(String mensaje, {Color color = Colors.red}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: color,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _escanearQREquipo() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              AppBar(
                title: const Text('Escanear QR de Equipo'),
                backgroundColor: const Color(0xFF0A2E5C),
                foregroundColor: Colors.white,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _scannerController.stop();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              Expanded(
                child: Stack(
                  children: [
                    MobileScanner(
                      controller: _scannerController,
                      onDetect: (capture) {
                        final List<Barcode> barcodes = capture.barcodes;
                        if (barcodes.isNotEmpty &&
                            barcodes.first.rawValue != null) {
                          final String rawValue = barcodes.first.rawValue!
                              .trim();

                          _scannerController.stop();
                          Navigator.of(context).pop();

                          setState(() {
                            _equipoValidado = true;
                          });
                          debugPrint('QR de equipo escaneado: $rawValue');
                        }
                      },
                    ),
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                        ),
                        child: Center(
                          child: Container(
                            width: 250,
                            height: 250,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFF0A2E5C),
                                width: 3,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.qr_code_scanner,
                                  size: 50,
                                  color: Color(0xFF0A2E5C),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Alinee el QR aquí',
                                  style: TextStyle(
                                    color: Color(0xFF0A2E5C),
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _escanearQRValidarCredencial() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              AppBar(
                title: const Text('Escanear Credencial'),
                backgroundColor: const Color(0xFF0A2E5C),
                foregroundColor: Colors.white,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _scannerController.stop();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              Expanded(
                child: Stack(
                  children: [
                    MobileScanner(
                      controller: _scannerController,
                      onDetect: (capture) {
                        final List<Barcode> barcodes = capture.barcodes;
                        if (barcodes.isNotEmpty &&
                            barcodes.first.rawValue != null) {
                          final String rawValue = barcodes.first.rawValue!
                              .trim();

                          _scannerController.stop();
                          Navigator.of(context).pop();

                          _validarQRDirectamente(rawValue);
                        }
                      },
                    ),
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                        ),
                        child: Center(
                          child: Container(
                            width: 250,
                            height: 250,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFF0A2E5C),
                                width: 3,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.qr_code_scanner,
                                  size: 50,
                                  color: Color(0xFF0A2E5C),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Alinee el QR aquí',
                                  style: TextStyle(
                                    color: Color(0xFF0A2E5C),
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _validarQRDirectamente(String qrCompleto) async {
    debugPrint(' INICIO COMPLETO DE VALIDACIÓN QR');
    debugPrint(' QR completo recibido: "$qrCompleto"');

    if (qrCompleto.startsWith('http://') || qrCompleto.startsWith('https://')) {
      debugPrint(' TIPO DETECTADO: QR CON URL (FORMATO NUEVO)');

      final uri = Uri.tryParse(qrCompleto);
      final String? idExtraido = uri?.queryParameters['id'];

      if (idExtraido != null && idExtraido.isNotEmpty) {
        await _enviarDatosApi(idExtraido);
      } else {
        _mostrarMensaje(
          'No se encontró un ID válido en el código QR',
          color: Colors.red,
        );
      }
    } else if (qrCompleto.contains('NOMBRE:') &&
        qrCompleto.contains('VIGENCIA:')) {
      debugPrint('Tipo detectado: QR de texto plano (formato antiguo)');

      String? vigenciaExtraida;
      if (qrCompleto.contains('VIGENCIA:')) {
        final RegExp vigenciaRegex = RegExp(r'VIGENCIA:([^|]+)');
        final Match? match = vigenciaRegex.firstMatch(qrCompleto);
        if (match != null) {
          vigenciaExtraida = match.group(1)?.trim();
        }
      }

      String? nombreExtraido;
      if (qrCompleto.contains('NOMBRE:')) {
        final RegExp nombreRegex = RegExp(r'NOMBRE:([^|]+)');
        final Match? match = nombreRegex.firstMatch(qrCompleto);
        if (match != null) {
          nombreExtraido = match.group(1)?.trim();
        }
      }

      if (nombreExtraido == null || nombreExtraido.isEmpty) {
        _mostrarMensaje(
          'El QR no contiene información de nombre',
          color: Colors.red,
        );
        return;
      }

      if (vigenciaExtraida == null || vigenciaExtraida.isEmpty) {
        _mostrarMensaje(
          'El QR no contiene información de vigencia',
          color: Colors.red,
        );
        return;
      }

      final RegExp mesAnoRegex = RegExp(r'([A-Z]+)\s+(\d{4})');
      final Match? match = mesAnoRegex.firstMatch(
        vigenciaExtraida.toUpperCase(),
      );

      if (match == null) {
        _mostrarMensaje('Formato de vigencia no reconocido', color: Colors.red);
        setState(() {
          _credencialValidada = false;
          _nombreConductorValidado = null;
          _vigenciaCredencial = null;
        });
        return;
      }

      final String mes = match.group(1)!;
      final int ano = int.parse(match.group(2)!);

      final Map<String, int> meses = {
        'ENERO': 1,
        'FEBRERO': 2,
        'MARZO': 3,
        'ABRIL': 4,
        'MAYO': 5,
        'JUNIO': 6,
        'JULIO': 7,
        'AGOSTO': 8,
        'SEPTIEMBRE': 9,
        'OCTUBRE': 10,
        'NOVIEMBRE': 11,
        'DICIEMBRE': 12,
      };

      final int mesNumero = meses[mes] ?? 1;
      final DateTime fechaVigencia = DateTime(
        ano,
        mesNumero + 1,
        0,
      );
      final DateTime fechaActual = DateTime.now();

      if (fechaActual.isAfter(fechaVigencia)) {
        setState(() {
          _credencialValidada = false;
          _nombreConductorValidado = null;
          _vigenciaCredencial = null;
        });
        _mostrarDialogoCredencialVencida(vigenciaExtraida);
      } else {
        setState(() {
          _credencialValidada = true;
          _nombreConductorValidado = nombreExtraido;
          _vigenciaCredencial = vigenciaExtraida;
        });
        _mostrarMensaje(
          'CREDENCIAL VIGENTE\nPersonal atendido: $nombreExtraido',
          color: Colors.green,
        );
      }
    } else {
      _mostrarMensaje(
        'QR no válido o formato no reconocido',
        color: Colors.red,
      );
    }
  }

  Future<void> _enviarDatosApi(String id) async {
    final url = Uri.parse(
      'http://187.216.141.163:8080/api_siarh/api_estatus_conductor.php',
    );
    _mostrarMensaje('Consultando credencial...', color: Colors.blue);

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode({'action': 'get_conductor', 'id': id}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        if (responseData['success'] == true && responseData['data'] != null) {
          final Map<String, dynamic> conductorData = responseData['data'];

          final String nombreCompleto =
              '${conductorData['NOMBRE'] ?? ''} ${conductorData['PATERNO'] ?? ''} ${conductorData['MATERNO'] ?? ''}'
                  .trim();
          final String vigenciaCredencial = conductorData['VIGENCIA'] ?? 'N/A';

          bool fechaVigente = false;
          try {
            final RegExp fechaRegexCompleta = RegExp(
              r'(\d{1,2})/([A-Z]{3})/(\d{4})',
            );
            final Match? matchCompleto = fechaRegexCompleta.firstMatch(
              vigenciaCredencial,
            );

            final Map<String, int> mesesAbrev = {
              'ENE': 1,
              'FEB': 2,
              'MAR': 3,
              'ABR': 4,
              'MAY': 5,
              'JUN': 6,
              'JUL': 7,
              'AGO': 8,
              'SEP': 9,
              'OCT': 10,
              'NOV': 11,
              'DIC': 12,
            };

            if (matchCompleto != null) {
              final int dia = int.parse(matchCompleto.group(1)!);
              final String mesStr = matchCompleto.group(2)!;
              final int ano = int.parse(matchCompleto.group(3)!);

              final int mes = mesesAbrev[mesStr] ?? 1;
              final DateTime fechaVigencia = DateTime(
                ano,
                mes,
                dia,
                23,
                59,
                59,
              );
              fechaVigente = DateTime.now().isBefore(fechaVigencia);
            } else {
              final RegExp fechaRegexMes = RegExp(r'([A-Z]{3})/(\d{4})');
              final Match? matchMes = fechaRegexMes.firstMatch(
                vigenciaCredencial,
              );

              if (matchMes != null) {
                final String mesStr = matchMes.group(1)!;
                final int ano = int.parse(matchMes.group(2)!);

                final int mes = mesesAbrev[mesStr] ?? 1;
                final DateTime fechaVigencia = DateTime(
                  ano,
                  mes + 1,
                  0,
                  23,
                  59,
                  59,
                );
                fechaVigente = DateTime.now().isBefore(fechaVigencia);
              } else {
                final RegExp fechaRegexEspacio = RegExp(
                  r'([A-Z]{3})\s+(\d{4})',
                );
                final Match? matchEspacio = fechaRegexEspacio.firstMatch(
                  vigenciaCredencial,
                );

                if (matchEspacio != null) {
                  final String mesStr = matchEspacio.group(1)!;
                  final int ano = int.parse(matchEspacio.group(2)!);

                  final int mes = mesesAbrev[mesStr] ?? 1;
                  final DateTime fechaVigencia = DateTime(
                    ano,
                    mes + 1,
                    0,
                    23,
                    59,
                    59,
                  );
                  fechaVigente = DateTime.now().isBefore(fechaVigencia);
                }
              }
            }
          } catch (e) {
            debugPrint('🔥 Error parsing date: $e');
          }

          if (fechaVigente) {
            setState(() {
              _credencialValidada = true;
              _nombreConductorValidado = nombreCompleto;
              _vigenciaCredencial = vigenciaCredencial;
            });

            _mostrarMensaje(
              'CREDENCIAL VIGENTE\nPersonal: $nombreCompleto',
              color: Colors.green,
            );
          } else {
            setState(() {
              _credencialValidada = false;
              _nombreConductorValidado = null;
              _vigenciaCredencial = null;
            });
            _mostrarDialogoCredencialVencida(vigenciaCredencial);
          }
        } else {
          final String message =
              responseData['message'] ??
              'No se encontraron detalles para la credencial.';
          _mostrarMensaje('Error en la API: $message', color: Colors.red);
        }
      } else {
        _mostrarMensaje(
          'Error al consultar la credencial: ${response.statusCode}',
          color: Colors.red,
        );
      }
    } catch (e) {
      _mostrarMensaje('Error de conexión al API: $e', color: Colors.red);
    }
  }

  void _mostrarDialogoCredencialVencida(String vigenciaExtraida) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 450),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline,
                  size: 40,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Credencial Vencida',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No se puede registrar el servicio técnico',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Color(0xFF333333)),
              ),
              const SizedBox(height: 8),
              Text(
                'La credencial está vencida\nVigencia: $vigenciaExtraida',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Regresar',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _enviarRespuestaTicket(Map<String, dynamic> ticket) async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('auth_token');

    if (token == null) {
      _mostrarMensaje('Sesión no válida o expirada.', color: Colors.red);
      return false;
    }

    final url = Uri.parse(
      'http://tickets.sspmichoacanlocal.gob.mx/api/respuesta/nuevo',
    );

    final dynamic ticketId = ticket['db_id'] ?? ticket['id'];
    final dynamic userId = ticket['raw']?['user_id'] ?? ticket['user_id'];
    final String respuesta = _procedimientoController.text.trim().toUpperCase();

    if (respuesta.isEmpty) {
      _mostrarMensaje(
        'Por favor escriba el procedimiento realizado.',
        color: Colors.red,
      );
      return false;
    }

    final Map<String, dynamic> requestBody = {
      'respuesta': respuesta,
      'ticket_id': int.tryParse(ticketId.toString()) ?? ticketId,
      'user_id': int.tryParse(userId.toString()) ?? userId,
      'estado_id': 5,
    };

    debugPrint('-----------------------------------------');
    debugPrint('📤 ENVIANDO POST A: $url');
    debugPrint('🔑 Token: Bearer $token');
    debugPrint('📦 Body: ${jsonEncode(requestBody)}');
    debugPrint('-----------------------------------------');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      debugPrint('📥 RESPUESTA POST - STATUS CODE: ${response.statusCode}');
      debugPrint('📥 RESPUESTA POST - BODY: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        _mostrarMensaje(
          'Procedimiento registrado con éxito.',
          color: Colors.green,
        );
        return true;
      } else {
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        final String errorMsg =
            errorData['message'] ??
            'Error desconocido al guardar el procedimiento';
        _mostrarMensaje('Servidor: $errorMsg', color: Colors.red);
        return false;
      }
    } catch (e) {
      _mostrarMensaje(
        'Error de red al registrar respuesta: $e',
        color: Colors.red,
      );
      return false;
    }
  }

  Future<bool> _actualizarEstadoTicket(Map<String, dynamic> ticket) async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('auth_token');

    if (token == null) {
      _mostrarMensaje('Sesión no válida o expirada.', color: Colors.red);
      return false;
    }

    final dynamic ticketId = ticket['db_id'] ?? ticket['id'];
    final url = Uri.parse(
      'http://tickets.sspmichoacanlocal.gob.mx/api/tickets/actualizar/$ticketId',
    );

    final Map<String, dynamic> requestBody = {'estado_actual': 5};

    debugPrint('-----------------------------------------');
    debugPrint('📤 ENVIANDO PUT A: $url');
    debugPrint('🔑 Token: Bearer $token');
    debugPrint('📦 Body: ${jsonEncode(requestBody)}');
    debugPrint('-----------------------------------------');

    try {
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      debugPrint('📥 RESPUESTA PUT - STATUS CODE: ${response.statusCode}');
      debugPrint('📥 RESPUESTA PUT - BODY: ${response.body}');

      if (response.statusCode == 200) {
        _mostrarMensaje('Ticket cerrado correctamente.', color: Colors.green);
        return true;
      } else {
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        final String errorMsg =
            errorData['message'] ?? 'Error desconocido al actualizar el estado';
        _mostrarMensaje('Servidor: $errorMsg', color: Colors.red);
        return false;
      }
    } catch (e) {
      _mostrarMensaje(
        'Error de red al actualizar estado: $e',
        color: Colors.red,
      );
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      elevation: 15,
      backgroundColor: Colors.white,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Cerrar Ticket',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0A2E5C),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.grey,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'DESCRIPCIÓN COMPLETA DE LA FALLA:',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Text(
                  widget.ticket['descripcion'] ?? 'Sin descripción disponible',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF334155),
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'PROCEDIMIENTO HECHO:',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _procedimientoController,
                maxLines: 2,
                minLines: 2,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF1E293B),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[a-zA-ZÁÉÍÓÚÑáéíóúñ\s]'),
                  ),
                  TextInputFormatter.withFunction(
                    (oldValue, newValue) => TextEditingValue(
                      text: newValue.text.toUpperCase(),
                      selection: newValue.selection,
                    ),
                  ),
                ],
                decoration: InputDecoration(
                  hintText:
                      'Escriba aquí los detalles del procedimiento realizado...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade400,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Color(0xFF0A2E5C),
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              if (widget.ticket['tipo_equipo'] != null &&
                  !(widget.ticket['tipo_equipo'] as String)
                      .toUpperCase()
                      .contains('LAP') &&
                  !(widget.ticket['tipo_equipo'] as String)
                      .toUpperCase()
                      .contains('OTRO')) ...[
                const SizedBox(height: 20),
                const Text(
                  'VALIDACIÓN DE EQUIPO:',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: _equipoValidado
                          ? [
                              BoxShadow(
                                color: Colors.green.withValues(
                                  alpha: 0.1,
                                ),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _escanearQREquipo,
                      icon: Icon(
                        _equipoValidado
                            ? Icons.check_circle_rounded
                            : Icons.qr_code_scanner_rounded,
                        color: Colors.white,
                      ),
                      label: Text(
                        _equipoValidado
                            ? 'Equipo Validado'
                            : 'Escanear QR de Equipo',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _equipoValidado
                            ? const Color(0xFF059669)
                            : const Color(0xFF0A2E5C),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              const Text(
                'VALIDACIÓN DE CREDENCIAL:',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _credencialValidada
                        ? [
                            BoxShadow(
                              color: Colors.green.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _escanearQRValidarCredencial,
                    icon: Icon(
                      _credencialValidada
                          ? Icons.check_circle_rounded
                          : Icons.qr_code_scanner_rounded,
                      color: Colors.white,
                    ),
                    label: Text(
                      _credencialValidada
                          ? 'Credencial Validada'
                          : 'Escanear QR para Validar',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _credencialValidada
                          ? const Color(0xFF059669)
                          : const Color(0xFF0A2E5C),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
              if (_credencialValidada &&
                  _nombreConductorValidado != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFDCFCE7)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person_rounded,
                        color: Color(0xFF16A34A),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PERSONAL VALIDADO',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF15803D),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _nombreConductorValidado!,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF14532D),
                              ),
                            ),
                            if (_vigenciaCredencial != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Vigencia: $_vigenciaCredencial',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF166534),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_credencialValidada && _equipoValidado) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () async {
                            setState(() {
                              _isSubmitting = true;
                            });

                            final bool exitoPost =
                                await _enviarRespuestaTicket(widget.ticket);
                            if (exitoPost) {
                              final bool exitoPut =
                                  await _actualizarEstadoTicket(widget.ticket);
                              if (exitoPut && context.mounted) {
                                Navigator.pop(context);
                                widget.onSuccess();
                              }
                            }

                            setState(() {
                              _isSubmitting = false;
                            });
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A2E5C),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'CERRAR TICKET',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
